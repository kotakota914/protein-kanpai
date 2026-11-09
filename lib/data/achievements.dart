import 'package:flutter/material.dart';

/// バッジの判定に使う数字
class AchievementStats {
  const AchievementStats({
    required this.totalDays,
    required this.bestStreak,
    required this.totalCheers,
    required this.level,
    required this.hasFavorite,
    required this.hasAvatar,
  });

  final int totalDays;
  final int bestStreak;
  final int totalCheers;
  final int level;
  final bool hasFavorite;
  final bool hasAvatar;
}

/// バッジ（実績）。続けること・乾杯すること・育てることを褒める。
class Achievement {
  const Achievement({
    required this.id,
    required this.name,
    required this.howTo,
    required this.icon,
    required this.earned,
  });

  final String id;
  final String name;

  /// 取り方（まだ取っていないときに表示する）
  final String howTo;
  final IconData icon;
  final bool Function(AchievementStats s) earned;
}

final achievements = <Achievement>[
  Achievement(
    id: 'first-shake',
    name: 'はじめの一杯',
    howTo: 'はじめてシェイカーを振る',
    icon: Icons.local_drink_rounded,
    earned: (s) => s.totalDays >= 1,
  ),
  Achievement(
    id: 'streak-3',
    name: '3日つづいた',
    howTo: '3日連続で振る',
    icon: Icons.local_fire_department_rounded,
    earned: (s) => s.bestStreak >= 3,
  ),
  Achievement(
    id: 'streak-7',
    name: '1週間つづいた',
    howTo: '7日連続で振る',
    icon: Icons.whatshot_rounded,
    earned: (s) => s.bestStreak >= 7,
  ),
  Achievement(
    id: 'first-cheer',
    name: 'はじめての乾杯',
    howTo: '友達と同時に振る',
    icon: Icons.wine_bar_rounded,
    earned: (s) => s.totalCheers >= 1,
  ),
  Achievement(
    id: 'cheer-10',
    name: '乾杯なかま',
    howTo: '乾杯を 10 回する',
    icon: Icons.groups_rounded,
    earned: (s) => s.totalCheers >= 10,
  ),
  Achievement(
    id: 'level-3',
    name: '細マッチョ到達',
    howTo: '振った日が 7 日になる',
    icon: Icons.fitness_center_rounded,
    earned: (s) => s.level >= 3,
  ),
  Achievement(
    id: 'level-5',
    name: 'ムキムキ到達',
    howTo: '振った日が 30 日になる',
    icon: Icons.emoji_events_rounded,
    earned: (s) => s.level >= 5,
  ),
  Achievement(
    id: 'favorite',
    name: '推しプロテイン',
    howTo: '好きなプロテインを登録する',
    icon: Icons.auto_awesome,
    earned: (s) => s.hasFavorite,
  ),
  Achievement(
    id: 'avatar',
    name: '顔を見せた',
    howTo: 'アイコンを写真にする',
    icon: Icons.face_rounded,
    earned: (s) => s.hasAvatar,
  ),
];
