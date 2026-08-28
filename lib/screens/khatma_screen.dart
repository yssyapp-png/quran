import 'package:flutter/material.dart';
import 'mushaf_page_screen.dart';
import '../services/bookmark_service.dart';
import '../theme/app_theme.dart';

/// تتبّع "الختمة": يعرض نسبة الصفحات التي وسمها المستخدم كمقروءة من أصل
/// 604 صفحة، مع إمكانية وسم الصفحة الحالية وإعادة ضبط الختمة للبدء من جديد.
class KhatmaScreen extends StatefulWidget {
  final int currentPage;
  const KhatmaScreen({super.key, required this.currentPage});

  @override
  State<KhatmaScreen> createState() => _KhatmaScreenState();
}

class _KhatmaScreenState extends State<KhatmaScreen> {
  final BookmarkService _bookmarkService = BookmarkService();
  late Future<Set<int>> _future;

  @override
  void initState() {
    super.initState();
    _future = _bookmarkService.getReadPages();
  }

  void _reload() {
    setState(() => _future = _bookmarkService.getReadPages());
  }

  Future<void> _markCurrentRead() async {
    await _bookmarkService.markPageRead(widget.currentPage);
    _reload();
  }

  Future<void> _confirmReset() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('إعادة ضبط الختمة'),
        content: const Text('سيتم مسح كل الصفحات المسجّلة كمقروءة والبدء من جديد. متابعة؟'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(dialogContext, false), child: const Text('إلغاء')),
          TextButton(onPressed: () => Navigator.pop(dialogContext, true), child: const Text('إعادة الضبط')),
        ],
      ),
    );
    if (confirmed == true) {
      await _bookmarkService.resetKhatma();
      _reload();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('الختمة'),
        actions: [
          IconButton(
            tooltip: 'إعادة ضبط الختمة',
            icon: const Icon(Icons.refresh),
            onPressed: _confirmReset,
          ),
        ],
      ),
      body: FutureBuilder<Set<int>>(
        future: _future,
        builder: (context, snapshot) {
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator(color: AppColors.gold));
          }
          final readCount = snapshot.data!.length;
          final progress = readCount / kMushafPageCount;
          final alreadyMarked = snapshot.data!.contains(widget.currentPage);
          return Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                SizedBox(
                  width: 160,
                  height: 160,
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      CircularProgressIndicator(
                        value: progress,
                        strokeWidth: 10,
                        backgroundColor: AppColors.gold.withValues(alpha: 0.15),
                        color: AppColors.inkGreen,
                      ),
                      Text('${(progress * 100).toStringAsFixed(1)}%',
                          style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                Text('$readCount من $kMushafPageCount صفحة مقروءة'),
                const SizedBox(height: 32),
                ElevatedButton.icon(
                  onPressed: alreadyMarked ? null : _markCurrentRead,
                  icon: const Icon(Icons.check_circle_outline),
                  label: Text(alreadyMarked
                      ? 'الصفحة ${widget.currentPage} مُسجَّلة كمقروءة'
                      : 'وسم الصفحة ${widget.currentPage} كمقروءة'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.inkGreen,
                    foregroundColor: AppColors.cream,
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}
