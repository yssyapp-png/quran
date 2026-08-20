import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// ألوان هوية التطبيق: أخضر داكن + ذهبي، مستوحاة من زخرفة المصاحف التقليدية.
class AppColors {
  static const gold = Color(0xFF74652F);
  static const goldLight = Color(0xFFC3B473);
  static const darkGreenBg = Color(0xFF000000);
  static const darkGreenSurface = Color(0xFF0A100D);
  static const cream = Color(0xFFF7F2E8);
  static const creamPage = Color(0xFFFBF8F1);
  static const inkGreen = Color(0xFF176B57);
}

/// ألوان مخصّصة لشاشة قراءة المصحف في الوضع الليلي تحديدًا — أسود محايد
/// دافئ بدل الأخضر الداكن العام للتطبيق، أقرب لتجربة القراءة الليلية
/// المريحة في تطبيقات القراءة المعروفة (خلفية شبه سوداء، وسطح الصفحة
/// أفتح قليلًا منها بدرجة واحدة فقط لإبراز حواف الصفحة دون وهج).
class MushafDarkColors {
  static const background = Color(0xFF0B0B0C);
  static const page = Color(0xFF181818);
  static const overlay = Color(0xFF0F1113);
  static const divider = Color(0xFF2E2E2E);
  static const shadow = Color(0x66000000);
}

class AppTheme {
  static ThemeData get light {
    final scheme = ColorScheme.fromSeed(
      seedColor: AppColors.inkGreen,
      brightness: Brightness.light,
      surface: AppColors.cream,
    ).copyWith(
      primary: AppColors.inkGreen,
      primaryContainer: const Color(0xFFD5E9E1),
      secondary: const Color(0xFF4D7568),
      tertiary: AppColors.gold,
      tertiaryContainer: const Color(0xFFE9E0BC),
      surfaceContainerLow: AppColors.creamPage,
      surfaceContainer: const Color(0xFFF1EBDD),
      outline: const Color(0xFF7A8983),
    );
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.light,
      scaffoldBackgroundColor: AppColors.cream,
      colorScheme: scheme,
      appBarTheme: const AppBarTheme(
        backgroundColor: AppColors.cream,
        foregroundColor: Color(0xFF173C33),
        centerTitle: true,
        elevation: 0,
      ),
      // خط "Cairo" لواجهة التطبيق (الأزرار، القوائم، النصوص العامة)، مختلف
      // عن خط النص القرآني نفسه (UthmanicHafs) الذي يُستخدم صراحةً في
      // عناصر عرض الآيات فقط (التفسير، نتائج البحث، معاينة القارئ).
      fontFamily: GoogleFonts.cairo().fontFamily,
      textSelectionTheme: const TextSelectionThemeData(
        // لون التحديد/التمييز الموحّد في كل التطبيق: ذهبي بدل الأخضر الداكن.
        selectionColor: Color(0x55C4A03C),
        selectionHandleColor: AppColors.gold,
        cursorColor: AppColors.gold,
      ),
      dividerColor: AppColors.gold.withValues(alpha: 0.35),
      cardTheme: CardThemeData(
        color: Colors.white.withValues(alpha: 0.82),
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: const BorderSide(color: Color(0xFFE5D9C5)),
        ),
      ),
      navigationBarTheme: const NavigationBarThemeData(
        height: 72,
        backgroundColor: Color(0xFFFBF8F1),
        indicatorColor: Color(0xFFD5E9E1),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: AppColors.creamPage,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(18),
          borderSide: BorderSide.none,
        ),
      ),
    );
  }

  static ThemeData get dark {
    final scheme = ColorScheme.fromSeed(
      seedColor: const Color(0xFF3F9B7B),
      brightness: Brightness.dark,
      surface: AppColors.darkGreenBg,
    ).copyWith(
      primary: const Color(0xFF72C5A6),
      onPrimary: const Color(0xFF001F16),
      primaryContainer: const Color(0xFF0B3B2D),
      secondary: const Color(0xFF91B7A8),
      tertiary: AppColors.goldLight,
      surfaceContainerLow: const Color(0xFF050806),
      surfaceContainer: AppColors.darkGreenSurface,
      surfaceContainerHigh: const Color(0xFF101914),
      outline: const Color(0xFF40544C),
      outlineVariant: const Color(0xFF26342E),
    );
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      scaffoldBackgroundColor: AppColors.darkGreenBg,
      colorScheme: scheme,
      appBarTheme: const AppBarTheme(
        backgroundColor: AppColors.darkGreenBg,
        foregroundColor: AppColors.gold,
        centerTitle: true,
        elevation: 0,
      ),
      fontFamily: GoogleFonts.cairo().fontFamily,
      textSelectionTheme: const TextSelectionThemeData(
        selectionColor: Color(0x55C4A03C),
        selectionHandleColor: AppColors.gold,
        cursorColor: AppColors.gold,
      ),
      dividerColor: AppColors.gold.withValues(alpha: 0.25),
      cardTheme: CardThemeData(
        color: AppColors.darkGreenSurface,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: const BorderSide(color: Color(0xFF26342E)),
        ),
      ),
      navigationBarTheme: const NavigationBarThemeData(
        height: 72,
        backgroundColor: Color(0xFF050806),
        indicatorColor: Color(0xFF0B3B2D),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: const Color(0xFF0A100D),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(18),
          borderSide: BorderSide.none,
        ),
      ),
    );
  }
}
