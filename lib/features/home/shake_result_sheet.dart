import 'dart:typed_data';

import 'package:flutter/material.dart';

import '../../app/theme.dart';
import '../../data/models.dart';
import '../../widgets/common.dart';
import '../../widgets/shaker.dart';

/// 03 振った結果（スタンプ・乾杯・ボーナス）を下から出して見せる
Future<void> showShakeResultSheet(
  BuildContext context,
  ShakeResult result, {
  required String myInitial,
  Uint8List? myPhoto,
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
    builder: (context) =>
        _ShakeResultSheet(result: result, myInitial: myInitial, myPhoto: myPhoto),
  );
}

class _ShakeResultSheet extends StatelessWidget {
  const _ShakeResultSheet({
    required this.result,
    required this.myInitial,
    required this.myPhoto,
  });

  final ShakeResult result;
  final String myInitial;
  final Uint8List? myPhoto;

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
            TweenAnimationBuilder<double>(
              tween: Tween(begin: 0.4, end: 1),
              duration: const Duration(milliseconds: 600),
              curve: Curves.elasticOut,
              builder: (context, scale, child) =>
                  Transform.scale(scale: scale, child: child),
              child: cheer != null
                  ? _CheersPair(
                      me: myInitial,
                      myPhoto: myPhoto,
                      friend: cheer.substring(0, 1),
                    )
                  : const ShakerBottle(mix: 1, height: 120),
            ),
            const SizedBox(height: 16),
            Text(title, style: AppFonts.heading(28)),
            const SizedBox(height: 8),
            Text(
              message,
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 14, color: AppColors.muted, height: 1.6),
            ),
            const SizedBox(height: 20),
            Row(
              children: [
                _Badge(icon: AppIcons.flame, label: '連続', value: '${result.streak}日'),
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

/// 自分と友達のアイコンの間にグラス
class _CheersPair extends StatelessWidget {
  const _CheersPair({required this.me, required this.myPhoto, required this.friend});

  final String me;
  final Uint8List? myPhoto;
  final String friend;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 196,
      height: 88,
      child: Stack(
        alignment: Alignment.center,
        children: [
          Positioned(
            left: 0,
            child: Avatar(
              initial: me,
              photo: myPhoto,
              color: AppColors.primary,
              size: 64,
            ),
          ),
          Positioned(
            right: 0,
            child: Avatar(initial: friend, color: AppColors.cheerSoft, size: 64),
          ),
          Container(
            width: 88,
            height: 88,
            decoration: BoxDecoration(
              color: AppColors.cheer,
              shape: BoxShape.circle,
              border: Border.all(color: AppColors.surface, width: 4),
            ),
            child: const Icon(AppIcons.cheer, size: 40, color: AppColors.ink),
          ),
        ],
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
