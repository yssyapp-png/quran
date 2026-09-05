import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'screens/home_screen.dart';
import 'theme/app_theme.dart';
import 'theme/quran_font_controller.dart';
import 'theme/theme_controller.dart';

void main() {
  runZonedGuarded(() async {
    WidgetsFlutterBinding.ensureInitialized();

    // معالجة عامة للأخطاء: بدل أن يتوقف التطبيق فجأة أو يظهر للمستخدم شاشة
    // حمراء تقنية غير مفهومة، نعرض واجهة عربية ودّية ونُسجّل الخطأ فقط
    // (في وضع التطوير) دون كسر تجربة القراءة.
    FlutterError.onError = (details) {
      FlutterError.presentError(details);
      if (kDebugMode) debugPrint('خطأ غير متوقع: ${details.exception}');
    };
    ErrorWidget.builder = (details) {
      return Material(
        color: AppColors.creamPage,
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.error_outline,
                    color: AppColors.inkGreen, size: 40),
                const SizedBox(height: 12),
                const Text('حدث خطأ غير متوقع أثناء عرض هذا الجزء',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: AppColors.inkGreen)),
              ],
            ),
          ),
        ),
      );
    };

    await themeController.load();
    await quranFontController.load();
    runApp(const QuranApp());
  }, (error, stack) {
    // أي خطأ غير متزامن (شبكة، تشغيل صوت...) يُسجَّل فقط ولا يُسقط التطبيق.
    if (kDebugMode) debugPrint('خطأ غير متزامن: $error');
  });
}

class QuranApp extends StatelessWidget {
  const QuranApp({super.key});

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<ThemeMode>(
      valueListenable: themeController,
      builder: (context, mode, _) {
        return MaterialApp(
          title: 'القرآن الكريم',
          debugShowCheckedModeBanner: false,
          locale: const Locale('ar'),
          themeMode: mode,
          theme: AppTheme.light,
          darkTheme: AppTheme.dark,
          builder: (context, child) {
            return Directionality(
              textDirection: TextDirection.rtl,
              child: child!,
            );
          },
          home: const HomeScreen(),
        );
      },
    );
  }
}
