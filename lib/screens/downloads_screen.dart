import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

/// تنزيل التلاوة للاستماع بدون إنترنت. قيد التطوير — يحتاج محرك تنزيل
/// وتخزين فعلي للملفات الصوتية، لذلك يُعرض هنا كميزة قادمة بدل الادّعاء
/// بعملها الآن (التطبيق حاليًا يبث الصوت مباشرة عبر الإنترنت فقط).
class DownloadsScreen extends StatelessWidget {
  const DownloadsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('التنزيلات')),
      body: const Center(
        child: Padding(
          padding: EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.download_outlined, size: 56, color: AppColors.gold),
              SizedBox(height: 16),
              Text(
                'ميزة تنزيل التلاوة للاستماع بدون إنترنت قيد التطوير وستتوفر قريبًا بإذن الله.',
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
