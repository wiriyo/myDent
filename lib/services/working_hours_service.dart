import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import '../models/working_hours_model.dart';
import '../config/feature_flags.dart';
import '../config/clinic_context.dart';

class WorkingHoursService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  DocumentReference<Map<String, dynamic>> _primaryDoc() {
    final clinicId = ClinicContext.activeClinicId;
    if (FeatureFlags.useNestedCollections && clinicId != null && clinicId.isNotEmpty) {
      return _firestore.collection('clinics').doc(clinicId).collection('settings').doc('clinicWorkingHours');
    }
    return _firestore.collection('settings').doc('clinicWorkingHours').withConverter<Map<String, dynamic>>(
      fromFirestore: (s, _) => s.data() ?? <String, dynamic>{},
      toFirestore: (m, _) => m,
    );
  }

  DocumentReference<Map<String, dynamic>> _rootDoc() {
    return _firestore.collection('settings').doc('clinicWorkingHours');
  }

  Future<List<DayWorkingHours>> loadWorkingHours() async {
    try {
      final docSnapshot = await _primaryDoc().get();

      if (docSnapshot.exists && docSnapshot.data() != null) {
        final data = docSnapshot.data() as Map<String, dynamic>;
        return (data['days'] as List<dynamic>)
            .map((json) => DayWorkingHours.fromJson(json))
            .toList();
      } else {
        if (FeatureFlags.dualReadFallbackEnabled) {
          final rootSnap = await _rootDoc().get();
          if (rootSnap.exists && rootSnap.data() != null) {
            final data = rootSnap.data() as Map<String, dynamic>;
            return (data['days'] as List<dynamic>)
                .map((json) => DayWorkingHours.fromJson(json))
                .toList();
          }
        }
        return _buildDefaultWorkingHours();
      }
    } catch (e) {
      debugPrint('Error loading working hours from Firestore: $e');
      // Re-throw to be handled by the UI/FutureBuilder
      throw Exception('เกิดข้อผิดพลาดในการโหลดข้อมูล: $e');
    }
  }

  Future<void> saveWorkingHours(List<DayWorkingHours> workingHours) async {
    final List<Map<String, dynamic>> dataToSave =
        workingHours.map((day) => day.toJson()).toList();

    final payload = {
      'days': dataToSave,
      'lastUpdated': FieldValue.serverTimestamp(),
    };

    final futures = <Future>[];
    futures.add(_primaryDoc().set(payload));
    if (FeatureFlags.dualWriteEnabled) {
      futures.add(_rootDoc().set(payload));
    }
    await Future.wait(futures);
  }

  List<DayWorkingHours> _buildDefaultWorkingHours() {
    return [
      DayWorkingHours(dayName: 'จันทร์', timeSlots: [
        TimeSlot(openTime: const TimeOfDay(hour: 9, minute: 0), closeTime: const TimeOfDay(hour: 12, minute: 0)),
        TimeSlot(openTime: const TimeOfDay(hour: 13, minute: 0), closeTime: const TimeOfDay(hour: 17, minute: 0)),
      ]),
      DayWorkingHours(dayName: 'อังคาร', timeSlots: [
        TimeSlot(openTime: const TimeOfDay(hour: 9, minute: 0), closeTime: const TimeOfDay(hour: 12, minute: 0)),
        TimeSlot(openTime: const TimeOfDay(hour: 13, minute: 0), closeTime: const TimeOfDay(hour: 17, minute: 0)),
      ]),
      DayWorkingHours(dayName: 'พุธ', timeSlots: [
        TimeSlot(openTime: const TimeOfDay(hour: 9, minute: 0), closeTime: const TimeOfDay(hour: 12, minute: 0)),
        TimeSlot(openTime: const TimeOfDay(hour: 13, minute: 0), closeTime: const TimeOfDay(hour: 17, minute: 0)),
      ]),
      DayWorkingHours(dayName: 'พฤหัสบดี', timeSlots: [
        TimeSlot(openTime: const TimeOfDay(hour: 9, minute: 0), closeTime: const TimeOfDay(hour: 12, minute: 0)),
        TimeSlot(openTime: const TimeOfDay(hour: 13, minute: 0), closeTime: const TimeOfDay(hour: 17, minute: 0)),
      ]),
      DayWorkingHours(dayName: 'ศุกร์', timeSlots: [
        TimeSlot(openTime: const TimeOfDay(hour: 9, minute: 0), closeTime: const TimeOfDay(hour: 12, minute: 0)),
        TimeSlot(openTime: const TimeOfDay(hour: 13, minute: 0), closeTime: const TimeOfDay(hour: 17, minute: 0)),
      ]),
      DayWorkingHours(dayName: 'เสาร์', timeSlots: [TimeSlot(openTime: const TimeOfDay(hour: 9, minute: 0), closeTime: const TimeOfDay(hour: 17, minute: 0))]),
      DayWorkingHours(dayName: 'อาทิตย์', isClosed: true, timeSlots: []),
    ];
  }
}
