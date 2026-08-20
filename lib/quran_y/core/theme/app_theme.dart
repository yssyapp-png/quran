import 'package:flutter/material.dart';

abstract final class AppTheme {
  static const Color _primary = Color(0xFF176B57);
  static const Color _background = Color(0xFFF7F2E8);

  static ThemeData get light {
    final colorScheme = ColorScheme.fromSeed(
      seedColor: _primary,
      brightness: Brightness.light,
      surface: _background,
    ).copyWith(
      primary: _primary,
      primaryContainer: const Color(0xFFD5E9E1),
      secondary: const Color(0xFF4D7568),
      secondaryContainer: const Color(0xFFD9E7E1),
      tertiary: const Color(0xFF74652F),
      tertiaryContainer: const Color(0xFFE9E0BC),
      error: const Color(0xFF8A6517),
      errorContainer: const Color(0xFFF1E1A9),
      surface: _background,
      surfaceContainerLow: const Color(0xFFFBF8F1),
      surfaceContainer: const Color(0xFFF1EBDD),
      outline: const Color(0xFF7A8983),
    );

    return ThemeData(
      useMaterial3: true,
      colorScheme: colorScheme,
      scaffoldBackgroundColor: _background,
      fontFamilyFallback: const ['Geeza Pro', 'Arial'],
      appBarTheme: const AppBarTheme(
        centerTitle: true,
        backgroundColor: _background,
        foregroundColor: Color(0xFF173C33),
        elevation: 0,
      ),
      cardTheme: CardThemeData(
        color: Colors.white.withValues(alpha: 0.82),
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: const BorderSide(color: Color(0xFFE5D9C5)),
        ),
      ),
    );
  }

  static ThemeData get night {
    const surface = Color(0xFF000000);
    final colorScheme = ColorScheme.fromSeed(
      seedColor: const Color(0xFF3F9B7B),
      brightness: Brightness.dark,
      surface: surface,
    ).copyWith(
      primary: const Color(0xFF72C5A6),
      onPrimary: const Color(0xFF001F16),
      primaryContainer: const Color(0xFF0B3B2D),
      onPrimaryContainer: const Color(0xFFA8E8CF),
      secondary: const Color(0xFF91B7A8),
      onSecondary: const Color(0xFF082018),
      secondaryContainer: const Color(0xFF18342B),
      onSecondaryContainer: const Color(0xFFC3DDD2),
      tertiary: const Color(0xFFC3B473),
      onTertiary: const Color(0xFF292300),
      tertiaryContainer: const Color(0xFF3D3615),
      onTertiaryContainer: const Color(0xFFE8DB9C),
      error: const Color(0xFFD7A93D),
      onError: const Color(0xFF211800),
      errorContainer: const Color(0xFF3C310F),
      onErrorContainer: const Color(0xFFF1D68B),
      surface: surface,
      onSurface: const Color(0xFFE1E7E3),
      surfaceContainerLowest: surface,
      surfaceContainerLow: const Color(0xFF050806),
      surfaceContainer: const Color(0xFF0A100D),
      surfaceContainerHigh: const Color(0xFF101914),
      surfaceContainerHighest: const Color(0xFF17231E),
      outline: const Color(0xFF40544C),
      outlineVariant: const Color(0xFF26342E),
      inverseSurface: const Color(0xFFDCE6E0),
      onInverseSurface: const Color(0xFF17201C),
      inversePrimary: const Color(0xFF176B57),
    );

    return ThemeData(
      useMaterial3: true,
      colorScheme: colorScheme,
      scaffoldBackgroundColor: surface,
      fontFamilyFallback: const ['Geeza Pro', 'Arial'],
      appBarTheme: const AppBarTheme(
        centerTitle: true,
        backgroundColor: surface,
        elevation: 0,
      ),
      navigationBarTheme: const NavigationBarThemeData(
        backgroundColor: Color(0xFF050806),
      ),
      cardTheme: CardThemeData(
        color: const Color(0xFF0A100D),
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: const BorderSide(color: Color(0xFF26342E)),
        ),
      ),
    );
  }
}
