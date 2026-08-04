import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show Clipboard, ClipboardData;
import 'package:just_audio/just_audio.dart';
import '../models/bookmark.dart';
import '../models/local_ayah.dart';
import '../models/reciter.dart';
import '../services/bookmark_service.dart';
import '../services/quran_local_service.dart';
import '../services/settings_service.dart';
import '../theme/app_theme.dart';
import '../theme/theme_controller.dart';
import '../widgets/tafsir_sheet.dart';
import 'downloads_screen.dart';
import 'index_screen.dart';
import 'khatma_screen.dart';
import 'library_screen.dart';
import 'listen_screen.dart';
import 'search_screen.dart';
import 'settings_screen.dart';

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
  // متحكم تحويل (تكبير/تحريك) مستقل لكل صفحة على حدة، بدل متحكم واحد
  // مشترك بين كل الصفحات. المشكلة سابقًا: PageView يُبقي الصفحة الحالية
  // والمجاورة لها محمّلتين في الذاكرة لسلاسة السحب، وكانتا تتشاركان نفس
  // متحكم التحويل، فيصبح تكبير/تصغير أي صفحة يؤثر فورًا على الصفحة
  // المجاورة أيضًا وكأنهما "مرتبطتان معًا". الآن كل رقم صفحة له متحكمه
  // الخاص المنفصل تمامًا عن باقي الصفحات.
  final Map<int, TransformationController> _zoomControllers = {};
  TransformationController _controllerFor(int page) =>
      _zoomControllers.putIfAbsent(page, () => TransformationController());
  late int _currentPage;
  bool _immersive = false;
  // نعرض صورة الصفحة بـ BoxFit.contain داخل SizedBox.expand (أنظر build())،
  // فتُحسب نسبة التكبير المطلوبة لملء أكبر مساحة ممكنة من الشاشة تلقائيًا
  // وبدقة رياضية بحتة اعتمادًا على أبعاد شاشة الجهاز الفعلية — مع إبقاء
  // الصفحة كاملة ظاهرة بدون أي اقتصاص لأطرافها (بخلاف BoxFit.cover الذي
  // يقتطع الأطراف)، وبدون أي انحراف يمين/يسار على أي حجم شاشة.
  // صفحتا الفاتحة وأول البقرة (1 و2) بحاجة لحجم أكبر من بقية الصفحات
  // بمقدار درجة ونصف من درجة التكبير اليدوي (كل درجة = 0.5×، بنفس مقدار
  // أزرار التكبير) بناءً على طلب المستخدم، فتُعرضان أكبر من الباقي افتراضيًا.
  // صُغِّرت باقي صفحات المصحف ربع درجة أخرى (0.0625) من 1.3125 إلى 1.25،
  // مع إبقاء صفحتي الفاتحة وأول البقرة عند 1.75 دون تغيير.
  double _baseZoomFor(int page) => (page == 1 || page == 2) ? 1.75 : 1.25;
  double get _baseZoom => _baseZoomFor(_currentPage);
  double _zoomScale = 1.0;
  // يسمح للمستخدم بتكبير الصفحة يدويًا (بالقرص بإصبعين أو بالأزرار) فوق
  // حالة الملء التلقائي، حتى 4×، وبتصغيرها للحد الأدنى 1× (الملء الكامل
  // نفسه — لا يمكن التصغير أكثر منه حتى لا تظهر فراغات حول الصفحة).
  static const double _minZoom = 1.0;
  static const double _maxZoom = 4.0;

  Reciter _reciter = Reciters.defaultReciter;
  LocalSurahInfo? _currentSurah;
  List<LocalAyah> _currentSurahAyahs = [];
  int? _playingIndex;
  bool _isPlaying = false;
  bool _repeatOne = false;
  bool _loadingSurah = false;
  bool _isBookmarked = false;

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
    for (final c in _zoomControllers.values) {
      c.dispose();
    }
    _player.dispose();
    super.dispose();
  }

  void _toggleImmersive() => setState(() => _immersive = !_immersive);

  /// يكبّر/يصغّر صفحة المصحف حول مركز الشاشة (وليس فقط بالقرص/التصغير باليد).
  /// يعمل دائمًا على متحكم الصفحة الحالية (_currentPage) وحدها، دون التأثير
  /// على أي صفحة أخرى محمّلة بجانبها.
  void _setZoom(double newScale) {
    final clamped = newScale.clamp(_minZoom, _maxZoom);
    final size = MediaQuery.of(context).size;
    final dx = size.width / 2 * (1 - clamped);
    final dy = size.height / 2 * (1 - clamped);
    _controllerFor(_currentPage).value = Matrix4.identity()
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
      // نؤجل التطبيق لما بعد البناء لأن _setZoom يحتاج MediaQuery من context جاهز.
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _setZoom(_baseZoom);
      });
    }
  }

  Future<void> _loadSurahForCurrentPage() async {
    final surah = await _service.getSurahAtPage(_currentPage);
    if (!mounted) return;
    if (_currentSurah?.number == surah.number) {
      _refreshBookmarkState();
      return;
    }
    setState(() => _loadingSurah = true);
    final ayahs = await _service.getSurahAyahs(surah.number);
    if (!mounted) return;
    setState(() {
      _currentSurah = surah;
      _currentSurahAyahs = ayahs;
      _loadingSurah = false;
    });
    _refreshBookmarkState();
  }

  /// الآية "المرجعية" للصفحة الحالية: الآية قيد التشغيل إن وُجدت، وإلا أول
  /// آية في الصفحة المعروضة — تُستخدم لأزرار التفسير والعلامة المرجعية.
  LocalAyah? get _referenceAyah {
    if (_playingIndex != null && _playingIndex! < _currentSurahAyahs.length) {
      return _currentSurahAyahs[_playingIndex!];
    }
    if (_currentSurahAyahs.isEmpty) return null;
    return _currentSurahAyahs.firstWhere((a) => a.page == _currentPage,
        orElse: () => _currentSurahAyahs.first);
  }

  Future<void> _refreshBookmarkState() async {
    final ayah = _referenceAyah;
    if (ayah == null) return;
    final bookmarked = await _bookmarkService.isBookmarked(ayah.suraNo, ayah.ayaNo);
    if (mounted) setState(() => _isBookmarked = bookmarked);
  }

  Future<void> _toggleBookmark() async {
    final ayah = _referenceAyah;
    if (ayah == null) return;
    await _bookmarkService.toggleBookmark(
      Bookmark(suraNo: ayah.suraNo, suraName: ayah.suraNameAr, ayaNo: ayah.ayaNo),
    );
    _refreshBookmarkState();
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
      // نخفي كل الأشرطة والأيقونات تلقائيًا عند بدء التلاوة حتى تبقى صفحة
      // المصحف خالية من أي مشتتات للقارئ أثناء الاستماع؛ لمسة واحدة على
      // الصفحة تعيد إظهارها مؤقتًا عند الحاجة.
      _immersive = true;
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
    final ayah = _referenceAyah;
    if (ayah == null) return;
    showTafsirSheet(context, ayah.suraNo, ayah.ayaNo, ayah.ayaTextEmlaey);
  }

  /// نسخ نص الآية الحالية (المرجعية) للحافظة لمشاركتها في أي تطبيق آخر.
  Future<void> _copyAyahText() async {
    final ayah = _referenceAyah;
    if (ayah == null) return;
    await Clipboard.setData(ClipboardData(
      text: '${ayah.ayaTextEmlaey}\n(${ayah.suraNameAr}: ${ayah.ayaNo})',
    ));
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('تم نسخ نص الآية')),
      );
    }
  }

  /// نافذة سريعة للانتقال المباشر إلى رقم صفحة معيّن.
  Future<void> _showGoToPageDialog() async {
    final fieldController = TextEditingController();
    final result = await showDialog<int>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: AppColors.inkGreen,
        title: const Text('الانتقال إلى صفحة', style: TextStyle(color: AppColors.gold)),
        content: TextField(
          controller: fieldController,
          autofocus: true,
          keyboardType: TextInputType.number,
          style: const TextStyle(color: AppColors.cream),
          decoration: const InputDecoration(
            hintText: '1 - 604',
            hintStyle: TextStyle(color: AppColors.cream),
            enabledBorder: UnderlineInputBorder(borderSide: BorderSide(color: AppColors.gold)),
            focusedBorder: UnderlineInputBorder(borderSide: BorderSide(color: AppColors.gold)),
          ),
          onSubmitted: (v) => Navigator.pop(dialogContext, int.tryParse(v)),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('إلغاء'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, int.tryParse(fieldController.text)),
            child: const Text('انتقال', style: TextStyle(color: AppColors.gold)),
          ),
        ],
      ),
    );
    if (result != null) _goToPage(result);
  }

  /// قائمة "المزيد" السفلية: تجمع الإجراءات الثانوية (تفسير، نسخ، علامة
  /// مرجعية، تكبير/تصغير) بعيدًا عن الشريط العلوي حتى يبقى بسيطًا وواضحًا.
  void _showMoreSheet() {
    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.inkGreen,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (sheetContext) => SafeArea(
        child: Wrap(
          children: [
            ListTile(
              leading: const Icon(Icons.menu_book_outlined, color: AppColors.gold),
              title: const Text('تفسير الآية الحالية', style: TextStyle(color: AppColors.cream)),
              onTap: () {
                Navigator.pop(sheetContext);
                _openTafsir();
              },
            ),
            ListTile(
              leading: Icon(_isBookmarked ? Icons.bookmark : Icons.bookmark_border,
                  color: AppColors.gold),
              title: Text(_isBookmarked ? 'إزالة العلامة المرجعية' : 'إضافة علامة مرجعية',
                  style: const TextStyle(color: AppColors.cream)),
              onTap: () {
                Navigator.pop(sheetContext);
                _toggleBookmark();
              },
            ),
            ListTile(
              leading: const Icon(Icons.copy_outlined, color: AppColors.gold),
              title: const Text('نسخ نص الآية', style: TextStyle(color: AppColors.cream)),
              onTap: () {
                Navigator.pop(sheetContext);
                _copyAyahText();
              },
            ),
            ListTile(
              leading: const Icon(Icons.dialpad, color: AppColors.gold),
              title: const Text('الانتقال إلى صفحة', style: TextStyle(color: AppColors.cream)),
              onTap: () {
                Navigator.pop(sheetContext);
                _showGoToPageDialog();
              },
            ),
            ListTile(
              leading: const Icon(Icons.zoom_in, color: AppColors.gold),
              title: const Text('تكبير الصفحة', style: TextStyle(color: AppColors.cream)),
              enabled: _zoomScale < _maxZoom,
              onTap: () {
                Navigator.pop(sheetContext);
                _zoomIn();
              },
            ),
            ListTile(
              leading: const Icon(Icons.zoom_out, color: AppColors.gold),
              title: const Text('تصغير الصفحة', style: TextStyle(color: AppColors.cream)),
              enabled: _zoomScale > _minZoom,
              onTap: () {
                Navigator.pop(sheetContext);
                _zoomOut();
              },
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    // نجعل خلفية الشاشة تتبع الوضع الليلي/النهاري الحالي بدل تثبيتها دائمًا
    // على البيج (creamPage) — كانت هذه هي المشكلة: تفعيل الوضع الليلي من
    // الإعدادات لم يكن ينعكس على شاشة قراءة المصحف إطلاقًا.
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Scaffold(
      backgroundColor: isDark ? MushafDarkColors.background : AppColors.creamPage,
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
                // نُخفي أي صفحة مجاورة فور بدء الانزلاق الفعلي عنها (بدل تركها
                // تظهر متتابعة نصفين أثناء السحب)، فيبدو التنقل انتقالًا مباشرًا
                // من صفحة كاملة لأخرى كاملة، دون منظر "صفحتين مقسومتين" أثناء
                // تحريك الإصبع. لا نغيّر آلية السحب/اتجاهه نفسها إطلاقًا — فقط
                // نُخفي العرض المرئي للصفحة غير المستقرة على الشاشة حاليًا.
                return AnimatedBuilder(
                  animation: _controller,
                  builder: (context, child) {
                    var isSettledHere = index == (_controller.hasClients
                        ? (_controller.page?.round() ??
                            _controller.initialPage)
                        : _controller.initialPage);
                    if (_controller.hasClients && _controller.page != null) {
                      final distance = (_controller.page! - index).abs();
                      isSettledHere = distance < 0.02;
                    }
                    return Visibility(
                      visible: isSettledHere,
                      maintainState: true,
                      maintainAnimation: true,
                      maintainSize: true,
                      child: child!,
                    );
                  },
                  child: GestureDetector(
                  onTap: _toggleImmersive,
                  child: Padding(
                    // هامش علوي بسيط فقط حتى لا يلامس رأس الصفحة الحافة
                    // المستديرة (النوتش)، مع رفع الصفحة للأعلى قدر الإمكان
                    // (بدل توسيطها رأسيًا) لتقليل الفراغ السفلي الفارغ.
                    padding: const EdgeInsets.only(top: 8, bottom: 4),
                    child: LayoutBuilder(
                      builder: (context, constraints) {
                        return InteractiveViewer(
                          // متحكم مستقل خاص بهذه الصفحة تحديدًا (pageNumber)، حتى
                          // لا يتأثر تكبير/تحريك أي صفحة بأختها المجاورة المحمّلة
                          // بجانبها في PageView (أنظر تعليق _zoomControllers أعلاه).
                          transformationController: _controllerFor(pageNumber),
                          minScale: _minZoom,
                          maxScale: _maxZoom,
                          // نعطّل السحب بإصبع واحد لأنه كان يتعارض مع سحب
                          // التنقل بين الصفحات (PageView) ويسبب خللًا أثناء
                          // التصفح. القرص بإصبعين (Pinch) للتكبير ما زال يعمل
                          // بشكل طبيعي، بالإضافة لأزرار التكبير/التصغير.
                          panEnabled: false,
                          scaleEnabled: true,
                          onInteractionEnd: (_) {
                            final s = _controllerFor(pageNumber).value.getMaxScaleOnAxis();
                            if (mounted && pageNumber == _currentPage) {
                              setState(() => _zoomScale = s);
                            }
                          },
                          boundaryMargin: const EdgeInsets.symmetric(horizontal: 200),
                          child: Align(
                            // نرفع باقي صفحات المصحف درجة بسيطة للأعلى (مع تقليل
                            // التوسيط الرأسي درجة بسيطة أيضًا) لتقليل الفراغ السفلي
                            // الفارغ، مع إبقاء صفحتي الفاتحة وأول البقرة بتوسيطهما
                            // الرأسي الكامل الأصلي دون أي تغيير كما طلب المستخدم.
                            alignment: (pageNumber == 1 || pageNumber == 2)
                                ? Alignment.center
                                : const Alignment(0, -0.1),
                            // BoxFit.contain مع SizedBox.expand أدناه يكبّر الصفحة
                            // تلقائيًا لأقصى حجم ممكن يملأ الشاشة دون قص أي جزء منها،
                            // مع الحفاظ على تناسبها الأصلي (بدون تمديد/تشويه)، وتوسيط
                            // تام عبر Align + مصفوفة تحويل بحالة الهوية عند الراحة —
                            // فلا يحدث أي انحراف نحو اليمين أو اليسار على أي شاشة.
                            child: SizedBox.expand(
                              // بدل الانعكاس اللحظي (ColorFilter) الذي كان يشوّه ألوان
                              // الصفحات المزخرفة، نستخدم الآن صورًا ليلية مُولَّدة مسبقًا
                              // لكل صفحات المصحف الـ604 (ملف "$pageNumber_dark.jpg" لكل
                              // صفحة)، فتظهر بجودة وألوان مضبوطة بدقة في الوضع الليلي دون
                              // أي تأثير جانبي، وتعود صورة النهار الأصلية فورًا عند إيقاف
                              // الوضع الليلي دون فقد أي تفاصيل من الصورة الرسمية المخزّنة.
                              child: Image.asset(
                                isDark
                                    ? 'assets/mushaf_pages/${pageNumber}_dark.jpg'
                                    : 'assets/mushaf_pages/$pageNumber.jpg',
                                fit: BoxFit.contain,
                                // جودة عرض عالية لضمان وضوح رسم الآيات بدون تشويش
                                // عند التكبير، وتفادي وميض إعادة التحميل بين الصفحات.
                                filterQuality: FilterQuality.high,
                                isAntiAlias: true,
                                gaplessPlayback: true,
                                errorBuilder: (context, error, stack) => const Center(
                                  child: Text('تعذر تحميل الصفحة',
                                      style: TextStyle(color: AppColors.inkGreen)),
                                ),
                              ),
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                  ),
                );
              },
            ),
          ),
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: _buildAnimatedBar(alignTop: true, child: _buildTopBar(context)),
          ),
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: _buildAnimatedBar(alignTop: false, child: _buildPlayerBar(context)),
          ),
        ],
      ),
    );
  }

  /// يغلّف الشريط العلوي/السفلي بحركة سلسة (انزلاق + تلاشي) بدل الإخفاء
  /// المفاجئ، وتُعطَّل اللمسات تمامًا أثناء الاختفاء حتى لا تعترض الصفحة.
  Widget _buildAnimatedBar({required bool alignTop, required Widget child}) {
    return IgnorePointer(
      ignoring: _immersive,
      child: AnimatedSlide(
        duration: const Duration(milliseconds: 260),
        curve: Curves.easeOutCubic,
        offset: _immersive ? Offset(0, alignTop ? -1 : 1) : Offset.zero,
        child: AnimatedOpacity(
          duration: const Duration(milliseconds: 200),
          opacity: _immersive ? 0 : 1,
          child: child,
        ),
      ),
    );
  }

  /// زر من أزرار الشريط العلوي الرئيسية (الفهرس/المصحف/البحث/المكتبة/المزيد)
  /// مع تسمية صغيرة تحته وحركة "ضغط" بسيطة (تصغير خفيف) عند اللمس تعطي
  /// إحساسًا حيًا بالاستجابة، ثم تعود لحجمها بحركة نابضة سلسة.
  Widget _topBarAction({
    required String label,
    required IconData icon,
    required VoidCallback onPressed,
    bool active = false,
  }) {
    return _BouncyTapScale(
      onTap: onPressed,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 6),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: active ? AppColors.goldLight : AppColors.gold, size: 22),
            const SizedBox(height: 2),
            Text(
              label,
              style: TextStyle(
                color: active ? AppColors.goldLight : AppColors.cream,
                fontSize: 10,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTopBar(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    // (أُزيلت شارة اسم/رقم السورة أعلى الشاشة بناءً على طلب المستخدم: اسم
    // السورة مدمج بالفعل داخل تصميم صفحة المصحف الرسمية نفسها، فلا داعي
    // لتكراره في شريط علوي منفصل.)
    return SafeArea(
      bottom: false,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
        decoration: BoxDecoration(
          color: isDark ? MushafDarkColors.overlay : AppColors.inkGreen.withOpacity(0.92),
        ),
        child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
            _topBarAction(
              label: 'الفهرس',
              icon: Icons.list_alt_outlined,
              // الفهرس يُعيد رقم الصفحة المختارة عند الضغط على سورة/جزء بدل
              // فتح شاشة قراءة جديدة فوق هذه الشاشة؛ هنا ننتقل مباشرة داخل
              // نفس شاشة المصحف الحالية بدون تكديس شاشات قراءة في السجلّ.
              onPressed: () async {
                final page = await Navigator.push<int>(
                  context,
                  MaterialPageRoute(builder: (_) => const IndexScreen()),
                );
                if (page != null && mounted) _goToPage(page);
              },
            ),
            _topBarAction(
              label: 'المصحف',
              icon: Icons.auto_stories,
              active: true,
              onPressed: () => setState(() => _immersive = false),
            ),
            _topBarAction(
              label: 'البحث',
              icon: Icons.search,
              onPressed: () => Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const SearchScreen()),
              ),
            ),
            _topBarAction(
              label: 'المكتبة',
              icon: Icons.collections_bookmark_outlined,
              onPressed: () => Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const LibraryScreen()),
              ),
            ),
            // زر سريع للتبديل بين الوضع الليلي والنهاري مباشرة من شاشة
            // القراءة نفسها، دون الحاجة للدخول إلى الإعدادات في كل مرة.
            ValueListenableBuilder<ThemeMode>(
              valueListenable: themeController,
              builder: (context, mode, _) => _topBarAction(
                label: mode == ThemeMode.dark ? 'نهاري' : 'ليلي',
                icon: mode == ThemeMode.dark ? Icons.light_mode_outlined : Icons.dark_mode_outlined,
                onPressed: themeController.toggle,
              ),
            ),
            _topBarAction(
              label: 'المزيد',
              icon: Icons.more_horiz,
              onPressed: _showMoreSheet,
            ),
              ],
            ),
      ),
    );
  }

  Widget _buildPlayerBar(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return SafeArea(
        top: false,
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 16),
          decoration: BoxDecoration(
            color: isDark ? MushafDarkColors.overlay : AppColors.inkGreen.withOpacity(0.92),
            border: Border(
                top: BorderSide(
                    color: isDark ? MushafDarkColors.divider : AppColors.gold.withOpacity(0.4))),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // صف ثانٍ من الأيقونات أسفل صفحة المصحف (الإعدادات/استماع/
              // ختمة/التنزيلات/تفسير) — منفصل عن أزرار التشغيل الأساسية
              // وقابل للتمرير الأفقي حتى لا يفيض على الشاشات الضيقة.
              Padding(
                padding: const EdgeInsets.only(bottom: 6),
                child: SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  reverse: true,
                  child: Row(
                    children: [
                      _topBarAction(
                        label: 'الإعدادات',
                        icon: Icons.settings_outlined,
                        onPressed: () => Navigator.push(
                          context,
                          MaterialPageRoute(builder: (_) => const SettingsScreen()),
                        ),
                      ),
                      _topBarAction(
                        label: 'استماع',
                        icon: Icons.headphones_outlined,
                        onPressed: () => Navigator.push(
                          context,
                          MaterialPageRoute(builder: (_) => const ListenScreen()),
                        ),
                      ),
                      _topBarAction(
                        label: 'ختمة',
                        icon: Icons.task_alt_outlined,
                        onPressed: () => Navigator.push(
                          context,
                          MaterialPageRoute(builder: (_) => KhatmaScreen(currentPage: _currentPage)),
                        ),
                      ),
                      _topBarAction(
                        label: 'التنزيلات',
                        icon: Icons.download_outlined,
                        onPressed: () => Navigator.push(
                          context,
                          MaterialPageRoute(builder: (_) => const DownloadsScreen()),
                        ),
                      ),
                      _topBarAction(
                        label: 'تفسير',
                        icon: Icons.menu_book_outlined,
                        onPressed: _openTafsir,
                      ),
                    ],
                  ),
                ),
              ),
              // اسم القارئ الحالي فوق شريط التشغيل مباشرة (كما في تطبيقات
              // القرآن الاحترافية) — اضغط عليه لاختيار قارئ آخر مستقبلًا.
              Padding(
                padding: const EdgeInsets.only(bottom: 2),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.mic_none, color: AppColors.gold, size: 14),
                    const SizedBox(width: 4),
                    Text(
                      _reciter.nameAr,
                      style: const TextStyle(color: AppColors.cream, fontSize: 12),
                    ),
                  ],
                ),
              ),
              Row(
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
            ],
          ),
        ),
    );
  }
}

/// غلاف بسيط يعطي أي زر إحساس "ضغط" حي: يصغّر الزر قليلًا عند لمسه ويعيده
/// لحجمه الطبيعي بحركة نابضة عند الرفع — يُستخدم لأزرار الشريط العلوي
/// الرئيسية (الفهرس/المصحف/البحث/المكتبة/المزيد).
class _BouncyTapScale extends StatefulWidget {
  final Widget child;
  final VoidCallback onTap;
  const _BouncyTapScale({required this.child, required this.onTap});

  @override
  State<_BouncyTapScale> createState() => _BouncyTapScaleState();
}

class _BouncyTapScaleState extends State<_BouncyTapScale> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: widget.onTap,
      onTapDown: (_) => setState(() => _pressed = true),
      onTapUp: (_) => setState(() => _pressed = false),
      onTapCancel: () => setState(() => _pressed = false),
      child: AnimatedScale(
        scale: _pressed ? 0.85 : 1.0,
        duration: const Duration(milliseconds: 120),
        curve: Curves.easeOut,
        child: widget.child,
      ),
    );
  }
}
