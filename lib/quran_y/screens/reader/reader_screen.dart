import 'package:flutter/material.dart';

import '../../core/constants/app_constants.dart';
import '../../core/constants/quran_index.dart';
import '../../core/state/app_state.dart';
import '../../services/quran_text_service.dart';
import '../../services/quran_audio_service.dart';
import '../../services/tafsir_service.dart';
import '../../widgets/mushaf_page.dart';
import '../../widgets/page_ayahs_sheet.dart';
import '../../widgets/reader_side_panel.dart';
import '../../widgets/tafsir_sheet.dart';
import '../settings/settings_screen.dart';

class ReaderScreen extends StatefulWidget {
  const ReaderScreen({required this.appState, this.initialPage = 1, super.key});

  final AppState appState;
  final int initialPage;

  @override
  State<ReaderScreen> createState() => _ReaderScreenState();
}

class _ReaderScreenState extends State<ReaderScreen> {
  late final PageController _pageController;
  final QuranTextService _quranTextService = QuranTextService();
  final TafsirService _tafsirService = TafsirService();
  late final QuranAudioService _audioService;
  late int _currentPage;
  bool _controlsVisible = true;
  ReaderPanel _openPanel = ReaderPanel.none;

  @override
  void initState() {
    super.initState();
    _currentPage = widget.initialPage.clamp(1, AppConstants.mushafPageCount);
    _pageController = PageController(initialPage: _currentPage - 1);
    _audioService = QuranAudioService(onPageStarted: _followAudioPage);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      widget.appState.updateLastReadPage(_currentPage);
    });
  }

  @override
  void dispose() {
    _pageController.dispose();
    _quranTextService.close();
    _tafsirService.close();
    _audioService.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: isDark ? Colors.black : const Color(0xFFEAE4D9),
        body: Stack(
          children: [
            GestureDetector(
              behavior: HitTestBehavior.translucent,
              onTap: () => setState(() => _controlsVisible = !_controlsVisible),
              child: PageView.builder(
                controller: _pageController,
                itemCount: AppConstants.mushafPageCount,
                onPageChanged: _onPageChanged,
                itemBuilder: (context, index) =>
                    MushafPage(pageNumber: index + 1, darkMode: isDark),
              ),
            ),
            AnimatedPositionedDirectional(
              duration: const Duration(milliseconds: 220),
              curve: Curves.easeOut,
              top: _controlsVisible ? 0 : -120,
              start: 0,
              end: 0,
              child: _ReaderTopBar(
                isDark: isDark,
                onIndex: () => _showPanel(ReaderPanel.surahs),
                onMushaf: () => setState(() => _controlsVisible = false),
                onSearch: _showSearch,
                onCopy: _showPageAyahs,
                onTheme: () => widget.appState.setThemeMode(
                  isDark ? ThemeMode.light : ThemeMode.dark,
                ),
                onMore: _showMore,
              ),
            ),
            AnimatedPositionedDirectional(
              duration: const Duration(milliseconds: 220),
              curve: Curves.easeOut,
              bottom: _controlsVisible ? 0 : -210,
              start: 0,
              end: 0,
              child: _ReaderBottomBar(
                pageNumber: _currentPage,
                audioService: _audioService,
                onPrevious: () => _playAdjacentPage(-1),
                onNext: () => _playAdjacentPage(1),
                onSettings: _openSettings,
                onKhatmaPlan: _showKhatmaPlan,
                onTafsir: _showTafsir,
                onLibrary: () => _showPanel(ReaderPanel.surahs),
              ),
            ),
            if (_openPanel != ReaderPanel.none)
              ReaderSidePanel(
                panel: _openPanel,
                currentPage: _currentPage,
                onSelectPage: _selectFromPanel,
                onClose: _closePanel,
              ),
          ],
        ),
      ),
    );
  }

  void _onPageChanged(int index) {
    final page = index + 1;
    setState(() => _currentPage = page);
    widget.appState.updateLastReadPage(page);
  }

  void _followAudioPage(int page) {
    if (!mounted || page == _currentPage || !_pageController.hasClients) return;
    _pageController.animateToPage(
      page - 1,
      duration: const Duration(milliseconds: 320),
      curve: Curves.easeOutCubic,
    );
  }

  Future<void> _playAdjacentPage(int offset) async {
    final target = (_currentPage + offset).clamp(
      1,
      AppConstants.mushafPageCount,
    );
    if (target == _currentPage) return;

    await _audioService.stop();
    await _pageController.animateToPage(
      target - 1,
      duration: const Duration(milliseconds: 280),
      curve: Curves.easeOutCubic,
    );
    if (mounted) await _audioService.togglePage(target);
  }

  Future<void> _openSettings() async {
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => SettingsScreen(appState: widget.appState),
      ),
    );
  }

  Future<void> _showKhatmaPlan() async {
    await showModalBottomSheet<void>(
      context: context,
      useSafeArea: true,
      showDragHandle: true,
      builder: (context) => _KhatmaPlanSheet(currentPage: _currentPage),
    );
  }

  Future<void> _showTafsir() async {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: false,
      builder: (context) => TafsirSheet(
        pageNumber: _currentPage,
        tafsirService: _tafsirService,
        quranTextService: _quranTextService,
      ),
    );
  }

  void _showPageAyahs() {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: false,
      builder: (_) =>
          PageAyahsSheet(pageNumber: _currentPage, service: _quranTextService),
    );
  }

  Future<void> _showSearch() async {
    final page = await showModalBottomSheet<int>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (_) => const _ReaderSearchSheet(),
    );
    if (page != null && mounted) _selectFromPanel(page);
  }

  Future<void> _showMore() async {
    final action = await showModalBottomSheet<_MoreAction>(
      context: context,
      useSafeArea: true,
      showDragHandle: true,
      builder: (context) => _ReaderMoreSheet(
        bookmarked: widget.appState.isBookmarked(_currentPage),
      ),
    );
    if (!mounted || action == null) return;

    switch (action) {
      case _MoreAction.surahIndex:
        _showPanel(ReaderPanel.surahs);
      case _MoreAction.juz:
        _showPanel(ReaderPanel.juz);
      case _MoreAction.hizb:
        await _showHizbDetails();
      case _MoreAction.bookmark:
        setState(() => widget.appState.toggleBookmark(_currentPage));
      case _MoreAction.settings:
        await Navigator.of(context).push(
          MaterialPageRoute<void>(
            builder: (_) => SettingsScreen(appState: widget.appState),
          ),
        );
    }
  }

  Future<void> _showHizbDetails() async {
    final openJuz = await showModalBottomSheet<bool>(
      context: context,
      useSafeArea: true,
      showDragHandle: true,
      builder: (context) => Directionality(
        textDirection: TextDirection.rtl,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 28),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.brightness_4_rounded, size: 42),
              const SizedBox(height: 10),
              Text('الحزب', style: Theme.of(context).textTheme.titleLarge),
              const SizedBox(height: 8),
              Text(
                'الصفحة الحالية ضمن الجزء ${QuranIndex.juzNames[QuranIndex.juzForPage(_currentPage) - 1]}',
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 18),
              FilledButton.icon(
                onPressed: () => Navigator.pop(context, true),
                icon: const Icon(Icons.auto_stories_rounded),
                label: const Text('فتح قائمة الأجزاء'),
              ),
            ],
          ),
        ),
      ),
    );
    if (openJuz == true && mounted) _showPanel(ReaderPanel.juz);
  }

  void _showPanel(ReaderPanel panel) {
    setState(() {
      _openPanel = panel;
      _controlsVisible = false;
    });
  }

  void _closePanel() {
    setState(() => _openPanel = ReaderPanel.none);
  }

  void _selectFromPanel(int page) {
    setState(() {
      _openPanel = ReaderPanel.none;
      _currentPage = page;
    });
    widget.appState.updateLastReadPage(page);
    _pageController.jumpToPage(page - 1);
  }
}

