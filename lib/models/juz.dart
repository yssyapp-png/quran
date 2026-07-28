/// معلومات جزء من أجزاء القرآن الثلاثين، مشتقة من بيانات المصحف المحلية.
class JuzInfo {
  final int number; // 1..30
  final int startSuraNo;
  final String startSuraName;
  final int startAyaNo;
  final int startPage;

  JuzInfo({
    required this.number,
    required this.startSuraNo,
    required this.startSuraName,
    required this.startAyaNo,
    required this.startPage,
  });
}
