import 'dart:io';
import 'package:flutter/material.dart';
import '../services/quran_service.dart';
import '../theme/app_theme.dart';
import '../theme/quran_font_controller.dart';
import 'extra_bold_arabic_text.dart';

/// نافذة سفلية تعرض تفسير الآية عند الضغط عليها.
/// التفسير وحده يُجلب من الإنترنت (نص المصحف وصوره محليان دائمًث)، لذا
/// نعالج هنا بوضوح حالتي: لا يوجد إنترنت، وخطأ من الخادم — مع زر
/// "إعادة المحاولة" بدل ترك المستخدم أمام رسالة عامة لا يفعل بها شيئًا.
Future<void> showTafsirSheet(
    BuildContext context, int surahNumber, int ayahNumber, String ayahText) {
  return showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
    ),
    builder: (context) {
      return DraggableScrollableSheet(
        initialChildSize: 0.5,
        maxChildSize: 0.9,
        minChildSize: 0.3,
        expand: false,
        builder: (context, scrollController) => _TafsirBody(
          scrollController: scrollController,
          surahNumber: surahNumber,
          ayahNumber: ayahNumber,
          ayahText: ayahText,
        ),
      );
    },
  );
}

class _TafsirBody extends StatefulWidget {
  final ScrollController scrollController;
  final int surahNumber;
  final int ayahNumber;
  final String ayahText;

  const _TafsirBody({
    required this.scrollController,
    required this.surahNumber,
    required this.ayahNumber,
    required this.ayahText,
  });

  @override
  State<_TafsirBody> createState() => _TafsirBodyState();
}

class _TafsirBodyState extends State<_TafsirBody> {
  final QuranService _service = QuranService();
  late Future<String> _future;

  @override
  void initState() {
    super.initState();
    _load();
  }

  void _load() {
    _future = _service.getAyahTafsir(widget.surahNumber, widget.ayahNumber);
  }

  void _retry() {
    setState(_load);
  }

  @override
  Widget build(BuildContext context) {
    // لون نص الآية والتفسير كان مثبّتًا على الأسود دائمًا حتى في الوضع
    // الليلي، فيصبح غير مقروء فوق خلفية النافذة الداكنة. الآن يتبع
    // السطوع الحالي: أبيض/رمادي فاتح في الليلي، أسود/رمادي داكن في النهاري.
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return SingleChildScrollView(
      controller: widget.scrollController,
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: const [
              Icon(Icons.menu_book, color: AppColors.gold),
              SizedBox(width: 8),
              Text('التفسير',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            ],
          ),
          const Divider(height: 24),
          // نص الآية بخط عثماني — مستوى السماكة (عادي/عريض/عريض
          // جدًا) يتبع اختيار المستخدم من الإعدادات، فيتحدّث فورًا
          // في كل مكان بالتطبيق دون أي خلل في وضوح النص أو التشكيل.
          ValueListenableBuilder<QuranFontBoldness>(
            valueListenable: quranFontController,
            builder: (context, boldness, _) => ExtraBoldArabicText(
              widget.ayahText,
              textAlign: TextAlign.right,
              strokeWidth: boldness.strokeWidth,
              style: TextStyle(
                fontSize: 25,
                fontFamily: 'UthmanicHafs',
                fontWeight: boldness.fontWeight,
                color: isDark ? Colors.white : Colors.black,
                height: 1.95,
                letterSpacing: 0,
              ),
            ),
          ),
          const SizedBox(height: 16),
          FutureBuilder<String>(
            future: _future,
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Padding(
                  padding: EdgeInsets.symmetric(vertical: 24),
                  child: Center(
                      child: CircularProgressIndicator(color: AppColors.gold)),
                );
              }
              if (snapshot.hasError) {
                final isOffline = snapshot.error is SocketException;
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Icon(
                      isOffline ? Icons.wifi_off_outlined : Icons.error_outline,
                      color: Colors.grey,
                      size: 32,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      isOffline
                          ? 'لا يوجد اتصال بالإنترنت — التفسير يحتاج اتصالًا لعرضه'
                          : 'تعذر تحميل التفسير، حاول مرة أخرى',
                      textAlign: TextAlign.center,
                      style: const TextStyle(color: Colors.grey),
                    ),
                    const SizedBox(height: 12),
                    OutlinedButton.icon(
                      onPressed: _retry,
                      icon: const Icon(Icons.refresh),
                      label: const Text('إعادة المحاولة'),
                    ),
                  ],
                );
              }
              return ValueListenableBuilder<QuranFontBoldness>(
                valueListenable: quranFontController,
                builder: (context, boldness, _) => ExtraBoldArabicText(
                  snapshot.data ?? '',
                  textAlign: TextAlign.right,
                  strokeWidth: boldness.strokeWidth,
                  style: TextStyle(
                    fontSize: 16,
                    fontFamily: 'UthmanicHafs',
                    fontWeight: boldness.fontWeight,
                    height: 1.7,
                    color: isDark ? Colors.white70 : Colors.black87,
                  ),
                ),
              );
            },
          ),
        ],
      ),
    );
  }
}
