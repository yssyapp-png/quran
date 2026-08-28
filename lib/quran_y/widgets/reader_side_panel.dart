import 'package:flutter/material.dart';

import '../core/constants/quran_index.dart';

enum ReaderPanel { none, surahs, juz }

class ReaderSidePanel extends StatelessWidget {
  const ReaderSidePanel({
    required this.panel,
    required this.currentPage,
    required this.onSelectPage,
    required this.onClose,
    super.key,
  });

  final ReaderPanel panel;
  final int currentPage;
  final ValueChanged<int> onSelectPage;
  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) {
    final fromRight = panel == ReaderPanel.juz;
    final width = panel == ReaderPanel.surahs
        ? MediaQuery.sizeOf(context).width
        : MediaQuery.sizeOf(context).width * 0.78;
    final content = panel == ReaderPanel.surahs
        ? _SurahsPanel(currentPage: currentPage, onSelectPage: onSelectPage)
        : _JuzPanel(currentPage: currentPage, onSelectPage: onSelectPage);

    return Stack(
      children: [
        Positioned.fill(
          child: GestureDetector(
            onTap: onClose,
            child: ColoredBox(color: Colors.black.withValues(alpha: 0.38)),
          ),
        ),
        Align(
          alignment: fromRight ? Alignment.centerRight : Alignment.centerLeft,
          child: TweenAnimationBuilder<double>(
            tween: Tween(begin: 1, end: 0),
            duration: const Duration(milliseconds: 280),
            curve: Curves.easeOutCubic,
            builder: (context, progress, child) {
              return Transform.translate(
                offset: Offset(
                  fromRight ? width * progress : -width * progress,
                  0,
                ),
                child: child,
              );
            },
            child: Material(
              color: Theme.of(context).colorScheme.surface,
              elevation: 24,
              borderRadius: panel == ReaderPanel.surahs
                  ? BorderRadius.zero
                  : const BorderRadius.horizontal(left: Radius.circular(24)),
              clipBehavior: Clip.antiAlias,
              child: SizedBox(
                width: width,
                height: MediaQuery.sizeOf(context).height,
                child: SafeArea(child: content),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class ReaderEdgeButtons extends StatelessWidget {
  const ReaderEdgeButtons({
    required this.onOpenSurahs,
    required this.onOpenJuz,
    required this.visible,
    super.key,
  });

  final VoidCallback onOpenSurahs;
  final VoidCallback onOpenJuz;
  final bool visible;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final top = MediaQuery.paddingOf(context).top + 72;
    return IgnorePointer(
      ignoring: !visible,
      child: AnimatedSlide(
        offset: visible ? Offset.zero : const Offset(0, -0.35),
        duration: const Duration(milliseconds: 220),
        curve: Curves.easeOutCubic,
        child: AnimatedOpacity(
          opacity: visible ? 1 : 0,
          duration: const Duration(milliseconds: 180),
          child: Stack(
            children: [
              Positioned(
                top: top,
                left: 0,
                child: _EdgeButton(
                  tooltip: 'فهرس السور',
                  icon: Icons.format_list_bulleted_rounded,
                  directionIcon: Icons.chevron_right_rounded,
                  borderRadius: const BorderRadius.horizontal(
                    right: Radius.circular(14),
                  ),
                  onTap: onOpenSurahs,
                  color: colors.primary,
                ),
              ),
              Positioned(
                top: top,
                right: 0,
                child: _EdgeButton(
                  tooltip: 'أجزاء المصحف',
                  icon: Icons.auto_stories_rounded,
                  directionIcon: Icons.chevron_left_rounded,
                  borderRadius: const BorderRadius.horizontal(
                    left: Radius.circular(14),
                  ),
                  onTap: onOpenJuz,
                  color: colors.tertiary,
                ),
              ),
              Positioned(
                top: top + 58,
                right: 0,
                child: _HizbBadge(color: colors.secondary),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _HizbBadge extends StatelessWidget {
  const _HizbBadge({required this.color});

  final Color color;

  @override
  Widget build(BuildContext context) {
    const borderRadius = BorderRadius.horizontal(left: Radius.circular(14));
    return Semantics(
      label: 'علامة الحزب',
      child: Container(
        width: 36,
        height: 48,
        decoration: BoxDecoration(
          borderRadius: borderRadius,
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              color.withValues(alpha: 0.98),
              color.withValues(alpha: 0.78),
            ],
          ),
          border: Border.all(color: Colors.white.withValues(alpha: 0.38)),
          boxShadow: [
            BoxShadow(
              color: color.withValues(alpha: 0.30),
              blurRadius: 10,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        child: const Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              '۞',
              style: TextStyle(
                color: Colors.white,
                fontSize: 19,
                height: 0.9,
                fontWeight: FontWeight.w700,
              ),
            ),
            SizedBox(height: 2),
            Text(
              'الحزب',
              style: TextStyle(
                color: Colors.white,
                fontSize: 8,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _EdgeButton extends StatelessWidget {
  const _EdgeButton({
    required this.tooltip,
    required this.icon,
    required this.directionIcon,
    required this.borderRadius,
    required this.onTap,
    required this.color,
  });

  final String tooltip;
  final IconData icon;
  final IconData directionIcon;
  final BorderRadius borderRadius;
  final VoidCallback onTap;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: tooltip,
      child: Material(
        color: Colors.transparent,
        borderRadius: borderRadius,
        child: Container(
          decoration: BoxDecoration(
            borderRadius: borderRadius,
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                color.withValues(alpha: 0.98),
                color.withValues(alpha: 0.78),
              ],
            ),
            border: Border.all(color: Colors.white.withValues(alpha: 0.38)),
            boxShadow: [
              BoxShadow(
                color: color.withValues(alpha: 0.32),
                blurRadius: 10,
                offset: const Offset(0, 3),
              ),
            ],
          ),
          child: InkWell(
            borderRadius: borderRadius,
            onTap: onTap,
            child: SizedBox(
              width: 36,
              height: 52,
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(icon, color: Colors.white, size: 18),
                  const SizedBox(height: 2),
                  Icon(
                    directionIcon,
                    color: Colors.white.withValues(alpha: 0.82),
                    size: 14,
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

class _PanelHeader extends StatelessWidget {
  const _PanelHeader({
    required this.title,
    required this.subtitle,
    required this.icon,
  });

  final String title;
  final String subtitle;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 10),
      color: Theme.of(context).colorScheme.primary,
      child: Row(
        children: [
          Icon(icon, color: Colors.white),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    color: Colors.white,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                Text(subtitle, style: const TextStyle(color: Colors.white70)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _SurahsPanel extends StatefulWidget {
  const _SurahsPanel({required this.currentPage, required this.onSelectPage});
  final int currentPage;
  final ValueChanged<int> onSelectPage;

  @override
  State<_SurahsPanel> createState() => _SurahsPanelState();
}

class _SurahsPanelState extends State<_SurahsPanel> {
  String _query = '';

  @override
  Widget build(BuildContext context) {
    final current = QuranIndex.surahForPage(widget.currentPage);
    final surahs = QuranIndex.surahs
        .where((surah) => surah.name.contains(_query.trim()))
        .toList();

    return Column(
      children: [
        const _PanelHeader(
          title: 'فهرس السور',
          subtitle: 'اختر سورة للانتقال إلى بدايتها',
          icon: Icons.format_list_bulleted_rounded,
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(10, 8, 10, 6),
          child: SearchBar(
            constraints: const BoxConstraints(minHeight: 42, maxHeight: 42),
            hintText: 'ابحث عن سورة',
            leading: const Icon(Icons.search_rounded),
            onChanged: (value) => setState(() => _query = value),
          ),
        ),
        Expanded(
          child: ListView.separated(
            padding: const EdgeInsets.only(bottom: 24),
            itemCount: surahs.length,
            separatorBuilder: (_, _) => const Divider(height: 1),
            itemBuilder: (context, index) {
              final surah = surahs[index];
              final selected = surah.number == current.number;
              return ListTile(
                dense: true,
                visualDensity: const VisualDensity(vertical: -2),
                selected: selected,
                selectedTileColor: Theme.of(
                  context,
                ).colorScheme.primaryContainer,
                leading: CircleAvatar(
                  radius: 15,
                  backgroundColor: selected
                      ? Theme.of(context).colorScheme.primary
                      : Theme.of(context).colorScheme.surfaceContainerHighest,
                  foregroundColor: selected ? Colors.white : null,
                  child: Text('${surah.number}'),
                ),
                title: Text(
                  'سورة ${surah.name}',
                  style: const TextStyle(
                    fontSize: 13.5,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                subtitle: Text(
                  '${surah.verses} آية  •  ${surah.revelationSymbol} ${surah.revelationLabel}',
                  style: const TextStyle(fontSize: 10),
                ),
                trailing: Text(
                  'ص ${surah.page}',
                  style: const TextStyle(fontSize: 10),
                ),
                onTap: () => widget.onSelectPage(surah.page),
              );
            },
          ),
        ),
      ],
    );
  }
}

class _JuzPanel extends StatelessWidget {
  const _JuzPanel({required this.currentPage, required this.onSelectPage});
  final int currentPage;
  final ValueChanged<int> onSelectPage;

  @override
  Widget build(BuildContext context) {
    final currentJuz = QuranIndex.juzForPage(currentPage);
    return Column(
      children: [
        const _PanelHeader(
          title: 'أجزاء المصحف',
          subtitle: 'اختر الجزء للانتقال إلى بدايته',
          icon: Icons.menu_book_rounded,
        ),
        Expanded(
          child: ListView.separated(
            padding: const EdgeInsets.only(bottom: 24),
            itemCount: QuranIndex.juzPages.length,
            separatorBuilder: (_, _) => const Divider(height: 1),
            itemBuilder: (context, index) {
              final page = QuranIndex.juzPages[index];
              final selected = index + 1 == currentJuz;
              final surah = QuranIndex.surahForPage(page);
              return ListTile(
                selected: selected,
                selectedTileColor: Theme.of(
                  context,
                ).colorScheme.primaryContainer,
                leading: Icon(
                  selected ? Icons.auto_stories_rounded : Icons.book_outlined,
                ),
                title: Text(
                  'الجزء ${QuranIndex.juzNames[index]}',
                  style: const TextStyle(fontWeight: FontWeight.w700),
                ),
                subtitle: Text('سورة ${surah.name}'),
                trailing: Text('ص $page'),
                onTap: () => onSelectPage(page),
              );
            },
          ),
        ),
      ],
    );
  }
}
