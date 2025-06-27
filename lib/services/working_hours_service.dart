import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import '../models/working_hours_model.dart';

class WorkingHoursService {
  final CollectionReference _settingsCollection = FirebaseFirestore.instance.collection('settings');

  Future<List<DayWorkingHours>> loadWorkingHours() async {
    try {
      final docSnapshot = await _settingsCollection.doc('clinicWorkingHours').get();

      if (docSnapshot.exists && docSnapshot.data() != null) {
        final data = docSnapshot.data() as Map<String, dynamic>;
        return (data['days'] as List<dynamic>)
            .map((json) => DayWorkingHours.fromJson(json))
            .toList();
      } else {
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

    await _settingsCollection.doc('clinicWorkingHours').set({
      'days': dataToSave,
      'lastUpdated': FieldValue.serverTimestamp(),
    });
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