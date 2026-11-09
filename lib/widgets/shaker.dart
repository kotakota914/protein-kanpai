import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../app/theme.dart';

/// 線で描いた小さなシェイカーのアイコン（24 x 24 を基準に拡大縮小）。
///
/// Material のアイコンにはプロテインシェイカーがないため、自前で描く。
class ShakerIcon extends StatelessWidget {
  const ShakerIcon({
    super.key,
    this.size = 24,
    this.color = AppColors.primary,
    this.liquidColor,
    this.fill = 0.55,
  });

  final double size;

  /// 線とフタの色
  final Color color;

  /// 中身の色（省略時は [color] の半透明）
  final Color? liquidColor;

  /// 中身の量（0〜1）
  final double fill;

  @override
  Widget build(BuildContext context) {
    return ExcludeSemantics(
      child: CustomPaint(
        size: Size.square(size),
        painter: _ShakerIconPainter(
          color: color,
          liquid: liquidColor ?? color.withValues(alpha: 0.45),
          fill: fill,
        ),
      ),
    );
  }
}

class _ShakerIconPainter extends CustomPainter {
  _ShakerIconPainter({
    required this.color,
    required this.liquid,
    required this.fill,
  });

  final Color color;
  final Color liquid;
  final double fill;

  @override
  void paint(Canvas canvas, Size size) {
    canvas.scale(size.width / 24);
    final body = Path()
      ..moveTo(6.6, 7.6)
      ..lineTo(17.4, 7.6)
      ..lineTo(16.5, 19.6)
      ..quadraticBezierTo(16.4, 21, 15, 21)
      ..lineTo(9, 21)
      ..quadraticBezierTo(7.6, 21, 7.5, 19.6)
      ..close();

    canvas.save();
    canvas.clipPath(body);
    canvas.drawRect(
      Rect.fromLTRB(0, 21 - 13.4 * fill.clamp(0, 1), 24, 24),
      Paint()..color = liquid,
    );
    canvas.restore();

    canvas.drawPath(
      body,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.8
        ..strokeJoin = StrokeJoin.round
        ..color = color,
    );
    final solid = Paint()..color = color;
    // フタ（えり）と注ぎ口
    canvas.drawRRect(
      RRect.fromLTRBR(5.4, 4.8, 18.6, 7.9, const Radius.circular(1.2)),
      solid,
    );
    canvas.drawRRect(
      RRect.fromLTRBR(8.6, 1.8, 15.4, 5.2, const Radius.circular(1.2)),
      solid,
    );
  }

  @override
  bool shouldRepaint(_ShakerIconPainter old) =>
      old.color != color || old.liquid != liquid || old.fill != fill;
}

/// 振るボタンの中の大きなシェイカー。
///
/// [mix] が 0 のときは「水＋底にたまった粉」、1 に近づくほど混ざって
/// ココア色になり、上に泡が立つ。[active] の間は傾きながら水面が揺れる。
class ShakerBottle extends StatefulWidget {
  const ShakerBottle({
    super.key,
    required this.mix,
    this.active = false,
    this.height = 120,
    this.liquidColor = AppColors.cocoa,
  });

  final double mix;
  final bool active;
  final double height;

  /// 混ざったときの色（好きなプロテインの味）
  final Color liquidColor;

  @override
  State<ShakerBottle> createState() => _ShakerBottleState();
}

class _ShakerBottleState extends State<ShakerBottle>
    with SingleTickerProviderStateMixin {
  late final AnimationController _wave = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 900),
  );

  @override
  void initState() {
    super.initState();
    if (widget.active) _wave.repeat();
  }

  @override
  void didUpdateWidget(ShakerBottle old) {
    super.didUpdateWidget(old);
    if (widget.active && !_wave.isAnimating) {
      _wave.repeat();
    } else if (!widget.active && _wave.isAnimating) {
      _wave.stop();
    }
  }

  @override
  void dispose() {
    _wave.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final width = widget.height * 100 / 140;
    return ExcludeSemantics(
      child: AnimatedBuilder(
        animation: _wave,
        builder: (context, _) {
          final t = _wave.value;
          final tilt = widget.active ? math.sin(t * 2 * math.pi) * 0.14 : 0.0;
          return Transform.rotate(
            angle: tilt,
            child: CustomPaint(
              size: Size(width, widget.height),
              painter: _BottlePainter(
                mix: widget.mix.clamp(0, 1),
                phase: t,
                agitation: widget.active ? 1 : 0,
                powder: widget.liquidColor,
              ),
            ),
          );
        },
      ),
    );
  }
}

class _BottlePainter extends CustomPainter {
  _BottlePainter({
    required this.mix,
    required this.phase,
    required this.agitation,
    required this.powder,
  });

  final double mix;
  final double phase;
  final double agitation;

  /// 粉と、混ざったあとの色
  final Color powder;

  static const _water = Color(0xFFE3EEF3);

