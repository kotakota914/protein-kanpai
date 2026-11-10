/// アプリで扱うデータの形。
///
/// バックエンドの API（docs/api-contract.md）と同じ項目を持つ。
/// 項目を変えるときは、契約と `backend/app/schemas.py` もあわせて変更する。
library;

import 'growth.dart';

/// 友達（フォロー関係がある人）
class Friend {
  const Friend({
    required this.id,
    required this.name,
    this.avatarUrl,
    this.following = false,
    this.shakingNow = false,
    this.shookToday = false,
  });

  factory Friend.fromJson(Map<String, dynamic> json) => Friend(
    id: json['id'] as String,
    name: json['name'] as String,
    avatarUrl: json['avatarUrl'] as String?,
    following: json['following'] as bool? ?? false,
    shakingNow: json['shakingNow'] as bool? ?? false,
    shookToday: json['shookToday'] as bool? ?? false,
  );

  final String id;
  final String name;

  /// アイコン画像の URL（`GET /avatars/{userId}`。未設定なら null）。
  /// ログイン必須なので、画面は AppRepository.avatarOf でバイト列にしてから表示する
  final String? avatarUrl;

  /// 自分がこの人をフォローしている（false なら、この人が自分をフォローしている）
  final bool following;

  /// いま振っている（数秒以内に振れば乾杯できる）
  final bool shakingNow;

  /// 今日すでに振った
  final bool shookToday;

  /// アイコンに出す 1 文字
  String get initial =>
      name.isEmpty ? '?' : String.fromCharCode(name.runes.first);

  Friend copyWith({bool? following}) => Friend(
    id: id,
    name: name,
    avatarUrl: avatarUrl,
    following: following ?? this.following,
    shakingNow: shakingNow,
    shookToday: shookToday,
  );
}

/// 1日分の「振った」記録
class ShakeLog {
  const ShakeLog({required this.date, this.cheerWith = const []});

  /// `{"date": "2026-11-05", "cheerWith": ["たろう"]}`（GET /shakes?month=）
  factory ShakeLog.fromJson(Map<String, dynamic> json) => ShakeLog(
    date: parseDateOnly(json['date'] as String),
    cheerWith: [for (final name in json['cheerWith'] as List? ?? []) '$name'],
  );

  /// 日付（時刻は 0:00 にそろえる）
  final DateTime date;

  /// その日に乾杯した友達の名前
  final List<String> cheerWith;

  bool get cheered => cheerWith.isNotEmpty;
}

/// `YYYY-MM-DD` を、その日の 0:00（端末の時刻）にする
DateTime parseDateOnly(String text) {
  final parts = text.split('-');
  return DateTime(
    int.parse(parts[0]),
    int.parse(parts[1]),
    int.parse(parts[2]),
  );
}

enum FeedKind {
  shake,
  cheer,
  streak;

  static FeedKind fromName(String name) =>
      FeedKind.values.firstWhere((k) => k.name == name, orElse: () => shake);
}

/// タイムラインの1件（「〇〇さんと乾杯しました」など）
class FeedItem {
  const FeedItem({
    required this.kind,
    required this.friendName,
    required this.text,
    required this.at,
  });

  factory FeedItem.fromJson(Map<String, dynamic> json) => FeedItem(
    kind: FeedKind.fromName(json['kind'] as String),
    friendName: (json['friend'] as Map<String, dynamic>)['name'] as String,
    text: json['text'] as String,
    at: DateTime.parse(json['at'] as String).toLocal(),
  );

  final FeedKind kind;
  final String friendName;
  final String text;
  final DateTime at;
}

/// 好きなプロテイン
class Protein {
  const Protein({
    required this.name,
    required this.flavor,
    required this.proteinGrams,
  });

  factory Protein.fromJson(Map<String, dynamic> json) => Protein(
    name: json['name'] as String,
    flavor: json['flavor'] as String? ?? '',
    proteinGrams: (json['proteinGrams'] as num).toInt(),
  );

  final String name;
  final String flavor;

  /// 1食あたりのたんぱく質量（g）
  final int proteinGrams;

  Map<String, Object> toJson() => {
    'name': name,
    'flavor': flavor,
    'proteinGrams': proteinGrams,
  };
}

/// 自分のプロフィールと記録の集計（GET /me）
class Profile {
  const Profile({
    required this.id,
    required this.name,
    required this.avatarUrl,
    required this.points,
    required this.streak,
    required this.bestStreak,
    required this.shookToday,
    required this.totalDays,
    required this.totalCheers,
    required this.daysThisWeek,
    required this.favoriteProtein,
  });

  factory Profile.fromJson(Map<String, dynamic> json) => Profile(
    id: json['id'] as String,
    name: json['name'] as String,
    avatarUrl: json['avatarUrl'] as String?,
    points: (json['points'] as num).toInt(),
    streak: (json['streak'] as num).toInt(),
    bestStreak: (json['bestStreak'] as num?)?.toInt() ?? 0,
    shookToday: json['shookToday'] as bool,
    totalDays: (json['totalDays'] as num).toInt(),
    totalCheers: (json['totalCheers'] as num).toInt(),
    daysThisWeek: (json['daysThisWeek'] as num).toInt(),
    favoriteProtein: json['favoriteProtein'] == null
        ? null
        : Protein.fromJson(json['favoriteProtein'] as Map<String, dynamic>),
  );

  final String id;
  final String name;
  final String? avatarUrl;
  final int points;

  /// 今日（まだなら昨日）までの連続日数
  final int streak;

  /// これまでで一番長い連続日数
  final int bestStreak;
  final bool shookToday;
  final int totalDays;
  final int totalCheers;
  final int daysThisWeek;
  final Protein? favoriteProtein;

  Profile copyWith({
    String? avatarUrl,
    bool clearAvatarUrl = false,
    int? points,
    int? streak,
    int? bestStreak,
    bool? shookToday,
    int? totalDays,
    int? totalCheers,
    int? daysThisWeek,
    Protein? favoriteProtein,
  }) => Profile(
    id: id,
    name: name,
    avatarUrl: clearAvatarUrl ? null : (avatarUrl ?? this.avatarUrl),
    points: points ?? this.points,
    streak: streak ?? this.streak,
    bestStreak: bestStreak ?? this.bestStreak,
    shookToday: shookToday ?? this.shookToday,
    totalDays: totalDays ?? this.totalDays,
    totalCheers: totalCheers ?? this.totalCheers,
    daysThisWeek: daysThisWeek ?? this.daysThisWeek,
    favoriteProtein: favoriteProtein ?? this.favoriteProtein,
  );
}

/// 「振った」ときにバックエンドから返ってくる結果
class ShakeResult {
  const ShakeResult({
    required this.firstToday,
    required this.streak,
    required this.bonusPoints,
    this.cheerWith,
    this.levelUpTo,
    this.newAchievements = const [],
  });

  /// 今日はじめて振ったか（スタンプが押されたか）
  final bool firstToday;

  /// 連続日数
  final int streak;

  /// ログインボーナスで増えたポイント（2回目以降は 0）
  final int bonusPoints;

  /// 同時に振って乾杯が成立した友達の名前（いなければ null）
  final String? cheerWith;

  /// この記録でキャラクターが成長したら、新しい段階（しなければ null）
  final GrowthStage? levelUpTo;

  /// この記録で新しく取ったバッジの名前
  final List<String> newAchievements;
}
