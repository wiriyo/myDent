// v1.1.0 - Added getAppointmentById function
// 📁 lib/services/appointment_service.dart

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import '../models/appointment_model.dart'; 
import '../models/patient.dart';
import '../services/patient_service.dart';
import '../config/feature_flags.dart';

class AppointmentService {
  // Optional clinic scoping if needed in future
  final String? clinicId;
  AppointmentService({this.clinicId});
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final CollectionReference _rootAppointments = FirebaseFirestore.instance.collection('appointments');

  // Base reference depending on feature flags
  CollectionReference<Map<String, dynamic>> get _primaryAppointments {
    if (FeatureFlags.useNestedCollections && clinicId != null && clinicId!.isNotEmpty) {
      return _firestore.collection('clinics').doc(clinicId).collection('appointments');
    }
    return _rootAppointments.withConverter<Map<String, dynamic>>(
      fromFirestore: (s, _) => s.data() ?? <String, dynamic>{},
      toFirestore: (m, _) => m,
    );
  }

  CollectionReference<Map<String, dynamic>>? get _nestedAppointmentsOrNull {
    if (clinicId != null && clinicId!.isNotEmpty) {
      return _firestore.collection('clinics').doc(clinicId).collection('appointments');
    }
    return null;
  }

  Future<void> addAppointment(AppointmentModel appointment) async {
    // if (await _isTimeSlotConflict(appointment.startTime, appointment.endTime)) {
    //   throw Exception("ช่วงเวลานี้มีการนัดหมายอื่นอยู่แล้ว");
    // }

    try {
      // Generate a single docId to be used across primary and legacy/root writes
      final primaryRef = _primaryAppointments;
      final docRef = primaryRef.doc();
      final payload = {
        ...appointment.toMap(),
        'clinicId': clinicId ?? appointment.clinicId,
        'appointmentId': docRef.id,
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      };

      final futures = <Future>[];
      futures.add(docRef.set(payload));

      // Dual-write: ensure both nested and root have the same document id and data
      if (FeatureFlags.dualWriteEnabled) {
        // Write to root
        futures.add(_rootAppointments.doc(docRef.id).set(payload));
        // Write to nested (if clinicId is available)
        final nested = _nestedAppointmentsOrNull;
        if (nested != null) {
          futures.add(nested.doc(docRef.id).set(payload));
        }
      }

      await Future.wait(futures);
    } catch (e) {
      debugPrint("Error adding appointment: $e");
      rethrow;
    }
  }

  Future<void> updateAppointment(AppointmentModel appointment) async {
    try {
      final payload = {
        ...appointment.toMap(),
        'clinicId': clinicId ?? appointment.clinicId,
        'updatedAt': FieldValue.serverTimestamp(),
      };

      final futures = <Future>[];
      futures.add(_primaryAppointments.doc(appointment.appointmentId).update(payload));

      if (FeatureFlags.dualWriteEnabled) {
        futures.add(_rootAppointments.doc(appointment.appointmentId).update(payload));
        final nested = _nestedAppointmentsOrNull;
        if (nested != null) {
          futures.add(nested.doc(appointment.appointmentId).update(payload));
        }
      }

      await Future.wait(futures);
    } catch (e) {
      debugPrint("Error updating appointment: $e");
      rethrow;
    }
  }

  // ✨ [ADDED v1.1.0] เพิ่มฟังก์ชันสำหรับดึงข้อมูลนัดหมายฉบับเต็มจาก ID ค่ะ
  // ฟังก์ชันนี้จำเป็นสำหรับหน้าค้นหา เพื่อให้สามารถเปิดดูรายละเอียดนัดหมายได้ค่ะ
  Future<AppointmentModel?> getAppointmentById(String appointmentId) async {
    try {
      // Try primary path first
      final primarySnap = await _primaryAppointments.doc(appointmentId).get();
      if (primarySnap.exists) {
        return AppointmentModel.fromFirestore(primarySnap as DocumentSnapshot<Map<String, dynamic>>);
      }
      // Fallback to root if enabled
      if (FeatureFlags.dualReadFallbackEnabled) {
        final rootSnap = await _rootAppointments.doc(appointmentId).get();
        if (rootSnap.exists) {
          return AppointmentModel.fromFirestore(rootSnap as DocumentSnapshot<Map<String, dynamic>>);
        }
      }
      return null;
    } catch (e) {
      debugPrint("Error fetching appointment by ID: $e");
      return null;
    }
  }

