import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import '../photo/photo_picker.dart';
import 'api_client.dart';
import 'app_repository.dart';
import 'auth.dart';
import 'models.dart';
import 'progress.dart';

/// バックエンド API（docs/api-contract.md）につながる窓口。
///
/// 数字（ポイント・連続日数・合計日数・乾杯回数）はサーバーが数えたものをそのまま持ち、
/// 端末では計算し直さない。端末で決めるのは、成長段階・バッジ・色のように
/// 数字から機械的に決まるものだけ（AppRepository の共通部分）。
class ApiAppRepository extends AppRepository {
  ApiAppRepository({
    required String baseUrl,
    this.googleAuth,
    this.allowDevSignIn = false,
    http.Client? httpClient,
    this.friendsPollInterval = const Duration(seconds: 4),
    super.clock,
  }) {
    _api = ApiClient(
      baseUrl: baseUrl,
      readIdToken: () async => _auth?.idToken(),
      httpClient: httpClient,
      onUnauthenticated: _leaveSignedIn,
    );
  }

  /// `GET /friends` を読み直す間隔。null なら読み直さない（テスト用）
  final Duration? friendsPollInterval;

  /// 間隔何回ごとに、自分の数字・タイムライン・今月の記録も読み直すか
  static const slowRefreshEvery = 8;

  /// 袋の写真はこの大きさまでそのまま送る（契約の POST /protein/scan は 10MB まで）
  static const maxScanBytes = 10 * 1024 * 1024;

  late final ApiClient _api;

  /// Google ログインの窓口。Firebase の設定が無いときは null
  final AuthGateway? googleAuth;

  /// Firebase なしの開発用ログインを許すか（DEV_TOOLS=true のときだけ）
  final bool allowDevSignIn;

  AuthGateway? _auth;
  Profile? _profile;
  bool _signedIn = false;

  final Map<DateTime, ShakeLog> _logs = {};
  final Set<String> _loadedMonths = {};
  final Set<String> _loadingMonths = {};

  List<Friend> _friends = const [];
  List<FeedItem> _feed = const [];

  final Map<String, Uint8List> _avatarBytesByUrl = {};
  final Set<String> _avatarUrlsLoading = {};
  final Set<String> _avatarUrlsFailed = {};

  String? _weeklySummary;
  String? _weeklySummaryError;

  Timer? _pollTimer;
  int _pollCount = 0;

  // ---- ログイン -------------------------------------------------------

  @override
  bool get signedIn => _signedIn;

  @override
  String get userName => _profile?.name ?? _auth?.currentUser?.name ?? '';

  /// 起動時：前回の Google ログインが残っていれば、そのまま使う
  Future<void> restoreSession() async {
    final google = googleAuth;
    if (google == null) return;
    await google.restoreSession();
    if (google.currentUser == null) return;
    try {
      await _enterSignedIn(google);
    } catch (error) {
      // 復元に失敗してもログイン画面が出るだけ。押し直せばやり直せる
      _report('ログインの復元', error);
    }
  }

  @override
  Future<void> signIn() async {
    final google = googleAuth;
    if (google == null) {
      throw StateError('Google ログインには Firebase の設定（FIREBASE_API_KEY など）が必要です');
    }
    await google.signInWithGoogle();
    await _enterSignedIn(google);
  }

  @override
  bool get supportsDevSignIn => allowDevSignIn;

  @override
  Future<void> signInForDevelopment({
    required String uid,
    required String name,
  }) async {
    if (!allowDevSignIn) {
      throw UnsupportedError('開発用ログインは DEV_TOOLS=true のときだけ使えます');
    }
    await _enterSignedIn(DevAuthGateway(uid: uid, name: name));
  }

  Future<void> _enterSignedIn(AuthGateway auth) async {
    _auth = auth;
    try {
      _profile = Profile.fromJson(_asMap(await _api.getJson('/me')));
    } catch (_) {
      if (identical(_auth, auth)) _auth = null;
      rethrow;
    }
    _signedIn = true;
    notifyListeners();
    _startPolling();
    unawaited(_loadAfterSignIn());
  }

