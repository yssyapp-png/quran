import 'package:shared_preferences/shared_preferences.dart';
import '../models/reciter.dart';

/// تفضيلات التطبيق العامة (القارئ المختار حاليًا، إلخ).
/// مبني ليتوسع لاحقًا (حجم الخط، عدد التكرار...) بنفس النمط.
class SettingsService {
  static const _reciterKey = 'selected_reciter_id';

  Future<Reciter> getSelectedReciter() async {
    final prefs = await SharedPreferences.getInstance();
    final id = prefs.getString(_reciterKey);
    if (id == null) return Reciters.defaultReciter;
    return Reciters.byId(id);
  }

  Future<void> setSelectedReciter(Reciter reciter) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_reciterKey, reciter.id);
  }
}
