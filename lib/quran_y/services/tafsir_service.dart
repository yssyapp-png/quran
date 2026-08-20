import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;

import '../models/tafsir_entry.dart';

class TafsirService {
  TafsirService({
    http.Client? client,
    List<TafsirSource> sources = const [TafsirSource.saadi],
  })  : _client = client ?? http.Client(),
        _sources = List<TafsirSource>.of(sources);

  final http.Client _client;
  final List<TafsirSource> _sources;
  final Map<String, List<TafsirEntry>> _cache = {};

  List<TafsirSource> get availableSources => List.unmodifiable(_sources);

  void addSource(TafsirSource source) {
    if (_sources.any((item) => item.id == source.id)) return;
    _sources.add(source);
  }

  Future<List<TafsirEntry>> tafsirByPage(
    int pageNumber, {
    TafsirSource source = TafsirSource.saadi,
  }) async {
    final cacheKey = '${source.id}:$pageNumber';
    final cached = _cache[cacheKey];
    if (cached != null) return cached;

    final uri = Uri.https(
      'api.quran.com',
      '/api/v4/tafsirs/${source.id}/by_page/$pageNumber',
      const {'fields': 'verse_key,resource_name', 'per_page': '50'},
    );
    final response = await _client.get(uri, headers: const {
      'accept': 'application/json'
    }).timeout(const Duration(seconds: 15));
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

    _cache[cacheKey] = entries;
    return entries;
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

  void close() => _client.close();
}
