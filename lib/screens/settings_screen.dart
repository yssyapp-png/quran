import 'package:flutter/material.dart';
import '../models/reciter.dart';
import '../services/settings_service.dart';
import '../theme/app_theme.dart';
import '../theme/quran_font_controller.dart';
import '../theme/theme_controller.dart';

/// الإعدادات: اختيار القارئ، والتبديل بين الوضع الليلي/النهاري.
class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  final SettingsService _settingsService = SettingsService();
  Reciter? _selected;

  @override
  void initState() {
    super.initState();
    _settingsService.getSelectedReciter().then((r) {
      if (mounted) setState(() => _selected = r);
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('الإعدادات')),
      body: ListView(
        children: [
          ValueListenableBuilder<ThemeMode>(
            valueListenable: themeController,
            builder: (context, mode, _) => SwitchListTile(
              title: const Text('الوضع الليلي'),
              secondary: const Icon(Icons.dark_mode_outlined),
              value: mode == ThemeMode.dark,
              onChanged: (_) => themeController.toggle(),
            ),
          ),
          const Divider(),
          // إعدادات الوضوح وضعاف البصر: مجمّعة هنا معًا (حجم صفحة المصحف +
          // سماكة الخط) لتسهيل الوصول إليها وتخصيصها حسب ذوق كل مستخدم.
          const Padding(
            padding: EdgeInsets.fromLTRB(16, 12, 16, 4),
            child: Row(
              children: [
                Icon(Icons.accessibility_new_outlined,
                    color: AppColors.inkGreen, size: 20),
                SizedBox(width: 6),
                Text('إعدادات الوضوح وضعاف البصر',
                    style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: AppColors.inkGreen)),
              ],
            ),
          ),
          // (أُزيلت خيارات "حجم صفحة المصحف" المتعددة بناءً على ملاحظة
          // المستخدم: الحجم العادي هو الأنسب والأكثر تطابقًا مع تصميم
          // الصفحة الرسمية؛ الأحجام الإضافية كانت تبدو غير متناسقة معها.
          // كذلك أُزيل خيار "الإطار الفاخر" لصفحتي الفاتحة وأول البقرة بناءً
          // على طلب المستخدم — تُعرض الآن كل الصفحات بدون أي إطار زخرفي.)
          const Padding(
            padding: EdgeInsets.fromLTRB(16, 12, 16, 4),
            child: Text('سماكة خط القرآن (التفسير والبحث)',
                style: TextStyle(fontWeight: FontWeight.w600)),
          ),
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 16, vertical: 4),
            child: Text(
              'يتحكم فقط بوضوح النص الحيّ في التفسير ونتائج البحث; صور صفحات '
              'المصحج الرسمية نفسها لا تتأثر بهذا الخيار.',
              style: TextStyle(color: Colors.grey, fontSize: 12),
            ),
          ),
          ValueListenableBuilder<QuranFontBoldness>(
            valueListenable: quranFontController,
            builder: (context, current, _) => Column(
              children: QuranFontBoldness.values
                  .map((level) => RadioListTile<QuranFontBoldness>(
                        title: Text(
                          level.labelAr,
                          style: TextStyle(
                            fontFamily: 'UthmanicHafs',
                            fontWeight: level.fontWeight,
                            fontSize: 18,
                          ),
                        ),
                        value: level,
                        groupValue: current,
                        activeColor: AppColors.gold,
                        onChanged: (v) {
                          if (v != null) quranFontController.setLevel(v);
                        },
                      ))
                  .toList(),
            ),
          ),
          const Divider(),
          const Padding(
            padding: EdgeInsets.fromLTRB(16, 12, 16, 4),
            child: Text('القارئ',
                style: TextStyle(
                    fontWeight: FontWeight.bold, color: AppColors.inkGreen)),
          ),
          if (_selected == null)
            const Padding(
              padding: EdgeInsets.all(16),
              child: Center(
                  child: CircularProgressIndicator(color: AppColors.gold)),
            )
          else
            ...Reciters.all.map((r) => RadioListTile<String>(
                  title: Text(r.nameAr),
                  value: r.id,
                  groupValue: _selected!.id,
                  activeColor: AppColors.gold,
                  onChanged: (_) async {
                    await _settingsService.setSelectedReciter(r);
                    if (mounted) setState(() => _selected = r);
                  },
                )),
          if (Reciters.all.length == 1)
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Text(
                'سيتم إضافة قراء آخرين لاحقًا.',
                style: TextStyle(color: Colors.grey, fontSize: 12),
              ),
            ),
        ],
      ),
    );
  }
}
