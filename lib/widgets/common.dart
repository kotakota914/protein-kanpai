import 'dart:typed_data';

import 'package:flutter/material.dart';

import '../app/theme.dart';

/// 一段上の面（角は小さめ・影なし）。ジムのゴムマットに置いた台のイメージ。
class AppCard extends StatelessWidget {
  const AppCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(16),
    this.color = AppColors.surface,
    this.borderColor,
    this.onTap,
  });

  final Widget child;
  final EdgeInsetsGeometry padding;
  final Color color;
  final Color? borderColor;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: color,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(8),
        side: borderColor != null
            ? BorderSide(color: borderColor!, width: 1.5)
            : BorderSide.none,
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(padding: padding, child: child),
      ),
    );
  }
}

/// 友達・自分のアイコン。写真があれば写真、なければ名前の 1 文字。
class Avatar extends StatelessWidget {
  const Avatar({
    super.key,
    required this.initial,
    this.photo,
    this.color = AppColors.surface,
    this.textColor = AppColors.ink,
    this.size = 44,
    this.ringColor,
  });

  final String initial;

  /// 自分で選んだ写真（なければ null）
  final Uint8List? photo;
  final Color color;
  final Color textColor;
  final double size;

  /// 外側の輪（乾杯できる友達などを目立たせる）
  final Color? ringColor;

  /// 名前ごとに文字の色を変える（同じ名前なら同じ色）
  static Color colorFor(String name) {
    const palette = [
      AppColors.primary,
      AppColors.cheer,
      Color(0xFF39C27A), // 10kg プレートの緑
      Color(0xFFFF4D4D), // 25kg プレートの赤
    ];
    return palette[name.hashCode.abs() % palette.length];
  }

  @override
  Widget build(BuildContext context) {
    final photo = this.photo;
    return Container(
      width: size,
      height: size,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: color,
        shape: BoxShape.circle,
        border: ringColor != null ? Border.all(color: ringColor!, width: 2.5) : null,
      ),
      clipBehavior: Clip.antiAlias,
      child: photo != null
          ? Image.memory(
              photo,
              width: size,
              height: size,
              fit: BoxFit.cover,
              gaplessPlayback: true,
            )
          : Text(initial, style: AppFonts.heading(size * 0.42, color: textColor)),
    );
  }
}

/// 丸の中にアイコン（またはシェイカーなどの部品）
class IconBadge extends StatelessWidget {
  const IconBadge({
    super.key,
    this.icon,
    this.child,
    this.size = 48,
    this.background = AppColors.surface,
    this.foreground = AppColors.primary,
  });

  /// どちらか一方を指定する（シェイカーは [child] に ShakerIcon を渡す）
  final IconData? icon;
  final Widget? child;
  final double size;
  final Color background;
  final Color foreground;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      alignment: Alignment.center,
      decoration: BoxDecoration(color: background, shape: BoxShape.circle),
      child: child ?? Icon(icon, size: size * 0.52, color: foreground),
    );
  }
}

/// 小さな札（「乾杯OK」など）。角は小さく、ジムのテープのような見た目。
class Pill extends StatelessWidget {
  const Pill({
    super.key,
    required this.label,
    this.icon,
    this.leading,
    this.background = AppColors.cheer,
    this.foreground = AppColors.ink,
    this.iconColor,
  });

  final String label;
  final IconData? icon;

  /// アイコンの代わりに置く部品（シェイカーなど）
  final Widget? leading;
  final Color background;
  final Color foreground;
  final Color? iconColor;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(4),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (leading != null || icon != null) ...[
            leading ?? Icon(icon, size: 14, color: iconColor ?? foreground),
            const SizedBox(width: 4),
          ],
          Text(
            label,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              color: foreground,
            ),
          ),
        ],
      ),
    );
  }
}

/// 小見出し
class SectionLabel extends StatelessWidget {
  const SectionLabel(this.text, {super.key});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: const TextStyle(
        fontSize: 13,
        fontWeight: FontWeight.w700,
        color: AppColors.muted,
      ),
    );
  }
}

/// アイコンの対応表。シェイカーは widgets/shaker.dart の ShakerIcon を使う。
class AppIcons {
  static const cheer = Icons.wine_bar_rounded;
  static const flame = Icons.local_fire_department_rounded;
  static const star = Icons.star_rounded;
  static const gemini = Icons.auto_awesome;
  static const camera = Icons.photo_camera_outlined;
}

/// 「40分前」のような相対時刻
String relativeTime(DateTime at, DateTime now) {
  final d = now.difference(at);
  if (d.inMinutes < 1) return 'たった今';
  if (d.inHours < 1) return '${d.inMinutes}分前';
  if (d.inDays < 1) return '${d.inHours}時間前';
  return '${d.inDays}日前';
}

const weekdayLabels = ['月', '火', '水', '木', '金', '土', '日'];
