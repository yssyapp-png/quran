import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// يتحكم بالوضع الليلي/النهاري ويحفظ اختيار المستخدم محليًا.
class ThemeController extends ValueNotifier<ThemeMode> {
  static const _prefKey = 'theme_mode';

  ThemeController() : super(ThemeMode.dark);

  Future<void> load() async {
    final prefs = await SharedPreferences.getInstance();
    final saved = prefs.getString(_prefKey);
    if (saved == 'light') {
      value = ThemeMode.light;
    } else if (saved == 'dark') {
      value = ThemeMode.dark;
    } else {
      // افتراضيًا: نتبع وضع النظام إن لم يوجد اختيار محفوظ
      value = ThemeMode.dark;
    }
  }

  Future<void> toggle() async {
    value = value == ThemeMode.dark ? ThemeMode.light : ThemeMode.dark;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_prefKey, value == ThemeMode.dark ? 'dark' : 'light');
  }

  bool get isDark => value == ThemeMode.dark;
}

final themeController = ThemeController();
