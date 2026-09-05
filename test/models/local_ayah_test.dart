import 'package:flutter_test/flutter_test.dart';
import 'package:quran/models/local_ayah.dart';

void main() {
  test('LocalAyah.fromJson يقرأ كل الحقول المطلوبة بأسمائها بصيغة snake_case',
      () {
    final ayah = LocalAyah.fromJson({
      'id': 1,
      'jozz': 1,
      'sura_no': 1,
      'sura_name_en': 'Al-Fatihah',
      'sura_name_ar': 'الفاتحة',
      'page': 1,
      'line_start': 2,
      'line_end': 2,
      'aya_no': 1,
      'aya_text': 'بِسْمِ اللَّهِ',
      'aya_text_emlaey': 'بسم الله',
    });

    expect(ayah.id, 1);
    expect(ayah.jozz, 1);
    expect(ayah.suraNo, 1);
    expect(ayah.suraNameEn, 'Al-Fatihah');
    expect(ayah.suraNameAr, 'الفاتحة');
    expect(ayah.page, 1);
    expect(ayah.lineStart, 2);
    expect(ayah.lineEnd, 2);
    expect(ayah.ayaNo, 1);
    expect(ayah.ayaText, 'بِسْمِ اللَّهِ');
    expect(ayah.ayaTextEmlaey, 'بسم الله');
  });

  test('LocalAyah.fromJson يستخدم نص فارغ عند غياب حقول النص الاختيارية', () {
    final ayah = LocalAyah.fromJson({
      'id': 1,
      'jozz': 1,
      'sura_no': 1,
      'page': 1,
      'line_start': 1,
      'line_end': 1,
      'aya_no': 1,
    });

    expect(ayah.suraNameEn, '');
    expect(ayah.suraNameAr, '');
    expect(ayah.ayaText, '');
    expect(ayah.ayaTextEmlaey, '');
  });
}
