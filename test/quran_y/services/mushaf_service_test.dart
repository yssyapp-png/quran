import 'package:flutter_test/flutter_test.dart';
import 'package:quran/quran_y/services/mushaf_service.dart';

void main() {
  const service = MushafService();

  test('builds stable asset paths for the first and last mushaf pages', () {
    expect(service.pageAssetPath(1), 'assets/mushaf_pages/1.jpg');
    expect(service.pageAssetPath(604), 'assets/mushaf_pages/604.jpg');
  });

  test('rejects page numbers outside the 604-page mushaf', () {
    expect(() => service.pageAssetPath(0), throwsRangeError);
    expect(() => service.pageAssetPath(605), throwsRangeError);
  });
}
