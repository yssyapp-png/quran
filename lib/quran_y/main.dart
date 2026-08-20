import 'package:flutter/material.dart';

import 'core/constants/app_constants.dart';
import 'core/state/app_state.dart';
import 'core/theme/app_theme.dart';
import 'screens/reader/reader_screen.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const MyApp());
}

class MyApp extends StatefulWidget {
  const MyApp({super.key});

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  final AppState _appState = AppState();

  @override
  void dispose() {
    _appState.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: _appState,
      builder: (context, child) {
        return MaterialApp(
          title: AppConstants.appName,
          debugShowCheckedModeBanner: false,
          theme: AppTheme.light,
          darkTheme: AppTheme.night,
          themeMode: _appState.themeMode,
          locale: const Locale('ar'),
          home: FutureBuilder<void>(
            future: _appState.ready,
            builder: (context, snapshot) {
              if (snapshot.connectionState != ConnectionState.done) {
                return const Scaffold(
                  body: Center(child: CircularProgressIndicator()),
                );
              }
              return ReaderScreen(
                appState: _appState,
                initialPage: _appState.lastReadPage,
              );
            },
          ),
        );
      },
    );
  }
}
