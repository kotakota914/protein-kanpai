/// アプリで扱うデータの形。
///
/// バックエンド担当と決める「注文票」にあたる。項目を変えるときは
/// バックエンドの API とあわせて変更する。
library;

import 'growth.dart';

/// 友達（フォロー相手）
class Friend {
  const Friend({
    required this.id,
    required this.name,
    this.following = false,
    this.shakingNow = false,
    this.shookToday = false,
  });

  final String id;
  final String name;
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
    following: following ?? this.following,
    shakingNow: shakingNow,
    shookToday: shookToday,
  );
}

/// 1日分の「振った」記録
class ShakeLog {
  const ShakeLog({required this.date, this.cheerWith = const []});

  /// 日付（時刻は 0:00 にそろえる）
  final DateTime date;

  /// その日に乾杯した友達の名前
  final List<String> cheerWith;

  bool get cheered => cheerWith.isNotEmpty;
}

enum FeedKind { shake, cheer, streak }

/// タイムラインの1件（「〇〇さんと乾杯しました」など）
class FeedItem {
  const FeedItem({
    required this.kind,
    required this.friendName,
    required this.text,
    required this.at,
  });

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

  final String name;
  final String flavor;

  /// 1食あたりのたんぱく質量（g）
  final int proteinGrams;
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
