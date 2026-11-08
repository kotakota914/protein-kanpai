import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../app/theme.dart';

/// バーベルのプレートのような輪。[lit] 個の区切りがアンバーに光る。
///
/// 振るボタンの外側に置き、揺れを数えるたびに 1 区切りずつ光らせる。
class PlateRing extends StatelessWidget {
  const PlateRing({
    super.key,
    required this.segments,
    required this.lit,
    required this.size,
    this.thickness = 16,
    this.litColor = AppColors.primary,
    this.child,
  });

  final int segments;
  final double lit;
  final double size;
  final double thickness;
  final Color litColor;
  final Widget? child;

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      painter: _PlateRingPainter(
        segments: segments,
        lit: lit,
        thickness: thickness,
        litColor: litColor,
      ),
      child: SizedBox.square(dimension: size, child: Center(child: child)),
    );
  }
}

class _PlateRingPainter extends CustomPainter {
  _PlateRingPainter({
    required this.segments,
    required this.lit,
    required this.thickness,
    required this.litColor,
  });

  final int segments;
  final double lit;
  final double thickness;
  final Color litColor;

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    final arcRect = rect.deflate(thickness / 2);
    const gap = 0.07; // 区切りのすき間（ラジアン）
    final sweep = 2 * math.pi / segments;
    for (var i = 0; i < segments; i++) {
      final on = i < lit.round();
      canvas.drawArc(
        arcRect,
        -math.pi / 2 + i * sweep + gap / 2,
        sweep - gap,
        false,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = thickness
          ..color = on ? litColor : AppColors.line,
      );
    }
  }

  @override
  bool shouldRepaint(_PlateRingPainter old) =>
      old.lit != lit || old.segments != segments || old.litColor != litColor;
}

/// 「正」の字で数を数える（部活のホワイトボード式）。
///
/// [total] 画ぶんの枠を描き、そのうち [count] 画をアンバーで書く。
class TallyMarks extends StatelessWidget {
  const TallyMarks({
    super.key,
    required this.count,
    this.total = 7,
    this.glyphSize = 34,
  });

  final int count;
  final int total;
  final double glyphSize;

  @override
  Widget build(BuildContext context) {
    final glyphs = (total / 5).ceil();
    return Semantics(
      label: '$total 回中 $count 回',
      child: ExcludeSemantics(
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            for (var g = 0; g < glyphs; g++) ...[
              if (g > 0) SizedBox(width: glyphSize * 0.3),
              CustomPaint(
                size: Size.square(glyphSize),
                painter: _TallyPainter(
                  strokes: math.min(5, total - g * 5),
                  lit: (count - g * 5).clamp(0, 5),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _TallyPainter extends CustomPainter {
  _TallyPainter({required this.strokes, required this.lit});

  /// この字で書く画数（最後の字は 5 画未満のことがある）
  final int strokes;
  final int lit;

  // 「正」の書き順：上の横線 → 中の縦線 → 右の短い横線 → 左の縦線 → 下の横線
  static const _lines = [
    [0.12, 0.12, 0.88, 0.12],
    [0.5, 0.12, 0.5, 0.88],
    [0.5, 0.5, 0.82, 0.5],
    [0.22, 0.44, 0.22, 0.88],
    [0.06, 0.88, 0.94, 0.88],
  ];

  @override
  void paint(Canvas canvas, Size size) {
    for (var i = 0; i < strokes; i++) {
      final l = _lines[i];
      canvas.drawLine(
        Offset(l[0] * size.width, l[1] * size.height),
        Offset(l[2] * size.width, l[3] * size.height),
        Paint()
          ..strokeWidth = size.width * 0.12
          ..strokeCap = StrokeCap.round
          ..color = i < lit ? AppColors.primary : AppColors.line,
      );
    }
  }

  @override
  bool shouldRepaint(_TallyPainter old) =>
      old.strokes != strokes || old.lit != lit;
}
