import 'package:flutter/material.dart';

import '../../core/state/app_state.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({required this.appState, super.key});

  final AppState appState;

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: appState,
      builder: (context, child) {
        return Scaffold(
          appBar: AppBar(title: const Text('الإعدادات')),
          body: ListView(
            padding: const EdgeInsets.all(20),
            children: [
              Text(
                'وضع القراءة',
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: 10),
              Card(
                child: RadioGroup<ThemeMode>(
                  groupValue: appState.themeMode,
                  onChanged: _setTheme,
                  child: const Column(
                    children: [
                      RadioListTile<ThemeMode>(
                        value: ThemeMode.system,
                        title: Text('حسب إعداد الجهاز'),
                        secondary: Icon(Icons.brightness_auto_rounded),
                      ),
                      RadioListTile<ThemeMode>(
                        value: ThemeMode.light,
                        title: Text('فاتح'),
                        secondary: Icon(Icons.light_mode_rounded),
                      ),
                      RadioListTile<ThemeMode>(
                        value: ThemeMode.dark,
                        title: Text('الوضع الليلي'),
                        subtitle: Text('ألوان مريحة للقراءة في الظلام'),
                        secondary: Icon(Icons.bedtime_rounded),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 24),
              Text(
                'حول التطبيق',
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: 10),
              const Card(
                child: ListTile(
                  leading: Icon(Icons.verified_outlined),
                  title: Text('مصحف المدينة النبوية'),
                  subtitle: Text('رواية حفص عن عاصم - 604 صفحات'),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  void _setTheme(ThemeMode? value) {
    if (value != null) appState.setThemeMode(value);
  }
}
