import 'package:flutter/material.dart';
import '../services/quran_service.dart';
import '../theme/app_theme.dart';

/// نافذة سفلية تعرض تفسير الآية عند الضغط عليها
Future<void> showTafsirSheet(
    BuildContext context, int surahNumber, int ayahNumber, String ayahText) {
  final service = QuranService();
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
        builder: (context, scrollController) {
          return FutureBuilder<String>(
            future: service.getAyahTafsir(surahNumber, ayahNumber),
            builder: (context, snapshot) {
              return SingleChildScrollView(
                controller: scrollController,
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: const [
                        Icon(Icons.menu_book, color: AppColors.gold),
                        SizedBox(width: 8),
                        Text('التفسير',
                            style: TextStyle(
                                fontSize: 18, fontWeight: FontWeight.bold)),
                      ],
                    ),
                    const Divider(height: 24),
                    Text(
                      ayahText,
                      textAlign: TextAlign.right,
                      style: const TextStyle(
                          fontSize: 20, fontFamily: 'HafsSmart', height: 1.8),
                    ),
                    const SizedBox(height: 16),
                    if (snapshot.connectionState == ConnectionState.waiting)
                      const Center(child: CircularProgressIndicator())
                    else if (snapshot.hasError)
                      const Text('حدث خطأ أثناء تحميل التفسير',
                          textAlign: TextAlign.right)
                    else
                      Text(
                        snapshot.data ?? '',
                        textAlign: TextAlign.right,
                        style: const TextStyle(fontSize: 16, height: 1.7),
                      ),
                  ],
                ),
              );
            },
          );
        },
      );
    },
  );
}
