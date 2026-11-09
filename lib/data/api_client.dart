import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:http/http.dart' as http;

/// バックエンドが返したエラー（docs/api-contract.md の「エラー」）。
///
/// [statusCode] が 0 のときは、サーバーまで届かなかった（通信できない・時間切れ）。
class ApiException implements Exception {
  const ApiException({
    required this.statusCode,
    this.code = '',
    this.message = '',
  });

  const ApiException.network([String detail = ''])
    : this(statusCode: 0, code: 'NETWORK', message: detail);

  final int statusCode;

  /// サーバーの `error.code`（`TOO_LARGE` など）
  final String code;

  /// サーバーの `error.message`
  final String message;

  bool get isUnauthenticated => statusCode == 401;

  /// 画面に出す文言。契約のエラー表の「フロントの表示」の列
  String get userMessage => switch (statusCode) {
    0 => '通信できませんでした。電波を確認してください',
    400 => '入力を確認してください',
    401 => 'ログインし直してください',
    403 => 'この操作はできません',
    404 => '見つかりません',
    413 => '写真が大きすぎます',
    422 => '読み取れませんでした。撮り直してください',
    429 => '少し待ってからもう一度',
    503 => 'いまは使えません。時間をおいてください',
    _ => message.isNotEmpty ? message : 'エラーが起きました（$statusCode）',
  };

  @override
  String toString() => 'ApiException($statusCode $code: $message)';
}

/// 画面に出すエラーの文言を決める。API 以外のエラーにも短い文を返す
String messageForError(Object error) {
  if (error is ApiException) return error.userMessage;
  if (error is ArgumentError) {
    return error.message?.toString() ?? '入力を確認してください';
  }
  if (error is StateError) return error.message;
  if (error is UnsupportedError) return error.message ?? 'この操作はできません';
  if (error is TimeoutException) return '時間がかかりすぎています。もう一度試してください';
  return '問題が起きました。もう一度試してください';
}

/// バックエンド API を呼ぶ HTTP クライアント。
///
/// 毎回 `Authorization: Bearer <ID トークン>` を付ける（契約の「共通」）。
/// トークンは [readIdToken] から都度もらう（Firebase が期限切れを自動で取り直すため、
/// ここでは保持しない）。
class ApiClient {
  ApiClient({
    required String baseUrl,
    required this.readIdToken,
    http.Client? httpClient,
    this.onUnauthenticated,
    this.timeout = const Duration(seconds: 20),
  }) : baseUri = Uri.base.resolve(baseUrl),
       _http = httpClient ?? http.Client();

  /// API の土台。`/api` のような相対指定は、Web ではページの URL を基準にする
  final Uri baseUri;

  final Future<String?> Function() readIdToken;

  /// 401 が返ったとき（ログイン画面へ戻すため）
  final void Function()? onUnauthenticated;

  /// POST /shakes はサーバーが相手の振りを最大 5 秒待つので、それより十分長くする
  final Duration timeout;

  final http.Client _http;

  Uri resolve(String path, [Map<String, String>? query]) {
    final basePath = baseUri.path.endsWith('/')
        ? baseUri.path.substring(0, baseUri.path.length - 1)
        : baseUri.path;
    return baseUri.replace(
      path: '$basePath$path',
      queryParameters: query,
      fragment: null,
    );
  }

  Future<Object?> getJson(String path, {Map<String, String>? query}) async {
    return _decodeJson(await _send('GET', resolve(path, query)));
  }

  Future<Object?> postJson(String path, {Object? body}) async {
    return _decodeJson(await _send('POST', resolve(path), json: body));
  }

  Future<Object?> putJson(String path, {Object? body}) async {
    return _decodeJson(await _send('PUT', resolve(path), json: body));
  }

  Future<Object?> putBytes(
    String path,
    Uint8List bytes, {
    required String contentType,
  }) async {
    return _decodeJson(
      await _send('PUT', resolve(path), bytes: bytes, contentType: contentType),
    );
  }

  Future<Object?> postBytes(
    String path,
    Uint8List bytes, {
    required String contentType,
  }) async {
    return _decodeJson(
      await _send(
        'POST',
        resolve(path),
        bytes: bytes,
        contentType: contentType,
      ),
    );
  }

  Future<void> delete(String path) async {
    await _send('DELETE', resolve(path));
  }

  /// 画像などをトークン付きで取りに行く（`GET /avatars/{userId}`）。
  ///
  /// トークンを他のサイトへ送らないように、API と同じ起点（scheme + host + port）の
  /// URL だけを受け付ける。
  Future<Uint8List> fetchBytes(Uri url) async {
    if (url.origin != baseUri.origin) {
      throw ApiException(
        statusCode: 0,
        code: 'FOREIGN_ORIGIN',
        message: 'API 以外の場所（${url.origin}）にはトークンを送らない',
      );
    }
    final response = await _send('GET', url);
    return response.bodyBytes;
  }

  void close() => _http.close();

  Future<http.Response> _send(
    String method,
    Uri url, {
    Object? json,
    Uint8List? bytes,
    String? contentType,
  }) async {
    final token = await readIdToken();
    if (token == null) {
      onUnauthenticated?.call();
      throw const ApiException(
        statusCode: 401,
        code: 'UNAUTHENTICATED',
        message: 'ログインが必要です',
      );
    }
    final request = http.Request(method, url)
      ..headers['Authorization'] = 'Bearer $token'
      ..headers['Accept'] = 'application/json';
    if (bytes != null) {
      request.headers['Content-Type'] =
          contentType ?? 'application/octet-stream';
      request.bodyBytes = bytes;
    } else if (json != null) {
      request.headers['Content-Type'] = 'application/json';
      request.body = jsonEncode(json);
    }

    final http.Response response;
    try {
      final streamed = await _http.send(request).timeout(timeout);
      response = await http.Response.fromStream(streamed).timeout(timeout);
    } on TimeoutException {
      throw const ApiException.network('時間切れ');
    } on http.ClientException catch (error) {
      throw ApiException.network(error.message);
    } catch (error) {
      // dart:io の SocketException は Web では import できないので、型で分けずにまとめる
      throw ApiException.network('$error');
    }

    if (response.statusCode >= 200 && response.statusCode < 300) {
      return response;
    }
    final failure = _errorFrom(response);
    if (failure.isUnauthenticated) onUnauthenticated?.call();
    throw failure;
  }

  ApiException _errorFrom(http.Response response) {
    var code = '';
    var message = '';
    try {
      // FastAPI は charset を付けないので、response.body（latin1 扱い）ではなく bytes から読む
      final decoded = jsonDecode(utf8.decode(response.bodyBytes));
      if (decoded is Map && decoded['error'] is Map) {
        final error = decoded['error'] as Map;
        code = '${error['code'] ?? ''}';
        message = '${error['message'] ?? ''}';
      }
    } on FormatException {
      message = '';
    }
    return ApiException(
      statusCode: response.statusCode,
      code: code,
      message: message,
    );
  }

  static Object? _decodeJson(http.Response response) {
    if (response.bodyBytes.isEmpty || response.statusCode == 204) return null;
    return jsonDecode(utf8.decode(response.bodyBytes));
  }
}
