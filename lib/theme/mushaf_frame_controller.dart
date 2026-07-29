import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// "الإطار الفاخر": زخرفة ذهبية اختيارية حول صفحة المصحف تُقرِّب شكل
/// العرض من طبعات "المصحف الممتاز" الفاخرة — دون أي مساس بصورة الصفحة
/// الرسمية نفسها (تبقى بكسلاتها كما هي تمامًا من مجمع الملك فهد)، فهي
/// مجرد إطار زخرفي في واجهة التطبيق حول الصورة الأصلية.
class MushafFrameController extends ValueNotifier<bool> {
  static const _prefKey = 'mushaf_luxury_frame';

  MushafFrameController() : super(false);

  Future<void> load() async {
    final prefs = await SharedPreferences.getInstance();
    value = prefs.getBool(_prefKey) ?? false;
  }

  Future<void> setEnabled(bool enabled) async {
    value = enabled;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_prefKey, enabled);
  }
}

final mushafFrameController = MushafFrameController();

/// نمط ألوان "الإطار الفاخر" — خيار ذوقي إضافي اختياري بالكامل، لا علاقة
/// له بصورة صفحة المصحف نفسها (تبقى كما هي دائمًا)؛ يغيّر فقط لون الإطار
/// الزخرفي المرسوم في واجهة التطبيق حول صفحتي الفاتحة وأول البقرة.
enum MushafFrameColorScheme {
  gold, // الذهبي الكلاسيكي المعتمد افتراضيًا
  harmonyGreen; // أخضر متناسق مع لون الزخرفة داخل صفحتي الافتتاح نفسيهما

  String get labelAr {
    switch (this) {
      case MushafFrameColorScheme.gold:
        return 'ذهبي كلاسيكي';
      case MushafFrameColorScheme.harmonyGreen:
        return 'أخضر متناسق مع صفحة الفاتحة';
    }
  }
}

class MushafFrameColorController extends ValueNotifier<MushafFrameColorScheme> {
  static const _prefKey = 'mushaf_frame_color_scheme';

  MushafFrameColorController() : super(MushafFrameColorScheme.gold);

  Future<void> load() async {
    final prefs = await SharedPreferences.getInstance();
    final saved = prefs.getString(_prefKey);
    value = MushafFrameColorScheme.values.firstWhere(
      (v) => v.name == saved,
      orElse: () => MushafFrameColorScheme.gold,
    );
  }

  Future<void> setScheme(MushafFrameColorScheme scheme) async {
    value = scheme;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_prefKey, scheme.name);
  }
}

final mushafFrameColorController = MushafFrameColorController();
