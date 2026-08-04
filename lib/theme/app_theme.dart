import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

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
        fontFamily: GoogleFonts.cairo().fontFamily,
        textSelectionTheme: const TextSelectionThemeData(
          selectionColor: Color(0x55C4A03C),
          selectionHandleColor: AppColors.gold,
          cursorColor: AppColors.gold,
        ),
        dividerColor: AppColors.gold.withOpacity(0.25),
      );
}
