import 'dart:math';

import 'package:flutter/foundation.dart';

import 'models.dart';

/// 画面が使うデータの窓口。
///
/// いまは仮のデータ（モック）で動く。バックエンドができたら、
/// このクラスの中身だけを Firebase / Cloud Run の呼び出しに差し替える。
/// 画面側のコードは変えなくてよいように、公開しているメソッドの形は保つ。
class AppRepository extends ChangeNotifier {
  AppRepository({DateTime Function()? clock, Random? random})
      : _clock = clock ?? DateTime.now,
        _random = random ?? Random() {
    _seed();
  }

  final DateTime Function() _clock;
  final Random _random;

  DateTime get today {
    final now = _clock();
    return DateTime(now.year, now.month, now.day);
  }

  // ---- ログイン -------------------------------------------------------

  bool _signedIn = false;
  bool get signedIn => _signedIn;

  String _userName = '';
  String get userName => _userName;
  String get userInitial => _userName.isEmpty ? '?' : _userName.substring(0, 1);

  /// TODO(backend): Firebase Authentication の Google ログインに置き換える
  Future<void> signIn() async {
    await Future<void>.delayed(const Duration(milliseconds: 600));
    _signedIn = true;
    _userName = 'こうたろう';
    notifyListeners();
  }

  void signOut() {
    _signedIn = false;
    notifyListeners();
  }

  // ---- 自分のアイコン（写真） -------------------------------------------

  /// 写真のサイズの上限。端末側で縮小してから渡すので、通常はこれより小さい
  static const maxAvatarBytes = 2 * 1024 * 1024;

  Uint8List? _avatar;

  /// 自分で選んだアイコンの写真（未設定なら null）
  Uint8List? get avatar => _avatar;

  /// アイコンの写真を設定する。大きすぎる写真は [ArgumentError] を投げる。
  ///
  /// TODO(backend): Cloud Storage にアップロードし、URL をプロフィールに保存する。
  /// 友達の画面にも表示されるので、サーバー側でも画像形式とサイズを確認する。
  Future<void> setAvatar(Uint8List bytes) async {
    if (bytes.isEmpty || bytes.length > maxAvatarBytes) {
      throw ArgumentError('写真が大きすぎます');
    }
    _avatar = bytes;
    notifyListeners();
  }

  void clearAvatar() {
    _avatar = null;
    notifyListeners();
  }

  // ---- 振った記録 -----------------------------------------------------

  final Map<DateTime, ShakeLog> _logs = {};

  /// 日付ごとの記録（カレンダー用）
  Map<DateTime, ShakeLog> get logs => Map.unmodifiable(_logs);

  int _points = 120;
  int get points => _points;

  bool get shookToday => _logs.containsKey(today);

  /// 今日（まだなら昨日）までの連続日数
  int get streak {
    var day = shookToday ? today : today.subtract(const Duration(days: 1));
    var count = 0;
    while (_logs.containsKey(day)) {
      count++;
      day = day.subtract(const Duration(days: 1));
    }
    return count;
  }

  int get totalDays => _logs.length;

  /// 今週（月曜はじまり）振った日数
  int get daysThisWeek {
    final monday = today.subtract(Duration(days: today.weekday - 1));
    return List.generate(7, (i) => monday.add(Duration(days: i)))
        .where(_logs.containsKey)
        .length;
  }

  int get totalCheers =>
      _logs.values.fold(0, (sum, log) => sum + log.cheerWith.length);

