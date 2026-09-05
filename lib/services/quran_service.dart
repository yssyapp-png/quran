import 'dart:convert';
import 'package:http/http.dart' as http;

/// خدمة الميزات التي تحتاج إنترنت: التفسير.
/// (نص القرآن نفسه محلي الآن من مصحف المدينة — راجع quran_local_service.dart)
class QuranService {
  static const String _baseUrl = 'https://api.alquran.cloud/v1';

  /// جلب تفسير آية معينة (تفسير الميسر كمثال)
  Future<String> getAyahTafsir(int surahNumber, int ayahNumber,
      {String tafsirEdition = 'ar.muyassar'}) async {
    final res = await http
        .get(
            Uri.parse('$_baseUrl/ayah/$surahNumber:$ayahNumber/$tafsirEdition'))
        .timeout(const Duration(seconds: 12));
    if (res.statusCode != 200) {
      throw Exception('تعذر تحميل التفسير');
    }
    final data = jsonDecode(utf8.decode(res.bodyBytes));
    return data['data']['text'] ?? 'لا يتوفر تفسير لهذه الآية حاليًا';
  }
}
