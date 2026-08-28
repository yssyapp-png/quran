import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:quran/quran_y/services/quran_text_service.dart';

void main() {
  group('QuranTextService', () {
    test('parses a valid page and reuses the cached result', () async {
      var requests = 0;
      final service = QuranTextService(
        client: MockClient((request) async {
          requests++;
          expect(request.url.host, 'api.quran.com');
          expect(request.url.path, '/api/v4/verses/by_page/42');
          return http.Response(
            jsonEncode({
              'verses': [
                {
                  'verse_key': '2:255',
                  'text_uthmani': 'اللَّهُ لَا إِلَٰهَ إِلَّا هُوَ',
                },
              ],
            }),
            200,
            headers: const {'content-type': 'application/json; charset=utf-8'},
          );
        }),
      );
      addTearDown(service.close);

      final first = await service.versesByPage(42);
      final second = await service.versesByPage(42);

      expect(first.single.verseKey, '2:255');
      expect(second, same(first));
      expect(requests, 1);
    });

    test('deduplicates concurrent requests for the same page', () async {
      var requests = 0;
      final service = QuranTextService(
        client: MockClient((_) async {
          requests++;
          await Future<void>.delayed(const Duration(milliseconds: 5));
          return http.Response(
            jsonEncode({
              'verses': [
                {'verse_key': '1:1', 'text_uthmani': 'بِسْمِ اللَّهِ'},
              ],
            }),
            200,
            headers: const {'content-type': 'application/json; charset=utf-8'},
          );
        }),
      );
      addTearDown(service.close);

      await Future.wait(List.generate(100, (_) => service.versesByPage(1)));

      expect(requests, 1);
    });

    test('evicts the oldest page when the bounded cache is full', () async {
      var requests = 0;
      final service = QuranTextService(
        maxCachedPages: 2,
        client: MockClient((request) async {
          requests++;
          final page = request.url.pathSegments.last;
          return http.Response(
            jsonEncode({
              'verses': [
                {'verse_key': '$page:1', 'text_uthmani': 'نص'},
              ],
            }),
            200,
            headers: const {'content-type': 'application/json; charset=utf-8'},
          );
        }),
      );
      addTearDown(service.close);

      await service.versesByPage(1);
      await service.versesByPage(2);
      await service.versesByPage(3);
      await service.versesByPage(1);

      expect(requests, 4);
    });

    test('rejects pages outside the mushaf before network access', () {
      var requests = 0;
      final service = QuranTextService(
        client: MockClient((_) async {
          requests++;
          return http.Response('{}', 200);
        }),
      );
      addTearDown(service.close);

      expect(() => service.versesByPage(0), throwsRangeError);
      expect(() => service.versesByPage(605), throwsRangeError);
      expect(requests, 0);
    });

    test('reports server and malformed payload failures', () async {
      final serverFailure = QuranTextService(
        client: MockClient((_) async => http.Response('unavailable', 503)),
      );
      final malformed = QuranTextService(
        client: MockClient((_) async => http.Response('{"verses":{}}', 200)),
      );
      addTearDown(serverFailure.close);
      addTearDown(malformed.close);

      await expectLater(
        serverFailure.versesByPage(1),
        throwsA(isA<http.ClientException>()),
      );
      await expectLater(
        malformed.versesByPage(1),
        throwsA(isA<FormatException>()),
      );
    });
  });
}
