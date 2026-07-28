class Bookmark {
  final int suraNo;
  final String suraName;
  final int ayaNo;

  Bookmark({required this.suraNo, required this.suraName, required this.ayaNo});

  String get key => '$suraNo:$ayaNo';

  Map<String, dynamic> toJson() => {
        'suraNo': suraNo,
        'suraName': suraName,
        'ayaNo': ayaNo,
      };

  factory Bookmark.fromJson(Map<String, dynamic> json) => Bookmark(
        suraNo: json['suraNo'],
        suraName: json['suraName'],
        ayaNo: json['ayaNo'],
      );
}
