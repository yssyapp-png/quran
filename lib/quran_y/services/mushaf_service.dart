import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import '../core/constants/app_constants.dart';

class MushafService {
  const MushafService();

  String pageAssetPath(int pageNumber) {
    _validatePageNumber(pageNumber);
    return AppConstants.mushafPageAsset(pageNumber);
  }

  Future<bool> pageAssetExists(int pageNumber) async {
    final path = pageAssetPath(pageNumber);
    try {
      await rootBundle.load(path);
      return true;
    } on FlutterError {
      return false;
    }
  }

  void _validatePageNumber(int pageNumber) {
    if (pageNumber < AppConstants.firstMushafPage ||
        pageNumber > AppConstants.mushafPageCount) {
      throw RangeError.range(
        pageNumber,
        AppConstants.firstMushafPage,
        AppConstants.mushafPageCount,
        'pageNumber',
      );
    }
  }
}