class _ReaderTopBar extends StatelessWidget {
  const _ReaderTopBar({
    required this.isDark,
    required this.onIndex,
    required this.onMushaf,
    required this.onSearch,
    required this.onCopy,
    required this.onTheme,
    required this.onMore,
  });

  final bool isDark;
  final VoidCallback onIndex;
  final VoidCallback onMushaf;
  final VoidCallback onSearch;
  final VoidCallback onCopy;
  final VoidCallback onTheme;
  final VoidCallback onMore;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: MediaQuery.sizeOf(context).width,
      padding: EdgeInsets.fromLTRB(
        6,
        MediaQuery.paddingOf(context).top + 5,
        6,
        7,
      ),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface.withValues(alpha: 0.96),
        boxShadow: const [BoxShadow(color: Colors.black12, blurRadius: 14)],
      ),
      child: Row(
        children: [
          _TopAction(
            label: 'الفهرس',
            icon: Icons.format_list_bulleted_rounded,
            onTap: onIndex,
          ),
          _TopAction(
            label: 'المصحف',
            icon: Icons.menu_book_rounded,
            onTap: onMushaf,
          ),
          _TopAction(
            label: 'البحث',
            icon: Icons.search_rounded,
            onTap: onSearch,
          ),
          _TopAction(
            label: 'النسخ',
            icon: Icons.content_copy_rounded,
            onTap: onCopy,
          ),
          _TopAction(
            label: isDark ? 'نهاري' : 'ليلي',
            icon: isDark ? Icons.light_mode_rounded : Icons.dark_mode_rounded,
            onTap: onTheme,
          ),
          _TopAction(
            label: 'المزيد',
            icon: Icons.more_horiz_rounded,
            onTap: onMore,
          ),
        ],
      ),
    );
  }
}