  Future<List<AppointmentModel>> getAppointmentsByDate(DateTime selectedDate) async {
    final startOfDay = DateTime(selectedDate.year, selectedDate.month, selectedDate.day);
    final endOfDay = startOfDay.add(const Duration(days: 1));

    try {
      Query query = _primaryAppointments
          .where('startTime', isGreaterThanOrEqualTo: Timestamp.fromDate(startOfDay))
          .where('startTime', isLessThan: Timestamp.fromDate(endOfDay));
      // When using root as primary, keep clinic filter if provided
      if (!(FeatureFlags.useNestedCollections && clinicId != null && clinicId!.isNotEmpty)) {
        if (clinicId != null && clinicId!.isNotEmpty) {
          query = _rootAppointments
              .where('clinicId', isEqualTo: clinicId)
              .where('startTime', isGreaterThanOrEqualTo: Timestamp.fromDate(startOfDay))
              .where('startTime', isLessThan: Timestamp.fromDate(endOfDay));
        }
      }
      var snapshot = await query.get();

      // Fallback to root if nested primary returns empty
      if (FeatureFlags.dualReadFallbackEnabled && snapshot.docs.isEmpty) {
        final fbQuery = _rootAppointments
            .where('clinicId', isEqualTo: clinicId)
            .where('startTime', isGreaterThanOrEqualTo: Timestamp.fromDate(startOfDay))
            .where('startTime', isLessThan: Timestamp.fromDate(endOfDay));
        snapshot = await fbQuery.get();
      }

      return snapshot.docs
          .map((doc) => AppointmentModel.fromFirestore(doc as DocumentSnapshot<Map<String, dynamic>>))
          .toList();
    } catch (e) {
      debugPrint("Error fetching appointments by date: $e");
      return []; 
    }
  }

  Future<bool> _isTimeSlotConflict(DateTime startTime, DateTime endTime, [String? excludeAppointmentId]) async {
    try {
      Query query = _primaryAppointments
        .where('startTime', isLessThan: Timestamp.fromDate(endTime))
        .where('endTime', isGreaterThan: Timestamp.fromDate(startTime));
      if (!(FeatureFlags.useNestedCollections && clinicId != null && clinicId!.isNotEmpty)) {
        if (clinicId != null && clinicId!.isNotEmpty) {
          query = _rootAppointments
            .where('clinicId', isEqualTo: clinicId)
            .where('startTime', isLessThan: Timestamp.fromDate(endTime))
            .where('endTime', isGreaterThan: Timestamp.fromDate(startTime));
        }
      }
      var querySnapshot = await query.get();

      if (FeatureFlags.dualReadFallbackEnabled && querySnapshot.docs.isEmpty) {
        final fbQuery = _rootAppointments
            .where('clinicId', isEqualTo: clinicId)
            .where('startTime', isLessThan: Timestamp.fromDate(endTime))
            .where('endTime', isGreaterThan: Timestamp.fromDate(startTime));
        querySnapshot = await fbQuery.get();
      }

      if (querySnapshot.docs.isEmpty) {
        return false;
      }

      if (excludeAppointmentId != null) {
        if (querySnapshot.docs.length == 1 && querySnapshot.docs.first.id == excludeAppointmentId) {
          return false;
        }
      }
      
      return true;
    } catch (e) {
      debugPrint("Error checking for time slot conflict: $e");
      return true; 
    }
  }

  Stream<List<AppointmentModel>> getAppointmentsStreamByDate(DateTime selectedDate) {
    final startOfDay = DateTime(selectedDate.year, selectedDate.month, selectedDate.day);
    final endOfDay = startOfDay.add(const Duration(days: 1));

    Query query = _primaryAppointments
        .where('startTime', isGreaterThanOrEqualTo: Timestamp.fromDate(startOfDay))
        .where('startTime', isLessThan: Timestamp.fromDate(endOfDay))
        .orderBy('startTime');
    if (!(FeatureFlags.useNestedCollections && clinicId != null && clinicId!.isNotEmpty)) {
      if (clinicId != null && clinicId!.isNotEmpty) {
        query = _rootAppointments
            .where('clinicId', isEqualTo: clinicId)
            .where('startTime', isGreaterThanOrEqualTo: Timestamp.fromDate(startOfDay))
            .where('startTime', isLessThan: Timestamp.fromDate(endOfDay))
            .orderBy('startTime');
      }
    }
    return query
        .snapshots()
        .map((snapshot) {
          return snapshot.docs
              .map((doc) => AppointmentModel.fromFirestore(doc as DocumentSnapshot<Map<String, dynamic>>))
              .toList();
        });
  }

  Future<Patient?> getPatientById(String patientId) async {
    final PatientService patientService = PatientService(clinicId: clinicId);
    return await patientService.getPatientById(patientId);
  }

  Future<void> deleteAppointment(String appointmentId) async {
    try {
      final futures = <Future>[];
      futures.add(_primaryAppointments.doc(appointmentId).delete());
      if (FeatureFlags.dualWriteEnabled) {
        futures.add(_rootAppointments.doc(appointmentId).delete());
        final nested = _nestedAppointmentsOrNull;
        if (nested != null) {
          futures.add(nested.doc(appointmentId).delete());
        }
      }
      await Future.wait(futures);
    } catch (e) {
      debugPrint('เกิดข้อผิดพลาดในการลบนัดหมาย: $e');
      rethrow;
    }
  }
}
