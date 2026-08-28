import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;

import '../core/constants/app_constants.dart';
import '../models/tafsir_entry.dart';

typedef TafsirLocalPageLoader = Future<String?> Function(int pageNumber);
typedef TafsirMukhtasarDocumentLoader = Future<String> Function();
typedef TafsirMushafDataLoader = Future<String> Function();

class TafsirService {
  TafsirService({
    http.Client? client,
    List<TafsirSource> sources = const [
      TafsirSource.saadi,
      TafsirSource.muyassar,
      TafsirSource.mukhtasar,
    ],
    TafsirLocalPageLoader? localPageLoader,
    TafsirMukhtasarDocumentLoader? loadMukhtasarDocument,
    TafsirMushafDataLoader? mushafDataLoader,
    this.maxCachedPages = 24,
  }) : _client = client ?? http.Client(),
       _localPageLoader = localPageLoader ?? _loadBundledSaadiPage,
       _mukhtasarDocumentLoader = loadMukhtasarDocument,
       _mushafDataLoader = mushafDataLoader ?? _loadBundledMushafData,
       assert(maxCachedPages > 0),
       _sources = List<TafsirSource>.of(sources);

  final http.Client _client;
  final TafsirLocalPageLoader _localPageLoader;
  final TafsirMukhtasarDocumentLoader? _mukhtasarDocumentLoader;
  final TafsirMushafDataLoader _mushafDataLoader;
  final List<TafsirSource> _sources;
  final int maxCachedPages;
  final Map<String, List<TafsirEntry>> _cache = {};
  final Map<String, Future<List<TafsirEntry>>> _inFlight = {};
  Future<Map<int, List<_MukhtasarRecord>>>? _mukhtasarRecords;
  Future<Map<int, List<int>>>? _mushafPages;

  List<TafsirSource> get availableSources => List.unmodifiable(_sources);

  void addSource(TafsirSource source) {
    if (_sources.any((item) => item.id == source.id)) return;
    _sources.add(source);
  }

  Future<List<TafsirEntry>> tafsirByPage(
    int pageNumber, {
    TafsirSource source = TafsirSource.saadi,
  }) {
    _validatePageNumber(pageNumber);
    final cacheKey = '${source.id}:$pageNumber';
    final cached = _cache[cacheKey];
    if (cached != null) return Future.value(cached);

    return _inFlight.putIfAbsent(cacheKey, () {
      return _loadPage(pageNumber, source: source).whenComplete(() {
        _inFlight.remove(cacheKey);
      });
    });
  }

  Future<List<TafsirEntry>> _loadPage(
    int pageNumber, {
    required TafsirSource source,
  }) async {
    if (source.id == TafsirSource.saadi.id) {
      final localEntries = await _loadLocalSaadiPage(pageNumber);
      if (localEntries == null) {
        throw FlutterError(
          'ملف تفسير السعدي المحلي للصفحة $pageNumber غير موجود داخل التطبيق. '
          'أعد بناء التطبيق لتضمين ملفات التفسير.',
        );
      }
      _cachePage(source, pageNumber, localEntries);
      return localEntries;
    }

    if (source.id == TafsirSource.mukhtasar.id) {
      final entries = await _loadMukhtasarPage(pageNumber);
      _cachePage(source, pageNumber, entries);
      return entries;
    }

    final entries = await _fetchRemotePage(pageNumber, source: source);
    _cachePage(source, pageNumber, entries);
    return entries;
  }

  Future<List<TafsirEntry>> _loadMukhtasarPage(int pageNumber) async {
    final recordsBySurah = await (_mukhtasarRecords ??=
        _loadMukhtasarRecords());
    final versesByPage = await (_mushafPages ??= _loadMushafPages());
    final verseIds = versesByPage[pageNumber];
    if (verseIds == null || verseIds.isEmpty) {
      throw const FormatException('تعذر تحديد آيات صفحة المصحف');
    }

    final entries = <TafsirEntry>[];
    for (final verseId in verseIds) {
      final surah = verseId ~/ 1000;
      final ayah = verseId % 1000;
      final records = recordsBySurah[surah] ?? const <_MukhtasarRecord>[];
      final index = records.lastIndexWhere((record) => record.ayah <= ayah);
      if (index < 0) continue;
      final record = records[index];
      if (entries.any((entry) => entry.verseKey == record.verseKey)) continue;
      entries.add(
        TafsirEntry(
          verseKey: record.verseKey,
          text: _cleanMukhtasarText(record.text),
          sourceName: TafsirSource.mukhtasar.name,
        ),
      );
    }

    if (entries.isEmpty) {
      throw const FormatException('لا توجد مادة المختصر لهذه الصفحة');
    }
    return entries;
  }

