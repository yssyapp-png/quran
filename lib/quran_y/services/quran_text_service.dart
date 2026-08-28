import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;

import '../core/constants/app_constants.dart';
import '../models/ayah.dart';

class QuranTextService {
  QuranTextService({http.Client? client, this.maxCachedPages = 24})
    : assert(maxCachedPages > 0),
      _client = client ?? http.Client();

  final http.Client _client;
  final int maxCachedPages;
  final Map<int, List<Ayah>> _cache = {};
  final Map<int, Future<List<Ayah>>> _inFlight = {};

  Future<List<Ayah>> versesByPage(int pageNumber) {
    _validatePageNumber(pageNumber);
    final cached = _cache[pageNumber];
    if (cached != null) return Future.value(cached);

    return _inFlight.putIfAbsent(pageNumber, () {
      return _fetchPage(pageNumber).whenComplete(() {
        _inFlight.remove(pageNumber);
      });
    });
  }

  Future<List<Ayah>> _fetchPage(int pageNumber) async {
    final uri = Uri.https(
      'api.quran.com',
      '/api/v4/verses/by_page/$pageNumber',
      {'language': 'ar', 'fields': 'text_uthmani', 'per_page': '50'},
    );
    final response = await _client
        .get(uri, headers: const {'accept': 'application/json'})
        .timeout(const Duration(seconds: 15));

    if (response.statusCode != 200) {
      throw http.ClientException('تعذر تحميل آيات الصفحة', uri);
    }

    final payload = jsonDecode(response.body) as Map<String, dynamic>;
    final records = payload['verses'];
    if (records is! List<dynamic>) {
      throw const FormatException('صيغة بيانات الآيات غير صحيحة');
    }

    final verses = records
        .map((item) {
          final verse = item as Map<String, dynamic>;
          final verseKey = verse['verse_key'];
          final text = verse['text_uthmani'];
          if (verseKey is! String || text is! String) {
            throw const FormatException('بيانات آية غير مكتملة');
          }
          return Ayah(verseKey: verseKey, text: text);
        })
        .toList(growable: false);

    _cachePage(pageNumber, verses);
    return verses;
  }

  void _cachePage(int pageNumber, List<Ayah> verses) {
    if (_cache.length >= maxCachedPages) {
      _cache.remove(_cache.keys.first);
    }
    _cache[pageNumber] = verses;
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

  void close() => _client.close();
}
