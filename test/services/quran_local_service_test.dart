import 'package:flutter_test/flutter_test.dart';
import 'package:quran/services/quran_local_service.dart';

/// اختبارات وحدة لخدمة النص القرآني المحلي (مصحف المدينة KFGQPC Hafs Smart
/// v8) — تُحمَّل من ملف JSON مضمَّن (assets/data/hafs_smart_v8.json)، وبيئة
/// `flutter test` تقرأ الأصول (assets) من القرص مباشرة فتعمل هذه الاختبارات
/// بلا أي جهاز أو محاكي، وتتحقق من صحة البيانات نفسها (١١٤ سورة، ٣٠ جزء...)
/// وليس فقط من منطق الكود.
/// يزيل علامات التشكيل العربية (الفتحة، الضمة، الشدة...) من نص، حتى تُقارَن
/// أسماء السور بحروفها الأساسية فقط دون التأثر بترتيب علامات Unicode
/// التوافقية (combining marks) التي قد تختلف شكلياً رغم تطابق المعنى.
String _stripTashkeel(String text) =>
    text.replaceAll(RegExp(r'[ً-ْ]'), '');

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final service = QuranLocalService();

  test('getSurahList يرجع ١١٤ سورة بالضبط', () async {
    final surahs = await service.getSurahList();
    expect(surahs, hasLength(114));
  });

  test('أول سورة في القائمة هي الفاتحة وآخرها الناس', () async {
    final surahs = await service.getSurahList();
    expect(surahs.first.number, 1);
    // نتحقق باحتواء الاسم على الحروف الأساسية دون تشكيل، بدل مطابقة حرفية
    // كاملة — لأن أسماء السور بالبيانات الأصلية تحوي تشكيلاً وقد تختلف طريقة
    // ترتيب علامات التشكيل (Unicode) رغم تطابق الشكل المرئي.
    expect(_stripTashkeel(surahs.first.nameAr), 'الفاتحة');
    expect(surahs.last.number, 114);
    expect(_stripTashkeel(surahs.last.nameAr), 'الناس');
  });

  test('سورة الفاتحة تحتوي ٧ آيات', () async {
    final ayahs = await service.getSurahAyahs(1);
    expect(ayahs, hasLength(7));
    expect(ayahs.first.ayaNo, 1);
    expect(ayahs.last.ayaNo, 7);
  });

  test('آيات السورة مرتّبة تصاعدياً برقم الآية', () async {
    final ayahs = await service.getSurahAyahs(2); // البقرة (أطول سورة)
    for (var i = 1; i < ayahs.length; i++) {
      expect(ayahs[i].ayaNo, greaterThan(ayahs[i - 1].ayaNo));
    }
  });

  test('getJuzList يرجع ٣٠ جزءاً بالضبط، أولها يبدأ من الفاتحة', () async {
    final juzList = await service.getJuzList();
    expect(juzList, hasLength(30));
    expect(juzList.first.number, 1);
    expect(juzList.first.startSuraNo, 1);
    expect(juzList.first.startAyaNo, 1);
  });

  test('getAyahPage يرجع رقم صفحة صالح لآية معروفة (الفاتحة: ١)', () async {
    final page = await service.getAyahPage(1, 1);
    expect(page, 1);
  });

  test('getSurahAtPage يرجع الفاتحة لأول صفحة في المصحف', () async {
    final surah = await service.getSurahAtPage(1);
    expect(surah.number, 1);
  });

  test('search بنص فارغ يرجع قائمة فارغة دون قراءة كل البيانات', () async {
    expect(await service.search(''), isEmpty);
    expect(await service.search('   '), isEmpty);
  });

  test('search يجد آيات تحتوي على نص "بسم الله" في النص الإملائي', () async {
    final results = await service.search('بسم الله');
    expect(results, isNotEmpty);
  });

  test('search لنص غير موجود إطلاقاً يرجع قائمة فارغة', () async {
    final results = await service.search('xyzxyzxyz123لا_يوجد_شيء_كذا');
    expect(results, isEmpty);
  });
}