  @override
  void paint(Canvas canvas, Size size) {
    canvas.scale(size.width / 100);

    final body = Path()
      ..moveTo(22, 34)
      ..lineTo(78, 34)
      ..lineTo(74, 126)
      ..quadraticBezierTo(73.5, 137, 63, 137)
      ..lineTo(37, 137)
      ..quadraticBezierTo(26.5, 137, 26, 126)
      ..close();

    // 本体（半透明の白いボトル）
    canvas.drawPath(
      body,
      Paint()..color = Colors.white.withValues(alpha: 0.94),
    );

    // 中身
    canvas.save();
    canvas.clipPath(body);
    const surfaceY = 56.0;
    final amp = 1.5 + agitation * 4;
    final waveTop = Path()..moveTo(0, 140);
    for (var x = 0.0; x <= 100; x += 4) {
      final y = surfaceY + math.sin((x / 100 * 2 + phase * 2) * math.pi) * amp;
      waveTop.lineTo(x, y);
    }
    waveTop
      ..lineTo(100, 140)
      ..close();
    final liquid = Color.lerp(_water, powder, mix)!;
    canvas.drawPath(waveTop, Paint()..color = liquid);

    // 底にたまった粉（混ざるほど薄くなる）
    final powderH = 26 * (1 - mix);
    if (powderH > 0.5) {
      final powderPath = Path()..moveTo(0, 140);
      for (var x = 0.0; x <= 100; x += 5) {
        powderPath.lineTo(x, 137 - powderH + math.sin(x / 9) * 2.5);
      }
      powderPath
        ..lineTo(100, 140)
        ..close();
      canvas.drawPath(powderPath, Paint()..color = powder);
      final grain = Paint()
        ..color = Color.lerp(
          powder,
          Colors.black,
          0.35,
        )!.withValues(alpha: 0.5);
      for (var i = 0; i < 14; i++) {
        canvas.drawCircle(
          Offset(30 + (i * 37) % 42, 137 - powderH * ((i * 0.37) % 0.9)),
          1.1,
          grain,
        );
      }
    }

    // 泡（混ざるほど厚くなる）
    if (mix > 0.15) {
      final foamH = 9 * mix;
      final foam = Path()..moveTo(0, surfaceY + foamH);
      for (var x = 0.0; x <= 100; x += 4) {
        foam.lineTo(
          x,
          surfaceY - 1 + math.sin((x / 100 * 2 + phase * 2) * math.pi) * amp,
        );
      }
      for (var x = 100.0; x >= 0; x -= 10) {
        foam.lineTo(x, surfaceY + foamH + math.sin(x / 6) * 1.5);
      }
      foam.close();
      canvas.drawPath(foam, Paint()..color = AppColors.milk);
    }

    // 振っている間の泡つぶ
    if (agitation > 0) {
      final bubble = Paint()..color = Colors.white.withValues(alpha: 0.7);
      for (var i = 0; i < 7; i++) {
        final x = 32 + (i * 23) % 38.0;
        final y = 128 - ((phase + i / 7) % 1) * 62;
        canvas.drawCircle(Offset(x, y), 1.6 + (i % 3), bubble);
      }
    }

    // 目盛り
    final tick = Paint()
      ..color = AppColors.ink.withValues(alpha: 0.22)
      ..strokeWidth = 2
      ..strokeCap = StrokeCap.round;
    for (final y in [70.0, 88.0, 106.0, 124.0]) {
      canvas.drawLine(Offset(62, y), Offset(70, y), tick);
    }
    canvas.restore();

    // ツヤ
    canvas.drawRRect(
      RRect.fromLTRBR(30, 42, 35, 120, const Radius.circular(3)),
      Paint()..color = Colors.white.withValues(alpha: 0.55),
    );
    // 輪郭
    canvas.drawPath(
      body,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2
        ..color = AppColors.ink.withValues(alpha: 0.12),
    );

    // えり・フタ・注ぎ口（濃い色）
    final cap = Paint()..color = AppColors.ink;
    canvas.drawRRect(
      RRect.fromLTRBR(18, 20, 82, 36, const Radius.circular(6)),
      cap,
    );
    canvas.drawRRect(
      RRect.fromLTRBR(30, 6, 70, 22, const Radius.circular(6)),
      cap,
    );
    canvas.drawRRect(
      RRect.fromLTRBR(42, 0, 58, 8, const Radius.circular(3)),
      Paint()..color = AppColors.inkSoft,
    );
    // フタの線
    canvas.drawLine(
      const Offset(22, 28),
      const Offset(78, 28),
      Paint()
        ..color = Colors.white.withValues(alpha: 0.15)
        ..strokeWidth = 1.5,
    );
  }

  @override
  bool shouldRepaint(_BottlePainter old) =>
      old.mix != mix ||
      old.phase != phase ||
      old.agitation != agitation ||
      old.powder != powder;
}
