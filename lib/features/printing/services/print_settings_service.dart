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

  static const String _legacyPrefix = 'mydent.printing';
  static const String scalePrefKey = '$_legacyPrefix.scale';
  static const String postFeedPrefKey = '$_legacyPrefix.postfeed';
  static const String headerSpacePrefKey = '$_legacyPrefix.headerspace';
  static const String browserModePrefKey = '$_legacyPrefix.browser.mode';
  static const String browserWidthPrefKey = '$_legacyPrefix.browser.width';
  static const String browserAutoClosePrefKey =
      '$_legacyPrefix.browser.autoclose';

  static const _LegacyKeys _legacyKeys = _LegacyKeys();

  Future<PrintSettings> load({String? clinicId}) async {
    final local = await _loadFromLocal(clinicId: clinicId);
    if (local != null) {
      return local;
    }
    const defaults = PrintSettings.defaults();
    await _saveToLocal(defaults, clinicId: clinicId);
    return defaults;
  }

  Future<void> save(PrintSettings settings, {String? clinicId}) async {
    await _saveToLocal(settings, clinicId: clinicId);
  }

  Future<PrintSettings?> _loadFromLocal({String? clinicId}) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final _ScopedKeys scoped = _scopedKeys(clinicId: clinicId);
      if (_prefsContains(prefs, scoped)) {
        return _readSettings(prefs, scoped);
      }
      if (_prefsContains(prefs, _legacyKeys)) {
        final PrintSettings migrated = _readSettings(prefs, _legacyKeys);
        await _writeSettings(prefs, migrated, scoped);
        await _clearLegacy(prefs);
        return migrated;
      }
      return null;
    } catch (e) {
      debugPrint('Error loading cached print settings: $e');
      return null;
    }
  }

  Future<void> _saveToLocal(
    PrintSettings settings, {
    String? clinicId,
  }) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final _ScopedKeys scoped = _scopedKeys(clinicId: clinicId);
      await _writeSettings(prefs, settings, scoped);
      await _clearLegacy(prefs);
    } catch (e) {
      debugPrint('Error caching print settings locally: $e');
    }
  }

  static String _platformSegment() {
    if (kIsWeb) return 'web';
    switch (defaultTargetPlatform) {
      case TargetPlatform.android:
        return 'android';
      case TargetPlatform.fuchsia:
        return 'fuchsia';
      case TargetPlatform.iOS:
        return 'ios';
      case TargetPlatform.linux:
        return 'linux';
      case TargetPlatform.macOS:
        return 'macos';
      case TargetPlatform.windows:
        return 'windows';
    }
  }

  static String _clinicSegment(String? clinicId) {
    final String trimmed = clinicId?.trim() ?? '';
    if (trimmed.isEmpty) {
      return 'default';
    }
    final sanitized =
        trimmed.replaceAll(RegExp(r'[^A-Za-z0-9_\-]'), '_').toLowerCase();
    return 'clinic_$sanitized';
  }

  static String _scopedPrefix({String? clinicId}) {
    return '$_legacyPrefix.${_platformSegment()}.${_clinicSegment(clinicId)}';
  }

  static _ScopedKeys _scopedKeys({String? clinicId}) =>
      _ScopedKeys(_scopedPrefix(clinicId: clinicId));

  static bool _prefsContains(SharedPreferences prefs, _KeySet keys) {
    for (final key in keys.values) {
      if (prefs.containsKey(key)) {
        return true;
      }
    }
    return false;
  }

  static PrintSettings _readSettings(
    SharedPreferences prefs,
    _KeySet keys,
  ) {
    final scale =
        prefs.getDouble(keys.scale) ?? PrintSettings.defaultScale;
    final postFeed =
        prefs.getInt(keys.postFeed) ?? PrintSettings.defaultPostFeed;
    final headerSpace =
        prefs.getInt(keys.headerSpace) ?? PrintSettings.defaultHeaderSpace;
    final String? modeRaw = prefs.getString(keys.browserMode);
    final BrowserPrintMode mode = _modeFromRaw(modeRaw);
    final int browserWidth =
        prefs.getInt(keys.browserPixelWidth) ??
        PrintSettings.defaultBrowserPixelWidth;
    final bool autoClose =
        prefs.getBool(keys.browserAutoClose) ??
        PrintSettings.defaultBrowserAutoClose;
    return PrintSettings(
      scale: scale,
      postFeed: postFeed,
      headerSpace: headerSpace,
      browserMode: mode,
      browserPixelWidth: browserWidth,
      browserAutoClose: autoClose,
    );
  }

  static Future<void> _writeSettings(
    SharedPreferences prefs,
    PrintSettings settings,
    _KeySet keys,
  ) async {
    await prefs.setDouble(keys.scale, settings.scale);
    await prefs.setInt(keys.postFeed, settings.postFeed);
    await prefs.setInt(keys.headerSpace, settings.headerSpace);
    await prefs.setString(keys.browserMode, settings.browserMode.name);
    await prefs.setInt(keys.browserPixelWidth, settings.browserPixelWidth);
    await prefs.setBool(keys.browserAutoClose, settings.browserAutoClose);
  }

  static Future<void> _clearLegacy(SharedPreferences prefs) async {
    if (!_prefsContains(prefs, _legacyKeys)) {
      return;
    }
    await prefs.remove(scalePrefKey);
    await prefs.remove(postFeedPrefKey);
    await prefs.remove(headerSpacePrefKey);
    await prefs.remove(browserModePrefKey);
    await prefs.remove(browserWidthPrefKey);
    await prefs.remove(browserAutoClosePrefKey);
  }

  @visibleForTesting
  static PrintSettingsStorageKeys storageKeysForTesting({String? clinicId}) {
    final _ScopedKeys keys = _scopedKeys(clinicId: clinicId);
    return PrintSettingsStorageKeys._(
      scale: keys.scale,
      postFeed: keys.postFeed,
      headerSpace: keys.headerSpace,
      browserMode: keys.browserMode,
      browserPixelWidth: keys.browserPixelWidth,
      browserAutoClose: keys.browserAutoClose,
    );
  }
}

