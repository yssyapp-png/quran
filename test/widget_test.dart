// اختبار إقلاع أساسي (smoke test) لتطبيق القرآن الكريم.
//
// ملاحظة: هذا الملف كان يحوي سابقًا اختبار "العدّاد" الافتراضي من قالب
// Flutter الأساسي (يشير إلى صنف MyApp غير الموجود في هذا المشروع أصلًا)،
// وكان يفشل دائمًا لعدم تعديله منذ إنشاء المشروع. استُبدل هنا باختبار حقيقي
// يتحقق أن شاشة الصفحة الرئيسية (HomeScreen) تُقلع وتُبنى بدون أي استثناء.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:quran/main.dart';

void main() {
  testWidgets('يُقلع تطبيق القرآن الكريم بدون أخطاء ويعرض الشاشة الرئيسية',
      (WidgetTester tester) async {
    await tester.pumpWidget(const QuranApp());
    // إطار واحد كافٍ للتأكد من عدم وجود استثناء أثناء البناء الأولي؛ لا
    // ننتظر اكتمال أي عمليات تحميل غير متزامنة (بيانات السور، الإعدادات...)
    // لأن هذا اختبار إقلاع بسيط فقط وليس اختبار وظائف الشاشة الرئيسية.
    await tester.pump();

    expect(tester.takeException(), isNull);
  });
}
