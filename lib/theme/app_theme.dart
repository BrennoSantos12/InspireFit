import 'package:flutter/material.dart';

class AppColors {
  static const black = Color(0xFF000000);
  static const surface = Color(0xFF111114);
  static const surfaceAlt = Color(0xFF1F2937);
  static const border = Color(0xFF374151);
  static const borderDim = Color(0xFF1F2937);
  static const textMuted = Color(0xFF9CA3AF);
  static const textFaint = Color(0xFF6B7280);

  static const green = Color(0xFF15803D);
  static const greenBright = Color(0xFF22C55E);
  static const blue = Color(0xFF3B82F6);
  static const orange = Color(0xFFF97316);
  static const red = Color(0xFFEF4444);
}

ThemeData buildAppTheme() {
  const seed = AppColors.greenBright;
  final base = ThemeData(
    useMaterial3: true,
    brightness: Brightness.dark,
    scaffoldBackgroundColor: AppColors.black,
    colorScheme: ColorScheme.fromSeed(
      seedColor: seed,
      brightness: Brightness.dark,
      surface: AppColors.black,
    ),
    fontFamily: 'Roboto',
  );

  return base.copyWith(
    appBarTheme: const AppBarTheme(
      backgroundColor: AppColors.black,
      foregroundColor: Colors.white,
      elevation: 0,
      centerTitle: false,
    ),
    drawerTheme: const DrawerThemeData(backgroundColor: AppColors.surface),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: AppColors.surface,
      hintStyle: const TextStyle(color: AppColors.textFaint),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: AppColors.border),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: AppColors.border),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: AppColors.greenBright),
      ),
    ),
    textTheme: base.textTheme.apply(
      bodyColor: Colors.white,
      displayColor: Colors.white,
    ),
  );
}
