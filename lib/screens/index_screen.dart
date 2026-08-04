import 'package:flutter/material.dart';
import '../models/juz.dart';
import '../models/local_ayah.dart';
import '../services/quran_local_service.dart';
import '../theme/app_theme.dart';

/// شاشة الفهرس: تصفح السور أو الأجزاء والانتقال المباشر لموضع القراءة.
///
/// عند الضغط على سورة أو جزء، تُغلق الشاشة نفسها وتُعيد رقم الصفحة المطلوبة
/// عبر [Navigator.pop] بدل فتح شاشة مصحف جديدة فوقها مباشرة. هذا يسمح
/// لمن يفتح الفهرس أثناء القراءة (من داخل صفحة المصحف نفسها) بالانتقال في
/// نفس الشاشة دون تكديس شاشات قراءة فوق بعضها في سجلّ التنقّل، بينما من
/// يفتحه من الشاشة الرئيسية يقرر بنفسه فتح شاشة قراءة جديدة بالرقم المُعاد.
class IndexScreen extends StatefulWidget {
  const IndexScreen({super.key});

  @override
  State<IndexScreen> createState() => _IndexScreenState();
}

class _IndexScreenState extends State<IndexScreen> with SingleTickerProviderStateMixin {
  final QuranLocalService _service = QuranLocalService();
  late final TabController _tabController;
  late Future<List<LocalSurahInfo>> _surahsFuture;
  late Future<List<JuzInfo>> _juzFuture;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _surahsFuture = _service.getSurahList();
    _juzFuture = _service.getJuzList();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _openSurah(int suraNo, {int? scrollToAya}) async {
    final surahs = await _surahsFuture;
    final surah = surahs.firstWhere((s) => s.number == suraNo);
    final page = scrollToAya != null
        ? await _service.getAyahPage(suraNo, scrollToAya)
        : surah.firstPage;
    if (!mounted) return;
    // نغلق شاشة الفهرس ونعيد رقم الصفحة فقط؛ القرار في فتح شاشة قراءة
    // جديدة أو الانتقال داخل الشاشة الحالية يعود للشاشة التي فتحت الفهرس.
    Navigator.pop(context, page);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('الفهرس'),
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: AppColors.gold,
          tabs: const [
            Tab(text: 'السور'),
            Tab(text: 'الأجزاء'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildSurahList(),
          _buildJuzList(),
        ],
      ),
    );
  }

  Widget _buildSurahList() {
    return FutureBuilder<List<LocalSurahInfo>>(
      future: _surahsFuture,
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }
        final surahs = snapshot.data!;
        return ListView.separated(
          itemCount: surahs.length,
          separatorBuilder: (_, __) => const Divider(height: 1),
          itemBuilder: (context, index) {
            final s = surahs[index];
            return ListTile(
              leading: CircleAvatar(
                backgroundColor: AppColors.gold.withOpacity(0.15),
                child: Text('${s.number}', style: const TextStyle(color: AppColors.gold)),
              ),
              title: Text(s.nameAr, textAlign: TextAlign.right),
              subtitle: Text(
                '${s.ayahCount} آية • صفحة ${s.firstPage} • ${s.isMeccan ? "مكية" : "مدنية"}',
                textAlign: TextAlign.right,
              ),
              // رمز الكعبة للسور المكية، ورمز المسجد النبوي للسور المدنية —
              // تمييز بصري سريع لمكان نزول كل سورة أثناء تصفح الفهرس.
              trailing: Text(
                s.isMeccan ? '🕋' : '🕌',
                style: const TextStyle(fontSize: 24),
              ),
              onTap: () => _openSurah(s.number),
            );
          },
        );
      },
    );
  }

  Widget _buildJuzList() {
    return FutureBuilder<List<JuzInfo>>(
      future: _juzFuture,
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }
        final juzList = snapshot.data!;
        return ListView.separated(
          itemCount: juzList.length,
          separatorBuilder: (_, __) => const Divider(height: 1),
          itemBuilder: (context, index) {
            final j = juzList[index];
            return ListTile(
              leading: CircleAvatar(
                backgroundColor: AppColors.gold.withOpacity(0.15),
                child: Text('${j.number}', style: const TextStyle(color: AppColors.gold)),
              ),
              title: Text('الجزء ${j.number}', textAlign: TextAlign.right),
              subtitle: Text(
                'يبدأ من ${j.startSuraName} - آية ${j.startAyaNo} • صفحة ${j.startPage}',
                textAlign: TextAlign.right,
              ),
              onTap: () => _openSurah(j.startSuraNo, scrollToAya: j.startAyaNo),
            );
          },
        );
      },
    );
  }
}
