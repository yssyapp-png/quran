/// يمثّل قارئًا وتلاوته — قابل للتوسعة بإضافة قراء جدد لاحقًا
/// بدون تعديل أي شاشة، فقط بإضافة عنصر جديد إلى [Reciters.all].
class Reciter {
  final String id; // معرف ثابت يُستخدم في التخزين (لا يتغير حتى لو تغير الاسم)
  final String nameAr;
  final String? everyayahFolder; // اسم مجلد التلاوة في everyayah.com
  /// رابط ملفات السور الكاملة. وجوده يعني أن التلاوة تُشغّل سورة كاملة
  /// بدل ملف منفصل لكل آية.
  final String? surahAudioBaseUrl;
  final bool
  supportsAyahTiming; // هل تتوفر بيانات توقيت للتتبع أثناء التلاوة (Karaoke)

  const Reciter({
    required this.id,
    required this.nameAr,
    this.everyayahFolder,
    this.surahAudioBaseUrl,
    this.supportsAyahTiming = false,
  }) : assert(everyayahFolder != null || surahAudioBaseUrl != null),
       assert(everyayahFolder == null || surahAudioBaseUrl == null);

  bool get playsFullSurah => surahAudioBaseUrl != null;

  String audioUrl(int suraNo, int ayaNo) {
    final s = suraNo.toString().padLeft(3, '0');
    final fullSurahBaseUrl = surahAudioBaseUrl;
    if (fullSurahBaseUrl != null) return '$fullSurahBaseUrl/$s.mp3';
    final a = ayaNo.toString().padLeft(3, '0');
    return 'https://everyayah.com/data/${everyayahFolder!}/$s$a.mp3';
  }
}

/// قائمة القراء المتاحين في التطبيق.
class Reciters {
  static const saadGhamdi = Reciter(
    id: 'ghamdi',
    nameAr: 'سعد الغامدي',
    surahAudioBaseUrl: 'https://server7.mp3quran.net/s_gmd/128',
    supportsAyahTiming: false,
  );

  /// تلاوة كاملة للشيخ عبد الله المطرود بجودة 128kbps.
  /// الملفات تُبث عند التشغيل، ولا تُضاف إلى حجم التطبيق.
  static const abdullahMatroud = Reciter(
    id: 'abdullah_matroud',
    nameAr: 'عبد الله المطرود',
    everyayahFolder: 'Abdullah_Matroud_128kbps',
    supportsAyahTiming: true,
  );

  static const List<Reciter> all = [saadGhamdi, abdullahMatroud];

  static const Reciter defaultReciter = saadGhamdi;

  static Reciter byId(String id) =>
      all.firstWhere((r) => r.id == id, orElse: () => defaultReciter);
}