  Future<void> _loadAfterSignIn() async {
    await Future.wait([
      _loadMonth(today),
      _loadMonthOfThisWeeksMondayIfDifferent(),
      _refreshFriends(),
      _refreshFeed(),
      _loadWeeklySummary(),
      _loadAvatarIfAny(_profile?.avatarUrl),
    ]);
  }

  /// ホームの「今週のスタンプ」は月曜から並ぶので、月をまたぐ週は前の月も要る
  Future<void> _loadMonthOfThisWeeksMondayIfDifferent() {
    final monday = today.subtract(Duration(days: today.weekday - 1));
    if (monday.month == today.month) return Future.value();
    return _loadMonth(monday);
  }

  @override
  Future<void> signOut() async {
    final auth = _auth;
    _leaveSignedIn();
    try {
      await auth?.signOut();
    } catch (error) {
      _report('ログアウト', error);
    }
  }

  /// ログイン状態を捨てて、ログイン画面に戻す（401 のときもここに来る）
  void _leaveSignedIn() {
    _stopPolling();
    final wasSignedIn = _signedIn;
    _signedIn = false;
    _profile = null;
    _auth = null;
    _logs.clear();
    _loadedMonths.clear();
    _friends = const [];
    _feed = const [];
    _avatarBytesByUrl.clear();
    _avatarUrlsFailed.clear();
    _weeklySummary = null;
    _weeklySummaryError = null;
    if (wasSignedIn) notifyListeners();
  }

  // ---- 自分のアイコン（写真） -------------------------------------------

  @override
  Uint8List? get avatar {
    final url = _profile?.avatarUrl;
    return url == null ? null : _avatarBytesByUrl[url];
  }

  @override
  bool get hasAvatar => _profile?.avatarUrl != null;

  @override
  Future<void> setAvatar(Uint8List bytes) async {
    if (bytes.isEmpty || bytes.length > AppRepository.maxAvatarBytes) {
      throw ArgumentError('写真が大きすぎます');
    }
    final contentType = detectImageType(bytes);
    if (contentType == null) {
      throw ArgumentError('JPEG か PNG の写真を選んでください');
    }
    final json = _asMap(
      await _api.putBytes('/me/avatar', bytes, contentType: contentType),
    );
    final url = json['avatarUrl'] as String;
    _avatarBytesByUrl[url] = bytes; // 送った写真そのものなので取りに行かない
    _profile = _requireProfile().copyWith(avatarUrl: url);
    notifyListeners();
  }

  @override
  Future<void> clearAvatar() async {
    await _api.delete('/me/avatar');
    _profile = _requireProfile().copyWith(clearAvatarUrl: true);
    notifyListeners();
  }

  @override
  Uint8List? avatarOf(Friend friend) {
    final url = friend.avatarUrl;
    if (url == null) return null;
    final cached = _avatarBytesByUrl[url];
    if (cached == null) unawaited(_loadAvatarIfAny(url));
    return cached;
  }

  Future<void> _loadAvatarIfAny(String? url) async {
    if (url == null ||
        _avatarBytesByUrl.containsKey(url) ||
        _avatarUrlsFailed.contains(url) ||
        !_avatarUrlsLoading.add(url)) {
      return;
    }
    try {
      _avatarBytesByUrl[url] = await _api.fetchBytes(Uri.parse(url));
      notifyListeners();
    } catch (error) {
      // 同じ URL を何度も取りに行かない。更新されると ?v= が変わり、別の URL として再挑戦する
      _avatarUrlsFailed.add(url);
      _report('アイコン $url', error);
    } finally {
      _avatarUrlsLoading.remove(url);
    }
  }

  // ---- 振った記録 -----------------------------------------------------

  @override
  Map<DateTime, ShakeLog> get logs => Map.unmodifiable(_logs);

  @override
  int get points => _profile?.points ?? 0;

  @override
  bool get shookToday => _profile?.shookToday ?? false;

  @override
  int get streak => _profile?.streak ?? 0;

  @override
  int get totalDays => _profile?.totalDays ?? 0;

  @override
  int get bestStreak => _profile?.bestStreak ?? 0;

  @override
  int get totalCheers => _profile?.totalCheers ?? 0;

