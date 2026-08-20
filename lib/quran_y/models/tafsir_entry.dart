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
    id: 24,
    name: 'تفسير السعدي',
    author: 'الشيخ عبد الرحمن بن ناصر السعدي',
    slug: 'ar-tafseer-al-saddi',
  );
}
