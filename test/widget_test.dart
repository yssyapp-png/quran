import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:quran/main.dart';

/// اختبار دخان (smoke test) بسيط: يتأكد أن الشاشة الرئيسية تُبنى بنجاح
/// وأن عنوانها يظهر — مؤشر موثوق لا يتأثر بطول القائمة أو حجم شاشة
/// الاختبار (بعكس عناصر أسفل قائمة قابلة للتمرير قد لا تُبنى في بيئة
/// الاختبار المحدودة).
void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  testWidgets('يفتح التطبيق ويعرض الشاشة الرئيسية بعنوانها',
      (WidgetTester tester) async {
    await tester.pumpWidget(const QuranApp());
    // ملاحظة: لا نستخدم pumpAndSettle هنا عمداً — أثناء تحميل قائمة السور
    // (Future) تُعرض CircularProgressIndicator، وهي حركة متكررة بلا نهاية
    // بطبيعتها، فتجعل pumpAndSettle "ينتظر إلى الأبد" ويفشل بخطأ انتهاء
    // المهلة رغم أن الشاشة بُنيت بنجاح فعلاً. عنوان AppBar يظهر في أول
    // إطار فوراً بغض النظر عن حالة تحميل البيانات، فيكفي pump واحد.
    await tester.pump();

    expect(find.text('القرآن الكريم'), findsOneWidget);
  });
}
