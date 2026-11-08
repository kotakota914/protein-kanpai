import 'package:flutter/material.dart';

/// アプリ全体の色。Figma の変数（Color コレクション）と同じ値にそろえている。
class AppColors {
  static const primary = Color(0xFFFF7A1A); // 振った：元気なオレンジ
  static const primarySoft = Color(0xFFFFECDD);
  static const cheer = Color(0xFFFFC233); // 乾杯：金色
  static const cheerSoft = Color(0xFFFFF3D5);
  static const background = Color(0xFFFFF8F1); // あたたかいクリーム色
  static const surface = Colors.white;
  static const ink = Color(0xFF2B2118); // 文字色
  static const muted = Color(0xFF8D7A69); // 補足の文字色
  static const line = Color(0xFFEFE5DB); // 線・空のマス
  static const gold = Color(0xFFE0A100); // 星アイコン
  static const inkSoft = Color(0xFF4A3B2E); // シェイカーの注ぎ口

  // プロテインの色（ココア味のシェイク）
  static const cocoa = Color(0xFF9A6240);
  static const cocoaDark = Color(0xFF6E4029);
  static const milk = Color(0xFFF4E4D0); // 泡
}

/// 文字の設定。見出しは丸みのある Zen Maru Gothic、本文は Noto Sans JP。
/// どちらも assets/fonts に同梱している（pubspec.yaml の fonts）。
class AppFonts {
  static const body = 'NotoSansJP';
  static const display = 'ZenMaruGothic';

  static TextStyle heading(double size, {Color color = AppColors.ink}) {
    return TextStyle(
      fontFamily: display,
      fontSize: size,
      fontWeight: FontWeight.w900,
      color: color,
      height: 1.3,
    );
  }
}

ThemeData buildTheme() {
  final scheme = ColorScheme.fromSeed(
    seedColor: AppColors.primary,
    primary: AppColors.primary,
    surface: AppColors.background,
  );
  final base = ThemeData(colorScheme: scheme, fontFamily: AppFonts.body);

  return base.copyWith(
    scaffoldBackgroundColor: AppColors.background,
    textTheme: base.textTheme.apply(
      bodyColor: AppColors.ink,
      displayColor: AppColors.ink,
    ),
    appBarTheme: AppBarTheme(
      backgroundColor: AppColors.background,
      surfaceTintColor: Colors.transparent,
      foregroundColor: AppColors.ink,
      centerTitle: false,
      titleTextStyle: AppFonts.heading(24),
    ),
    cardTheme: CardThemeData(
      color: AppColors.surface,
      elevation: 0,
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        minimumSize: const Size.fromHeight(54),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        textStyle: const TextStyle(
          fontFamily: AppFonts.body,
          fontSize: 16,
          fontWeight: FontWeight.w700,
        ),
      ),
    ),
    navigationBarTheme: NavigationBarThemeData(
      backgroundColor: AppColors.surface,
      indicatorColor: AppColors.primarySoft,
      iconTheme: WidgetStateProperty.resolveWith(
        (states) => IconThemeData(
          color: states.contains(WidgetState.selected)
              ? AppColors.primary
              : AppColors.muted,
        ),
      ),
      labelTextStyle: WidgetStateProperty.resolveWith(
        (states) => TextStyle(
          fontFamily: AppFonts.body,
          fontSize: 11,
          fontWeight: states.contains(WidgetState.selected)
              ? FontWeight.w700
              : FontWeight.w400,
          color: states.contains(WidgetState.selected)
              ? AppColors.primary
              : AppColors.muted,
        ),
      ),
    ),
  );
}