abstract class _KeySet {
  String get scale;
  String get postFeed;
  String get headerSpace;
  String get browserMode;
  String get browserPixelWidth;
  String get browserAutoClose;

  Iterable<String> get values => <String>[
        scale,
        postFeed,
        headerSpace,
        browserMode,
        browserPixelWidth,
        browserAutoClose,
      ];
}

class _ScopedKeys implements _KeySet {
  _ScopedKeys(String prefix) : _prefix = prefix;

  final String _prefix;

  @override
  String get scale => '$_prefix.scale';
  @override
  String get postFeed => '$_prefix.postfeed';
  @override
  String get headerSpace => '$_prefix.headerspace';
  @override
  String get browserMode => '$_prefix.browser.mode';
  @override
  String get browserPixelWidth => '$_prefix.browser.width';
  @override
  String get browserAutoClose => '$_prefix.browser.autoclose';

  @override
  Iterable<String> get values => <String>[
        scale,
        postFeed,
        headerSpace,
        browserMode,
        browserPixelWidth,
        browserAutoClose,
      ];
}

class _LegacyKeys implements _KeySet {
  const _LegacyKeys();

  @override
  String get scale => PrintSettingsService.scalePrefKey;
  @override
  String get postFeed => PrintSettingsService.postFeedPrefKey;
  @override
  String get headerSpace => PrintSettingsService.headerSpacePrefKey;
  @override
  String get browserMode => PrintSettingsService.browserModePrefKey;
  @override
  String get browserPixelWidth => PrintSettingsService.browserWidthPrefKey;
  @override
  String get browserAutoClose =>
      PrintSettingsService.browserAutoClosePrefKey;

  @override
  Iterable<String> get values => <String>[
        scale,
        postFeed,
        headerSpace,
        browserMode,
        browserPixelWidth,
        browserAutoClose,
      ];
}

class PrintSettingsStorageKeys {
  const PrintSettingsStorageKeys._({
    required this.scale,
    required this.postFeed,
    required this.headerSpace,
    required this.browserMode,
    required this.browserPixelWidth,
    required this.browserAutoClose,
  });

  final String scale;
  final String postFeed;
  final String headerSpace;
  final String browserMode;
  final String browserPixelWidth;
  final String browserAutoClose;
}

BrowserPrintMode _modeFromRaw(String? raw) {
  if (raw == BrowserPrintMode.html.name || raw == 'html') {
    return BrowserPrintMode.html;
  }
  return BrowserPrintMode.png;
}
