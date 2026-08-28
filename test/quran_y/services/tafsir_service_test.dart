import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:quran/quran_y/models/tafsir_entry.dart';
import 'package:quran/quran_y/services/tafsir_service.dart';

void main() {
  group('TafsirService', () {
    test('يعرض التفسير الميسر كمصدر إلكتروني اختياري للمستخدم', () async {
      final service = TafsirService(
        client: MockClient((request) async {
          expect(request.url.path, '/api/v4/tafsirs/16/by_page/1');
          return http.Response(
            jsonEncode({
              'tafsirs': [
                {
                  'verse_key': '1:1',
                  'text': 'تفسير ميسر موثوق.',
                  'resource_name': 'الميسر',
                },
              ],
            }),
            200,
            headers: const {'content-type': 'application/json; charset=utf-8'},
          );
        }),
      );
      addTearDown(service.close);

      expect(service.availableSources, contains(TafsirSource.muyassar));
      final entries = await service.tafsirByPage(
        1,
        source: TafsirSource.muyassar,
      );
      expect(entries.single.text, 'تفسير ميسر موثوق.');
      expect(entries.single.sourceName, 'الميسر');
    });

    test(
      'يعرض المختصر من المصدر المنظّم دون إضافته إلى ملفات التطبيق',
      () async {
        final service = TafsirService(
          loadMukhtasarDocument: () async => jsonEncode({
            'ayahs': [
              {
                'surah': 1,
                'ayah': 1,
                'content': [
                  {'text': 'zتفسير الفاتحة للآيات الأولى.<br />\rتفصيل موثوق.'},
                ],
              },
              {
                'surah': 1,
                'ayah': 5,
                'content': [
                  {'text': 'تفسير بقية الفاتحة.'},
                ],
              },
            ],
          }),
          mushafDataLoader: () async => jsonEncode([
            {'page': 1, 'sura_no': 1, 'aya_no': 1},
            {'page': 1, 'sura_no': 1, 'aya_no': 2},
            {'page': 1, 'sura_no': 1, 'aya_no': 5},
            {'page': 1, 'sura_no': 1, 'aya_no': 7},
          ]),
        );
        addTearDown(service.close);

        expect(service.availableSources, contains(TafsirSource.mukhtasar));
        final entries = await service.tafsirByPage(
          1,
          source: TafsirSource.mukhtasar,
        );

        expect(entries.map((entry) => entry.verseKey), ['1:1', '1:5']);
        expect(
          entries.first.text,
          'تفسير الفاتحة للآيات الأولى.\nتفصيل موثوق.',
        );
        expect(entries.first.sourceName, TafsirSource.mukhtasar.name);
      },
    );

    test(
      'parses, sanitizes, and caches a valid response for an online source',
      () async {
        var requests = 0;
        final service = TafsirService(
          sources: const [
            TafsirSource(
              id: 999,
              name: 'مصدر اختبار',
              author: 'اختبار',
              slug: 'test',
            ),
          ],
          localPageLoader: (_) async => null,
          client: MockClient((request) async {
            requests++;
            expect(request.url.path, '/api/v4/tafsirs/999/by_page/1');
            return http.Response(
              jsonEncode({
                'tafsirs': [
                  {
                    'verse_key': '1:1',
                    'text': '<p>تفسير &amp; بيان</p><br>سطر ثان',
                    'resource_name': 'تفسير السعدي',
                  },
                ],
              }),
              200,
              headers: const {
                'content-type': 'application/json; charset=utf-8',
              },
            );
          }),
        );
        addTearDown(service.close);

        const source = TafsirSource(
          id: 999,
          name: 'مصدر اختبار',
          author: 'اختبار',
          slug: 'test',
        );
        final first = await service.tafsirByPage(1, source: source);
        final second = await service.tafsirByPage(1, source: source);

        expect(first.single.verseKey, '1:1');
        expect(first.single.text, 'تفسير & بيان\n\nسطر ثان');
        expect(second, same(first));
        expect(requests, 1);
      },
    );

    test('deduplicates concurrent requests and bounds memory', () async {
      var requests = 0;
      final service = TafsirService(
        sources: const [
          TafsirSource(id: 999, name: 'اختبار', author: 'اختبار', slug: 'test'),
        ],
        maxCachedPages: 1,
        localPageLoader: (_) async => null,
        client: MockClient((request) async {
          requests++;
          await Future<void>.delayed(const Duration(milliseconds: 5));
          final page = request.url.pathSegments.last;
          return http.Response(
            jsonEncode({
              'tafsirs': [
                {
                  'verse_key': '$page:1',
                  'text': 'تفسير',
                  'resource_name': 'المصدر',
                },
              ],
            }),
            200,
            headers: const {'content-type': 'application/json; charset=utf-8'},
          );
        }),
      );
      addTearDown(service.close);

      const source = TafsirSource(
        id: 999,
        name: 'اختبار',
        author: 'اختبار',
        slug: 'test',
      );
      await Future.wait([
        service.tafsirByPage(1, source: source),
        service.tafsirByPage(1, source: source),
      ]);
      await service.tafsirByPage(2, source: source);
      await service.tafsirByPage(1, source: source);

      expect(requests, 3);
    });

    test('validates page range and malformed responses', () async {
      var requests = 0;
      final service = TafsirService(
        sources: const [
          TafsirSource(id: 999, name: 'اختبار', author: 'اختبار', slug: 'test'),
        ],
        localPageLoader: (_) async => null,
        client: MockClient((_) async {
          requests++;
          return http.Response('{"tafsirs":{}}', 200);
        }),
      );
      addTearDown(service.close);

      expect(() => service.tafsirByPage(0), throwsRangeError);
      expect(requests, 0);
      await expectLater(
        service.tafsirByPage(
          1,
          source: const TafsirSource(
            id: 999,
            name: 'اختبار',
            author: 'اختبار',
            slug: 'test',
          ),
        ),
        throwsA(isA<FormatException>()),
      );
    });

    test(
      'prefers the bundled Shamela page without a network request',
      () async {
        var requests = 0;
        final service = TafsirService(
          localPageLoader: (page) async => jsonEncode({
            'schema_version': 1,
            'book_id': 42,
            'page': page,
            'entries': [
              {'verse_key': '1:1', 'text': 'تفسير محلي من تيسير الكريم الرحمن'},
            ],
          }),
          client: MockClient((_) async {
            requests++;
            return http.Response('', 500);
          }),
        );
        addTearDown(service.close);

        final entries = await service.tafsirByPage(1);

        expect(entries.single.verseKey, '1:1');
        expect(entries.single.text, 'تفسير محلي من تيسير الكريم الرحمن');
        expect(entries.single.sourceName, 'تفسير السعدي');
        expect(requests, 0);
      },
    );

    test(
      'rejects malformed local data instead of showing wrong tafsir',
      () async {
        var requests = 0;
        final service = TafsirService(
          localPageLoader: (_) async => jsonEncode({
            'schema_version': 1,
            'book_id': 42,
            'page': 2,
            'entries': [
              {'verse_key': '1:1', 'text': 'بيانات لصفحة أخرى'},
            ],
          }),
          client: MockClient((_) async {
            requests++;
            return http.Response('', 500);
          }),
        );
        addTearDown(service.close);

        await expectLater(
          service.tafsirByPage(1),
          throwsA(isA<FormatException>()),
        );
        expect(requests, 0);
      },
    );
  });

  test(
    'removes the malformed leading Qur\'an quote from the same PDF source',
    () async {
      final service = TafsirService(
        localPageLoader: (page) async => jsonEncode({
          'schema_version': 1,
          'book_id': 42,
          'page': page,
          'entries': [
            {
              'verse_key': '7:1',
              'text':
                  'نص الآية غير المنسق}. يقول تعالى لرسوله محمد صلى الله عليه وسلم بيان صحيح.',
            },
          ],
        }),
      );
      addTearDown(service.close);

      final entries = await service.tafsirByPage(151);

      expect(
        entries.single.text,
        'يقول تعالى لرسوله محمد صلى الله عليه وسلم بيان صحيح.',
      );
    },
  );
}
