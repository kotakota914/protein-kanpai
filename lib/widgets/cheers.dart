import 'dart:math' as math;
import 'dart:typed_data';

import 'package:flutter/material.dart';

import '../app/theme.dart';
import 'common.dart';
import 'shaker.dart';

/// 乾杯の演出：2 本のシェイカーが左右から寄ってぶつかり、泡がはじける。
///
/// 端末で「視差効果を減らす」などアニメーションを減らす設定のときは、
/// 最後の場面だけを表示する。
class CheersAnimation extends StatefulWidget {
  const CheersAnimation({
    super.key,
    required this.myInitial,
    required this.friendInitial,
    this.myPhoto,
    this.myLiquid = AppColors.cocoa,
    this.friendLiquid = AppColors.cocoa,
  });

  final String myInitial;
  final String friendInitial;
  final Uint8List? myPhoto;
  final Color myLiquid;
  final Color friendLiquid;

  @override
  State<CheersAnimation> createState() => _CheersAnimationState();
}

class _CheersAnimationState extends State<CheersAnimation>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1300),
  );

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (MediaQuery.of(context).disableAnimations) {
      _c.value = 1;
    } else if (!_c.isAnimating && _c.value == 0) {
      _c.forward();
    }
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: '乾杯',
      child: ExcludeSemantics(
        child: SizedBox(
          width: 240,
          height: 150,
          child: AnimatedBuilder(
            animation: _c,
            builder: (context, _) {
              final t = _c.value;
              // 0〜0.45：寄ってぶつかる／0.45〜：少し跳ね返って止まる
              final approach = Curves.easeIn.transform((t / 0.45).clamp(0, 1));
              final settle = Curves.elasticOut.transform(
                ((t - 0.45) / 0.55).clamp(0, 1),
              );
              final distance = t < 0.45
                  ? 78 - (78 - 24) * approach
                  : 24 + 8 * settle; // 中心からの距離
              final tilt = 0.32 * (t < 0.45 ? approach : 1 - 0.3 * settle);
              final burst = ((t - 0.42) / 0.5).clamp(0.0, 1.0);

              return Stack(
                clipBehavior: Clip.none,
                alignment: Alignment.topCenter,
                children: [
                  for (final side in const [-1.0, 1.0])
                    Positioned(
                      left: 120 + side * distance - 30,
                      top: 0,
                      child: Column(
                        children: [
                          Transform.rotate(
                            angle: -side * tilt,
                            alignment: Alignment.bottomCenter,
                            child: ShakerBottle(
                              mix: 1,
                              height: 84,
                              liquidColor: side < 0
                                  ? widget.myLiquid
                                  : widget.friendLiquid,
                            ),
                          ),
                          const SizedBox(height: 6),
                          side < 0
                              ? Avatar(
                                  initial: widget.myInitial,
                                  photo: widget.myPhoto,
                                  color: AppColors.primary,
                                  size: 40,
                                )
                              : Avatar(
                                  initial: widget.friendInitial,
                                  color: AppColors.cheerSoft,
                                  size: 40,
                                ),
                        ],
                      ),
                    ),
                  if (burst > 0)
                    Positioned.fill(
                      child: CustomPaint(painter: _FoamBurst(progress: burst)),
                    ),
                ],
              );
            },
          ),
        ),
      ),
    );
  }
}

/// ぶつかった所から泡と星がはじける
class _FoamBurst extends CustomPainter {
  _FoamBurst({required this.progress});

  final double progress;

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, 14);
    final fade = (1 - progress).clamp(0.0, 1.0);
    for (var i = 0; i < 12; i++) {
      final angle = -math.pi + (i / 11) * math.pi; // 上半分に広がる
      final reach =
          18 + 52 * Curves.easeOut.transform(progress) * (0.7 + (i % 3) * 0.15);
      final p =
          center + Offset(math.cos(angle) * reach, math.sin(angle) * reach);
      final paint = Paint()
        ..color = (i.isEven ? AppColors.milk : AppColors.cheer).withValues(
          alpha: fade,
        );
      canvas.drawCircle(p, 3.5 + (i % 3) * 1.5, paint);
    }
  }

  @override
  bool shouldRepaint(_FoamBurst old) => old.progress != progress;
}
