import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../app/theme.dart';

/// シェイカーくん。段階（1〜5）が上がるほど腕が太くなり、力こぶが大きくなる。
class Mascot extends StatelessWidget {
  const Mascot({
    super.key,
    required this.level,
    this.size = 120,
    this.liquidColor = AppColors.cocoa,
  });

  /// 1（ひよっこ）〜 5（ムキムキ）
  final int level;
  final double size;

  /// 体の中身の色（好きなプロテインの味）
  final Color liquidColor;

  @override
  Widget build(BuildContext context) {
    return ExcludeSemantics(
      child: CustomPaint(
        size: Size.square(size),
        painter: _MascotPainter(level: level.clamp(1, 5), liquid: liquidColor),
      ),
    );
  }
}

class _MascotPainter extends CustomPainter {
  _MascotPainter({required this.level, required this.liquid});

  final int level;
  final Color liquid;

  @override
  void paint(Canvas canvas, Size size) {
    canvas.scale(size.width / 120);
    final t = (level - 1) / 4; // 0〜1

    final outline = Paint()
      ..color = AppColors.ink
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3
      ..strokeJoin = StrokeJoin.round
      ..strokeCap = StrokeCap.round;

    // ---- 腕（体の後ろに描く） ----
    final armW = 7 + 7 * t; // 腕の太さ
    final bicep = 6 + 10 * t; // 力こぶの大きさ
    final skin = Paint()..color = AppColors.milk;
    for (final side in [-1.0, 1.0]) {
      final shoulder = Offset(60 + side * 24, 66);
      final elbow = Offset(60 + side * (44 + 4 * t), 70);
      final fist = Offset(60 + side * (44 + 4 * t), 44 - 4 * t);
      final arm = Paint()
        ..color = AppColors.milk
        ..style = PaintingStyle.stroke
        ..strokeWidth = armW
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round;
      final path = Path()
        ..moveTo(shoulder.dx, shoulder.dy)
        ..lineTo(elbow.dx, elbow.dy)
        ..lineTo(fist.dx, fist.dy);
      // 輪郭 → 中身の順に描いて、ふちどりにする
      canvas.drawPath(
        path,
        Paint()
          ..color = AppColors.ink
          ..style = PaintingStyle.stroke
          ..strokeWidth = armW + 5
          ..strokeCap = StrokeCap.round
          ..strokeJoin = StrokeJoin.round,
      );
      canvas.drawPath(path, arm);
      // 力こぶ
      final bulge = Offset(
        (shoulder.dx + elbow.dx) / 2 + side * 1,
        (shoulder.dy + elbow.dy) / 2 - bicep * 0.55,
      );
      canvas.drawCircle(bulge, bicep / 2 + 2.5, Paint()..color = AppColors.ink);
      canvas.drawCircle(bulge, bicep / 2, skin);
      // こぶし
      canvas.drawCircle(fist, armW / 2 + 4.5, Paint()..color = AppColors.ink);
      canvas.drawCircle(fist, armW / 2 + 2, skin);
    }

    // ---- 体（シェイカー） ----
    final body = RRect.fromLTRBR(36, 40, 84, 108, const Radius.circular(12));
    canvas.drawRRect(body, Paint()..color = Colors.white);
    canvas.save();
    canvas.clipRRect(body);
    canvas.drawRect(
      const Rect.fromLTRB(30, 74, 90, 112),
      Paint()..color = liquid,
    );
    canvas.drawRect(
      const Rect.fromLTRB(30, 70, 90, 76),
      Paint()..color = AppColors.milk,
    );
    canvas.restore();
    canvas.drawRRect(body, outline);

    // ---- フタ（ハチマキ代わり） ----
    final cap = RRect.fromLTRBR(32, 28, 88, 44, const Radius.circular(7));
    canvas.drawRRect(cap, Paint()..color = AppColors.primary);
    canvas.drawRRect(cap, outline);
    final spout = RRect.fromLTRBR(52, 18, 68, 30, const Radius.circular(4));
    canvas.drawRRect(spout, Paint()..color = AppColors.primary);
    canvas.drawRRect(spout, outline);
    if (level >= 4) {
      // ハチマキの結び目
      final knot = Paint()..color = AppColors.primary;
      canvas.drawCircle(const Offset(90, 34), 4, knot);
      canvas.drawLine(const Offset(92, 34), const Offset(102, 28), outline);
      canvas.drawLine(const Offset(92, 36), const Offset(101, 42), outline);
    }

    // ---- 顔 ----
    final ink = Paint()..color = AppColors.ink;
    final eyeY = 56.0;
    if (level >= 5) {
      // 自信のまゆげ
      canvas.drawLine(const Offset(44, 49), const Offset(54, 51), outline);
      canvas.drawLine(const Offset(76, 49), const Offset(66, 51), outline);
    }
    canvas.drawCircle(Offset(50, eyeY), 3.2, ink);
    canvas.drawCircle(Offset(70, eyeY), 3.2, ink);
    // ほっぺ
    final cheek = Paint()..color = AppColors.primary.withValues(alpha: 0.35);
    canvas.drawCircle(const Offset(44, 63), 4, cheek);
    canvas.drawCircle(const Offset(76, 63), 4, cheek);
    // 口（段階が上がるほど大きく笑う）
    final smile = Path()
      ..moveTo(53, 62)
      ..quadraticBezierTo(60, 66 + 4 * t, 67, 62);
    canvas.drawPath(smile, outline);

    // ---- ムキムキのきらめき ----
    if (level >= 5) {
      final spark = Paint()..color = AppColors.cheer;
      for (final c in const [
        Offset(18, 22),
        Offset(104, 14),
        Offset(108, 60),
      ]) {
        final p = Path();
        for (var i = 0; i < 8; i++) {
          final r = i.isEven ? 6.0 : 2.0;
          final a = i * math.pi / 4;
          final pt = c + Offset(math.cos(a) * r, math.sin(a) * r);
          i == 0 ? p.moveTo(pt.dx, pt.dy) : p.lineTo(pt.dx, pt.dy);
        }
        p.close();
        canvas.drawPath(p, spark);
      }
    }
  }

  @override
  bool shouldRepaint(_MascotPainter old) =>
      old.level != level || old.liquid != liquid;
}
