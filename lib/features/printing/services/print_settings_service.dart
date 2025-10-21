import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

enum BrowserPrintMode { png, html }

class PrintSettings {
  static const double defaultScale = 1.0;
  static const int defaultPostFeed = 3;
  static const int defaultHeaderSpace = 0;

  static const BrowserPrintMode defaultBrowserMode = BrowserPrintMode.png;
  static const int defaultBrowserPixelWidth = 576;
  static const bool defaultBrowserAutoClose = true;

  static const double minScale = 0.5;
  static const double maxScale = 2.0;
  static const int minPostFeed = 0;
  static const int maxPostFeed = 10;
  static const int minHeaderSpace = 0;
  static const int maxHeaderSpace = 50;
  static const int minBrowserPixelWidth = 384;
  static const int maxBrowserPixelWidth = 640;

  static const int _feedStepLines = 4;
  static const int _minEffectiveFeedLines = 3;

  final double scale;
  final int postFeed;
  final int headerSpace;

  final BrowserPrintMode browserMode;
  final int browserPixelWidth;
  final bool browserAutoClose;

  const PrintSettings._(
    this.scale,
    this.postFeed,
    this.headerSpace,
    this.browserMode,
    this.browserPixelWidth,
    this.browserAutoClose,
  );

  const PrintSettings.defaults()
    : this._(
        defaultScale,
        defaultPostFeed,
        defaultHeaderSpace,
        defaultBrowserMode,
        defaultBrowserPixelWidth,
        defaultBrowserAutoClose,
      );

  factory PrintSettings({
    required double scale,
    required int postFeed,
    required int headerSpace,
    BrowserPrintMode? browserMode,
    int? browserPixelWidth,
    bool? browserAutoClose,
  }) {
    final clampedScale = scale.clamp(minScale, maxScale).toDouble();
    final clampedPostFeed = postFeed.clamp(minPostFeed, maxPostFeed).toInt();
    final clampedHeaderSpace =
        headerSpace.clamp(minHeaderSpace, maxHeaderSpace).toInt();
    final int width =
        (browserPixelWidth ?? defaultBrowserPixelWidth)
            .clamp(minBrowserPixelWidth, maxBrowserPixelWidth)
            .toInt();
    return PrintSettings._(
      clampedScale,
      clampedPostFeed,
      clampedHeaderSpace,
      browserMode ?? defaultBrowserMode,
      width,
      browserAutoClose ?? defaultBrowserAutoClose,
    );
  }

  PrintSettings copyWith({
    double? scale,
    int? postFeed,
    int? headerSpace,
    BrowserPrintMode? browserMode,
    int? browserPixelWidth,
    bool? browserAutoClose,
  }) {
    return PrintSettings(
      scale: scale ?? this.scale,
      postFeed: postFeed ?? this.postFeed,
      headerSpace: headerSpace ?? this.headerSpace,
      browserMode: browserMode ?? this.browserMode,
      browserPixelWidth: browserPixelWidth ?? this.browserPixelWidth,
      browserAutoClose: browserAutoClose ?? this.browserAutoClose,
    );
  }

  Map<String, dynamic> toMap() => <String, dynamic>{
    'scale': scale,
    'postFeed': postFeed,
    'headerSpace': headerSpace,
    'browserMode': browserMode.name,
    'browserPixelWidth': browserPixelWidth,
    'browserAutoClose': browserAutoClose,
  };

  static PrintSettings fromMap(Map<String, dynamic>? data) {
    if (data == null) {
      return const PrintSettings.defaults();
    }
    final scale = (data['scale'] as num?)?.toDouble();
    final postFeed = (data['postFeed'] as num?)?.toInt();
    final headerSpace = (data['headerSpace'] as num?)?.toInt();
    final String? modeRaw = data['browserMode'] as String?;
    final BrowserPrintMode mode = _modeFromRaw(modeRaw);
    final int? browserWidth = (data['browserPixelWidth'] as num?)?.toInt();
    final bool autoClose =
        (data['browserAutoClose'] as bool?) ??
        PrintSettings.defaultBrowserAutoClose;
    return PrintSettings(
      scale: scale ?? defaultScale,
      postFeed: postFeed ?? defaultPostFeed,
      headerSpace: headerSpace ?? defaultHeaderSpace,
      browserMode: mode,
      browserPixelWidth: browserWidth ?? defaultBrowserPixelWidth,
      browserAutoClose: autoClose,
    );
  }

