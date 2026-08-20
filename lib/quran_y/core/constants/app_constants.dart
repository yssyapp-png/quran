abstract final class AppConstants {
  static const String appName = 'القرآن الكريم';
  static const int mushafPageCount = 604;
  static const int firstMushafPage = 1;
  static const String mushafPagesPath = 'assets/mushaf_pages';

  static String mushafPageAsset(int pageNumber) {
    return '$mushafPagesPath/$pageNumber.jpg';
  }
}
