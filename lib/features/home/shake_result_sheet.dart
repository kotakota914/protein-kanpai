import 'dart:typed_data';

import 'package:flutter/material.dart';

import '../../app/theme.dart';
import '../../data/models.dart';
import '../../widgets/common.dart';
import '../../widgets/shaker.dart';

/// 03 振った結果（記録・乾杯・ボーナス）を下から出して見せる
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
    showDragHandle: true,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
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
        ? '乾杯！'
        : (result.firstToday ? 'シェイク完了' : 'ナイスシェイク');
    final message = cheer != null
        ? '$cheerと同時に振った。今日の筋トレ、ふたりで完了。'
        : (result.firstToday ? '今日の筋トレ、完了。' : '今日の分はもう記録済み。');

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            TweenAnimationBuilder<double>(
              tween: Tween(begin: 0.5, end: 1),
              duration: const Duration(milliseconds: 500),
              curve: Curves.elasticOut,
              builder: (context, scale, child) => Transform.scale(
                scale: scale,
                alignment: Alignment.centerLeft,
                child: child,
              ),
              child: cheer != null
                  ? _CheersPair(
                      me: myInitial,
                      myPhoto: myPhoto,
                      friend: cheer.substring(0, 1),
                      friendColor: Avatar.colorFor(cheer),
                    )
                  : const ShakerBottle(mix: 1, height: 110),
            ),
            const SizedBox(height: 18),
            Text(
              title,
              style: AppFonts.heading(
                40,
                color: cheer != null ? AppColors.cheer : AppColors.primary,
              ),
            ),
            const SizedBox(height: 6),
            Text(message, style: const TextStyle(fontSize: 15, height: 1.6)),
            const SizedBox(height: 22),
            Row(
              children: [
                _BigStat(value: '${result.streak}', unit: '日連続'),
                if (result.bonusPoints > 0) ...[
                  const SizedBox(width: 28),
                  _BigStat(value: '+${result.bonusPoints}', unit: 'pt ボーナス'),
                ],
              ],
            ),
            const SizedBox(height: 26),
            FilledButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('閉じる'),
            ),
          ],
        ),
      ),
    );
  }
}

/// 自分と友達のアイコンの間に、青いグラス
class _CheersPair extends StatelessWidget {
  const _CheersPair({
    required this.me,
    required this.myPhoto,
    required this.friend,
    required this.friendColor,
  });

  final String me;
  final Uint8List? myPhoto;
  final String friend;
  final Color friendColor;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 188,
      height: 80,
      child: Stack(
        alignment: Alignment.center,
        children: [
          Positioned(
            left: 0,
            child: Avatar(
              initial: me,
              photo: myPhoto,
              color: AppColors.primary,
              textColor: AppColors.onPrimary,
              size: 64,
            ),
          ),
          Positioned(
            right: 0,
            child: Avatar(initial: friend, textColor: friendColor, size: 64),
          ),
          Container(
            width: 80,
            height: 80,
            decoration: BoxDecoration(
              color: AppColors.cheer,
              shape: BoxShape.circle,
              border: Border.all(color: AppColors.surface, width: 5),
            ),
            child: const Icon(AppIcons.cheer, size: 36, color: AppColors.ink),
          ),
        ],
      ),
    );
  }
}

class _BigStat extends StatelessWidget {
  const _BigStat({required this.value, required this.unit});

  final String value;
  final String unit;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.baseline,
      textBaseline: TextBaseline.alphabetic,
      children: [
        Text(value, style: AppFonts.heading(34)),
        const SizedBox(width: 4),
        Text(unit, style: const TextStyle(fontSize: 13, color: AppColors.muted)),
      ],
    );
  }
}
