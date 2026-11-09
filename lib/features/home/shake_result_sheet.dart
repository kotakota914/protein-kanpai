import 'dart:typed_data';

import 'package:flutter/material.dart';

import '../../app/theme.dart';
import '../../data/models.dart';
import '../../widgets/cheers.dart';
import '../../widgets/common.dart';
import '../../widgets/mascot.dart';
import '../../widgets/shaker.dart';

/// 03 振った結果（スタンプ・乾杯・ボーナス）を下から出して見せる
Future<void> showShakeResultSheet(
  BuildContext context,
  ShakeResult result, {
  required String myInitial,
  Uint8List? myPhoto,
  Color liquidColor = AppColors.cocoa,
}) {
  return showModalBottomSheet<void>(
    context: context,
    // 既定では画面の約半分までしか伸びず、スマホで内容がはみ出すため
    isScrollControlled: true,
    backgroundColor: AppColors.surface,
    showDragHandle: true,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
    ),
    builder: (context) => _ShakeResultSheet(
      result: result,
      myInitial: myInitial,
      myPhoto: myPhoto,
      liquidColor: liquidColor,
    ),
  );
}

class _ShakeResultSheet extends StatelessWidget {
  const _ShakeResultSheet({
    required this.result,
    required this.myInitial,
    required this.myPhoto,
    required this.liquidColor,
  });

  final ShakeResult result;
  final String myInitial;
  final Uint8List? myPhoto;
  final Color liquidColor;

  @override
  Widget build(BuildContext context) {
    final cheer = result.cheerWith;
    final title = cheer != null
        ? '$cheerさんと乾杯！'
        : (result.firstToday ? '今日のスタンプ ゲット！' : 'ナイスシェイク！');
    final message = cheer != null
        ? '同じタイミングで振りました。\n一緒に今日の筋トレ完了！'
        : (result.firstToday ? '今日の筋トレ、おつかれさま！' : '今日のスタンプはもう押してあります');

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (cheer != null)
              CheersAnimation(
                myInitial: myInitial,
                myPhoto: myPhoto,
                friendInitial: cheer.substring(0, 1),
                myLiquid: liquidColor,
              )
            else
              TweenAnimationBuilder<double>(
                tween: Tween(begin: 0.4, end: 1),
                duration: const Duration(milliseconds: 600),
                curve: Curves.elasticOut,
                builder: (context, scale, child) =>
                    Transform.scale(scale: scale, child: child),
                child: ShakerBottle(
                  mix: 1,
                  height: 120,
                  liquidColor: liquidColor,
                ),
              ),
            const SizedBox(height: 16),
            Text(title, style: AppFonts.heading(28)),
            const SizedBox(height: 8),
            Text(
              message,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 14,
                color: AppColors.muted,
                height: 1.6,
              ),
            ),
            const SizedBox(height: 20),
            Row(
              children: [
                _Badge(
                  icon: AppIcons.flame,
                  label: '連続',
                  value: '${result.streak}日',
                ),
                if (result.bonusPoints > 0) ...[
                  const SizedBox(width: 10),
                  _Badge(
                    icon: AppIcons.star,
                    label: 'ログインボーナス',
                    value: '+${result.bonusPoints} pt',
                  ),
                ],
                const SizedBox(width: 10),
                _Badge(
                  icon: Icons.check_rounded,
                  label: 'スタンプ',
                  value: result.firstToday ? 'ゲット' : '押印済み',
                ),
              ],
            ),
            if (result.levelUpTo case final stage?) ...[
              const SizedBox(height: 14),
              _LevelUp(
                level: stage.level,
                name: stage.name,
                liquidColor: liquidColor,
              ),
            ],
            if (result.newAchievements.isNotEmpty) ...[
              const SizedBox(height: 12),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                alignment: WrapAlignment.center,
                children: [
                  for (final name in result.newAchievements)
                    Pill(
                      label: 'バッジ獲得：$name',
                      icon: Icons.military_tech_rounded,
                      background: AppColors.cheer,
                    ),
                ],
              ),
            ],
            const SizedBox(height: 24),
            FilledButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('OK'),
            ),
          ],
        ),
      ),
    );
  }
}

class _Badge extends StatelessWidget {
  const _Badge({required this.icon, required this.label, required this.value});

  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 6),
        decoration: BoxDecoration(
          color: AppColors.cheerSoft,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Column(
          children: [
            Icon(icon, size: 20, color: AppColors.primary),
            const SizedBox(height: 4),
            Text(
              label,
              style: const TextStyle(fontSize: 11, color: AppColors.muted),
              overflow: TextOverflow.ellipsis,
            ),
            Text(
              value,
              style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w700),
            ),
          ],
        ),
      ),
    );
  }
}

/// キャラクターが成長したときの帯
class _LevelUp extends StatelessWidget {
  const _LevelUp({
    required this.level,
    required this.name,
    required this.liquidColor,
  });

  final int level;
  final String name;
  final Color liquidColor;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(8, 8, 16, 8),
      decoration: BoxDecoration(
        color: AppColors.primarySoft,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.primary, width: 1.5),
      ),
      child: Row(
        children: [
          Mascot(level: level, size: 64, liquidColor: liquidColor),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'シェイカーくんが成長した！',
                  style: TextStyle(fontSize: 12, color: AppColors.muted),
                ),
                Text('Lv.$level $name', style: AppFonts.heading(20)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
