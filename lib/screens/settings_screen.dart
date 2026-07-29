import 'package:flutter/material.dart';
import '../models/reciter.dart';
import '../services/settings_service.dart';
import '../theme/app_theme.dart';
import '../theme/mushaf_frame_controller.dart';
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
                Icon(Icons.accessibility_new_outlined, color: AppColors.inkGreen, size: 20),
                SizedBox(width: 6),
                Text('إعدادات الوضوح وضعاف البصر',
                    style: TextStyle(fontWeight: FontWeight.bold, color: AppColors.inkGreen)),
              ],
            ),
          ),
          // (أُزيلت خيارات "حجم صفحة المصحف" المتعددة بناءً على ملاحظة
          // المستخدم: الحجم العادي هو الأنسب والأكثر تطابقًا مع تصميم
          // الصفحة الرسمية؛ الأحجام الإضافية كانت تبدو غير متناسقة معها.)
          const Padding(
            padding: EdgeInsets.fromLTRB(16, 12, 16, 4),
            child: Text('العرض الفاخر', style: TextStyle(fontWeight: FontWeight.w600)),
          ),
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 16),
            child: Text(
              'إطار ذهبي زخرفي يظهر فقط في صفحتي الفاتحة وأول البقرة '
              '(صفحتا الافتتاح)، يملأ الهامش الأبيض حولهما بشكل أنيق، دون '
              'أي تعديل على صورة الصفحة الرسمية نفسها.',
              style: TextStyle(color: Colors.grey, fontSize: 12),
            ),
          ),
          ValueListenableBuilder<bool>(
            valueListenable: mushafFrameController,
            builder: (context, enabled, _) => Column(
              children: [
                SwitchListTile(
                  title: const Text('الإطار الفاخر للصفحة'),
                  secondary: const Icon(Icons.auto_awesome_outlined, color: AppColors.gold),
                  value: enabled,
                  activeColor: AppColors.inkGreen,
                  onChanged: (v) => mushafFrameController.setEnabled(v),
                ),
                // لون الإطار نفسه خيار ذوقي مستقل، يظهر فقط عند تفعيل
                // الإطار الفاخر أعلاه — لا علاقة له بصورة المصحف نفسها.
                if (enabled)
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('لون الإطار', style: TextStyle(fontWeight: FontWeight.w600)),
                        const Padding(
                          padding: EdgeInsets.symmetric(vertical: 4),
                          child: Text(
                            'الأخضر المتناسق مستوحى من لون الزخرفة داخل صفحتي '
                            'الافتتاح نفسيهما.',
                            style: TextStyle(color: Colors.grey, fontSize: 12),
                          ),
                        ),
                        ValueListenableBuilder<MushafFrameColorScheme>(
                          valueListenable: mushafFrameColorController,
                          builder: (context, scheme, _) => Column(
                            children: MushafFrameColorScheme.values
                                .map((s) => RadioListTile<MushafFrameColorScheme>(
                                      title: Text(s.labelAr),
                                      value: s,
                                      groupValue: scheme,
                                      activeColor: AppColors.inkGreen,
                                      contentPadding: EdgeInsets.zero,
                                      onChanged: (v) {
                                        if (v != null) mushafFrameColorController.setScheme(v);
                                      },
                                    ))
                                .toList(),
                          ),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
          ),
          const Padding(
            padding: EdgeInsets.fromLTRB(16, 12, 16, 4),
            child: Text('سماكة خط القرآن (التفسير والبحث)',
                style: TextStyle(fontWeight: FontWeight.w600)),
          ),
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 16, vertical: 4),
            child: Text(
              'يتحكم فقط بوضوح النص الحيّ في التفسير ونتائج البحث؛ صور صفحات '
              'المصحف الرسمية نفسها لا تتأثر بهذا الخيار.',
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
                            fontFamily: 'HafsSmart',
                            fontWeight: level.fontWeight,
                            fontSize: 18,
                          ),
                        ),
                        value: level,
                        groupValue: current,
                        activeColor: AppColors.inkGreen,
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
            child: Text('القارئ', style: TextStyle(fontWeight: FontWeight.bold, color: AppColors.inkGreen)),
          ),
          if (_selected == null)
            const Padding(
              padding: EdgeInsets.all(16),
              child: Center(child: CircularProgressIndicator(color: AppColors.gold)),
            )
          else
            ...Reciters.all.map((r) => RadioListTile<String>(
                  title: Text(r.nameAr),
                  value: r.id,
                  groupValue: _selected!.id,
                  activeColor: AppColors.inkGreen,
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
