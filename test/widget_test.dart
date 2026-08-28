import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:quran/main.dart';

/// يتأكد أن تجربة Quran-y الجديدة تفتح قارئ المصحف مباشرة من الصفحة الأولى.
void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  testWidgets('يفتح التطبيق قارئ المصحف من الصفحة الأولى', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(const QuranApp());
    await tester.pumpAndSettle();

    expect(find.text('سعد الغامدي'), findsOneWidget);
  });
}
