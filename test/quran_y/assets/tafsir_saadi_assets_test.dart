import 'dart:convert';
import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:quran/quran_y/services/tafsir_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('تفسير السعدي مضمّن في حزمة Flutter ويعمل دون إنترنت', () async {
    final contents = await rootBundle.loadString(
      'assets/data/tafsir_saadi/151.json',
    );
    final payload = jsonDecode(contents) as Map<String, dynamic>;

    expect(payload['page'], 151);
    expect(payload['book_id'], 42);
    expect(payload['entries'], isNotEmpty);
  });

  test(
    'واجهة التفسير تعرض التعليق العربي ولا تعرض اقتباس PDF المشوّه',
    () async {
      final service = TafsirService();
      addTearDown(service.close);

      final entries = await service.tafsirByPage(151);
      final first = entries.firstWhere((entry) => entry.verseKey == '7:1');

      expect(first.text, startsWith('يقول تعالى'));
      expect(first.text, isNot(contains('}} {')));
    },
  );

  test('حزمة تفسير السعدي مكتملة وآمنة للتحميل المحلي', () {
    final projectRoot = Directory.current;
    final tafsirRoot = Directory(
      '${projectRoot.path}/assets/data/tafsir_saadi',
    );
    final quranFile = File(
      '${projectRoot.path}/assets/data/hafs_smart_v8.json',
    );
    final manifestFile = File('${tafsirRoot.path}/manifest.json');

    expect(tafsirRoot.existsSync(), isTrue);
    expect(quranFile.existsSync(), isTrue);
    expect(manifestFile.existsSync(), isTrue);

    final quranRecords = (jsonDecode(quranFile.readAsStringSync()) as List)
        .cast<Map<String, dynamic>>();
    expect(quranRecords, hasLength(6236));
    final versePages = <String, int>{
      for (final record in quranRecords)
        '${record['sura_no']}:${record['aya_no']}': record['page'] as int,
    };

    final manifest = jsonDecode(manifestFile.readAsStringSync());
    expect(manifest, isA<Map<String, dynamic>>());
    final manifestMap = manifest as Map<String, dynamic>;
    expect(manifestMap['schema_version'], 1);
    expect(manifestMap['book_id'], 42);
    expect(manifestMap['ayahs_verified'], 6236);
    expect(manifestMap['mushaf_pages'], 604);
    expect(manifestMap['tafsir_groups'], 1998);
    expect(manifestMap['text_groups'], 1998);
    expect(manifestMap['groups_without_independent_commentary'], isEmpty);
    expect(
      manifestMap['source_file_sha256'],
      matches(RegExp(r'^[a-f0-9]{64}$')),
    );

    var entryCount = 0;
    for (var page = 1; page <= 604; page++) {
      final pageFile = File(
        '${tafsirRoot.path}/${page.toString().padLeft(3, '0')}.json',
      );
      expect(
        pageFile.existsSync(),
        isTrue,
        reason: 'صفحة التفسير $page مفقودة',
      );
      final payload = jsonDecode(pageFile.readAsStringSync());
      expect(payload, isA<Map<String, dynamic>>());
      final pageMap = payload as Map<String, dynamic>;
      expect(pageMap['schema_version'], 1);
      expect(pageMap['book_id'], 42);
      expect(pageMap['page'], page);
      expect(pageMap['entries'], isA<List<dynamic>>());
      final entries = pageMap['entries'] as List<dynamic>;
      expect(entries, isNotEmpty, reason: 'صفحة التفسير $page فارغة');

      final seen = <String>{};
      for (final value in entries) {
        expect(value, isA<Map<String, dynamic>>());
        final entry = value as Map<String, dynamic>;
        final verseKey = entry['verse_key'];
        final text = entry['text'];
        expect(verseKey, isA<String>());
        expect(text, isA<String>());
        expect((text as String).trim(), isNotEmpty);
        expect(text, isNot(contains('Shamela.org')));
        expect(text, isNot(contains('\u000c')));
        expect(
          text.runes.any((rune) {
            return rune == 0x200e ||
                rune == 0x200f ||
                (rune >= 0x202a && rune <= 0x202e) ||
                (rune >= 0x2066 && rune <= 0x2069);
          }),
          isFalse,
        );
        expect(seen.add(verseKey as String), isTrue);
        expect(versePages[verseKey], page);
        entryCount++;
      }
    }

    expect(entryCount, manifestMap['tafsir_entries']);
  });
}
