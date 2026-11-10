import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:protein_app/data/api_client.dart';
import 'package:protein_app/data/api_repository.dart';
import 'package:protein_app/data/models.dart';

/// 2026-11-07（土）を「今日」として固定する
DateTime fixedNow() => DateTime(2026, 11, 7, 12);

const pngHeader = [0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A, 1, 2, 3];

/// バックエンドの代わり。受け取ったリクエストを覚え、決めた応答を返す
class FakeBackend {
  final requests = <http.Request>[];
  final responses = <String, http.Response Function(http.Request)>{};

  Map<String, Object?> me = {
    'id': 'u1',
    'name': 'こうたろう',
    'avatarUrl': null,
    'points': 120,
    'streak': 2,
    'bestStreak': 2,
    'shookToday': false,
    'totalDays': 6,
    'totalCheers': 0,
    'daysThisWeek': 2,
    'favoriteProtein': null,
  };

  http.Client get client => MockClient((request) async {
    requests.add(request);
    final key = '${request.method} ${request.url.path}';
    final handler = responses[key];
    if (handler != null) return handler(request);
    return switch (key) {
      'GET /me' => json(me),
      'GET /shakes' => json([
        {'date': '2026-11-05', 'cheerWith': <String>[]},
        {
          'date': '2026-11-06',
          'cheerWith': ['はなこ'],
        },
      ]),
      'GET /friends' => json([
        {
          'id': 'u2',
          'name': 'はなこ',
          'avatarUrl': 'http://api.test/avatars/u2?v=1',
          'following': true,
          'shakingNow': true,
          'shookToday': true,
        },
      ]),
      'GET /feed' => json([
        {
          'kind': 'cheer',
          'friend': {'id': 'u2', 'name': 'はなこ'},
          'text': 'はなこさんと乾杯しました',
          'at': '2026-11-06T10:00:00Z',
        },
      ]),
      'GET /me/weekly-summary' => json({
        'text': '今週は 2日 振れました。',
        'model': 'fake',
        'generatedAt': '2026-11-07T00:00:00Z',
      }),
      'GET /avatars/u2' => http.Response.bytes(pngHeader, 200),
      _ => http.Response('{"error":{"code":"NOT_FOUND","message":"x"}}', 404),
    };
  });

  static http.Response json(Object body, [int status = 200]) =>
      http.Response.bytes(
        utf8.encode(jsonEncode(body)),
        status,
        headers: {'content-type': 'application/json'},
      );

  static http.Response error(int status, String code, String message) => json({
    'error': {'code': code, 'message': message},
  }, status);

  http.Request requestOf(String key) => requests.firstWhere(
    (r) => '${r.method} ${r.url.path}' == key,
    orElse: () => throw StateError('$key は呼ばれていない'),
  );
}

Future<ApiAppRepository> signedInRepo(FakeBackend backend) async {
  final repo = ApiAppRepository(
    baseUrl: 'http://api.test',
    allowDevSignIn: true,
    httpClient: backend.client,
    friendsPollInterval: null,
    clock: fixedNow,
  );
  await repo.signInForDevelopment(uid: 'u1', name: 'こうたろう');
  // ログイン直後に裏で始まる読み込み（今月の記録・友達・タイムラインなど）を待つ
  await Future<void>.delayed(Duration.zero);
  await Future<void>.delayed(Duration.zero);
  return repo;
}

