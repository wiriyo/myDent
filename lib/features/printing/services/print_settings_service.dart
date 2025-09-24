import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../config/clinic_context.dart';
import '../../../config/feature_flags.dart';

class PrintSettings {
  static const double defaultScale = 1.0;
  static const int defaultPostFeed = 3;
  static const int defaultHeaderSpace = 0;

  static const double minScale = 0.5;
  static const double maxScale = 2.0;
  static const int minPostFeed = 0;
  static const int maxPostFeed = 10;
  static const int minHeaderSpace = 0;
  static const int maxHeaderSpace = 50;

  final double scale;
  final int postFeed;
  final int headerSpace;

  const PrintSettings._(this.scale, this.postFeed, this.headerSpace);

  const PrintSettings.defaults()
      : this._(defaultScale, defaultPostFeed, defaultHeaderSpace);

  factory PrintSettings({
    required double scale,
    required int postFeed,
    required int headerSpace,
  }) {
    final clampedScale = scale.clamp(minScale, maxScale).toDouble();
    final clampedPostFeed = postFeed.clamp(minPostFeed, maxPostFeed).toInt();
    final clampedHeaderSpace =
        headerSpace.clamp(minHeaderSpace, maxHeaderSpace).toInt();
    return PrintSettings._(clampedScale, clampedPostFeed, clampedHeaderSpace);
  }

  PrintSettings copyWith({double? scale, int? postFeed, int? headerSpace}) {
    return PrintSettings(
      scale: scale ?? this.scale,
      postFeed: postFeed ?? this.postFeed,
      headerSpace: headerSpace ?? this.headerSpace,
    );
  }

  Map<String, dynamic> toMap() => <String, dynamic>{
        'scale': scale,
        'postFeed': postFeed,
        'headerSpace': headerSpace,
      };

  static PrintSettings fromMap(Map<String, dynamic>? data) {
    if (data == null) {
      return const PrintSettings.defaults();
    }
    final scale = (data['scale'] as num?)?.toDouble();
    final postFeed = (data['postFeed'] as num?)?.toInt();
    final headerSpace = (data['headerSpace'] as num?)?.toInt();
    return PrintSettings(
      scale: scale ?? defaultScale,
      postFeed: postFeed ?? defaultPostFeed,
      headerSpace: headerSpace ?? defaultHeaderSpace,
    );
  }
}

class PrintSettingsService {
  PrintSettingsService({FirebaseFirestore? firestore})
      : _firestore = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _firestore;

  static const String scalePrefKey = 'mydent.printing.scale';
  static const String postFeedPrefKey = 'mydent.printing.postfeed';
  static const String headerSpacePrefKey = 'mydent.printing.headerspace';

  DocumentReference<Map<String, dynamic>> _primaryDoc(String clinicId) {
    if (FeatureFlags.useNestedCollections && clinicId.isNotEmpty) {
      return _firestore
          .collection('clinics')
          .doc(clinicId)
          .collection('settings')
          .doc('printerSettings');
    }
    return _rootDoc();
  }

  DocumentReference<Map<String, dynamic>> _rootDoc() {
    return _firestore.collection('settings').doc('printerSettings');
  }

  String _effectiveClinicId(String? provided) {
    final id = provided ?? ClinicContext.activeClinicId;
    return id ?? '';
  }

  Future<PrintSettings> load({String? clinicId}) async {
    final id = _effectiveClinicId(clinicId);
    PrintSettings? firestoreSettings;

    if (id.isNotEmpty) {
      firestoreSettings = await _fetchFromFirestore(id);
      if (firestoreSettings == null && FeatureFlags.dualReadFallbackEnabled) {
        firestoreSettings = await _fetchFromRoot();
      }
    }

    if (firestoreSettings != null) {
      await _saveToLocal(firestoreSettings);
      return firestoreSettings;
    }

    final local = await _loadFromLocal();
    if (local != null) {
      if (id.isNotEmpty) {
        try {
          await _writeToFirestore(id, local);
        } catch (e) {
          debugPrint('Failed to sync local print settings to Firestore: $e');
        }
      }
      return local;
    }

    return const PrintSettings.defaults();
  }

  Future<void> save(PrintSettings settings, {String? clinicId}) async {
    await _saveToLocal(settings);
    final id = _effectiveClinicId(clinicId);
    if (id.isEmpty) {
      return;
    }
    await _writeToFirestore(id, settings);
  }

  Future<PrintSettings?> _fetchFromFirestore(String clinicId) async {
    try {
      final snap = await _primaryDoc(clinicId).get();
      if (!snap.exists) return null;
      return PrintSettings.fromMap(snap.data());
    } catch (e) {
      debugPrint('Error loading print settings from Firestore: $e');
      return null;
    }
  }

  Future<PrintSettings?> _fetchFromRoot() async {
    try {
      final snap = await _rootDoc().get();
      if (!snap.exists) return null;
      return PrintSettings.fromMap(snap.data());
    } catch (e) {
      debugPrint('Error loading fallback print settings: $e');
      return null;
    }
  }

  Future<void> _writeToFirestore(String clinicId, PrintSettings settings) async {
    final payload = <String, dynamic>{
      ...settings.toMap(),
      'updatedAt': FieldValue.serverTimestamp(),
    };

    final futures = <Future<void>>[
      _primaryDoc(clinicId).set(payload, SetOptions(merge: true)),
    ];
    if (FeatureFlags.dualWriteEnabled) {
      futures.add(_rootDoc().set(payload, SetOptions(merge: true)));
    }
    await Future.wait(futures);
  }

  Future<PrintSettings?> _loadFromLocal() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      if (!prefs.containsKey(scalePrefKey) &&
          !prefs.containsKey(postFeedPrefKey) &&
          !prefs.containsKey(headerSpacePrefKey)) {
        return null;
      }
      final scale = prefs.getDouble(scalePrefKey) ?? PrintSettings.defaultScale;
      final postFeed =
          prefs.getInt(postFeedPrefKey) ?? PrintSettings.defaultPostFeed;
      final headerSpace = prefs.getInt(headerSpacePrefKey) ??
          PrintSettings.defaultHeaderSpace;
      return PrintSettings(
        scale: scale,
        postFeed: postFeed,
        headerSpace: headerSpace,
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
    } catch (e) {
      debugPrint('Error caching print settings locally: $e');
    }
  }
}
