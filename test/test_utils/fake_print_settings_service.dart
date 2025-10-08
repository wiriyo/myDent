import 'package:mydent_app/features/printing/services/print_settings_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

class FakePrintSettingsService implements PrintSettingsService {
  const FakePrintSettingsService();

  @override
  Future<PrintSettings> load({String? clinicId}) async {
    final prefs = await SharedPreferences.getInstance();
    final scale = prefs.getDouble(PrintSettingsService.scalePrefKey) ?? PrintSettings.defaultScale;
    final postFeed = prefs.getInt(PrintSettingsService.postFeedPrefKey) ?? PrintSettings.defaultPostFeed;
    final headerSpace = prefs.getInt(PrintSettingsService.headerSpacePrefKey) ?? PrintSettings.defaultHeaderSpace;
    return PrintSettings(scale: scale, postFeed: postFeed, headerSpace: headerSpace);
  }

  @override
  Future<void> save(PrintSettings settings, {String? clinicId}) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setDouble(PrintSettingsService.scalePrefKey, settings.scale);
    await prefs.setInt(PrintSettingsService.postFeedPrefKey, settings.postFeed);
    await prefs.setInt(PrintSettingsService.headerSpacePrefKey, settings.headerSpace);
  }
}
