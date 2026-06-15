import 'package:flutter/material.dart';

/// Paleta e tema escuro do InspireFit (espelha o app Vue: fundo preto, texto
/// branco, verde como cor de ação, vermelho para excluir).
class AppColors {
  static const black = Color(0xFF000000);
  static const surface = Color(0xFF111114); // gray-900 aprox.
  static const surfaceAlt = Color(0xFF1F2937); // gray-800
  static const border = Color(0xFF374151); // gray-700
  static const borderDim = Color(0xFF1F2937);
  static const textMuted = Color(0xFF9CA3AF); // gray-400
  static const textFaint = Color(0xFF6B7280); // gray-500

  static const green = Color(0xFF15803D); // green-700 (ações)
  static const greenBright = Color(0xFF22C55E); // green-500 (concluído)
  static const blue = Color(0xFF3B82F6); // treino de hoje
  static const orange = Color(0xFFF97316); // adiantar
  static const red = Color(0xFFEF4444); // atrasado / excluir
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