  /// シェイカーを振ったことを記録する。
  ///
  /// TODO(backend): Cloud Run の API を呼ぶ。乾杯の判定（フォロー中の友達が
  /// 数秒以内に振ったか）とログインボーナスの計算はサーバー側で行う。
  Future<ShakeResult> recordShake() async {
    await Future<void>.delayed(const Duration(milliseconds: 500));
    final firstToday = !shookToday;

    // モック：いま振っている友達がいれば乾杯成立。いなければ半分の確率で成立
    final following = _friends.where((f) => f.following).toList();
    final shaking = following.where((f) => f.shakingNow).toList();
    final String? cheer = shaking.isNotEmpty
        ? shaking.first.name
        : (following.isNotEmpty && _random.nextBool()
            ? following[_random.nextInt(following.length)].name
            : null);

    final previous = _logs[today]?.cheerWith ?? const <String>[];
    _logs[today] = ShakeLog(
      date: today,
      cheerWith: [
        ...previous,
        if (cheer != null && !previous.contains(cheer)) cheer,
      ],
    );

    var bonus = 0;
    if (firstToday) {
      bonus = 10 + (streak % 7 == 0 ? 50 : 0); // 7日ごとに追加ボーナス
      _points += bonus;
    }
    if (cheer != null) {
      _feed.insert(
        0,
        FeedItem(
          kind: FeedKind.cheer,
          friendName: cheer,
          text: '$cheerと乾杯した',
          at: _clock(),
        ),
      );
    }
    notifyListeners();
    return ShakeResult(
      firstToday: firstToday,
      streak: streak,
      bonusPoints: bonus,
      cheerWith: cheer,
    );
  }

  // ---- 友達 -----------------------------------------------------------

  final List<Friend> _friends = [];
  List<Friend> get friends => List.unmodifiable(_friends);
  List<Friend> get following =>
      _friends.where((f) => f.following).toList(growable: false);

  /// いま振っているフォロー中の友達（ホームの「乾杯チャンス」用）
  Friend? get shakingFriend {
    for (final f in _friends) {
      if (f.following && f.shakingNow) return f;
    }
    return null;
  }

  final List<FeedItem> _feed = [];
  List<FeedItem> get feed => List.unmodifiable(_feed);

  /// TODO(backend): フォロー API に置き換える
  void toggleFollow(String friendId) {
    final i = _friends.indexWhere((f) => f.id == friendId);
    if (i < 0) return;
    _friends[i] = _friends[i].copyWith(following: !_friends[i].following);
    notifyListeners();
  }

  // ---- 好きなプロテイン・ふりかえり -------------------------------------

  Protein? _favorite;
  Protein? get favoriteProtein => _favorite;

  /// プロテインの袋の写真から、商品名などを読み取って登録する。
  ///
  /// TODO(backend): 写真を Cloud Run に送り、Gemini で読み取った結果を返す。
  Future<Protein> scanProtein() async {
    await Future<void>.delayed(const Duration(milliseconds: 1500));
    const result =
        Protein(name: 'ホエイプロテイン', flavor: 'ココア味', proteinGrams: 20);
    _favorite = result;
    notifyListeners();
    return result;
  }

  /// 今週のふりかえり文。
  ///
  /// TODO(backend): 記録をもとに Gemini が作った文章を返す。
  String get weeklySummary {
    final days = daysThisWeek;
    final left = max(0, 5 - days);
    return left == 0
        ? '今週は $days日 振れました。目標の 5日 を達成。この調子で続けよう。'
        : '今週は $days日 振れました。あと $left日 で目標の 5日 に届きます。';
  }

  // ---- 仮データ -------------------------------------------------------

  void _seed() {
    _friends.addAll(const [
      Friend(id: 'u1', name: 'たろう', following: true),
      Friend(
        id: 'u2',
        name: 'はなこ',
        following: true,
        shakingNow: true,
        shookToday: true,
      ),
      Friend(id: 'u3', name: 'けんた'),
      Friend(id: 'u4', name: 'みさき'),
    ]);

    // 昨日までの 3 日連続 ＋ とびとびの記録
    for (final daysAgo in [1, 2, 3, 5, 8, 9, 12]) {
      final day = today.subtract(Duration(days: daysAgo));
      _logs[day] = ShakeLog(
        date: day,
        cheerWith: daysAgo == 2 ? const ['たろう'] : const [],
      );
    }

    final now = _clock();
    _feed.addAll([
      FeedItem(
        kind: FeedKind.shake,
        friendName: 'はなこ',
        text: 'はなこが今日のプロテインを振った',
        at: now.subtract(const Duration(minutes: 40)),
      ),
      FeedItem(
        kind: FeedKind.cheer,
        friendName: 'たろう',
        text: 'たろうと乾杯した',
        at: now.subtract(const Duration(days: 2)),
      ),
      FeedItem(
        kind: FeedKind.streak,
        friendName: 'たろう',
        text: 'たろうが 7日連続を達成',
        at: now.subtract(const Duration(days: 3)),
      ),
    ]);
  }
}
