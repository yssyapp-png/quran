import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:quran/quran_y/core/state/app_state.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  group('AppState', () {
    test(
      'restores safe persisted preferences and filters invalid bookmarks',
      () async {
        SharedPreferences.setMockInitialValues({
          'quran_y_theme_mode': ThemeMode.dark.index,
          'quran_y_last_read_page': 900,
          'quran_y_bookmarked_pages': ['1', '42', '0', '605', 'invalid'],
        });

        final state = AppState();
        addTearDown(state.dispose);
        await state.ready;

        expect(state.themeMode, ThemeMode.dark);
        expect(state.lastReadPage, 604);
        expect(state.bookmarkedPages, {1, 42});
      },
    );

    test('persists theme, bounded last page, and sorted bookmarks', () async {
      SharedPreferences.setMockInitialValues({});
      final state = AppState();
      addTearDown(state.dispose);
      await state.ready;

      state.setThemeMode(ThemeMode.light);
      state.updateLastReadPage(900);
      state.toggleBookmark(42);
      state.toggleBookmark(2);
      await Future<void>.delayed(const Duration(milliseconds: 20));

      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getInt('quran_y_theme_mode'), ThemeMode.light.index);
      expect(prefs.getInt('quran_y_last_read_page'), 604);
      expect(prefs.getStringList('quran_y_bookmarked_pages'), ['2', '42']);
    });
  });
}
