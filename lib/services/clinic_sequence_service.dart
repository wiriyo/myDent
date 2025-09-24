import 'package:cloud_firestore/cloud_firestore.dart';

import '../config/clinic_context.dart';
import '../config/feature_flags.dart';

class ClinicSequenceResult {
  final int year;
  final int counter;
  final String value;

  const ClinicSequenceResult({
    required this.year,
    required this.counter,
    required this.value,
  });
}

class ClinicSequenceSeed {
  final int year;
  final int counter;

  const ClinicSequenceSeed({
    required this.year,
    required this.counter,
  });
}

class ClinicSequenceService {
  ClinicSequenceService({this.clinicId});

  final String? clinicId;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  DocumentReference<Map<String, dynamic>>? get _docRef {
    final effectiveClinicId = clinicId ?? ClinicContext.activeClinicId;
    if (FeatureFlags.useNestedCollections) {
      if (effectiveClinicId == null || effectiveClinicId.isEmpty) {
        return null;
      }
      return _firestore
          .collection('clinics')
          .doc(effectiveClinicId)
          .collection('settings')
          .doc('counters');
    }
    if (effectiveClinicId != null && effectiveClinicId.isNotEmpty) {
      return _firestore
          .collection('clinics')
          .doc(effectiveClinicId)
          .collection('settings')
          .doc('counters');
    }
    return _firestore.collection('settings').doc('counters');
  }

  Future<ClinicSequenceSeed?> _resolveSeed(
    String key,
    Future<ClinicSequenceSeed?> Function()? resolver,
  ) async {
    if (resolver == null) return null;
    final docRef = _docRef;
    if (docRef == null) {
      return await resolver();
    }
    try {
      final snapshot = await docRef.get();
      final data = snapshot.data();
      final Map<String, dynamic>? entry =
          data != null ? (data[key] as Map<String, dynamic>?) : null;
      final hasYear = entry != null && entry['year'] != null;
      final hasCounter = entry != null && entry['counter'] != null;
      if (hasYear && hasCounter) return null;
    } catch (_) {
      // Ignore and fallback to resolver
    }
    return await resolver();
  }

  Future<ClinicSequenceResult> _next({
    required String key,
    required int currentYear,
    required String Function(int year, int counter) formatter,
    Future<ClinicSequenceSeed?> Function()? seedResolver,
  }) async {
    final docRef = _docRef;
    if (docRef == null) {
      throw StateError('Clinic id is not set for sequence "$key"');
    }

    final seed = await _resolveSeed(key, seedResolver);

    return _firestore.runTransaction((transaction) async {
      final snapshot = await transaction.get(docRef);
      final data = snapshot.data();
      final Map<String, dynamic>? entry =
          data != null ? (data[key] as Map<String, dynamic>?) : null;

      int baseYear = entry?['year'] as int? ?? seed?.year ?? currentYear;
      int baseCounter = entry?['counter'] as int? ?? seed?.counter ?? 0;

      if (baseYear != currentYear) {
        baseYear = currentYear;
        baseCounter = 0;
      }

      final nextCounter = baseCounter + 1;
      final formatted = formatter(baseYear, nextCounter);

      transaction.set(
        docRef,
        {
          key: {
            'year': baseYear,
            'counter': nextCounter,
            'lastValue': formatted,
            'updatedAt': FieldValue.serverTimestamp(),
          },
          'updatedAt': FieldValue.serverTimestamp(),
        },
        SetOptions(merge: true),
      );

      return ClinicSequenceResult(
        year: baseYear,
        counter: nextCounter,
        value: formatted,
      );
    });
  }

  Future<ClinicSequenceResult?> _peek({
    required String key,
    required String Function(int year, int counter) formatter,
  }) async {
    final docRef = _docRef;
    if (docRef == null) return null;
    final snapshot = await docRef.get();
    final data = snapshot.data();
    final Map<String, dynamic>? entry =
        data != null ? (data[key] as Map<String, dynamic>?) : null;
    final int? year = entry?['year'] as int?;
    final int? counter = entry?['counter'] as int?;
    if (year == null || counter == null) return null;
    final String value =
        (entry?['lastValue'] as String?) ?? formatter(year, counter);
    return ClinicSequenceResult(year: year, counter: counter, value: value);
  }

  Future<ClinicSequenceResult> nextHn({
    Future<ClinicSequenceSeed?> Function()? seedResolver,
  }) async {
    final now = DateTime.now();
    final buddhistYear = now.year + 543;
    return _next(
      key: 'hn',
      currentYear: buddhistYear,
      formatter: (year, counter) {
        final prefix = (year % 100).toString().padLeft(2, '0');
        return 'HN-$prefix-${counter.toString().padLeft(4, '0')}';
      },
      seedResolver: seedResolver,
    );
  }

  Future<ClinicSequenceResult> nextReceipt() async {
    final now = DateTime.now();
    final buddhistYear = now.year + 543;
    return _next(
      key: 'receipt',
      currentYear: buddhistYear,
      formatter: (year, counter) {
        final prefix = (year % 100).toString().padLeft(2, '0');
        return '$prefix-${counter.toString().padLeft(3, '0')}';
      },
    );
  }

  Future<ClinicSequenceResult?> peekReceipt() async {
    return _peek(
      key: 'receipt',
      formatter: (year, counter) {
        final prefix = (year % 100).toString().padLeft(2, '0');
        return '$prefix-${counter.toString().padLeft(3, '0')}';
      },
    );
  }

  Future<void> overrideReceiptCounter(int counter, {int? year}) async {
    final docRef = _docRef;
    if (docRef == null) {
      throw StateError('Clinic id is not set for sequence "receipt"');
    }
    final now = DateTime.now();
    final buddhistYear = year ?? (now.year + 543);
    final value = '${(buddhistYear % 100).toString().padLeft(2, '0')}-'
        '${counter.toString().padLeft(3, '0')}';
    await docRef.set(
      {
        'receipt': {
          'year': buddhistYear,
          'counter': counter,
          'lastValue': value,
          'updatedAt': FieldValue.serverTimestamp(),
        },
        'updatedAt': FieldValue.serverTimestamp(),
      },
      SetOptions(merge: true),
    );
  }
}
