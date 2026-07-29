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

/// باقة ألوان اختيارية لـ"الإطار الفاخر" فقط — مستوحاة من لون الزخرفة
/// الفعلي داخل صفحتي الفاتحة وأول البقرة نفسيهما (المربع الأخضر الفاتح
/// خلف النص)، لمن يفضّل انسجامًا بصريًا مع الصفحة بدل الذهبي الكلاسيكي.
/// لا تُستخدم في أي مكان آخر بالتطبيق ولا تؤثر على صورة المصحف نفسها.
class MushafFrameHarmonyColors {
  static const background = Color(0xFFF8F4E8);
  static const primaryGreen = Color(0xFF9FB78D);
  static const darkGreen = Color(0xFF6E8B63);
  static const gold = Color(0xFFC8A55A);
  static const outline = Color(0xFF5A6A4C);
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