  Future<Map<int, List<_MukhtasarRecord>>> _loadMukhtasarRecords() async {
    final contents =
        await (_mukhtasarDocumentLoader?.call() ??
            _downloadMukhtasarDocument());
    final payload = jsonDecode(contents);
    if (payload is! Map<String, dynamic> || payload['ayahs'] is! List) {
      throw const FormatException('صيغة ملف المختصر غير صحيحة');
    }

    final bySurah = <int, List<_MukhtasarRecord>>{};
    for (final item in payload['ayahs'] as List<dynamic>) {
      if (item is! Map<String, dynamic>) continue;
      final surah = item['surah'];
      final ayah = item['ayah'];
      final content = item['content'];
      if (surah is! int ||
          ayah is! int ||
          content is! List ||
          content.isEmpty) {
        continue;
      }
      final firstContent = content.first;
      if (firstContent is! Map<String, dynamic>) continue;
      final text = firstContent['text'];
      if (text is! String || text.trim().isEmpty) continue;
      bySurah
          .putIfAbsent(surah, () => <_MukhtasarRecord>[])
          .add(_MukhtasarRecord(surah: surah, ayah: ayah, text: text));
    }
    if (bySurah.isEmpty) {
      throw const FormatException('ملف المختصر لا يحتوي على آيات صالحة');
    }
    for (final records in bySurah.values) {
      records.sort((a, b) => a.ayah.compareTo(b.ayah));
    }
    return bySurah;
  }

  Future<Map<int, List<int>>> _loadMushafPages() async {
    final payload = jsonDecode(await _mushafDataLoader());
    if (payload is! List<dynamic>) {
      throw const FormatException('صيغة بيانات المصحف غير صحيحة');
    }
    final pages = <int, List<int>>{};
    for (final item in payload) {
      if (item is! Map<String, dynamic>) continue;
      final page = item['page'];
      final surah = item['sura_no'];
      final ayah = item['aya_no'];
      if (page is! int || surah is! int || ayah is! int) continue;
      pages.putIfAbsent(page, () => <int>[]).add(surah * 1000 + ayah);
    }
    return pages;
  }

  Future<String> _downloadMukhtasarDocument() async {
    final uri = Uri.parse(
      'https://api.quranpedia.net/dumps/tafsir-book-503.json.gz',
    );
    final response = await _client
        .get(uri, headers: const {'accept': 'application/gzip'})
        .timeout(const Duration(seconds: 20));
    if (response.statusCode != 200) {
      throw http.ClientException('تعذر تحميل المختصر', uri);
    }
    try {
      return utf8.decode(gzip.decode(response.bodyBytes));
    } on FormatException {
      throw const FormatException('تعذر فك ملف المختصر');
    }
  }

  Future<List<TafsirEntry>?> _loadLocalSaadiPage(int pageNumber) async {
    final contents = await _localPageLoader(pageNumber);
    if (contents == null) return null;

    final payload = jsonDecode(contents);
    if (payload is! Map<String, dynamic> ||
        payload['schema_version'] != 1 ||
        payload['book_id'] != 42 ||
        payload['page'] != pageNumber ||
        payload['entries'] is! List<dynamic>) {
      throw const FormatException('صيغة تفسير السعدي المحلي غير صحيحة');
    }

    final entries = (payload['entries'] as List<dynamic>)
        .map((record) {
          if (record is! Map<String, dynamic>) {
            throw const FormatException('سجل تفسير محلي غير صحيح');
          }
          final verseKey = record['verse_key'];
          final text = record['text'];
          if (verseKey is! String ||
              !RegExp(r'^\d{1,3}:\d{1,3}$').hasMatch(verseKey) ||
              text is! String ||
              text.trim().isEmpty) {
            throw const FormatException(
              'بيانات آية في التفسير المحلي غير مكتملة',
            );
          }
          return TafsirEntry(
            verseKey: verseKey,
            text: _cleanSaadiCommentary(text),
            sourceName: TafsirSource.saadi.name,
          );
        })
        .toList(growable: false);

    if (entries.isEmpty) {
      throw const FormatException('صفحة التفسير المحلي فارغة');
    }
    return entries;
  }

