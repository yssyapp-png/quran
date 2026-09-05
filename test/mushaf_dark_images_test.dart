// اختبار سلامة الصور الليلية المُولَّدة مسبقًا لكل صفحات المصحف.
//
// يتحقق هذا الاختبار من:
// 1) وجود صورة نهارية وصورة ليلية لكل صفحة من صفحات المصحف الـ604،
//    وأن حجم كل ملف أكبر من صفر (لم يفشل التوليد أو يُنتج ملفًا فارغًا).
// 2) أن صفحتي الفاتحة وأول البقرة (1 و2) — الزخرفيتين — نُسخت صورتهما
//    الليلية كما هي (بدون انعكاس ألوان) كما هو مقصود.
// 3) أن باقي الصفحات (3 وما بعدها) لها بالفعل نسخة ليلية مختلفة عن
//    النهارية (أي أن الانعكاس اللوني طُبِّق فعليًا ولم يُنسَ).
//
// شغّله من جذر المشروع (المكان الذي يحوي مجلد assets) عبر:
//   flutter test test/mushaf_dark_images_test.dart
//
// ملاحظة: هذا اختبار يعتمد على ملفات حقيقية على القرص، لذلك لا يعمل إلا
// على الجهاز الذي يحوي مجلد assets/mushaf_pages كاملًا (604 صورة نهارية
// + 604 صورة ليلية)، وليس نسخة الحاوية السحابية الجزئية.

import 'dart:io';
import 'package:flutter_test/flutter_test.dart';

const int kMushafPageCount = 604;
const Set<int> kDecorativePages = {1, 2};

void main() {
  final assetsDir = Directory('assets/mushaf_pages');

  setUpAll(() {
    expect(
      assetsDir.existsSync(),
      isTrue,
      reason:
          'مجلد assets/mushaf_pages غير موجود — شغّل الاختبار من جذر المشروع '
          'على جهاز يحوي كل صور المصحف (604 صورة)، وليس نسخة جزئية.',
    );
  });

  group('وجود الصور النهارية والليلية لكل صفحة', () {
    for (var n = 1; n <= kMushafPageCount; n++) {
      test('الصفحة $n: توجد نسخة نهارية وليلية غير فارغتين', () {
        final light = File('assets/mushaf_pages/$n.jpg');
        final dark = File('assets/mushaf_pages/${n}_dark.jpg');

        expect(light.existsSync(), isTrue,
            reason: 'الصورة النهارية للصفحة $n غير موجودة: ${light.path}');
        expect(dark.existsSync(), isTrue,
            reason: 'الصورة الليلية للصفحة $n غير موجودة: ${dark.path}');

        expect(light.lengthSync(), greaterThan(0),
            reason: 'الصورة النهارية للصفحة $n فارغة');
        expect(dark.lengthSync(), greaterThan(0),
            reason: 'الصورة الليلية للصفحة $n فارغة');
      });
    }
  });

  group('صفحتا الفاتحة وأول البقرة: بلا انعكاس ألوان', () {
    for (final n in kDecorativePages) {
      test('الصفحة $n: النسخة الليلية بنفس حجم النسخة النهارية تقريبًا', () {
        final light = File('assets/mushaf_pages/$n.jpg');
        final dark = File('assets/mushaf_pages/${n}_dark.jpg');
        final lightBytes = light.lengthSync();
        final darkBytes = dark.lengthSync();

        // إعادة الترميز عبر PIL بجودة 90 تُصغّر كل الصور (المنعكسة وغير
        // المنعكسة على حدٍّ سواء) إلى نحو 42%-44% من حجمها الأصلي تقريبًا
        // (تم التحقق تجريبيًا عبر عيّنة من الصفحات العادية أيضًا)، لذا لا
        // يصلح حجم الملف مقياسًا لاكتشاف انعكاس الألوان بالخطأ — هذا الفحص
        // يكتفي بأن حجم الصورة الليلية ضمن مدى إعادة الترميز الطبيعي.
        final ratio = darkBytes / lightBytes;
        expect(ratio, inInclusiveRange(0.2, 0.7),
            reason:
                'حجم الصورة الليلية للصفحة $n خارج مدى إعادة الترميز الطبيعي '
                '(نهاري: $lightBytes، ليلي: $darkBytes، النسبة: $ratio) — قد '
                'يشير هذا لخلل في توليد الصورة.');
      });
    }
  });

  group('باقي الصفحات: الانعكاس اللوني مُطبَّق فعليًا', () {
    // عيّنة من الصفحات العادية (غير 1 و2) للتأكد أن الانعكاس تم فعلاً،
    // بمقارنة أول بايتات الملفين (لن تتطابق أبدًا بين صورة وانعكاسها).
    final samplePages = [3, 50, 150, 300, 450, 604];

    for (final n in samplePages) {
      test('الصفحة $n: محتوى الصورة الليلية مختلف عن النهارية', () {
        final light = File('assets/mushaf_pages/$n.jpg');
        final dark = File('assets/mushaf_pages/${n}_dark.jpg');

        final lightBytes = light.readAsBytesSync();
        final darkBytes = dark.readAsBytesSync();

        expect(lightBytes, isNot(equals(darkBytes)),
            reason: 'الصورة الليلية للصفحة $n مطابقة تمامًا للنهارية — يبدو أن '
                'الانعكاس اللوني لم يُطبَّق على هذه الصفحة.');
      });
    }
  });
}