  @override
  int get daysThisWeek => _profile?.daysThisWeek ?? 0;

  @override
  Future<ShakeResult> recordShake() async {
    final before = achievementStats;
    final wasShookToday = shookToday;
    final json = _asMap(await _api.postJson('/shakes'));
    final firstToday = json['firstToday'] as bool;
    final cheerWith = json['cheerWith'] as Map<String, dynamic>?;
    final cheerName = cheerWith?['name'] as String?;

    _profile = _requireProfile().copyWith(
      points: (json['points'] as num).toInt(),
      streak: (json['streak'] as num).toInt(),
      bestStreak: (json['bestStreak'] as num).toInt(),
      totalDays: (json['totalDays'] as num).toInt(),
      totalCheers: (json['totalCheers'] as num).toInt(),
      shookToday: true,
      daysThisWeek: daysThisWeek + (firstToday && !wasShookToday ? 1 : 0),
    );
    _recordTodayLog(cheerName);
    notifyListeners();

    if (cheerName != null) unawaited(_refreshFeed());
    if (firstToday) unawaited(_loadWeeklySummary());

    return composeShakeResult(
      before: before,
      after: achievementStats,
      firstToday: firstToday,
      streak: _requireProfile().streak,
      bonusPoints: (json['bonusPoints'] as num).toInt(),
      cheerWith: cheerName,
    );
  }

  void _recordTodayLog(String? cheerName) {
    final names = [...?_logs[today]?.cheerWith];
    if (cheerName != null && !names.contains(cheerName)) names.add(cheerName);
    _logs[today] = ShakeLog(date: today, cheerWith: names);
  }

  @override
  void ensureMonthLoaded(DateTime month) {
    if (!_signedIn || _loadedMonths.contains(_monthKey(month))) return;
    unawaited(_loadMonth(month));
  }

  Future<void> _loadMonth(DateTime month) async {
    final key = _monthKey(month);
    if (!_loadingMonths.add(key)) return;
    try {
      final days = _asList(
        await _api.getJson('/shakes', query: {'month': key}),
      );
      _logs.removeWhere(
        (date, _) => date.year == month.year && date.month == month.month,
      );
      for (final day in days) {
        final log = ShakeLog.fromJson(_asMap(day));
        _logs[log.date] = log;
      }
      _loadedMonths.add(key);
      notifyListeners();
    } catch (error) {
      _report('カレンダー $key', error);
    } finally {
      _loadingMonths.remove(key);
    }
  }

  static String _monthKey(DateTime month) =>
      '${month.year}-${month.month.toString().padLeft(2, '0')}';

  // ---- 友達 -----------------------------------------------------------

  @override
  List<Friend> get friends => _friends;

  @override
  List<FeedItem> get feed => _feed;

  @override
  Future<void> toggleFollow(String friendId) async {
    final i = _friends.indexWhere((f) => f.id == friendId);
    if (i < 0) return;
    final friend = _friends[i];
    if (friend.following) {
      await _api.delete('/follows/$friendId');
    } else {
      await _api.putJson('/follows/$friendId');
    }
    _friends = [
      for (final f in _friends)
        f.id == friendId ? f.copyWith(following: !friend.following) : f,
    ];
    notifyListeners();
    unawaited(_refreshFriends());
  }

  @override
  Future<String> createInviteLink() async {
    final json = _asMap(await _api.postJson('/invites'));
    return json['url'] as String;
  }

  @override
  Future<Friend> acceptInvite(String code) async {
    final json = _asMap(await _api.postJson('/invites/$code/accept'));
    final inviter = _asMap(json['friend']);
    unawaited(_refreshFriends());
    unawaited(_refreshFeed());
    return Friend(
      id: inviter['id'] as String,
      name: inviter['name'] as String,
      following: true,
    );
  }

  Future<void> _refreshFriends() async {
    try {
      final friends = [
        for (final f in _asList(await _api.getJson('/friends')))
          Friend.fromJson(_asMap(f)),
      ];
      if (_describe(friends) != _describe(_friends)) {
        _friends = friends;
        notifyListeners();
      }
    } catch (error) {
      _report('友達一覧', error);
    }
  }

