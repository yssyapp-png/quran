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
    },
  );

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
    },
  );

  test('Reciters.byId يرجع القارئ الصحيح لمعرف موجود', () {
    expect(Reciters.byId('ghamdi').id, 'ghamdi');
    expect(Reciters.byId('abdullah_matroud'), Reciters.abdullahMatroud);
  });

  test('سعد الغامدي يستخدم ملف السورة الكامل بجودة 128kbps', () {
    expect(Reciters.saadGhamdi.playsFullSurah, isTrue);
    expect(
      Reciters.saadGhamdi.audioUrl(2, 5),
      'https://server7.mp3quran.net/s_gmd/128/002.mp3',
    );
  });

  test('تلاوة عبد الله المطرود تستخدم المصدر عالي الجودة الصحيح', () {
    expect(
      Reciters.abdullahMatroud.audioUrl(1, 1),
      'https://everyayah.com/data/Abdullah_Matroud_128kbps/001001.mp3',
    );
    expect(Reciters.all, contains(Reciters.abdullahMatroud));
  });

  test('Reciters.byId يرجع القارئ الافتراضي لمعرف غير موجود', () {
    expect(Reciters.byId('غير_موجود'), Reciters.defaultReciter);
  });

  test('Reciters.all تحتوي القارئ الافتراضي على الأقل', () {
    expect(Reciters.all, contains(Reciters.defaultReciter));
  });
}
