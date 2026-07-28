import 'package:flutter/material.dart';
import 'package:just_audio/just_audio.dart';
import '../models/local_ayah.dart';
import '../models/reciter.dart';
import '../services/bookmark_service.dart';
import '../services/quran_local_service.dart';
import '../services/settings_service.dart';
import '../theme/app_theme.dart';
import '../widgets/tafsir_sheet.dart';

const int kMushafPageCount = 604;

/// عرض صفحات مصحف المدينة الحقيقية (صور KFGQPC الرسمية) صفحة بصفحة،
/// مع تشغيل التلاوة مباشرة فوق نفس صفحة المصحف الحقيقية (بدون شاشة نصية
/// وسيطة)، وتكبير/تصغير سلس، ووضع قراءة مريحة (إخفاء الأشرطة بلمسة واحدة).
/// هذه هي شاشة القراءة الوحيدة في التطبيق — تطابق شكل المصحف المطبوع تمامًا.
class MushafPageScreen extends StatefulWidget {
  final int initialPage; // رقم الصفحة الفعلي في المصحف (1..604)
  const MushafPageScreen({super.key, this.initialPage = 1});

  @override
  State<MushafPageScreen> createState() => _MushafPageScreenState();
}

class _MushafPageScreenState extends State<MushafPageScreen> {
  final QuranLocalService _service = QuranLocalService();
  final BookmarkService _bookmarkService = BookmarkService();
  final SettingsService _settingsService = SettingsService();
  final AudioPlayer _player = AudioPlayer();
  late final PageController _controller;
  final TransformationController _zoomController = TransformationController();
  late int _currentPage;
  bool _immersive = false;
  // الصور الأصلية تحتوي هامشًا أبيض واسعًا حول الإطار المزخرف (جزء من
  // تصميم الصفحة المطبوعة نفسها)، فنبدأ بتكبير أساسي بسيط (١.٢٥×) يقتطع
  // هذا الهامش الفارغ فقط، بحيث يملأ إطار المصحف الشاشة بشكل متوازن
  // دون المساس بالنص أو الزخرفة نفسها.
  static const double _baseZoom = 1.25;
  double _zoomScale = _baseZoom;
  static const double _minZoom = _baseZoom;
  static const double _maxZoom = 4.0;

  Reciter _reciter = Reciters.defaultReciter;
  LocalSurahInfo? _currentSurah;
  List<LocalAyah> _currentSurahAyahs = [];
  int? _playingIndex;
  bool _isPlaying = false;
  bool _repeatOne = false;
  bool _loadingSurah = false;

  @override
  void initState() {
    super.initState();
    _currentPage = widget.initialPage.clamp(1, kMushafPageCount);
    // الصفحة 1 تبدأ يمين الكتاب؛ نستخدم فهرسة عكسية بحيث السحب لليمين
    // (المتوافق مع اتجاه القراءة العربية) ينقل لصفحة تالية أكبر رقمًا.
    _controller = PageController(initialPage: kMushafPageCount - _currentPage);
    _settingsService.getSelectedReciter().then((r) {
      if (mounted) setState(() => _reciter = r);
    });
    _loadSurahForCurrentPage();
    // نطبّق التكبير الأساسي على أول صفحة تُعرض أيضًا (وليس فقط عند التنقل).
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _setZoom(_baseZoom);
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    _zoomController.dispose();
    _player.dispose();
    super.dispose();
  }

  void _toggleImmersive() => setState(() => _immersive = !_immersive);

  /// يكبّر/يصغّر صفحة المصحف حول مركز الشاشة (وليس فقط بالقرص/التصغير باليد).
  void _setZoom(double newScale) {
    final clamped = newScale.clamp(_minZoom, _maxZoom);
    final size = MediaQuery.of(context).size;
    final dx = size.width / 2 * (1 - clamped);
    final dy = size.height / 2 * (1 - clamped);
    _zoomController.value = Matrix4.identity()
      ..translate(dx, dy)
      ..scale(clamped);
    setState(() => _zoomScale = clamped);
  }

  void _zoomIn() => _setZoom(_zoomScale + 0.5);
  void _zoomOut() => _setZoom(_zoomScale - 0.5);