class _TopAction extends StatelessWidget {
  const _TopAction({
    required this.label,
    required this.icon,
    required this.onTap,
  });

  final String label;
  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Expanded(
      child: Semantics(
        button: true,
        label: label,
        child: Material(
          color: Colors.transparent,
          borderRadius: BorderRadius.circular(14),
          child: InkWell(
            borderRadius: BorderRadius.circular(14),
            onTap: onTap,
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 5),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(icon, size: 22, color: colors.primary),
                  const SizedBox(height: 3),
                  Text(
                    label,
                    maxLines: 1,
                    overflow: TextOverflow.fade,
                    softWrap: false,
                    style: Theme.of(context).textTheme.labelSmall?.copyWith(
                          fontSize: 10,
                          fontWeight: FontWeight.w700,
                        ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

enum _MoreAction { surahIndex, juz, hizb, bookmark, settings }

class _ReaderMoreSheet extends StatelessWidget {
  const _ReaderMoreSheet({required this.bookmarked});

  final bool bookmarked;

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.format_list_bulleted_rounded),
              title: const Text('فهرس السور'),
              onTap: () => Navigator.pop(context, _MoreAction.surahIndex),
            ),
            ListTile(
              leading: const Icon(Icons.auto_stories_rounded),
              title: const Text('أجزاء المصحف'),
              onTap: () => Navigator.pop(context, _MoreAction.juz),
            ),
            ListTile(
              leading: const Text('۞', style: TextStyle(fontSize: 25)),
              title: const Text('الحزب'),
              onTap: () => Navigator.pop(context, _MoreAction.hizb),
            ),
            ListTile(
              leading: Icon(
                bookmarked
                    ? Icons.bookmark_remove_rounded
                    : Icons.bookmark_add_rounded,
              ),
              title: Text(bookmarked ? 'إزالة العلامة' : 'حفظ علامة الصفحة'),
              onTap: () => Navigator.pop(context, _MoreAction.bookmark),
            ),
            ListTile(
              leading: const Icon(Icons.settings_rounded),
              title: const Text('الإعدادات'),
              onTap: () => Navigator.pop(context, _MoreAction.settings),
            ),
          ],
        ),
      ),
    );
  }
}

class _ReaderSearchSheet extends StatefulWidget {
  const _ReaderSearchSheet();

  @override
  State<_ReaderSearchSheet> createState() => _ReaderSearchSheetState();
}

class _ReaderSearchSheetState extends State<_ReaderSearchSheet> {
  String _query = '';

