/// يمثّل قارئًا وتلاوته — قابل للتوسعة بإضافة قراء جدد لاحقًا
/// بدون تعديل أي شاشة، فقط بإضافة عنصر جديد إلى [Reciters.all].
class Reciter {
  final String id; // معرف ثابت يُستخدم في التخزين (لا يتغير حتى لو تغير الاسم)
  final String nameAr;
  final String everyayahFolder; // اسم مجلد التلاوة في everyayah.com
  final bool
      supportsAyahTiming; // هل تتوفر بيانات توقيت للتتبع أثناء التلاوة (Karaoke)

  const Reciter({
    required this.id,
    required this.nameAr,
    required this.everyayahFolder,
    this.supportsAyahTiming = false,
  });

  String audioUrl(int suraNo, int ayaNo) {
    final s = suraNo.toString().padLeft(3, '0');
    final a = ayaNo.toString().padLeft(3, '0');
    return 'https://everyayah.com/data/$everyayahFolder/$s$a.mp3';
  }
}

/// قائمة القراء المتاحين في التطبيق.
/// حاليًا: سعد الغامدي فقط، حسب طلب المستخدم، مع إبقاء الباب مفتوحًا للإضافة.
class Reciters {
  static const saadGhamdi = Reciter(
    id: 'ghamdi',
    nameAr: 'سعد الغامدي',
    everyayahFolder: 'Ghamadi_40kbps',
    // بيانات توقيت الكلمات (segments) لتلاوته متوفرة فعليًا عبر مشروع
    // Quranic Universal Library التابع لـ Tarteel (qul.tarteel.ai) — نفس
    // المصدر الذي يستخدمه تطبيق Quran.com لتمييز الآية/الكلمة أثناء التلاوة.
    // TODO: لم يتم بعد سحب ودمج ملف التوقيتات الفعلي داخل التطبيق —
    // العلم هنا فقط يعلن الإمكانية؛ شاشة القراءة لا تستخدمها بعد.
    supportsAyahTiming: true,
  );

  static const List<Reciter> all = [saadGhamdi];

  static const Reciter defaultReciter = saadGhamdi;

  static Reciter byId(String id) =>
      all.firstWhere((r) => r.id == id, orElse: () => defaultReciter);
}
