import 'package:mydent_app/features/printing/services/print_settings_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

class FakePrintSettingsService implements PrintSettingsService {
  const FakePrintSettingsService();

  @override
  Future<PrintSettings> load({String? clinicId}) async {
    final prefs = await SharedPreferences.getInstance();
    final keys = PrintSettingsService.storageKeysForTesting(clinicId: clinicId);
    final scale = prefs.getDouble(keys.scale) ?? PrintSettings.defaultScale;
    final postFeed = prefs.getInt(keys.postFeed) ?? PrintSettings.defaultPostFeed;
    final headerSpace =
        prefs.getInt(keys.headerSpace) ?? PrintSettings.defaultHeaderSpace;
    final String? modeRaw = prefs.getString(keys.browserMode);
    final BrowserPrintMode mode =
        modeRaw == BrowserPrintMode.html.name ? BrowserPrintMode.html : BrowserPrintMode.png;
    final int width = prefs.getInt(keys.browserPixelWidth) ??
        PrintSettings.defaultBrowserPixelWidth;
    final bool autoClose = prefs.getBool(keys.browserAutoClose) ??
        PrintSettings.defaultBrowserAutoClose;
    return PrintSettings(
      scale: scale,
      postFeed: postFeed,
      headerSpace: headerSpace,
      browserMode: mode,
      browserPixelWidth: width,
      browserAutoClose: autoClose,
    );
  }

  @override
  Future<void> save(PrintSettings settings, {String? clinicId}) async {
    final prefs = await SharedPreferences.getInstance();
    final keys = PrintSettingsService.storageKeysForTesting(clinicId: clinicId);
    await prefs.setDouble(keys.scale, settings.scale);
    await prefs.setInt(keys.postFeed, settings.postFeed);
    await prefs.setInt(keys.headerSpace, settings.headerSpace);
    await prefs.setString(keys.browserMode, settings.browserMode.name);
    await prefs.setInt(keys.browserPixelWidth, settings.browserPixelWidth);
    await prefs.setBool(keys.browserAutoClose, settings.browserAutoClose);
  }
}