  @override
  Widget build(BuildContext context) {
    final normalized = _query.replaceFirst('سورة', '').trim();
    final requestedPage = int.tryParse(normalized);
    final surahs = QuranIndex.surahs.where((surah) {
      return normalized.isEmpty ||
          surah.name.contains(normalized) ||
          surah.number.toString() == normalized;
    }).toList();
    final validPage = requestedPage != null &&
        requestedPage >= 1 &&
        requestedPage <= AppConstants.mushafPageCount;

    return Directionality(
      textDirection: TextDirection.rtl,
      child: DraggableScrollableSheet(
        expand: false,
        initialChildSize: 0.72,
        minChildSize: 0.42,
        maxChildSize: 0.92,
        builder: (context, scrollController) {
          return Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 14, 16, 10),
                child: SearchBar(
                  hintText: 'ابحث باسم السورة أو رقم الصفحة',
                  leading: const Icon(Icons.search_rounded),
                  onChanged: (value) => setState(() => _query = value),
                ),
              ),
              Expanded(
                child: ListView(
                  controller: scrollController,
                  padding: const EdgeInsets.fromLTRB(12, 0, 12, 24),
                  children: [
                    if (validPage)
                      ListTile(
                        leading: const Icon(Icons.find_in_page_rounded),
                        title: Text('الانتقال إلى صفحة $requestedPage'),
                        onTap: () => Navigator.pop(context, requestedPage),
                      ),
                    ...surahs.map(
                      (surah) => ListTile(
                        leading: CircleAvatar(child: Text('${surah.number}')),
                        title: Text('سورة ${surah.name}'),
                        subtitle: Text(
                          'صفحة ${surah.page}  •  ${surah.revelationSymbol} ${surah.revelationLabel}',
                        ),
                        onTap: () => Navigator.pop(context, surah.page),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _ReaderBottomBar extends StatelessWidget {
  const _ReaderBottomBar({
    required this.pageNumber,
    required this.audioService,
    required this.onPrevious,
    required this.onNext,
    required this.onSettings,
    required this.onKhatmaPlan,
    required this.onTafsir,
    required this.onLibrary,
  });

  final int pageNumber;
  final QuranAudioService audioService;
  final VoidCallback onPrevious;
  final VoidCallback onNext;
  final VoidCallback onSettings;
  final VoidCallback onKhatmaPlan;
  final VoidCallback onTafsir;
  final VoidCallback onLibrary;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: MediaQuery.sizeOf(context).width,
      padding: EdgeInsets.fromLTRB(
        6,
        7,
        6,
        MediaQuery.paddingOf(context).bottom + 7,
      ),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface.withValues(alpha: 0.96),
        boxShadow: const [BoxShadow(color: Colors.black12, blurRadius: 14)],
      ),
      child: ListenableBuilder(
        listenable: audioService,
        builder: (context, child) {
          final active = audioService.playingPage == pageNumber;
          return Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _ReciterControls(
                pageNumber: pageNumber,
                audioService: audioService,
                active: active,
                onPrevious: onPrevious,
                onNext: onNext,
              ),
              const SizedBox(height: 3),
              Row(
                children: [
                  _BottomAction(
                    label: 'الإعدادات',
                    icon: Icons.settings_rounded,
                    onTap: onSettings,
                  ),
                  _BottomAction(
                    label: 'الاستماع',
                    icon: audioService.isLoading && active
                        ? Icons.hourglass_top_rounded
                        : active && audioService.isPlaying
                            ? Icons.pause_circle_rounded
                            : Icons.headphones_rounded,
                    active: active,
                    onTap: () => audioService.togglePage(pageNumber),
                  ),
                  _BottomAction(
                    label: 'ختمة',
                    tooltip: 'خطة الختمة',
                    icon: Icons.calendar_month_rounded,
                    onTap: onKhatmaPlan,
                  ),
                  _BottomAction(
                    label: 'تفسير',
                    icon: Icons.chrome_reader_mode_rounded,
                    onTap: onTafsir,
                  ),
                  _BottomAction(
                    label: 'المكتبة',
                    icon: Icons.local_library_rounded,
                    onTap: onLibrary,
                  ),
                ],
              ),
            ],
          );
        },
      ),
    );
  }
}

class _ReciterControls extends StatelessWidget {
  const _ReciterControls({
    required this.pageNumber,
    required this.audioService,
    required this.active,
    required this.onPrevious,
    required this.onNext,
  });

  final int pageNumber;
  final QuranAudioService audioService;
  final bool active;
  final VoidCallback onPrevious;
  final VoidCallback onNext;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final loading = audioService.isLoading && active;
    final playing = audioService.isPlaying && active;

    return Container(
      height: 48,
      padding: const EdgeInsetsDirectional.only(start: 12, end: 5),
      decoration: BoxDecoration(
        color: colors.surfaceContainerHigh.withValues(alpha: 0.92),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: colors.outlineVariant),
      ),
      child: Row(
        children: [
          Icon(Icons.graphic_eq_rounded, color: colors.primary, size: 22),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  QuranAudioService.reciterName,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(
                    context,
                  ).textTheme.labelLarge?.copyWith(fontWeight: FontWeight.w800),
                ),
                Text(
                  loading ? 'جارٍ تحميل التلاوة…' : 'تلاوة الصفحة $pageNumber',
                  style: Theme.of(context).textTheme.labelSmall?.copyWith(
                        color: colors.onSurfaceVariant,
                        fontSize: 9.5,
                      ),
                ),
              ],
            ),
          ),
          _PlayerIcon(
            tooltip: 'الصفحة السابقة',
            icon: Icons.skip_previous_rounded,
            onPressed: pageNumber > 1 ? onPrevious : null,
          ),
          _PlayerIcon(
            tooltip: playing ? 'إيقاف مؤقت' : 'تشغيل التلاوة',
            icon: loading
                ? Icons.hourglass_top_rounded
                : playing
                    ? Icons.pause_rounded
                    : Icons.play_arrow_rounded,
            emphasized: true,
            onPressed:
                loading ? null : () => audioService.togglePage(pageNumber),
          ),
          _PlayerIcon(
            tooltip: 'إيقاف التلاوة',
            icon: Icons.stop_rounded,
            onPressed:
                audioService.playingPage == null ? null : audioService.stop,
          ),
          _PlayerIcon(
            tooltip: 'الصفحة التالية',
            icon: Icons.skip_next_rounded,
            onPressed:
                pageNumber < AppConstants.mushafPageCount ? onNext : null,
          ),
        ],
      ),
    );
  }
}

