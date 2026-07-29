import 'package:flutter/material.dart';
import '../models/bookmark.dart';
import '../services/bookmark_service.dart';
import '../services/quran_local_service.dart';
import '../theme/app_theme.dart';
import 'mushaf_page_screen.dart';

/// المكتبة: آخر موضع قراءة + كل العلامات المرجعية المحفوظة، في مكان واحد
/// لتسهيل العودة السريعة لأي موضع توقف عنده القارئ سابقًا.
class LibraryScreen extends StatefulWidget {
  const LibraryScreen({super.key});

  @override
  State<LibraryScreen> createState() => _LibraryScreenState();
}

class _LibraryScreenState extends State<LibraryScreen> {
  final BookmarkService _bookmarkService = BookmarkService();
  final QuranLocalService _service = QuranLocalService();
  late Future<_LibraryData> _future;

  @override
  void initState() {
    super.initState();
    _future = _load();
  }

  Future<_LibraryData> _load() async {
    final lastRead = await _bookmarkService.getLastRead();
    final bookmarks = await _bookmarkService.getBookmarks();
    return _LibraryData(lastRead: lastRead, bookmarks: bookmarks.reversed.toList());
  }

  Future<void> _openBookmark(Bookmark b) async {
    final page = await _service.getAyahPage(b.suraNo, b.ayaNo);
    if (!mounted) return;
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => MushafPageScreen(initialPage: page)),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('المكتبة')),
      body: FutureBuilder<_LibraryData>(
        future: _future,
        builder: (context, snapshot) {
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator(color: AppColors.gold));
          }
          final data = snapshot.data!;
          if (data.lastRead == null && data.bookmarks.isEmpty) {
            return const Center(
              child: Padding(
                padding: EdgeInsets.all(24),
                child: Text(
                  'لا توجد علامات مرجعية أو قراءة سابقة بعد.\nابدأ بالقراءة وأضف علامات لتظهر هنا.',
                  textAlign: TextAlign.center,
                ),
              ),
            );
          }
          return ListView(
            padding: const EdgeInsets.all(12),
            children: [
              if (data.lastRead != null) ...[
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 8, horizontal: 4),
                  child: Text('متابعة القراءة',
                      style: TextStyle(fontWeight: FontWeight.bold, color: AppColors.inkGreen)),
                ),
                Card(
                  color: AppColors.inkGreen,
                  child: ListTile(
                    leading: const Icon(Icons.auto_stories, color: AppColors.gold),
                    title: Text(data.lastRead!.suraName,
                        style: const TextStyle(color: AppColors.cream)),
                    subtitle: Text('آية ${data.lastRead!.ayaNo}',
                        style: const TextStyle(color: AppColors.cream)),
                    trailing: const Icon(Icons.chevron_left, color: AppColors.gold),
                    onTap: () => _openBookmark(data.lastRead!),
                  ),
                ),
                const SizedBox(height: 16),
              ],
              if (data.bookmarks.isNotEmpty) ...[
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 8, horizontal: 4),
                  child: Text('العلامات المرجعية',
                      style: TextStyle(fontWeight: FontWeight.bold, color: AppColors.inkGreen)),
                ),
                ...data.bookmarks.map((b) => Card(
                      child: ListTile(
                        leading: const Icon(Icons.bookmark, color: AppColors.inkGreen),
                        title: Text(b.suraName),
                        subtitle: Text('آية ${b.ayaNo}'),
                        trailing: const Icon(Icons.chevron_left),
                        onTap: () => _openBookmark(b),
                      ),
                    )),
              ],
            ],
          );
        },
      ),
    );
  }
}

class _LibraryData {
  final Bookmark? lastRead;
  final List<Bookmark> bookmarks;
  _LibraryData({required this.lastRead, required this.bookmarks});
}
