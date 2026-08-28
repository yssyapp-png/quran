import 'package:flutter/material.dart';

import '../models/ayah.dart';
import '../models/tafsir_entry.dart';
import '../services/quran_text_service.dart';
import '../services/tafsir_service.dart';

class TafsirSheet extends StatefulWidget {
  const TafsirSheet({
    required this.pageNumber,
    required this.tafsirService,
    required this.quranTextService,
    super.key,
  });

  final int pageNumber;
  final TafsirService tafsirService;
  final QuranTextService quranTextService;

  @override
  State<TafsirSheet> createState() => _TafsirSheetState();
}

class _TafsirSheetState extends State<TafsirSheet> {
  TafsirSource _source = TafsirSource.saadi;
  late Future<_TafsirPageData> _future;

  @override
  void initState() {
    super.initState();
    _load();
  }

  void _load() {
    _future = _loadPage();
  }

  Future<_TafsirPageData> _loadPage() async {
    final results = await Future.wait([
      widget.quranTextService.versesByPage(widget.pageNumber),
      widget.tafsirService.tafsirByPage(widget.pageNumber, source: _source),
    ]);
    final ayahs = results[0] as List<Ayah>;
    final tafsirs = results[1] as List<TafsirEntry>;
    return _TafsirPageData(
      ayahs: {for (final ayah in ayahs) ayah.verseKey: ayah},
      tafsirs: tafsirs,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: SafeArea(
        child: DraggableScrollableSheet(
          expand: false,
          initialChildSize: 0.88,
          minChildSize: 0.55,
          maxChildSize: 0.97,
          builder: (context, scrollController) => Column(
            children: [
              const SizedBox(height: 10),
              Container(
                width: 42,
                height: 4,
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.outlineVariant,
                  borderRadius: BorderRadius.circular(20),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 10, 12, 8),
                child: Row(
                  children: [
                    Icon(
                      Icons.chrome_reader_mode_rounded,
                      color: Theme.of(context).colorScheme.primary,
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            _source.name,
                            style: Theme.of(context).textTheme.titleMedium
                                ?.copyWith(fontWeight: FontWeight.w800),
                          ),
                          Text(
                            '${_source.author} • صفحة ${widget.pageNumber}',
                            style: Theme.of(context).textTheme.labelSmall,
                          ),
                        ],
                      ),
                    ),
                    PopupMenuButton<TafsirSource>(
                      tooltip: 'اختيار التفسير',
                      icon: const Icon(Icons.library_books_rounded),
                      onSelected: (source) {
                        setState(() {
                          _source = source;
                          _load();
                        });
                      },
                      itemBuilder: (context) => [
                        for (final source
                            in widget.tafsirService.availableSources)
                          PopupMenuItem(
                            value: source,
                            child: Row(
                              children: [
                                if (source == _source)
                                  const Icon(Icons.check_rounded, size: 18),
                                if (source == _source) const SizedBox(width: 8),
                                Text(source.name),
                              ],
                            ),
                          ),
                      ],
                    ),
                    IconButton(
                      tooltip: 'إغلاق',
                      onPressed: () => Navigator.pop(context),
                      icon: const Icon(Icons.close_rounded),
                    ),
                  ],
                ),
              ),
              const Divider(height: 1),
              Expanded(
                child: FutureBuilder<_TafsirPageData>(
                  future: _future,
                  builder: (context, snapshot) {
                    if (snapshot.connectionState != ConnectionState.done) {
                      return const Center(child: CircularProgressIndicator());
                    }
                    if (snapshot.hasError ||
                        (snapshot.data?.tafsirs.isEmpty ?? true)) {
                      return _TafsirLoadError(onRetry: () => setState(_load));
                    }
                    final data = snapshot.data!;
                    return ListView.separated(
                      controller: scrollController,
                      padding: const EdgeInsets.fromLTRB(18, 14, 18, 28),
                      itemCount: data.tafsirs.length,
                      separatorBuilder: (_, _) => const Divider(height: 28),
                      itemBuilder: (context, index) {
                        final tafsir = data.tafsirs[index];
                        return _TafsirEntryCard(
                          tafsir: tafsir,
                          ayah: data.ayahs[tafsir.verseKey],
                        );
                      },
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _TafsirEntryCard extends StatelessWidget {
  const _TafsirEntryCard({required this.tafsir, required this.ayah});

  final TafsirEntry tafsir;
  final Ayah? ayah;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
              decoration: BoxDecoration(
                color: colors.primaryContainer,
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(
                'الآية ${tafsir.verseKey}',
                style: TextStyle(
                  color: colors.onPrimaryContainer,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
          ],
        ),
        if (ayah != null) ...[
          const SizedBox(height: 10),
          Text(
            ayah!.copyText,
            textAlign: TextAlign.right,
            style: Theme.of(
              context,
            ).textTheme.titleMedium?.copyWith(height: 1.9),
          ),
        ],
        const SizedBox(height: 12),
        Text(
          tafsir.text,
          textAlign: TextAlign.justify,
          style: Theme.of(context).textTheme.bodyLarge?.copyWith(height: 1.8),
        ),
      ],
    );
  }
}

class _TafsirLoadError extends StatelessWidget {
  const _TafsirLoadError({required this.onRetry});

  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.cloud_off_rounded, size: 48),
            const SizedBox(height: 12),
            const Text(
              'تعذر عرض تفسير السعدي. أعد المحاولة، أو تحقق من الاتصال إذا لم تُنزّل النسخة المحلية.',
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 14),
            FilledButton.tonal(
              onPressed: onRetry,
              child: const Text('إعادة المحاولة'),
            ),
          ],
        ),
      ),
    );
  }
}

class _TafsirPageData {
  const _TafsirPageData({required this.ayahs, required this.tafsirs});

  final Map<String, Ayah> ayahs;
  final List<TafsirEntry> tafsirs;
}
