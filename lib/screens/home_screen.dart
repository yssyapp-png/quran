import 'package:flutter/material.dart';
import '../models/bookmark.dart';
import '../models/local_ayah.dart';
import '../services/bookmark_service.dart';
import '../services/quran_local_service.dart';
import '../theme/app_theme.dart';
import '../theme/theme_controller.dart';
import 'index_screen.dart';
import 'mushaf_page_screen.dart';
import 'search_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final QuranLocalService _service = QuranLocalService();
  final BookmarkService _bookmarkService = BookmarkService();
  late Future<List<LocalSurahInfo>> _surahsFuture;
  Bookmark? _lastRead;
  String _query = '';

  @override
  void initState() {
    super.initState();
    _surahsFuture = _service.getSurahList();
    _loadLastRead();
  }

  Future<void> _loadLastRead() async {
    final last = await _bookmarkService.getLastRead();
    if (mounted) setState(() => _lastRead = last);
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Scaffold(
      appBar: AppBar(
        title: const Text('القرآن الكريم'),
        actions: [
          IconButton(
            tooltip: 'الفهرس (السور/الأجزاء)',
            icon: const Icon(Icons.list_alt_outlined),
            // الفهرس يُعيد رقم الصفحة المختارة (أو null إن أُلغي دون اختيار)
            // بدل فتح شاشة قراءة من داخل نفسه؛ من هنا (الشاشة الرئيسية) نحن
            // من يقرر فتح شاشة القراءة بالصفحة المُعادة.
            onPressed: () async {
              final page = await Navigator.push<int>(
                context,
                MaterialPageRoute(builder: (_) => const IndexScreen()),
              );
              if (page != null && context.mounted) {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => MushafPageScreen(initialPage: page)),
                );
              }
            },
          ),
          IconButton(
            tooltip: 'بحث في كل القرآن',
            icon: const Icon(Icons.travel_explore_outlined),
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const SearchScreen()),
            ),
          ),
          IconButton(
            tooltip: isDark ? 'الوضع النهاري' : 'الوضع الليلي',
            icon: Icon(isDark ? Icons.light_mode_outlined : Icons.dark_mode_outlined),
            onPressed: () => themeController.toggle(),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: AppColors.gold,
        foregroundColor: AppColors.darkGreenBg,
        icon: const Icon(Icons.menu_book),
        label: const Text('صفحات المصحف'),
        onPressed: () async {
          int startPage = 1;
          if (_lastRead != null) {
            startPage = await _service.getAyahPage(_lastRead!.suraNo, _lastRead!.ayaNo);
          }
          if (!mounted) return;
          Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => MushafPageScreen(initialPage: startPage)),
          );
        },
      ),
      body: Column(
        children: [
          _buildLogo(context),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
            child: TextField(
              textAlign: TextAlign.right,
              decoration: InputDecoration(
                hintText: 'ابحث عن سورة...',
                prefixIcon: const Icon(Icons.search),
                filled: true,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(18),
                  borderSide: BorderSide(color: AppColors.gold.withOpacity(0.4)),
                ),
              ),
              onChanged: (v) => setState(() => _query = v.trim()),
            ),
          ),
          if (_lastRead != null) _buildContinueReadingCard(context),
          const Divider(height: 1),
          Expanded(
            child: FutureBuilder<List<LocalSurahInfo>>(
              future: _surahsFuture,
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }
                if (snapshot.hasError) {
                  return Center(child: Text('خطأ: ${snapshot.error}'));
                }
                var surahs = snapshot.data!;
                if (_query.isNotEmpty) {
                  surahs = surahs
                      .where((s) =>
                          s.nameAr.contains(_query) ||
                          s.nameEn.toLowerCase().contains(_query.toLowerCase()))
                      .toList();
                }
                return ListView.separated(
                  itemCount: surahs.length,
                  separatorBuilder: (_, __) => const Divider(height: 1),
                  itemBuilder: (context, index) {
                    final surah = surahs[index];
                    return ListTile(
                      leading: CircleAvatar(
                        backgroundColor: AppColors.gold.withOpacity(0.15),
                        child: Text('${surah.number}',
                            style: const TextStyle(color: AppColors.gold)),
                      ),
                      title: Text(surah.nameAr,
                          textAlign: TextAlign.right,
                          style: const TextStyle(
                              fontSize: 18, fontWeight: FontWeight.bold)),
                      subtitle: Text(
                        '${surah.ayahCount} آية • صفحة ${surah.firstPage}',
                        textAlign: TextAlign.right,
                      ),
                      onTap: () async {
                        await Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => MushafPageScreen(
                              initialPage: surah.firstPage,
                            ),
                          ),
                        );
                        _loadLastRead();
                      },
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLogo(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 12, bottom: 4),
      child: Container(
        width: 96,
        height: 96,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          border: Border.all(color: AppColors.gold, width: 2),
          color: Theme.of(context).colorScheme.surface,
        ),
        alignment: Alignment.center,
        child: const Icon(Icons.menu_book, color: AppColors.gold, size: 40),
      ),
    );
  }

  Widget _buildContinueReadingCard(BuildContext context) {
    final last = _lastRead!;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      child: InkWell(
        borderRadius: BorderRadius.circular(18),
        onTap: () async {
          final page = await _service.getAyahPage(last.suraNo, last.ayaNo);
          if (!mounted) return;
          await Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => MushafPageScreen(initialPage: page),
            ),
          );
          _loadLastRead();
        },
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: AppColors.gold.withOpacity(0.5)),
            color: AppColors.gold.withOpacity(0.08),
          ),
          child: Row(
            children: [
              const Icon(Icons.bookmark, color: AppColors.gold),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  'متابعة القراءة: ${last.suraName} - آية ${last.ayaNo}',
                  textAlign: TextAlign.right,
                ),
              ),
              const Icon(Icons.chevron_left),
            ],
          ),
        ),
      ),
    );
  }
}
