import 'dart:math';
import 'dart:typed_data';

import 'app_repository.dart';
import 'models.dart';
import 'progress.dart';

/// 仮のデータ（モック）で動く窓口。
///
/// `--dart-define=API_BASE_URL` を付けずに起動したときに使う。
/// バックエンド無しでも画面の見た目と流れを確かめられるように、
/// 振る・乾杯・フォロー・袋の読み取りをすべて端末の中だけで真似る。
/// ページを読み込み直すと最初の状態に戻る。
class MockAppRepository extends AppRepository {
  MockAppRepository({super.clock, Random? random})
    : _random = random ?? Random() {
    _seed();
  }

  final Random _random;

  // ---- ログイン -------------------------------------------------------

  bool _signedIn = false;

  @override
  bool get signedIn => _signedIn;

  String _userName = '';

  @override
  String get userName => _userName;

  @override
  Future<void> signIn() async {
    await Future<void>.delayed(const Duration(milliseconds: 600));
    _signedIn = true;
    _userName = 'こうたろう';
    notifyListeners();
  }

  @override
  Future<void> signOut() async {
    _signedIn = false;
    notifyListeners();
  }

  // ---- 自分のアイコン（写真） -------------------------------------------

  Uint8List? _avatar;

  @override
  Uint8List? get avatar => _avatar;

  @override
  Future<void> setAvatar(Uint8List bytes) async {
    if (bytes.isEmpty || bytes.length > AppRepository.maxAvatarBytes) {
      throw ArgumentError('写真が大きすぎます');
    }
    _avatar = bytes;
    notifyListeners();
  }

  @override
  Future<void> clearAvatar() async {
    _avatar = null;
    notifyListeners();
  }

  // ---- 振った記録 -----------------------------------------------------

  final Map<DateTime, ShakeLog> _logs = {};

  @override
  Map<DateTime, ShakeLog> get logs => Map.unmodifiable(_logs);

  int _points = 120;

  @override
  int get points => _points;

  @override
  bool get shookToday => _logs.containsKey(today);

  @override
  int get streak {
    var day = shookToday ? today : today.subtract(const Duration(days: 1));
    var count = 0;
    while (_logs.containsKey(day)) {
      count++;
      day = day.subtract(const Duration(days: 1));
    }
    return count;
  }

  @override
  int get totalDays => _logs.length;

  @override
  int get bestStreak {
    final days = _logs.keys.toList()..sort();
    var best = 0, current = 0;
    DateTime? previous;
    for (final d in days) {
      current = (previous != null && d.difference(previous).inDays == 1)
          ? current + 1
          : 1;
      if (current > best) best = current;
      previous = d;
    }
    return best;
  }

  @override
  int get daysThisWeek {
    final monday = today.subtract(Duration(days: today.weekday - 1));
    return List.generate(
      7,
      (i) => monday.add(Duration(days: i)),
    ).where(_logs.containsKey).length;
  }

  @override
  int get totalCheers =>
      _logs.values.fold(0, (sum, log) => sum + log.cheerWith.length);

  @override
  Future<ShakeResult> recordShake() async {
    await Future<void>.delayed(const Duration(milliseconds: 500));
    final firstToday = !shookToday;
    final before = achievementStats;

    // モック：いま振っている友達がいれば乾杯成立。いなければ半分の確率で成立
    final following = this.following;
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
          text: '$cheerさんと乾杯しました',
          at: currentTime,
        ),
      );
    }
    notifyListeners();
    return composeShakeResult(
      before: before,
      after: achievementStats,
      firstToday: firstToday,
      streak: streak,
      bonusPoints: bonus,
      cheerWith: cheer,
    );
  }

  // ---- 友達 -----------------------------------------------------------

  final List<Friend> _friends = [];

  @override
  List<Friend> get friends => List.unmodifiable(_friends);

  final List<FeedItem> _feed = [];

  @override
  List<FeedItem> get feed => List.unmodifiable(_feed);

  @override
  Future<void> toggleFollow(String friendId) async {
    final i = _friends.indexWhere((f) => f.id == friendId);
    if (i < 0) return;
    _friends[i] = _friends[i].copyWith(following: !_friends[i].following);
    notifyListeners();
  }

  @override
  Future<String> createInviteLink() async {
    await Future<void>.delayed(const Duration(milliseconds: 300));
    // Web ならこのページの URL を土台にする（開くと acceptInvite の流れを試せる）
    final base = Uri.base.scheme.startsWith('http')
        ? Uri.base
        : Uri.parse('https://protein-kanpai.example');
    return base.resolve('/invite/demo').toString();
  }

  @override
  Future<Friend> acceptInvite(String code) async {
    await Future<void>.delayed(const Duration(milliseconds: 400));
    final i = _friends.indexWhere((f) => !f.following);
    if (i >= 0) {
      _friends[i] = _friends[i].copyWith(following: true);
    } else {
      _friends.add(const Friend(id: 'u5', name: 'ゆい', following: true));
    }
    notifyListeners();
    return _friends.lastWhere((f) => f.following);
  }

  // ---- 好きなプロテイン・ふりかえり -------------------------------------

  Protein? _favorite;

  @override
  Protein? get favoriteProtein => _favorite;

  int _scanCount = 0;

  @override
  Future<Protein> scanProtein(Uint8List photo) async {
    await Future<void>.delayed(const Duration(milliseconds: 1500));
    // モック：読み取るたびに別の味を返し、シェイカーの色が変わる様子を確かめられるようにする
    const samples = [
      Protein(name: 'ホエイプロテイン', flavor: 'ココア味', proteinGrams: 20),
      Protein(name: 'ホエイプロテイン', flavor: 'ストロベリー味', proteinGrams: 19),
      Protein(name: 'ソイプロテイン', flavor: '抹茶味', proteinGrams: 18),
      Protein(name: 'ホエイプロテイン', flavor: 'バニラ味', proteinGrams: 21),
    ];
    return samples[_scanCount++ % samples.length];
  }

  @override
  Future<void> saveFavoriteProtein(Protein protein) async {
    _favorite = protein;
    notifyListeners();
  }

  @override
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

    final now = currentTime;
    _feed.addAll([
      FeedItem(
        kind: FeedKind.shake,
        friendName: 'はなこ',
        text: 'はなこさんが今日のプロテインを振りました',
        at: now.subtract(const Duration(minutes: 40)),
      ),
      FeedItem(
        kind: FeedKind.cheer,
        friendName: 'たろう',
        text: 'たろうさんと乾杯しました',
        at: now.subtract(const Duration(days: 2)),
      ),
      FeedItem(
        kind: FeedKind.streak,
        friendName: 'たろう',
        text: 'たろうさんが 7日連続を達成！',
        at: now.subtract(const Duration(days: 3)),
      ),
    ]);
  }
}
