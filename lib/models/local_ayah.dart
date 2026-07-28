/// آية من بيانات مصحف المدينة للمطورين (KFGQPC Hafs Smart v8)
class LocalAyah {
  final int id;
  final int jozz;
  final int suraNo;
  final String suraNameEn;
  final String suraNameAr;
  final int page;
  final int lineStart;
  final int lineEnd;
  final int ayaNo;
  final String ayaText; // نص مشفر بحروف خط HafsSmart (الرسم العثماني الرسمي)
  final String ayaTextEmlaey; // نص إملائي عادي (للبحث والتفسير)

  LocalAyah({
    required this.id,
    required this.jozz,
    required this.suraNo,
    required this.suraNameEn,
    required this.suraNameAr,
    required this.page,
    required this.lineStart,
    required this.lineEnd,
    required this.ayaNo,
    required this.ayaText,
    required this.ayaTextEmlaey,
  });

  factory LocalAyah.fromJson(Map<String, dynamic> json) {
    return LocalAyah(
      id: json['id'],
      jozz: json['jozz'],
      suraNo: json['sura_no'],
      suraNameEn: json['sura_name_en'] ?? '',
      suraNameAr: json['sura_name_ar'] ?? '',
      page: json['page'],
      lineStart: json['line_start'],
      lineEnd: json['line_end'],
      ayaNo: json['aya_no'],
      ayaText: json['aya_text'] ?? '',
      ayaTextEmlaey: json['aya_text_emlaey'] ?? '',
    );
  }
}

/// معلومات سورة مشتقة من بيانات المصحف المحلية
class LocalSurahInfo {
  final int number;
  final String nameAr;
  final String nameEn;
  final int ayahCount;
  final int firstPage;

  LocalSurahInfo({
    required this.number,
    required this.nameAr,
    required this.nameEn,
    required this.ayahCount,
    required this.firstPage,
  });
}
