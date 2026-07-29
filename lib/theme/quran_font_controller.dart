import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// مستوى سماكة خط القرآن (HafsSmart) في النصوص الحيّة بالتطبيق (التفسير
/// ونتائج البحث) — قابل للتبديل من الإعدادات ليختار المستخدم ما يناسب
/// راحته البصرية دون التأثير على صور صفحات المصحف نفسها (وهي صور ثابتة
/// من المصدر الرسمي ولا تتأثر بهذا الإعداد).
enum QuranFontBoldness {
  normal, // الوزن الافتراضي للخط دون أي تثخين إضافي
  bold, // FontWeight.bold فقط
  extraBold; // FontWeight.bold + طبقة "حدّ" (stroke) إضافية لتثخين أعلى

  String get labelAr {
    switch (this) {
      case QuranFontBoldness.normal:
        return 'عادي';
      case QuranFontBoldness.bold:
        return 'عريض';
      case QuranFontBoldness.extraBold:
        return 'عريض جدًا';
    }
  }

  FontWeight get fontWeight =>
      this == QuranFontBoldness.normal ? FontWeight.normal : FontWeight.bold;

  /// سماكة طبقة الحدّ الإضافية؛ صفر يعني عدم رسم أي طبقة حدّ (لا فرق عن bold).
  double get strokeWidth => this == QuranFontBoldness.extraBold ? 1.1 : 0;
}

/// يتحكم بمستوى سماكة خط القرآن الحيّ في كل أنحاء التطبيق ويحفظ اختيار
/// المستخدم محليًا، بنفس نمط [ThemeController] الموجود فعلًا.
class QuranFontController extends ValueNotifier<QuranFontBoldness> {
  static const _prefKey = 'quran_font_boldness';

  QuranFontController() : super(QuranFontBoldness.bold);

  Future<void> load() async {
    final prefs = await SharedPreferences.getInstance();
    final saved = prefs.getString(_prefKey);
    value = QuranFontBoldness.values.firstWhere(
      (v) => v.name == saved,
      orElse: () => QuranFontBoldness.bold,
    );
  }

  Future<void> setLevel(QuranFontBoldness level) async {
    value = level;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_prefKey, level.name);
  }
}

final quranFontController = QuranFontController();
