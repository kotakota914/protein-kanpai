import 'package:flutter/material.dart';

/// アプリ全体の色。ジムの景色から取っている。
///
/// - 床：ゴムマットの黒
/// - 文字：チョークの白
/// - 振った：電光掲示板のアンバー（唯一のネオン色）
/// - 乾杯：バーベルの 20kg プレートの青
class AppColors {
  static const background = Color(0xFF000000); // ゴムマットの床
  static const surface = Color(0xFF1C1C1C); // 一段上の面
  static const line = Color(0xFF2E2E2E); // 区切り・空のマス
  static const ink = Color(0xFFF2F1EC); // チョークの白
  static const muted = Color(0xFF9C9B95); // 補足の文字
  static const primary = Color(0xFFFFB21A); // 電光掲示板のアンバー
  static const onPrimary = Color(0xFF000000);
  static const primarySoft = Color(0xFF2B2112); // アンバーの暗い下地
  static const cheer = Color(0xFF3D7BFF); // 20kg プレートの青
  static const cheerSoft = Color(0xFF111C33);
  static const inkSoft = Color(0xFFCC8A00); // シェイカーの注ぎ口

  // プロテインの色（ココア味のシェイク）
  static const cocoa = Color(0xFF9A6240);
  static const cocoaDark = Color(0xFF6E4029);
  static const milk = Color(0xFFF4E4D0); // 泡
}

/// 文字。見出しと数字は極太の Dela Gothic One、本文は Zen Kaku Gothic New。
/// どちらも assets/fonts に同梱している（pubspec.yaml の fonts）。
class AppFonts {
  static const body = 'ZenKakuGothicNew';
  static const display = 'DelaGothicOne';

  /// 見出し・大きな数字（Dela Gothic One は太さが 1 種類だけ）
  static TextStyle heading(double size, {Color color = AppColors.ink}) {
    return TextStyle(
      fontFamily: display,
      fontSize: size,
      fontWeight: FontWeight.w400,
      color: color,
      height: 1.15,
    );
  }
}

ThemeData buildTheme() {
  const scheme = ColorScheme.dark(
    primary: AppColors.primary,
    onPrimary: AppColors.onPrimary,
    secondary: AppColors.cheer,
    onSecondary: AppColors.ink,
    surface: AppColors.background,
    onSurface: AppColors.ink,
    surfaceContainerHighest: AppColors.surface,
    outline: AppColors.line,
  );
  final base = ThemeData(
    colorScheme: scheme,
    brightness: Brightness.dark,
    fontFamily: AppFonts.body,
  );

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
      titleTextStyle: AppFonts.heading(22),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        backgroundColor: AppColors.primary,
        foregroundColor: AppColors.onPrimary,
        minimumSize: const Size.fromHeight(56),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
        textStyle: const TextStyle(
          fontFamily: AppFonts.display,
          fontSize: 17,
        ),
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        foregroundColor: AppColors.ink,
        side: const BorderSide(color: AppColors.line, width: 1.5),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
        textStyle: const TextStyle(
          fontFamily: AppFonts.body,
          fontSize: 14,
          fontWeight: FontWeight.w700,
        ),
      ),
    ),
    snackBarTheme: const SnackBarThemeData(
      backgroundColor: AppColors.ink,
      contentTextStyle: TextStyle(
        fontFamily: AppFonts.body,
        color: AppColors.background,
        fontWeight: FontWeight.w700,
      ),
    ),
    bottomSheetTheme: const BottomSheetThemeData(
      backgroundColor: AppColors.surface,
      dragHandleColor: AppColors.line,
    ),
    navigationBarTheme: NavigationBarThemeData(
      backgroundColor: AppColors.background,
      indicatorColor: Colors.transparent,
      height: 68,
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
          fontWeight: FontWeight.w700,
          color: states.contains(WidgetState.selected)
              ? AppColors.primary
              : AppColors.muted,
        ),
      ),
    ),
  );
}