void main() {
  group('ログイン', () {
    test('開発用ログインは dev トークンを付けて GET /me を呼び、数字をそのまま持つ', () async {
      final backend = FakeBackend();
      final repo = await signedInRepo(backend);
      expect(repo.signedIn, isTrue);
      expect(repo.userName, 'こうたろう');
      expect(repo.points, 120);
      expect(repo.streak, 2);
      expect(repo.totalDays, 6);
      expect(repo.stage.name, 'ちょいマッチョ');
      expect(
        backend.requestOf('GET /me').headers['Authorization'],
        'Bearer dev:u1:${Uri.encodeComponent('こうたろう')}',
      );
    });

    test('ログイン直後に今月の記録・友達・タイムライン・ふりかえりを読み込む', () async {
      final backend = FakeBackend();
      final repo = await signedInRepo(backend);
      expect(
        backend.requestOf('GET /shakes').url.queryParameters['month'],
        '2026-11',
      );
      expect(repo.logs[DateTime(2026, 11, 6)]?.cheerWith, ['はなこ']);
      expect(repo.friends.single.name, 'はなこ');
      expect(repo.shakingFriend?.name, 'はなこ');
      expect(repo.feed.single.kind, FeedKind.cheer);
      expect(repo.weeklySummary, '今週は 2日 振れました。');
    });

    test('401 が返るとログアウト状態になる', () async {
      final backend = FakeBackend();
      final repo = await signedInRepo(backend);
      backend.responses['POST /shakes'] = (_) =>
          FakeBackend.error(401, 'UNAUTHENTICATED', 'ログインが必要です');
      await expectLater(repo.recordShake(), throwsA(isA<ApiException>()));
      expect(repo.signedIn, isFalse);
      expect(repo.friends, isEmpty);
    });

    test('GET /me に失敗したらログインしたことにしない', () async {
      final backend = FakeBackend();
      backend.responses['GET /me'] = (_) =>
          FakeBackend.error(503, 'AI_UNAVAILABLE', 'down');
      final repo = ApiAppRepository(
        baseUrl: 'http://api.test',
        allowDevSignIn: true,
        httpClient: backend.client,
        friendsPollInterval: null,
        clock: fixedNow,
      );
      await expectLater(
        repo.signInForDevelopment(uid: 'u1', name: 'x'),
        throwsA(isA<ApiException>()),
      );
      expect(repo.signedIn, isFalse);
    });
  });

  group('振る', () {
    test('応答の数字から、成長と新しいバッジを端末側で決める', () async {
      final backend = FakeBackend();
      final repo = await signedInRepo(backend);
      backend.responses['POST /shakes'] = (_) => FakeBackend.json({
        'firstToday': true,
        'streak': 3,
        'bonusPoints': 10,
        'cheerWith': {'id': 'u2', 'name': 'はなこ'},
        'points': 130,
        'totalDays': 7,
        'bestStreak': 3,
        'totalCheers': 1,
      });

      final result = await repo.recordShake();

      expect(result.firstToday, isTrue);
      expect(result.streak, 3);
      expect(result.bonusPoints, 10);
      expect(result.cheerWith, 'はなこ');
      // 6 日 → 7 日で「細マッチョ」に成長
      expect(result.levelUpTo?.name, '細マッチョ');
      expect(
        result.newAchievements,
        containsAll(['3日つづいた', 'はじめての乾杯', '細マッチョ到達']),
      );
      expect(repo.points, 130);
      expect(repo.shookToday, isTrue);
      expect(repo.daysThisWeek, 3);
      expect(repo.logs[DateTime(2026, 11, 7)]?.cheerWith, ['はなこ']);
    });

    test('連打で 429 が返ると「少し待ってからもう一度」になる', () async {
      final backend = FakeBackend();
      final repo = await signedInRepo(backend);
      backend.responses['POST /shakes'] = (_) =>
          FakeBackend.error(429, 'TOO_MANY', '少し待ってからもう一度');
      await expectLater(
        repo.recordShake(),
        throwsA(
          isA<ApiException>().having(
            (e) => e.userMessage,
            'userMessage',
            '少し待ってからもう一度',
          ),
        ),
      );
      expect(repo.signedIn, isTrue);
    });
  });

  group('アイコン', () {
    test('友達のアイコンはトークン付きで取りに行き、2 回目は覚えている分を返す', () async {
      final backend = FakeBackend();
      final repo = await signedInRepo(backend);
      final hanako = repo.friends.single;
      expect(repo.avatarOf(hanako), isNull); // 取りに行き始めたところ
      await Future<void>.delayed(Duration.zero);
      expect(repo.avatarOf(hanako), Uint8List.fromList(pngHeader));
      final request = backend.requestOf('GET /avatars/u2');
      expect(request.headers['Authorization'], startsWith('Bearer dev:u1:'));
      expect(
        backend.requests.where((r) => r.url.path == '/avatars/u2').length,
        1,
      );
    });

    test('自分のアイコンは PUT /me/avatar に送り、返った URL を覚える', () async {
      final backend = FakeBackend();
      final repo = await signedInRepo(backend);
      backend.responses['PUT /me/avatar'] = (_) =>
          FakeBackend.json({'avatarUrl': 'http://api.test/avatars/u1?v=2'});
      final photo = Uint8List.fromList(pngHeader);
      await repo.setAvatar(photo);
      expect(repo.hasAvatar, isTrue);
      expect(repo.avatar, photo);
      expect(repo.earnedAchievementIds, contains('avatar'));
      expect(
        backend.requestOf('PUT /me/avatar').headers['Content-Type'],
        'image/png',
      );
    });

    test('写真でないバイト列は送る前に断る', () async {
      final backend = FakeBackend();
      final repo = await signedInRepo(backend);
      await expectLater(
        repo.setAvatar(Uint8List.fromList([1, 2, 3])),
        throwsArgumentError,
      );
    });
  });

  group('友達・招待', () {
    test('招待リンクを作り、受け取ると相互フォローの相手が返る', () async {
      final backend = FakeBackend();
      final repo = await signedInRepo(backend);
      backend.responses['POST /invites'] = (_) =>
          FakeBackend.json({'url': 'http://app.test/invite/abc'});
      backend.responses['POST /invites/abc/accept'] = (_) => FakeBackend.json({
        'friend': {'id': 'u9', 'name': 'たろう'},
      });
      expect(await repo.createInviteLink(), 'http://app.test/invite/abc');
      final friend = await repo.acceptInvite('abc');
      expect(friend.name, 'たろう');
      expect(friend.following, isTrue);
    });

    test('フォロー解除は DELETE /follows/{id} を呼ぶ', () async {
      final backend = FakeBackend();
      final repo = await signedInRepo(backend);
      backend.responses['DELETE /follows/u2'] = (_) => http.Response('', 204);
      await repo.toggleFollow('u2');
      expect(backend.requestOf('DELETE /follows/u2'), isNotNull);
      expect(repo.friends.single.following, isFalse);
    });
  });

  group('好きなプロテイン', () {
    test('読み取りは保存せず、保存すると数字とバッジが変わる', () async {
      final backend = FakeBackend();
      final repo = await signedInRepo(backend);
      backend.responses['POST /protein/scan'] = (_) => FakeBackend.json({
        'name': 'ソイプロテイン',
        'flavor': '抹茶味',
        'proteinGrams': 18,
      });
      backend.responses['PUT /me/favorite-protein'] = (_) =>
          http.Response('', 204);
      final protein = await repo.scanProtein(Uint8List.fromList(pngHeader));
      expect(protein.flavor, '抹茶味');
      expect(repo.favoriteProtein, isNull);
      await repo.saveFavoriteProtein(protein);
      expect(repo.favoriteProtein?.flavor, '抹茶味');
      expect(repo.earnedAchievementIds, contains('favorite'));
      expect(jsonDecode(backend.requestOf('PUT /me/favorite-protein').body), {
        'name': 'ソイプロテイン',
        'flavor': '抹茶味',
        'proteinGrams': 18,
      });
    });

    test('422 は「読み取れませんでした。撮り直してください」になる', () async {
      final backend = FakeBackend();
      final repo = await signedInRepo(backend);
      backend.responses['POST /protein/scan'] = (_) =>
          FakeBackend.error(422, 'UNREADABLE', 'x');
      await expectLater(
        repo.scanProtein(Uint8List.fromList(pngHeader)),
        throwsA(
          isA<ApiException>().having(
            (e) => e.userMessage,
            'userMessage',
            '読み取れませんでした。撮り直してください',
          ),
        ),
      );
    });
  });

  group('ApiClient', () {
    test('API 以外の場所にはトークンを送らない', () async {
      final client = ApiClient(
        baseUrl: 'http://api.test',
        readIdToken: () async => 'dev:u1:x',
        httpClient: MockClient((_) async => http.Response('', 200)),
      );
      await expectLater(
        client.fetchBytes(Uri.parse('http://evil.test/avatars/u1')),
        throwsA(isA<ApiException>()),
      );
    });

    test('/api のような相対指定でも道筋をつなげる', () {
      final client = ApiClient(
        baseUrl: 'http://host.test/api',
        readIdToken: () async => null,
      );
      expect(client.resolve('/me').toString(), 'http://host.test/api/me');
      expect(
        client.resolve('/shakes', {'month': '2026-11'}).toString(),
        'http://host.test/api/shakes?month=2026-11',
      );
    });

    test('契約のエラー表の文言を返す', () {
      expect(const ApiException(statusCode: 413).userMessage, '写真が大きすぎます');
      expect(
        const ApiException(statusCode: 503).userMessage,
        'いまは使えません。時間をおいてください',
      );
      expect(const ApiException.network().userMessage, contains('通信できませんでした'));
    });
  });
}
