import 'package:flutter/material.dart';
import '../models/local_ayah.dart';
import '../services/quran_local_service.dart';
import '../theme/app_theme.dart';
import 'mushaf_page_screen.dart';

/// بحث لحظي في كامل نص القرآن الكريم (بالنص الإملائي) مع تمييز الكلمة المطابقة.
class SearchScreen extends StatefulWidget {
  const SearchScreen({super.key});

  @override
  State<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends State<SearchScreen> {
  final QuranLocalService _service = QuranLocalService();
  List<LocalAyah> _results = [];
  String _query = '';
  bool _loading = false;

  Future<void> _onChanged(String value) async {
    setState(() {
      _query = value.trim();
      _loading = true;
    });
    final results = await _service.search(_query);
    if (!mounted) return;
    setState(() {
      _results = results;
      _loading = false;
    });
  }

  Future<void> _openResult(LocalAyah ayah) async {
    if (!mounted) return;
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => MushafPageScreen(initialPage: ayah.page),
      ),
    );
  }

  /// يبني نصًا مع تمييز الجزء المطابق للبحث بلون ذهبي غامق
  Widget _highlighted(String text) {
    if (_query.isEmpty) return Text(text, textAlign: TextAlign.right);
    final lower = text;
    final idx = lower.indexOf(_query);
    if (idx == -1) return Text(text, textAlign: TextAlign.right);
    return RichText(
      textAlign: TextAlign.right,
      text: TextSpan(
        style: DefaultTextStyle.of(context).style,
        children: [
          TextSpan(text: text.substring(0, idx)),
          TextSpan(
            text: text.substring(idx, idx + _query.length),
            style: const TextStyle(color: AppColors.gold, fontWeight: FontWeight.bold),
          ),
          TextSpan(text: text.substring(idx + _query.length)),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: TextField(
          autofocus: true,
          textAlign: TextAlign.right,
          textDirection: TextDirection.rtl,
          decoration: const InputDecoration(
            hintText: 'ابحث في كل القرآن الكريم...',
            border: InputBorder.none,
          ),
          onChanged: _onChanged,
        ),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _query.isEmpty
              ? const Center(child: Text('اكتب كلمة أو جزءًا من آية للبحث'))
              : _results.isEmpty
                  ? const Center(child: Text('لا توجد نتائج'))
                  : ListView.separated(
                      itemCount: _results.length,
                      separatorBuilder: (_, __) => const Divider(height: 1),
                      itemBuilder: (context, index) {
                        final ayah = _results[index];
                        return ListTile(
                          title: _highlighted(ayah.ayaTextEmlaey),
                          subtitle: Text(
                            '${ayah.suraNameAr} - آية ${ayah.ayaNo}',
                            textAlign: TextAlign.right,
                          ),
                          onTap: () => _openResult(ayah),
                        );
                      },
                    ),
    );
  }
}