  Future<List<TafsirEntry>> _fetchRemotePage(
    int pageNumber, {
    required TafsirSource source,
  }) async {
    final uri = Uri.https(
      'api.quran.com',
      '/api/v4/tafsirs/${source.id}/by_page/$pageNumber',
      const {'fields': 'verse_key,resource_name', 'per_page': '50'},
    );
    final response = await _client
        .get(uri, headers: const {'accept': 'application/json'})
        .timeout(const Duration(seconds: 15));
    if (response.statusCode != 200) {
      throw http.ClientException('تعذر تحميل التفسير', uri);
    }

    final payload = jsonDecode(response.body) as Map<String, dynamic>;
    final records = payload['tafsirs'];
    if (records is! List<dynamic>) {
      throw const FormatException('صيغة بيانات التفسير غير صحيحة');
    }
    final entries = records
        .whereType<Map<String, dynamic>>()
        .map(
          (record) => TafsirEntry(
            verseKey: record['verse_key'] as String? ?? '',
            text: _plainText(record['text'] as String? ?? ''),
            sourceName: record['resource_name'] as String? ?? source.name,
          ),
        )
        .where((entry) => entry.verseKey.isNotEmpty && entry.text.isNotEmpty)
        .toList(growable: false);

    return entries;
  }

  void _cachePage(
    TafsirSource source,
    int pageNumber,
    List<TafsirEntry> entries,
  ) {
    if (_cache.length >= maxCachedPages) {
      _cache.remove(_cache.keys.first);
    }
    _cache['${source.id}:$pageNumber'] = entries;
  }

  static Future<String?> _loadBundledSaadiPage(int pageNumber) async {
    final page = pageNumber.toString().padLeft(3, '0');
    try {
      return await rootBundle.loadString('assets/data/tafsir_saadi/$page.json');
    } on FlutterError {
      return null;
    }
  }

  static Future<String> _loadBundledMushafData() {
    return rootBundle.loadString('assets/data/hafs_smart_v8.json');
  }

  /// Keep the canonical Arabic text intact. In particular, do not collapse
  /// whitespace: paragraphs and Qur'anic quotations in the source are part of
  /// the reading experience and must remain correctly shaped by Flutter.
  static String _cleanSaadiCommentary(String value) {
    var text = value
        .replaceAll(RegExp(r'[\u200e\u200f\u202a-\u202e]'), '')
        .replaceAll(RegExp(r'\n[ \t]*\n[ \t]*\n+'), '\n\n')
        .trim();

    // Shamela puts the ayah quotation before the commentary. The Mushaf
    // reader already renders the verified ayah, so remove only that leading
    // quotation and keep the source commentary verbatim.
    final commentaryStart = RegExp(
      r'\}\s*\.\s*(?=(?:يقول|يخبر|يذكر|يبين|هذا|ثم|لما|وفي|أي)\s)',
      multiLine: true,
    ).firstMatch(text);
    if (commentaryStart != null) {
      text = text.substring(commentaryStart.end).trim();
    }
    return text;
  }

  void _validatePageNumber(int pageNumber) {
    if (pageNumber < AppConstants.firstMushafPage ||
        pageNumber > AppConstants.mushafPageCount) {
      throw RangeError.range(
        pageNumber,
        AppConstants.firstMushafPage,
        AppConstants.mushafPageCount,
        'pageNumber',
      );
    }
  }

  String _plainText(String html) {
    var text = html
        .replaceAll(RegExp(r'<br\s*/?>', caseSensitive: false), '\n')
        .replaceAll(RegExp(r'</(p|div|h[1-6]|li)>', caseSensitive: false), '\n')
        .replaceAll(RegExp(r'<[^>]+>'), '')
        .replaceAll('&nbsp;', ' ')
        .replaceAll('&amp;', '&')
        .replaceAll('&quot;', '"')
        .replaceAll('&#39;', "'")
        .replaceAll('&lt;', '<')
        .replaceAll('&gt;', '>');
    return text.replaceAll(RegExp(r'\n\s*\n+'), '\n\n').trim();
  }

  static String _cleanMukhtasarText(String html) {
    final text = html
        .replaceAll(RegExp(r'<br\s*/?>', caseSensitive: false), '\n')
        .replaceAll(RegExp(r'<[^>]+>'), '')
        .replaceAll('\r', '')
        .replaceAllMapped(
          RegExp(r'(^|\n)[xyz]\s*'),
          (match) => match.group(1) ?? '',
        )
        .replaceAll(RegExp(r'\n\s*\n+'), '\n\n')
        .trim();
    return text;
  }

  void close() => _client.close();
}

class _MukhtasarRecord {
  const _MukhtasarRecord({
    required this.surah,
    required this.ayah,
    required this.text,
  });

  final int surah;
  final int ayah;
  final String text;

  String get verseKey => '$surah:$ayah';
}