class _PlayerIcon extends StatelessWidget {
  const _PlayerIcon({
    required this.tooltip,
    required this.icon,
    required this.onPressed,
    this.emphasized = false,
  });

  final String tooltip;
  final IconData icon;
  final VoidCallback? onPressed;
  final bool emphasized;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return IconButton(
      tooltip: tooltip,
      visualDensity: VisualDensity.compact,
      style: emphasized
          ? IconButton.styleFrom(
              backgroundColor: colors.primary,
              foregroundColor: colors.onPrimary,
            )
          : null,
      onPressed: onPressed,
      icon: Icon(icon, size: emphasized ? 25 : 22),
    );
  }
}

class _BottomAction extends StatelessWidget {
  const _BottomAction({
    required this.label,
    required this.icon,
    required this.onTap,
    this.tooltip,
    this.active = false,
  });

  final String label;
  final String? tooltip;
  final IconData icon;
  final VoidCallback onTap;
  final bool active;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Expanded(
      child: Tooltip(
        message: tooltip ?? label,
        child: Material(
          color: active
              ? colors.primaryContainer.withValues(alpha: 0.82)
              : Colors.transparent,
          borderRadius: BorderRadius.circular(14),
          child: InkWell(
            borderRadius: BorderRadius.circular(14),
            onTap: onTap,
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 6),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    icon,
                    size: 22,
                    color: active ? colors.primary : colors.onSurfaceVariant,
                  ),
                  const SizedBox(height: 3),
                  Text(
                    label,
                    maxLines: 1,
                    overflow: TextOverflow.fade,
                    softWrap: false,
                    style: Theme.of(context).textTheme.labelSmall?.copyWith(
                          fontSize: 9.5,
                          fontWeight: FontWeight.w700,
                        ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _KhatmaPlanSheet extends StatelessWidget {
  const _KhatmaPlanSheet({required this.currentPage});

  final int currentPage;

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text('خطة الختمة', style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 8),
            Text('تبقى ${AppConstants.mushafPageCount - currentPage} صفحة.'),
            const SizedBox(height: 12),
            LinearProgressIndicator(
              value: currentPage / AppConstants.mushafPageCount,
              minHeight: 9,
            ),
            const SizedBox(height: 8),
            Text(
              'أنجزت ${(currentPage / AppConstants.mushafPageCount * 100).toStringAsFixed(1)}٪',
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            for (final days in const [30, 60, 90])
              ListTile(
                leading: const Icon(Icons.calendar_today_rounded),
                title: Text('ختمة خلال $days يومًا'),
                subtitle: Text(
                  '${((AppConstants.mushafPageCount - currentPage) / days).ceil()} صفحات يوميًا',
                ),
              ),
          ],
        ),
      ),
    );
  }
}
