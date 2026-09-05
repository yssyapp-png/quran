import 'package:flutter_test/flutter_test.dart';
import 'package:quran/models/reciter.dart';

void main() {
  test(
      'audioUrl يبني رابط everyayah.com بالصيغة الصحيحة (سورة/آية بثلاث خانات)',
      () {
    const reciter = Reciter(
      id: 'test',
      nameAr: 'قارئ تجريبي',
      everyayahFolder: 'Test_40kbps',
    );
    expect(
      reciter.audioUrl(2, 5),
      'https://everyayah.com/data/Test_40kbps/002005.mp3',
    );
  });

  test(
      'audioUrl يضبط الأصفار الناقصة حتى لأرقام السور/الآيات الكبيرة (٣ أرقام)',
      () {
    const reciter = Reciter(
      id: 'test',
      nameAr: 'قارئ تجريبي',
      everyayahFolder: 'Test_40kbps',
    );
    expect(
      reciter.audioUrl(114, 6),
      'https://everyayah.com/data/Test_40kbps/114006.mp3',
    );
  });

  test('Reciters.byId يرجع القارئ الصحيح لمعرف موجود', () {
    expect(Reciters.byId('ghamdi').id, 'ghamdi');
  });

  test('Reciters.byId يرجع القارئ الافتراضي لمعرف غير موجود', () {
    expect(Reciters.byId('غير_موجود'), Reciters.defaultReciter);
  });

  test('Reciters.all تحتوي القارئ الافتراضي على الأقل', () {
    expect(Reciters.all, contains(Reciters.defaultReciter));
  });
}
