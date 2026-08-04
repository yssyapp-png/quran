import 'package:flutter/material.dart';
import '../models/local_ayah.dart';
import '../services/quran_local_service.dart';
import '../theme/app_theme.dart';
import '../theme/quran_font_controller.dart';
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

  /// نمط نص الآية في نتائج البحث حسب مستوى السماكة المختار من الإعدادات
  /// (عادي/عريض/عريض جدًا) — نفس المعايير المعتمدة في نافذة التفسير.
  TextStyle _ayahResultStyle(QuranFontBoldness b) => TextStyle(
        fontFamily: 'UthmanicHafs',
        fontWeight: b.fontWeight,
        color: Colors.black,
        fontSize: 19,
        height: 1.75,
      );

  /// يحوّل نمطًا إلى نسخة "حدّ" (stroke) بلونه نفسه بدل التعبئة، لبناء طبقة
  /// "فائقة السماكة" خلف النص المعبّأ العادي (انظر [_highlighted]).
  TextStyle _asStroke(TextStyle base, double width) => base.copyWith(
        foreground: Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = width
          ..color = base.color ?? Colors.black,
      );

  /// يبني قائمة الأجزاء النصية للآية مع تمييز الجزء المطابق للبحث بلون
  /// ذهبي غامق. [strokeWidth] > 0 يحوّل كل الأجزاء (الأساسية والمميَّزة)
  /// إلى نمط الحدّ بدل التعبئة (طبقة "فائقة السماكة").
  List<TextSpan> _spans(String text, QuranFontBoldness boldness, {double strokeWidth = 0}) {
    final ayahStyle = _ayahResultStyle(boldness);
    final baseStyle = strokeWidth > 0 ? _asStroke(ayahStyle, strokeWidth) : ayahStyle;
    final highlightBase = TextStyle(color: AppColors.gold, fontWeight: boldness.fontWeight);
    final highlightStyle = strokeWidth > 0 ? _asStroke(highlightBase, strokeWidth) : highlightBase;

    if (_query.isEmpty) {
      return [TextSpan(text: text, style: baseStyle)];
    }
    final idx = text.indexOf(_query);
    if (idx == -1) {
      return [TextSpan(text: text, style: baseStyle)];
    }
    return [
      TextSpan(text: text.substring(0, idx), style: baseStyle),
      TextSpan(text: text.substring(idx, idx + _query.length), style: highlightStyle),
      TextSpan(text: text.substring(idx + _query.length), style: baseStyle),
    ];
  }

  /// نص الآية — مستوى السماكة يتبع اختيار المستخدم من الإعدادات؛ عند
  /// "عريض جدًا" فقط تُرسم طبقة حدّ (stroke) إضافية خلف النص المعبّأ.
  Widget _highlighted(String text) {
    return ValueListenableBuilder<QuranFontBoldness>(
      valueListenable: quranFontController,
      builder: (context, boldness, _) {
        if (boldness.strokeWidth <= 0) {
          return RichText(
            textAlign: TextAlign.right,
            text: TextSpan(children: _spans(text, boldness)),
          );
        }
        return Stack(
          children: [
            RichText(
              textAlign: TextAlign.right,
              text: TextSpan(children: _spans(text, boldness, strokeWidth: boldness.strokeWidth)),
            ),
            RichText(textAlign: TextAlign.right, text: TextSpan(children: _spans(text, boldness))),
          ],
        );
      },
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
