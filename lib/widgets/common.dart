import 'dart:typed_data';

import 'package:flutter/material.dart';

import '../app/theme.dart';

/// 白いカード（角丸 20・うすい影）。Figma の各カードと同じ見た目。
class AppCard extends StatelessWidget {
  const AppCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
    this.color = AppColors.surface,
    this.borderColor,
    this.shadow = true,
    this.onTap,
  });

  final Widget child;
  final EdgeInsetsGeometry padding;
  final Color color;
  final Color? borderColor;
  final bool shadow;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final radius = BorderRadius.circular(20);
    return DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: radius,
        boxShadow: shadow
            ? const [
                BoxShadow(
                  color: Color(0x14664019),
                  blurRadius: 16,
                  offset: Offset(0, 4),
                ),
              ]
            : null,
      ),
      child: Material(
        color: color,
        shape: RoundedRectangleBorder(
          borderRadius: radius,
          side: borderColor != null
              ? BorderSide(color: borderColor!, width: 1.5)
              : BorderSide.none,
        ),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: Padding(padding: padding, child: child),
        ),
      ),
    );
  }
}

/// 友達・自分のアイコン。写真があれば写真、なければ名前の 1 文字を丸に入れる。
class Avatar extends StatelessWidget {
  const Avatar({
    super.key,
    required this.initial,
    this.photo,
    this.color = AppColors.cheerSoft,
    this.size = 44,
  });

  final String initial;

  /// 自分で選んだ写真（なければ null）
  final Uint8List? photo;
  final Color color;
  final double size;

  /// 名前ごとに色を変える（同じ名前なら同じ色）
  static Color colorFor(String name) {
    const palette = [
      AppColors.cheerSoft,
      AppColors.primarySoft,
      Color(0xFFE6F2E8),
      Color(0xFFE6EEF8),
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
      decoration: BoxDecoration(color: color, shape: BoxShape.circle),
      clipBehavior: Clip.antiAlias,
      child: photo != null
          ? Image.memory(
              photo,
              width: size,
              height: size,
              fit: BoxFit.cover,
              gaplessPlayback: true,
            )
          : Text(
              initial,
              style: AppFonts.heading(
                size * 0.4,
                color: color == AppColors.primary ? Colors.white : AppColors.ink,
              ),
            ),
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
    this.background = AppColors.primarySoft,
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

/// 小さな丸いラベル（「乾杯OK」「Gemini で読み取り」など）
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
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(999),
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

/// 小見出し（「いま振っている友達」など）
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

/// アイコンの対応表（Figma のアイコンに近い Material アイコン）。
/// シェイカーは Material にないため widgets/shaker.dart の ShakerIcon を使う。
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
