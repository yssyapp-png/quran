class Ayah {
  const Ayah({required this.verseKey, required this.text});

  final String verseKey;
  final String text;

  String get copyText => '$text ﴿${_toArabicDigits(verseKey.split(':').last)}﴾';

  static String _toArabicDigits(String value) {
    const western = '0123456789';
    const arabic = '٠١٢٣٤٥٦٧٨٩';
    return value.split('').map((digit) {
      final index = western.indexOf(digit);
      return index < 0 ? digit : arabic[index];
    }).join();
  }
}
