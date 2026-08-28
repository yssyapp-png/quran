import 'package:flutter/material.dart';

import '../../core/constants/app_constants.dart';
import '../../core/constants/quran_index.dart';
import '../../core/state/app_state.dart';
import '../reader/reader_screen.dart';

class IndexScreen extends StatefulWidget {
  const IndexScreen({required this.appState, super.key});

  final AppState appState;

  @override
  State<IndexScreen> createState() => _IndexScreenState();
}

class _IndexScreenState extends State<IndexScreen> {
  final TextEditingController _searchController = TextEditingController();
  String _query = '';

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 3,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('فهرس المصحف'),
          bottom: const TabBar(
            tabs: [
              Tab(text: 'السور'),
              Tab(text: 'الأجزاء'),
              Tab(text: 'الصفحات'),
            ],
          ),
        ),
        body: TabBarView(
          children: [
            _SurahsTab(
              query: _query,
              controller: _searchController,
              onQueryChanged: (value) => setState(() => _query = value.trim()),
              onOpenPage: _openPage,
            ),
            _JuzTab(onOpenPage: _openPage),
            _PagesTab(
              currentPage: widget.appState.lastReadPage,
              onOpenPage: _openPage,
            ),
          ],
        ),
      ),
    );
  }

  void _openPage(int page) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) =>
            ReaderScreen(appState: widget.appState, initialPage: page),
      ),
    );
  }
}

class _SurahsTab extends StatelessWidget {
  const _SurahsTab({
    required this.query,
    required this.controller,
    required this.onQueryChanged,
    required this.onOpenPage,
  });

  final String query;
  final TextEditingController controller;
  final ValueChanged<String> onQueryChanged;
  final ValueChanged<int> onOpenPage;

  @override
  Widget build(BuildContext context) {
    final normalized = query.replaceFirst('سورة', '').trim();
    final surahs = QuranIndex.surahs.where((surah) {
      return normalized.isEmpty ||
          surah.name.contains(normalized) ||
          surah.number.toString() == normalized;
    }).toList();

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(12, 10, 12, 6),
          child: SearchBar(
            constraints: const BoxConstraints(minHeight: 44, maxHeight: 44),
            controller: controller,
            hintText: 'ابحث باسم السورة أو رقمها',
            leading: const Icon(Icons.search_rounded),
            trailing: [
              if (query.isNotEmpty)
                IconButton(
                  tooltip: 'مسح البحث',
                  onPressed: () {
                    controller.clear();
                    onQueryChanged('');
                  },
                  icon: const Icon(Icons.close_rounded),
                ),
            ],
            onChanged: onQueryChanged,
          ),
        ),
        Expanded(
          child: ListView.separated(
            padding: const EdgeInsets.fromLTRB(12, 4, 12, 20),
            itemCount: surahs.length,
            separatorBuilder: (_, _) => const Divider(height: 1, indent: 72),
            itemBuilder: (context, index) {
              final surah = surahs[index];
              return ListTile(
                dense: true,
                visualDensity: const VisualDensity(vertical: -2),
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 6,
                  vertical: 1,
                ),
                leading: _OrnamentNumber(number: surah.number),
                title: Text(
                  'سورة ${surah.name}',
                  style: Theme.of(
                    context,
                  ).textTheme.bodyLarge?.copyWith(fontWeight: FontWeight.w700),
                ),
                subtitle: Padding(
                  padding: const EdgeInsets.only(top: 3),
                  child: Wrap(
                    spacing: 7,
                    runSpacing: 3,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      Text(
                        '${surah.verses} آية  •  صفحة ${surah.page}',
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                      _RevelationBadge(surah: surah),
                    ],
                  ),
                ),
                trailing: const Icon(Icons.chevron_left_rounded, size: 20),
                onTap: () => onOpenPage(surah.page),
              );
            },
          ),
        ),
      ],
    );
  }
}

class _JuzTab extends StatelessWidget {
  const _JuzTab({required this.onOpenPage});
  final ValueChanged<int> onOpenPage;

  @override
  Widget build(BuildContext context) {
    return ListView.separated(
      padding: const EdgeInsets.all(16),
      itemCount: 30,
      separatorBuilder: (_, _) => const SizedBox(height: 8),
      itemBuilder: (context, index) {
        final page = QuranIndex.juzPages[index];
        final surah = QuranIndex.surahForPage(page);
        return Card(
          clipBehavior: Clip.antiAlias,
          child: ListTile(
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 18,
              vertical: 8,
            ),
            leading: const Icon(Icons.auto_stories_rounded),
            title: Text('الجزء ${QuranIndex.juzNames[index]}'),
            subtitle: Text('صفحة $page  •  سورة ${surah.name}'),
            trailing: const Icon(Icons.chevron_left_rounded),
            onTap: () => onOpenPage(page),
          ),
        );
      },
    );
  }
}

class _PagesTab extends StatelessWidget {
  const _PagesTab({required this.currentPage, required this.onOpenPage});
  final int currentPage;
  final ValueChanged<int> onOpenPage;

  @override
  Widget build(BuildContext context) {
    return GridView.builder(
      padding: const EdgeInsets.all(16),
      gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
        maxCrossAxisExtent: 92,
        childAspectRatio: 1.15,
        crossAxisSpacing: 8,
        mainAxisSpacing: 8,
      ),
      itemCount: AppConstants.mushafPageCount,
      itemBuilder: (context, index) {
        final page = index + 1;
        final selected = page == currentPage;
        return Material(
          color: selected
              ? Theme.of(context).colorScheme.primaryContainer
              : Theme.of(context).colorScheme.surfaceContainerLow,
          borderRadius: BorderRadius.circular(14),
          child: InkWell(
            borderRadius: BorderRadius.circular(14),
            onTap: () => onOpenPage(page),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text('$page', style: Theme.of(context).textTheme.titleMedium),
                if (selected)
                  Text('موضعك', style: Theme.of(context).textTheme.labelSmall),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _RevelationBadge extends StatelessWidget {
  const _RevelationBadge({required this.surah});

  final SurahIndexEntry surah;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final badgeColor = surah.isMakki ? colors.tertiary : colors.primary;
    return Semantics(
      label: 'سورة ${surah.revelationLabel}',
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
        decoration: BoxDecoration(
          color: badgeColor.withValues(alpha: 0.10),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: badgeColor.withValues(alpha: 0.28)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(surah.revelationSymbol, style: const TextStyle(fontSize: 13)),
            const SizedBox(width: 4),
            Text(
              surah.revelationLabel,
              style: Theme.of(context).textTheme.labelSmall?.copyWith(
                color: badgeColor,
                fontWeight: FontWeight.w800,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _OrnamentNumber extends StatelessWidget {
  const _OrnamentNumber({required this.number});
  final int number;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 38,
      height: 38,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(color: Theme.of(context).colorScheme.primary),
      ),
      child: Text(
        '$number',
        style: const TextStyle(fontWeight: FontWeight.w700),
      ),
    );
  }
}
