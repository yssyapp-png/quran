import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:quran/models/reciter.dart';
import 'package:quran/services/settings_service.dart';

void main() {
  final service = SettingsService();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  test('getSelectedReciter يرجع القارئ الافتراضي عند عدم وجود اختيار محفوظ',
      () async {
    final reciter = await service.getSelectedReciter();
    expect(reciter, Reciters.defaultReciter);
  });

  test('setSelectedReciter/getSelectedReciter يحفظان ويرجعان نفس القارئ',
      () async {
    await service.setSelectedReciter(Reciters.saadGhamdi);
    final reciter = await service.getSelectedReciter();
    expect(reciter.id, Reciters.saadGhamdi.id);
  });
}