  /// يرجع للتكبير الأساسي (وليس 1.0) حتى تبقى الصفحة مملوءة ومتوازنة
  /// مع الشاشة دون الهامش الأبيض الزائد حول إطار المصحف.
  void _resetZoom() {
    if (mounted) {
      setState(() => _zoomScale = _baseZoom);
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _setZoom(_baseZoom);
      });
    }
  }

  Future<void> _loadSurahForCurrentPage() async {
    final surah = await _service.getSurahAtPage(_currentPage);
    if (!mounted) return;
    if (_currentSurah?.number == surah.number) return;
    setState(() => _loadingSurah = true);
    final ayahs = await _service.getSurahAyahs(surah.number);
    if (!mounted) return;
    setState(() {
      _currentSurah = surah;
      _currentSurahAyahs = ayahs;
      _loadingSurah = false;
    });
  }

  void _onPageChanged(int index) {
    setState(() => _currentPage = kMushafPageCount - index);
    _resetZoom(); // نعيد التكبير للوضع الطبيعي عند الانتقال لصفحة جديدة لوضوح أفضل
    _loadSurahForCurrentPage();
  }

  Future<void> _goToPage(int page) async {
    final target = page.clamp(1, kMushafPageCount);
    await _controller.animateToPage(
      kMushafPageCount - target,
      duration: const Duration(milliseconds: 350),
      curve: Curves.easeInOut,
    );
  }

  Future<void> _playIndex(int index) async {
    if (index < 0 || index >= _currentSurahAyahs.length) return;
    final ayah = _currentSurahAyahs[index];
    setState(() {
      _playingIndex = index;
      _isPlaying = true;
    });
    _bookmarkService.saveLastRead(ayah.suraNo, ayah.ayaNo, ayah.suraNameAr);
    // إذا كانت الآية في صفحة مختلفة عن الصفحة المعروضة، ننتقل إليها تلقائيًا.
    if (ayah.page != _currentPage) {
      _goToPage(ayah.page);
    }
    try {
      await _player.setUrl(_reciter.audioUrl(ayah.suraNo, ayah.ayaNo));
      _player.play();
      _player.playerStateStream.listen((state) {
        if (state.processingState == ProcessingState.completed && mounted) {
          if (_repeatOne && _playingIndex != null) {
            _playIndex(_playingIndex!);
          } else if (_playingIndex != null &&
              _playingIndex! < _currentSurahAyahs.length - 1) {
            _playIndex(_playingIndex! + 1);
          } else {
            setState(() {
              _isPlaying = false;
              _playingIndex = null;
            });
          }
        }
      });
    } catch (_) {
      if (mounted) setState(() => _isPlaying = false);
    }
  }

  Future<void> _togglePlayPause() async {
    if (_playingIndex != null && _isPlaying) {
      await _player.pause();
      setState(() => _isPlaying = false);
    } else if (_playingIndex != null && !_isPlaying) {
      await _player.play();
      setState(() => _isPlaying = true);
    } else {
      // أول ضغط: نبدأ من أول آية موجودة في الصفحة المعروضة حاليًا.
      final startIndex = _currentSurahAyahs.indexWhere((a) => a.page == _currentPage);
      _playIndex(startIndex == -1 ? 0 : startIndex);
    }
  }

  void _next() {
    final i = _playingIndex ?? -1;
    if (i + 1 < _currentSurahAyahs.length) _playIndex(i + 1);
  }

  void _previous() {
    final i = _playingIndex ?? 0;
    if (i - 1 >= 0) _playIndex(i - 1);
  }

  Future<void> _stop() async {
    await _player.stop();
    setState(() {
      _isPlaying = false;
      _playingIndex = null;
    });
  }

  void _openTafsir() {
    final ayah = _playingIndex != null && _playingIndex! < _currentSurahAyahs.length
        ? _currentSurahAyahs[_playingIndex!]
        : (_currentSurahAyahs.isNotEmpty
            ? _currentSurahAyahs.firstWhere((a) => a.page == _currentPage,
                orElse: () => _currentSurahAyahs.first)
            : null);
    if (ayah == null) return;
    showTafsirSheet(context, ayah.suraNo, ayah.ayaNo, ayah.ayaTextEmlaey);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.creamPage,
      extendBodyBehindAppBar: true,
      body: Stack(
        children: [
          // SafeArea هنا ضروري: بدونها كانت حواف الصفحة العلوية/السفلية
          // تُرسم خلف النوتش/مؤشر الهوم فتختفي جزئيًا. بهذا تظهر الصفحة
          // كاملة وواضحة داخل المساحة المرئية الفعلية للشاشة.
          SafeArea(
            child: PageView.builder(
              controller: _controller,
              reverse: true, // ليتوافق اتجاه السحب مع ترقيم صفحات المصحف
              itemCount: kMushafPageCount,
              onPageChanged: _onPageChanged,
              itemBuilder: (context, index) {
                final pageNumber = kMushafPageCount - index;
                return GestureDetector(
                  onTap: _toggleImmersive,
                  child: Padding(
                    padding: const EdgeInsets.only(top: 18, bottom: 14),
                    child: LayoutBuilder(
                      builder: (context, constraints) {
                        return InteractiveViewer(
                          transformationController: _zoomController,
                          minScale: _minZoom,
                          maxScale: _maxZoom,
                          onInteractionEnd: (_) {
                            final s = _zoomController.value.getMaxScaleOnAxis();
                            if (mounted) setState(() => _zoomScale = s);
                          },
                          boundaryMargin: const EdgeInsets.symmetric(horizontal: 200),
                          child: Center(
                            child: Image.asset(
                              'assets/mushaf_pages/$pageNumber.jpg',
                              fit: BoxFit.fitHeight,
                              height: constraints.maxHeight,
                              filterQuality: FilterQuality.high,
                              isAntiAlias: true,
                              gaplessPlayback: true,
                              errorBuilder: (context, error, stack) => const Center(
                                child: Text('تعذر تحميل الصفحة',
                                    style: TextStyle(color: AppColors.inkGreen)),
                              ),
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                );
              },
            ),
          ),
          if (!_immersive) _buildTopBar(context),
          if (!_immersive) _buildPlayerBar(context),
        ],
      ),
    );
  }

  Widget _buildTopBar(BuildContext context) {
    return Positioned(
      top: 0,
      left: 0,
      right: 0,
      child: SafeArea(
        bottom: false,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            color: AppColors.inkGreen.withOpacity(0.92),
          ),
          child: Row(
            children: [
              IconButton(
                tooltip: 'تفسير الآية الحالية',
                icon: const Icon(Icons.menu_book_outlined, color: AppColors.gold),
                onPressed: _openTafsir,
              ),
              IconButton(
                tooltip: 'تصغير الصفحة',
                icon: Icon(Icons.zoom_out,
                    color: _zoomScale > _minZoom
                        ? AppColors.gold
                        : AppColors.gold.withOpacity(0.35)),
                onPressed: _zoomScale > _minZoom ? _zoomOut : null,
              ),
              IconButton(
                tooltip: 'تكبير الصفحة',
                icon: Icon(Icons.zoom_in,
                    color: _zoomScale < _maxZoom
                        ? AppColors.gold
                        : AppColors.gold.withOpacity(0.35)),
                onPressed: _zoomScale < _maxZoom ? _zoomIn : null,
              ),
              Text(
                _reciter.nameAr,
                style: const TextStyle(color: AppColors.cream, fontSize: 13),
              ),
              const Spacer(),
              Text(
                _loadingSurah ? '...' : (_currentSurah?.nameAr ?? ''),
                style: const TextStyle(
                  color: AppColors.gold,
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(width: 6),
              Text(
                'صفحة $_currentPage',
                style: const TextStyle(color: AppColors.cream, fontSize: 12),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPlayerBar(BuildContext context) {
    return Positioned(
      left: 0,
      right: 0,
      bottom: 0,
      child: SafeArea(
        top: false,
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
          decoration: BoxDecoration(
            color: AppColors.inkGreen.withOpacity(0.92),
            border: Border(top: BorderSide(color: AppColors.gold.withOpacity(0.4))),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              IconButton(
                tooltip: 'إيقاف',
                icon: const Icon(Icons.stop_circle_outlined, color: AppColors.gold),
                onPressed: _stop,
              ),
              IconButton(
                icon: const Icon(Icons.skip_previous, color: AppColors.gold, size: 30),
                onPressed: _previous,
              ),
              const SizedBox(width: 8),
              Container(
                decoration: const BoxDecoration(shape: BoxShape.circle, color: AppColors.gold),
                child: IconButton(
                  icon: Icon(_isPlaying ? Icons.pause : Icons.play_arrow,
                      color: AppColors.darkGreenBg, size: 32),
                  onPressed: _togglePlayPause,
                ),
              ),
              const SizedBox(width: 8),
              IconButton(
                icon: const Icon(Icons.skip_next, color: AppColors.gold, size: 30),
                onPressed: _next,
              ),
              IconButton(
                tooltip: 'تكرار الآية',
                icon: Icon(Icons.repeat_one,
                    color: _repeatOne ? AppColors.gold : AppColors.gold.withOpacity(0.4)),
                onPressed: () => setState(() => _repeatOne = !_repeatOne),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
