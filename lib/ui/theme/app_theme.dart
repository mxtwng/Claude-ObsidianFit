/// Obsidian-dark, high-contrast theme: pure black background, white text,
/// violet accent.
library;

import 'package:flutter/material.dart';

class AppColors {
  const AppColors._();

  static const Color background = Color(0xFF000000);
  static const Color surface = Color(0xFF0D0D10);
  static const Color surfaceHigh = Color(0xFF17171C);
  static const Color outline = Color(0xFF2A2A32);
  static const Color text = Color(0xFFFFFFFF);
  static const Color textDim = Color(0xFFA1A1AA);
  static const Color accent = Color(0xFFA78BFA);
  static const Color done = Color(0xFF4ADE80);
  static const Color activity = Color(0xFFFB923C);
  static const Color danger = Color(0xFFF87171);
  static const Color warmup = Color(0xFFFBBF24);
  static const Color drop = Color(0xFF60A5FA);
}

ThemeData buildAppTheme() {
  const scheme = ColorScheme.dark(
    primary: AppColors.accent,
    onPrimary: Colors.black,
    secondary: AppColors.done,
    onSecondary: Colors.black,
    surface: AppColors.surface,
    onSurface: AppColors.text,
    error: AppColors.danger,
    outline: AppColors.outline,
  );
  final base = ThemeData(
    brightness: Brightness.dark,
    useMaterial3: true,
    colorScheme: scheme,
  );

  return base.copyWith(
    scaffoldBackgroundColor: AppColors.background,
    canvasColor: AppColors.background,
    textTheme: base.textTheme.apply(
      bodyColor: AppColors.text,
      displayColor: AppColors.text,
    ),
    appBarTheme: const AppBarTheme(
      backgroundColor: AppColors.background,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      scrolledUnderElevation: 0,
      centerTitle: false,
      titleTextStyle: TextStyle(
        color: AppColors.text,
        fontSize: 22,
        fontWeight: FontWeight.w700,
      ),
    ),
    navigationBarTheme: NavigationBarThemeData(
      backgroundColor: AppColors.background,
      surfaceTintColor: Colors.transparent,
      indicatorColor: AppColors.accent.withAlpha(60),
    ),
    bottomSheetTheme: const BottomSheetThemeData(
      backgroundColor: AppColors.surfaceHigh,
      modalBackgroundColor: AppColors.surfaceHigh,
      surfaceTintColor: Colors.transparent,
      showDragHandle: true,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
    ),
    dividerTheme: const DividerThemeData(color: AppColors.outline),
    snackBarTheme: const SnackBarThemeData(
      backgroundColor: AppColors.surfaceHigh,
      contentTextStyle: TextStyle(color: AppColors.text),
      behavior: SnackBarBehavior.floating,
    ),
  );
}
