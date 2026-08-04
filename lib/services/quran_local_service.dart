import 'dart:convert';
import 'package:flutter/services.dart' show rootBundle;
import '../models/juz.dart';
import '../models/local_ayah.dart';

/// خدمة تحميل النص القرآني من بيانات مصحف المدينة للمطورين
/// (KFGQPC Hafs Smart v8) المضمّنة داخل التطبيق — تعمل بدون إنترنت.
class QuranLocalService {
  static final QuranLocalService _instance = QuranLocalService._internal();
  factory QuranLocalService() => _instance;
  QuranLocalService._internal();

  List<LocalAyah>? _allAyahs;
  List<LocalSurahInfo>? _surahs;
  List<JuzInfo>? _juzList;

  Future<List<LocalAyah>> _loadAll() async {
    if (_allAyahs != null) return _allAyahs!;
    final raw = await rootBundle.loadString('assets/data/hafs_smart_v8.json');
    final List data = jsonDecode(raw);
    _allAyahs = data.map((e) => LocalAyah.fromJson(e)).toList();
    return _allAyahs!;
  }

  /// قائمة السور الـ114 مشتقة مباشرة من بيانات المصحف (بدون إنترنت)
  Future<List<LocalSurahInfo>> getSurahList() async {
    if (_surahs != null) return _surahs!;
    final ayahs = await _loadAll();
    final Map<int, List<LocalAyah>> grouped = {};
    for (final a in ayahs) {
      grouped.putIfAbsent(a.suraNo, () => []).add(a);
    }
    final list = grouped.entries.map((e) {
      final first = e.value.first;
      return LocalSurahInfo(
        number: e.key,
        nameAr: first.suraNameAr,
        nameEn: first.suraNameEn,
        ayahCount: e.value.length,
        firstPage: first.page,
        isMeccan: !kMedinanSurahNumbers.contains(e.key),
      );
    }).toList()
      ..sort((a, b) => a.number.compareTo(b.number));
    _surahs = list;
    return list;
  }

  /// آيات سورة معينة مرتبة حسب رقم الآية
  Future<List<LocalAyah>> getSurahAyahs(int suraNo) async {
    final ayahs = await _loadAll();
    final result = ayahs.where((a) => a.suraNo == suraNo).toList()
      ..sort((a, b) => a.ayaNo.compareTo(b.ayaNo));
    return result;
  }

  /// قائمة الأجزاء الثلاثين، كل جزء يبدأ عند أول آية تحمل رقم الجزء (jozz) هذا.
  Future<List<JuzInfo>> getJuzList() async {
    if (_juzList != null) return _juzList!;
    final ayahs = await _loadAll(); // مرتبة أصلًا حسب ترتيب المصحف (id تصاعدي)
    final Map<int, LocalAyah> firstAyahOfJuz = {};
    for (final a in ayahs) {
      if (!firstAyahOfJuz.containsKey(a.jozz)) {
        firstAyahOfJuz[a.jozz] = a;
      }
    }
    final list = firstAyahOfJuz.entries.map((e) {
      final a = e.value;
      return JuzInfo(
        number: e.key,
        startSuraNo: a.suraNo,
        startSuraName: a.suraNameAr,
        startAyaNo: a.ayaNo,
        startPage: a.page,
      );
    }).toList()
      ..sort((a, b) => a.number.compareTo(b.number));
    _juzList = list;
    return list;
  }

  /// رقم صفحة المصحف التي توجد بها آية معينة (لفتح عارض الصفحات عليها مباشرة)
  Future<int> getAyahPage(int suraNo, int ayaNo) async {
    final ayahs = await _loadAll();
    final ayah = ayahs.firstWhere(
      (a) => a.suraNo == suraNo && a.ayaNo == ayaNo,
      orElse: () => ayahs.first,
    );
    return ayah.page;
  }

  /// السورة التي تقع فيها صفحة معينة (آخر سورة تبدأ عند صفحة <= الصفحة المطلوبة)
  Future<LocalSurahInfo> getSurahAtPage(int page) async {
    final surahs = await getSurahList();
    LocalSurahInfo result = surahs.first;
    for (final s in surahs) {
      if (s.firstPage <= page) {
        result = s;
      } else {
        break;
      }
    }
    return result;
  }

  /// بحث نصي بسيط باستخدام النص الإملائي (aya_text_emlaey)
  Future<List<LocalAyah>> search(String query) async {
    if (query.trim().isEmpty) return [];
    final ayahs = await _loadAll();
    return ayahs.where((a) => a.ayaTextEmlaey.contains(query)).toList();
  }
}
