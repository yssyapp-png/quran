import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/bookmark.dart';

/// إدارة العلامات المرجعية وآخر موضع قراءة، محفوظة محليًا عبر SharedPreferences.
class BookmarkService {
  static const _bookmarksKey = 'bookmarks';
  static const _lastReadKey = 'last_read';
  static const _readPagesKey = 'khatma_read_pages';

  Future<List<Bookmark>> getBookmarks() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getStringList(_bookmarksKey) ?? [];
    return raw.map((e) => Bookmark.fromJson(jsonDecode(e))).toList();
  }

  Future<bool> isBookmarked(int suraNo, int ayaNo) async {
    final list = await getBookmarks();
    return list.any((b) => b.suraNo == suraNo && b.ayaNo == ayaNo);
  }

  Future<void> toggleBookmark(Bookmark bookmark) async {
    final prefs = await SharedPreferences.getInstance();
    final list = await getBookmarks();
    final exists = list.any(
        (b) => b.suraNo == bookmark.suraNo && b.ayaNo == bookmark.ayaNo);
    if (exists) {
      list.removeWhere(
          (b) => b.suraNo == bookmark.suraNo && b.ayaNo == bookmark.ayaNo);
    } else {
      list.add(bookmark);
    }
    await prefs.setStringList(
        _bookmarksKey, list.map((b) => jsonEncode(b.toJson())).toList());
  }

  Future<void> saveLastRead(int suraNo, int ayaNo, String suraName) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
        _lastReadKey,
        jsonEncode(
            {'suraNo': suraNo, 'ayaNo': ayaNo, 'suraName': suraName}));
  }

  Future<Bookmark?> getLastRead() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_lastReadKey);
    if (raw == null) return null;
    final json = jsonDecode(raw);
    return Bookmark(
        suraNo: json['suraNo'], suraName: json['suraName'], ayaNo: json['ayaNo']);
  }

  /// تتبع "الختمة": مجموعة أرقام الصفحات (1..604) التي وسمها المستخدم كمقروءة.
  Future<Set<int>> getReadPages() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getStringList(_readPagesKey) ?? [];
    return raw.map(int.parse).toSet();
  }

  Future<void> markPageRead(int page) async {
    final prefs = await SharedPreferences.getInstance();
    final pages = await getReadPages();
    pages.add(page);
    await prefs.setStringList(_readPagesKey, pages.map((e) => e.toString()).toList());
  }

  Future<void> resetKhatma() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_readPagesKey);
  }
}
