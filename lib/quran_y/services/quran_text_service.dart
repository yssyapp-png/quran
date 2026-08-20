import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;

import '../models/ayah.dart';

class QuranTextService {
  QuranTextService({http.Client? client}) : _client = client ?? http.Client();

  final http.Client _client;
  final Map<int, List<Ayah>> _cache = {};

  Future<List<Ayah>> versesByPage(int pageNumber) async {
    final cached = _cache[pageNumber];
    if (cached != null) return cached;

    final uri = Uri.https(
      'api.quran.com',
      '/api/v4/verses/by_page/$pageNumber',
      {'language': 'ar', 'fields': 'text_uthmani', 'per_page': '50'},
    );
    final response = await _client.get(uri, headers: const {
      'accept': 'application/json'
    }).timeout(const Duration(seconds: 15));

    if (response.statusCode != 200) {
      throw http.ClientException('تعذر تحميل آيات الصفحة', uri);
    }

    final payload = jsonDecode(response.body) as Map<String, dynamic>;
    final records = payload['verses'];
    if (records is! List<dynamic>) {
      throw const FormatException('صيغة بيانات الآيات غير صحيحة');
    }

    final verses = records.map((item) {
      final verse = item as Map<String, dynamic>;
      final verseKey = verse['verse_key'];
      final text = verse['text_uthmani'];
      if (verseKey is! String || text is! String) {
        throw const FormatException('بيانات آية غير مكتملة');
      }
      return Ayah(verseKey: verseKey, text: text);
    }).toList(growable: false);

    _cache[pageNumber] = verses;
    return verses;
  }

  void close() => _client.close();
}
