import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../app/theme.dart';
import 'achievements.dart';
import 'growth.dart';
import 'models.dart';

/// 画面が使うデータの窓口。
///
/// 画面（lib/features/、lib/widgets/）は、このクラスの公開メソッドだけを使う。
/// 中身は 2 つあり、起動時の設定（`--dart-define=API_BASE_URL`）で選ぶ：
///
/// - `MockAppRepository`（mock_repository.dart）：仮のデータ。バックエンド無しのデモ用
/// - `ApiAppRepository`（api_repository.dart）：バックエンド API（docs/api-contract.md）
///
/// 成長段階・バッジ・シェイクの色のように、数字から決まるものはここで計算する。
abstract class AppRepository extends ChangeNotifier {
  AppRepository({DateTime Function()? clock}) : _clock = clock ?? DateTime.now;

  final DateTime Function() _clock;

  @protected
  DateTime get currentTime => _clock();

  DateTime get today {
    final now = _clock();
    return DateTime(now.year, now.month, now.day);
  }

  // ---- ログイン -------------------------------------------------------

  bool get signedIn;

  String get userName;

  String get userInitial =>
      userName.isEmpty ? '?' : String.fromCharCode(userName.runes.first);

  /// Google でログインする
  Future<void> signIn();

  /// Firebase なしの開発用ログインが使えるか（ローカルのバックエンドに対して試すとき）
  bool get supportsDevSignIn => false;

  Future<void> signInForDevelopment({
    required String uid,
    required String name,
  }) => throw UnsupportedError('開発用ログインはこの構成では使えません');

  Future<void> signOut();

  // ---- 自分のアイコン（写真） -------------------------------------------

  /// 写真のサイズの上限。端末側で縮小してから渡すので、通常はこれより小さい
  static const maxAvatarBytes = 2 * 1024 * 1024;

  /// 自分で選んだアイコンの写真（未設定なら null。読み込み中も null）
  Uint8List? get avatar;

  /// アイコンを設定済みか（写真の読み込みがまだでも true）
  bool get hasAvatar => avatar != null;

  /// アイコンの写真を設定する。大きすぎる写真は [ArgumentError] を投げる
  Future<void> setAvatar(Uint8List bytes);

  Future<void> clearAvatar();

  /// 友達のアイコンの写真。未設定・読み込み中は null（読み込めたら通知する）
  Uint8List? avatarOf(Friend friend) => null;

  // ---- 振った記録 -----------------------------------------------------

  /// 日付ごとの記録（カレンダー用）
  Map<DateTime, ShakeLog> get logs;

  int get points;

  bool get shookToday;

  /// 今日（まだなら昨日）までの連続日数
  int get streak;

  int get totalDays;

  /// これまでで一番長い連続日数
  int get bestStreak;

  int get totalCheers;

  /// 今週（月曜はじまり）振った日数
  int get daysThisWeek;

  /// キャラクター（シェイカーくん）のいまの段階。振った日数の合計で決まる
  GrowthStage get stage => stageFor(totalDays);

  /// バッジの判定に使う数字
  AchievementStats get achievementStats => AchievementStats(
    totalDays: totalDays,
    bestStreak: bestStreak,
    totalCheers: totalCheers,
    level: stage.level,
    hasFavorite: favoriteProtein != null,
    hasAvatar: hasAvatar,
  );

  /// 取ったバッジの id
  Set<String> get earnedAchievementIds => {
    for (final a in achievements)
      if (a.earned(achievementStats)) a.id,
  };

  /// シェイカーを振ったことを記録する
  Future<ShakeResult> recordShake();

  /// カレンダーで表示する月の記録を用意する（まだ無ければ取りに行き、届いたら通知する）
  void ensureMonthLoaded(DateTime month) {}

  // ---- 友達 -----------------------------------------------------------

  List<Friend> get friends;

  List<Friend> get following =>
      friends.where((f) => f.following).toList(growable: false);

  /// いま振っているフォロー中の友達（ホームの「乾杯チャンス」用）
  Friend? get shakingFriend {
    for (final f in friends) {
      if (f.following && f.shakingNow) return f;
    }
    return null;
  }

  List<FeedItem> get feed;

  Future<void> toggleFollow(String friendId);

  /// 招待リンクを作る。相手がこのリンクを開くと、お互いにフォローした状態になる
  Future<String> createInviteLink();

  /// 招待リンクを開いた側が呼ぶ。招待した人を返す
  Future<Friend> acceptInvite(String code);

  // ---- 好きなプロテイン・ふりかえり -------------------------------------

  Protein? get favoriteProtein;

  /// プロテインの袋の写真から、商品名・味・たんぱく質量を読み取る（保存はしない）
  Future<Protein> scanProtein(Uint8List photo);

  /// 読み取った内容を確認したあと、好きなプロテインとして保存する
  Future<void> saveFavoriteProtein(Protein protein);

  /// シェイクの色（好きなプロテインの味。未登録ならココア）
  Color get liquidColor => AppColors.flavor(favoriteProtein?.flavor);

  /// 今週のふりかえり文（Gemini が作る。届くまでは準備中の文）
  String get weeklySummary;
}
