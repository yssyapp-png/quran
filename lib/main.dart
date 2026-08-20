import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import 'quran_y/main.dart' as quran_y;

void main() {
  WidgetsFlutterBinding.ensureInitialized();

  if (_isSupportedPlatform) {
    quran_y.main();
    return;
  }

  runApp(const _UnsupportedPlatformApp());
}

bool get _isSupportedPlatform =>
    !kIsWeb &&
    (defaultTargetPlatform == TargetPlatform.android ||
        defaultTargetPlatform == TargetPlatform.iOS ||
        defaultTargetPlatform == TargetPlatform.macOS);

class _UnsupportedPlatformApp extends StatelessWidget {
  const _UnsupportedPlatformApp();

  @override
  Widget build(BuildContext context) {
    return const MaterialApp(
      debugShowCheckedModeBanner: false,
      home: Scaffold(
        body: Center(
          child: Padding(
            padding: EdgeInsets.all(24),
            child: Text(
              'المصحف متاح على Android وiPhone وiPad وMac فقط',
              textAlign: TextAlign.center,
              textDirection: TextDirection.rtl,
            ),
          ),
        ),
      ),
    );
  }
}

// إبقاء الاسم العام السابق متاحًا للاختبارات والتكاملات الداخلية.
typedef QuranApp = quran_y.MyApp;
