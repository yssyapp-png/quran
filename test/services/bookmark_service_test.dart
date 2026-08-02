import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:quran/models/bookmark.dart';
import 'package:quran/services/bookmark_service.dart';

/// اختبارات وحدة لخدمة العلامات المرجعية وآخر موضع قراءة وتتبع الختمة —
/// كلها مبنية على SharedPreferences، فنعتمد mock للقيم الابتدائية بدل
/// التخزين الفعلي، وهذا كافٍ لأن الخدمة لا تلمس أي قناة منصّة حقيقية.
void main() {
  final service = BookmarkService();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  test('يبدأ بدون أي علامات مرجعية', () async {
    expect(await service.getBookmarks(), isEmpty);
  });

  test('toggleBookmark يضيف علامة جديدة غير موجودة', () async {
    await service.toggleBookmark(Bookmark(suraNo: 2, suraName: 'البقرة', ayaNo: 255));
    final list = await service.getBookmarks();
    expect(list, hasLength(1));
    expect(list.first.key, '2:255');
  });

  test('toggleBookmark يحذف علامة موجودة مسبقاً (تبديل)', () async {
    final bookmark = Bookmark(suraNo: 2, suraName: 'البقرة', ayaNo: 255);
    await service.toggleBookmark(bookmark);
    await service.toggleBookmark(bookmark);
    expect(await service.getBookmarks(), isEmpty);
  });

  test('isBookmarked يعكس حالة العلامة بدقة', () async {
    expect(await service.isBookmarked(1, 1), isFalse);
    await service.toggleBookmark(Bookmark(suraNo: 1, suraName: 'الفاتحة', ayaNo: 1));
    expect(await service.isBookmarked(1, 1), isTrue);
  });

  test('saveLastRead/getLastRead يحفظان ويرجعان آخر موضع قراءة', () async {
    expect(await service.getLastRead(), isNull);
    await service.saveLastRead(3, 10, 'آل عمران');
    final last = await service.getLastRead();
    expect(last, isNotNull);
    expect(last!.suraNo, 3);
    expect(last.ayaNo, 10);
    expect(last.suraName, 'آل عمران');
  });

  test('getReadPages يبدأ فارغاً ثم markPageRead يضيف صفحات دون تكرار', () async {
    expect(await service.getReadPages(), isEmpty);
    await service.markPageRead(1);
    await service.markPageRead(2);
    await service.markPageRead(1);
    final pages = await service.getReadPages();
    expect(pages, {1, 2});
  });

  test('resetKhatma يمسح كل صفحات الختمة المقروءة', () async {
    await service.markPageRead(1);
    await service.markPageRead(2);
    await service.resetKhatma();
    expect(await service.getReadPages(), isEmpty);
  });
}