  /// 友達一覧が変わったかを見るための文字列（数秒ごとの読み直しで無駄に描き直さないため）
  static String _describe(List<Friend> friends) => [
    for (final f in friends)
      '${f.id}|${f.name}|${f.avatarUrl}|${f.following}|${f.shakingNow}|${f.shookToday}',
  ].join('\n');

  Future<void> _refreshFeed() async {
    try {
      _feed = [
        for (final item in _asList(
          await _api.getJson('/feed', query: {'limit': '20'}),
        ))
          FeedItem.fromJson(_asMap(item)),
      ];
      notifyListeners();
    } catch (error) {
      _report('タイムライン', error);
    }
  }

  Future<void> _refreshProfile() async {
    try {
      final profile = Profile.fromJson(_asMap(await _api.getJson('/me')));
      _profile = profile;
      notifyListeners();
      unawaited(_loadAvatarIfAny(profile.avatarUrl));
    } catch (error) {
      _report('自分の記録', error);
    }
  }

  void _startPolling() {
    final interval = friendsPollInterval;
    if (interval == null || _pollTimer != null) return;
    _pollCount = 0;
    _pollTimer = Timer.periodic(interval, (_) => _onPollTick());
  }

  void _stopPolling() {
    _pollTimer?.cancel();
    _pollTimer = null;
  }

  void _onPollTick() {
    if (!_signedIn) return;
    _pollCount++;
    unawaited(_refreshFriends());
    // 相手側から書かれた乾杯（自分が先に振り、待ち時間を過ぎて成立した分）も拾う
    if (_pollCount % slowRefreshEvery == 0) {
      unawaited(_refreshProfile());
      unawaited(_refreshFeed());
      unawaited(_loadMonth(today));
    }
  }

  // ---- 好きなプロテイン・ふりかえり -------------------------------------

  @override
  Protein? get favoriteProtein => _profile?.favoriteProtein;

  @override
  Future<Protein> scanProtein(Uint8List photo) async {
    final (bytes, contentType) = await _prepareForScan(photo);
    final json = _asMap(
      await _api.postBytes('/protein/scan', bytes, contentType: contentType),
    );
    return Protein.fromJson(json);
  }

  /// JPEG / PNG で 10MB 以内ならそのまま。それ以外（HEIC など・大きすぎる）は縮めて PNG にする
  Future<(Uint8List, String)> _prepareForScan(Uint8List photo) async {
    final contentType = detectImageType(photo);
    if (contentType != null && photo.length <= maxScanBytes) {
      return (photo, contentType);
    }
    // 文字（商品名・たんぱく質量）を読むので、アイコン用の 320px では足りない
    final shrunk = await shrinkPhoto(photo, maxSide: 1280);
    return (shrunk, 'image/png');
  }

  @override
  Future<void> saveFavoriteProtein(Protein protein) async {
    await _api.putJson('/me/favorite-protein', body: protein.toJson());
    _profile = _requireProfile().copyWith(favoriteProtein: protein);
    notifyListeners();
  }

  @override
  String get weeklySummary =>
      _weeklySummary ?? _weeklySummaryError ?? 'ふりかえりを作成中…';

  Future<void> _loadWeeklySummary() async {
    try {
      final json = _asMap(await _api.getJson('/me/weekly-summary'));
      _weeklySummary = json['text'] as String;
      _weeklySummaryError = null;
    } catch (error) {
      _weeklySummaryError = messageForError(error);
      _report('今週のふりかえり', error);
    }
    notifyListeners();
  }

  // ---- 共通 -----------------------------------------------------------

  Profile _requireProfile() {
    final profile = _profile;
    if (profile == null) throw StateError('ログインしていません');
    return profile;
  }

  static Map<String, dynamic> _asMap(Object? value) {
    if (value is Map<String, dynamic>) return value;
    throw const FormatException('API の応答がオブジェクトではありません');
  }

  static List<Object?> _asList(Object? value) {
    if (value is List) return value;
    throw const FormatException('API の応答が配列ではありません');
  }

  void _report(String what, Object error) {
    debugPrint('[api] $what: $error');
  }

  @override
  void dispose() {
    _stopPolling();
    _api.close();
    super.dispose();
  }
}
