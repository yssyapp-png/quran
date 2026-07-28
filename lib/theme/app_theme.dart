import 'package:flutter/material.dart';

/// ألوان هوية التطبيق: أخضر داكن + ذهبي، مستوحاة من زخرفة المصاحف التقليدية.
class AppColors {
  static const gold = Color(0xFFC4A03C);
  static const goldLight = Color(0xFFE3C879);
  static const darkGreenBg = Color(0xFF0C2320);
  static const darkGreenSurface = Color(0xFF123330);
  static const cream = Color(0xFFF7F1DE);
  static const creamPage = Color(0xFFFBF6E9);
  static const inkGreen = Color(0xFF0F3D3A);
}

class AppTheme {
  static ThemeData get light => ThemeData(
        useMaterial3: true,
        brightness: Brightness.light,
        scaffoldBackgroundColor: AppColors.cream,
        colorScheme: ColorScheme.fromSeed(
          seedColor: AppColors.inkGreen,
          brightness: Brightness.light,
          primary: AppColors.inkGreen,
          secondary: AppColors.gold,
        ),
        appBarTheme: const AppBarTheme(
          backgroundColor: AppColors.inkGreen,
          foregroundColor: AppColors.cream,
          centerTitle: true,
          elevation: 0,
        ),
        fontFamily: 'HafsSmart',
        dividerColor: AppColors.gold.withOpacity(0.35),
      );

  static ThemeData get dark => ThemeData(
        useMaterial3: true,
        brightness: Brightness.dark,
        scaffoldBackgroundColor: AppColors.darkGreenBg,
        colorScheme: ColorScheme.fromSeed(
          seedColor: AppColors.inkGreen,
          brightness: Brightness.dark,
          primary: AppColors.gold,
          secondary: AppColors.goldLight,
          surface: AppColors.darkGreenSurface,
        ),
        appBarTheme: const AppBarTheme(
          backgroundColor: AppColors.darkGreenBg,
          foregroundColor: AppColors.gold,
          centerTitle: true,
          elevation: 0,
        ),
        fontFamily: 'HafsSmart',
        dividerColor: AppColors.gold.withOpacity(0.25),
      );
}
