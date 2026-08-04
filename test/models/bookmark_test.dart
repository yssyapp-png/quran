import 'package:flutter_test/flutter_test.dart';
import 'package:quran/models/bookmark.dart';

void main() {
  test('key يتكوّن من رقم السورة والآية بصيغة سورة:آية', () {
    final bookmark = Bookmark(suraNo: 2, suraName: 'البقرة', ayaNo: 255);
    expect(bookmark.key, '2:255');
  });

  test('toJson يحوّل كل الحقول بشكل صحيح', () {
    final bookmark = Bookmark(suraNo: 1, suraName: 'الفاتحة', ayaNo: 1);
    final json = bookmark.toJson();
    expect(json, {'suraNo': 1, 'suraName': 'الفاتحة', 'ayaNo': 1});
  });

  test('fromJson يبني نسخة مطابقة لما تم تحويله بـ toJson (round-trip)', () {
    final original = Bookmark(suraNo: 18, suraName: 'الكهف', ayaNo: 10);
    final rebuilt = Bookmark.fromJson(original.toJson());
    expect(rebuilt.suraNo, original.suraNo);
    expect(rebuilt.suraName, original.suraName);
    expect(rebuilt.ayaNo, original.ayaNo);
    expect(rebuilt.key, original.key);
  });
}