  /// Converts the user-facing post feed value (0-10) into ESC/POS feed lines.
  /// Each unit maps to 4 printer lines (~1.7 cm on 80 mm paper) so changes are easy to see at the cutter.
  static int feedLinesFromSetting(int postFeed) {
    if (postFeed <= 0) return 0;
    final int computed = postFeed * _feedStepLines;
    final int bounded = math.min(
      255,
      math.max(_minEffectiveFeedLines, computed),
    );
    return bounded;
  }
}

class PrintSettingsService {
  const PrintSettingsService();

  static const String scalePrefKey = 'mydent.printing.scale';
  static const String postFeedPrefKey = 'mydent.printing.postfeed';
  static const String headerSpacePrefKey = 'mydent.printing.headerspace';
  static const String browserModePrefKey = 'mydent.printing.browser.mode';
  static const String browserWidthPrefKey = 'mydent.printing.browser.width';
  static const String browserAutoClosePrefKey =
      'mydent.printing.browser.autoclose';

  Future<PrintSettings> load({String? clinicId}) async {
    final local = await _loadFromLocal();
    if (local != null) {
      return local;
    }
    const defaults = PrintSettings.defaults();
    await _saveToLocal(defaults);
    return defaults;
  }

  Future<void> save(PrintSettings settings, {String? clinicId}) async {
    await _saveToLocal(settings);
  }

  Future<PrintSettings?> _loadFromLocal() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      if (!prefs.containsKey(scalePrefKey) &&
          !prefs.containsKey(postFeedPrefKey) &&
          !prefs.containsKey(headerSpacePrefKey) &&
          !prefs.containsKey(browserModePrefKey)) {
        return null;
      }
      final scale = prefs.getDouble(scalePrefKey) ?? PrintSettings.defaultScale;
      final postFeed =
          prefs.getInt(postFeedPrefKey) ?? PrintSettings.defaultPostFeed;
      final headerSpace =
          prefs.getInt(headerSpacePrefKey) ?? PrintSettings.defaultHeaderSpace;
      final String? modeRaw = prefs.getString(browserModePrefKey);
      final BrowserPrintMode mode = _modeFromRaw(modeRaw);
      final int browserWidth =
          prefs.getInt(browserWidthPrefKey) ??
          PrintSettings.defaultBrowserPixelWidth;
      final bool autoClose =
          prefs.getBool(browserAutoClosePrefKey) ??
          PrintSettings.defaultBrowserAutoClose;
      return PrintSettings(
        scale: scale,
        postFeed: postFeed,
        headerSpace: headerSpace,
        browserMode: mode,
        browserPixelWidth: browserWidth,
        browserAutoClose: autoClose,
      );
    } catch (e) {
      debugPrint('Error loading cached print settings: $e');
      return null;
    }
  }

  Future<void> _saveToLocal(PrintSettings settings) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setDouble(scalePrefKey, settings.scale);
      await prefs.setInt(postFeedPrefKey, settings.postFeed);
      await prefs.setInt(headerSpacePrefKey, settings.headerSpace);
      await prefs.setString(browserModePrefKey, settings.browserMode.name);
      await prefs.setInt(browserWidthPrefKey, settings.browserPixelWidth);
      await prefs.setBool(browserAutoClosePrefKey, settings.browserAutoClose);
    } catch (e) {
      debugPrint('Error caching print settings locally: $e');
    }
  }
}

BrowserPrintMode _modeFromRaw(String? raw) {
  if (raw == BrowserPrintMode.html.name || raw == 'html') {
    return BrowserPrintMode.html;
  }
  return BrowserPrintMode.png;
}
