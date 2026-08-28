import 'dart:async';

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../constants/app_constants.dart';

class AppState extends ChangeNotifier {
  AppState() {
    ready = _restore();
  }

  late final Future<void> ready;

  static const _themeKey = 'quran_y_theme_mode';
  static const _lastPageKey = 'quran_y_last_read_page';
  static const _bookmarksKey = 'quran_y_bookmarked_pages';

  ThemeMode _themeMode = ThemeMode.system;
  int _lastReadPage = AppConstants.firstMushafPage;
  final Set<int> _bookmarkedPages = <int>{};

  ThemeMode get themeMode => _themeMode;
  int get lastReadPage => _lastReadPage;
  Set<int> get bookmarkedPages => Set.unmodifiable(_bookmarkedPages);

  bool isBookmarked(int pageNumber) => _bookmarkedPages.contains(pageNumber);

  void setThemeMode(ThemeMode value) {
    if (_themeMode == value) return;
    _themeMode = value;
    notifyListeners();
    unawaited(_saveTheme(value));
  }

  void updateLastReadPage(int pageNumber) {
    final safePage = pageNumber.clamp(
      AppConstants.firstMushafPage,
      AppConstants.mushafPageCount,
    );
    if (_lastReadPage == safePage) return;
    _lastReadPage = safePage;
    notifyListeners();
    unawaited(_saveLastPage(safePage));
  }

  void toggleBookmark(int pageNumber) {
    if (!_bookmarkedPages.remove(pageNumber)) {
      _bookmarkedPages.add(pageNumber);
    }
    notifyListeners();
    unawaited(_saveBookmarks());
  }

  Future<void> _restore() async {
    final prefs = await SharedPreferences.getInstance();
    final themeIndex = prefs.getInt(_themeKey);
    final savedPage = prefs.getInt(_lastPageKey);
    final savedBookmarks = prefs.getStringList(_bookmarksKey) ?? const [];

    if (themeIndex != null &&
        themeIndex >= 0 &&
        themeIndex < ThemeMode.values.length) {
      _themeMode = ThemeMode.values[themeIndex];
    }
    if (savedPage != null) {
      _lastReadPage = savedPage.clamp(
        AppConstants.firstMushafPage,
        AppConstants.mushafPageCount,
      );
    }
    _bookmarkedPages
      ..clear()
      ..addAll(
        savedBookmarks
            .map(int.tryParse)
            .whereType<int>()
            .where(
              (page) =>
                  page >= AppConstants.firstMushafPage &&
                  page <= AppConstants.mushafPageCount,
            ),
      );
    notifyListeners();
  }

  Future<void> _saveTheme(ThemeMode value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_themeKey, value.index);
  }

  Future<void> _saveLastPage(int page) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_lastPageKey, page);
  }

  Future<void> _saveBookmarks() async {
    final prefs = await SharedPreferences.getInstance();
    final pages = _bookmarkedPages.toList()..sort();
    await prefs.setStringList(
      _bookmarksKey,
      pages.map((page) => '$page').toList(growable: false),
    );
  }
}
