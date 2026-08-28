class TafsirEntry {
  const TafsirEntry({
    required this.verseKey,
    required this.text,
    required this.sourceName,
  });

  final String verseKey;
  final String text;
  final String sourceName;
}

class TafsirSource {
  const TafsirSource({
    required this.id,
    required this.name,
    required this.author,
    required this.slug,
  });

  final int id;
  final String name;
  final String author;
  final String slug;

  static const saadi = TafsirSource(
    id: 91,
    name: 'تفسير السعدي',
    author: 'الشيخ عبد الرحمن بن ناصر السعدي',
    slug: 'ar-tafseer-al-saddi',
  );

  /// التفسير الميسر المعتمد من مجمع الملك فهد لطباعة المصحف الشريف.
  /// النص يُحمّل عند اختيار المستخدم له؛ لا توجد أي مكوّنات صوتية.
  static const muyassar = TafsirSource(
    id: 16,
    name: 'التفسير الميسر',
    author: 'نخبة من العلماء - مجمع الملك فهد',
    slug: 'ar-tafsir-muyassar',
  );

  /// يُحمَّل النص المنظّم عند اختيار المستخدم له، لذلك لا يضيف ملف PDF
  /// المصوّر أو قاعدة بيانات كبيرة إلى حجم التطبيق.
  static const mukhtasar = TafsirSource(
    id: 503,
    name: 'المختصر في تفسير القرآن الكريم',
    author: 'مجموعة من المؤلفين - مركز تفسير للدراسات القرآنية',
    slug: 'quranpedia-book-503',
  );
}
