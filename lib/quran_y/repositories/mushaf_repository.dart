import '../services/mushaf_service.dart';

class MushafRepository {
  const MushafRepository({this.service = const MushafService()});

  final MushafService service;

  String pageAssetPath(int pageNumber) => service.pageAssetPath(pageNumber);

  Future<bool> pageAssetExists(int pageNumber) {
    return service.pageAssetExists(pageNumber);
  }
}
