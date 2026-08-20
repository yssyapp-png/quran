import 'package:flutter/material.dart';
import '../models/bookmark.dart';
import '../models/local_ayah.dart';
import '../services/bookmark_service.dart';
import '../services/quran_local_service.dart';
import '../theme/app_theme.dart';
import '../theme/theme_controller.dart';
import 'index_screen.dart';
import 'library_screen.dart';
import 'mushaf_page_screen.dart';
import 'search_screen.dart';
import 'settings_screen.dart';

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

  Future<void> _openIndex() async {
    final page = await Navigator.push<int>(
      context,
      MaterialPageRoute(builder: (_) => const IndexScreen()),
    );
    if (page != null && mounted) {
      await Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => MushafPageScreen(initialPage: page)),
      );
      _loadLastRead();
    }
  }

  Future<void> _openReader() async {
    var startPage = 1;
    if (_lastRead != null) {
      startPage = await _service.getAyahPage(
        _lastRead!.suraNo,
        _lastRead!.ayaNo,
      );
    }
    if (!mounted) return;
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => MushafPageScreen(initialPage: startPage),
      ),
    );
    _loadLastRead();
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
            onPressed: _openIndex,
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
            icon: Icon(
              isDark ? Icons.light_mode_outlined : Icons.dark_mode_outlined,
            ),
            onPressed: () => themeController.toggle(),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: Theme.of(context).colorScheme.primary,
        foregroundColor: Theme.of(context).colorScheme.onPrimary,
        icon: const Icon(Icons.menu_book),
        label: const Text('صفحات المصحف'),
        onPressed: _openReader,
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: 0,
        onDestinationSelected: (index) {
          if (index == 1) _openIndex();
          if (index == 2) {
            Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const LibraryScreen()),
            );
          }
          if (index == 3) {
            Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const SettingsScreen()),
            );
          }
        },
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.home_outlined),
            selectedIcon: Icon(Icons.home_rounded),
            label: 'الرئيسية',
          ),
          NavigationDestination(
            icon: Icon(Icons.format_list_bulleted_rounded),
            label: 'الفهرس',
          ),
          NavigationDestination(
            icon: Icon(Icons.bookmark_border_rounded),
            label: 'المكتبة',
          ),
          NavigationDestination(
            icon: Icon(Icons.tune_rounded),
            label: 'الإعدادات',
          ),
        ],
      ),
      body: Column(
        children: [
          _buildReadingHero(context),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              children: [
                Expanded(
                  child: _QuickAction(
                    icon: Icons.grid_view_rounded,
                    title: 'فهرس المصحف',
                    subtitle: 'السور والأجزاء',
                    onTap: _openIndex,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _QuickAction(
                    icon: Icons.manage_search_rounded,
                    title: 'البحث',
                    subtitle: 'في كامل القرآن',
                    onTap: () => Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => const SearchScreen()),
                    ),
                  ),
                ),
              ],
            ),
          ),
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
                  borderSide: BorderSide(
                    color: AppColors.gold.withValues(alpha: 0.4),
                  ),
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
                      .where(
                        (s) =>
                            s.nameAr.contains(_query) ||
                            s.nameEn.toLowerCase().contains(
                                  _query.toLowerCase(),
                                ),
                      )
                      .toList();
                }
                return ListView.separated(
                  itemCount: surahs.length,
                  separatorBuilder: (_, __) => const Divider(height: 1),
                  itemBuilder: (context, index) {
                    final surah = surahs[index];
                    return ListTile(
                      leading: CircleAvatar(
                        backgroundColor: AppColors.gold.withValues(alpha: 0.15),
                        child: Text(
                          '${surah.number}',
                          style: const TextStyle(color: AppColors.gold),
                        ),
                      ),
                      title: Text(
                        surah.nameAr,
                        textAlign: TextAlign.right,
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      subtitle: Text(
                        '${surah.ayahCount} آية • صفحة ${surah.firstPage}',
                        textAlign: TextAlign.right,
                      ),
                      onTap: () async {
                        await Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) =>
                                MushafPageScreen(initialPage: surah.firstPage),
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

  Widget _buildReadingHero(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.fromLTRB(16, 8, 16, 14),
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(28),
        gradient: LinearGradient(
          begin: Alignment.topRight,
          end: Alignment.bottomLeft,
          colors: [colors.primary, colors.tertiary],
        ),
      ),
      child: Row(
        children: [
          const Icon(Icons.auto_stories_rounded, color: Colors.white, size: 42),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'تابع القراءة',
                  style: TextStyle(color: Colors.white70),
                ),
                const SizedBox(height: 4),
                Text(
                  _lastRead == null
                      ? 'ابدأ من سورة الفاتحة'
                      : '${_lastRead!.suraName} • آية ${_lastRead!.ayaNo}',
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        color: Colors.white,
                        fontWeight: FontWeight.w700,
                      ),
                ),
              ],
            ),
          ),
          FilledButton.tonal(
            onPressed: _openReader,
            child: const Icon(Icons.arrow_back_rounded),
          ),
        ],
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
          if (!context.mounted) return;
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
            border: Border.all(color: AppColors.gold.withValues(alpha: 0.5)),
            color: AppColors.gold.withValues(alpha: 0.08),
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

class _QuickAction extends StatelessWidget {
  const _QuickAction({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Row(
            children: [
              Icon(icon, color: Theme.of(context).colorScheme.primary),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title, style: Theme.of(context).textTheme.titleSmall),
                    Text(
                      subtitle,
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
