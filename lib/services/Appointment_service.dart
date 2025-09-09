// v1.2.0 - Nested collections + dual path support
// 📁 lib/services/appointment_service.dart

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import '../models/appointment_model.dart';
import '../models/patient.dart';
import '../services/patient_service.dart';
import '../config/feature_flags.dart';
import '../config/clinic_context.dart';

class AppointmentService {
  final String? clinicId; // optional: if null, fallback to ClinicContext
  AppointmentService({this.clinicId});

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final CollectionReference _rootAppointments =
      FirebaseFirestore.instance.collection('appointments');

  String? get _effectiveClinicId => clinicId ?? ClinicContext.activeClinicId;

  // Primary base ref depends on flags + clinic scope
  CollectionReference<Map<String, dynamic>> get _primaryAppointments {
    final id = _effectiveClinicId;
    if (FeatureFlags.useNestedCollections && id != null && id.isNotEmpty) {
      return _firestore.collection('clinics').doc(id).collection('appointments');
    }
    return _rootAppointments.withConverter<Map<String, dynamic>>(
      fromFirestore: (s, _) => s.data() ?? <String, dynamic>{},
      toFirestore: (m, _) => m,
    );
  }

  CollectionReference<Map<String, dynamic>>? get _nestedAppointmentsOrNull {
    final id = _effectiveClinicId;
    if (id != null && id.isNotEmpty) {
      return _firestore.collection('clinics').doc(id).collection('appointments');
    }
    return null;
  }

  Future<void> addAppointment(AppointmentModel appointment) async {
    try {
      final primaryRef = _primaryAppointments;
      final docRef = primaryRef.doc();
      final payload = {
        ...appointment.toMap(),
        'clinicId': _effectiveClinicId ?? appointment.clinicId,
        'appointmentId': docRef.id,
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      };

      final futures = <Future>[];
      futures.add(docRef.set(payload));

      if (FeatureFlags.dualWriteEnabled) {
        // Write root
        futures.add(_rootAppointments.doc(docRef.id).set(payload));
        // Write nested (if available and not already primary)
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
        'clinicId': _effectiveClinicId ?? appointment.clinicId,
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

  Future<AppointmentModel?> getAppointmentById(String appointmentId) async {
    try {
      final primarySnap = await _primaryAppointments.doc(appointmentId).get();
      if (primarySnap.exists) {
        return AppointmentModel.fromFirestore(primarySnap);
      }
      if (FeatureFlags.dualReadFallbackEnabled) {
        final rootSnap = await _rootAppointments.doc(appointmentId).get();
        if (rootSnap.exists) {
          return AppointmentModel.fromFirestore(rootSnap);
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

      final id = _effectiveClinicId;
      // If primary is root, keep clinic filter
      if (!(FeatureFlags.useNestedCollections && id != null && id.isNotEmpty)) {
        if (id != null && id.isNotEmpty) {
          query = _rootAppointments
              .where('clinicId', isEqualTo: id)
              .where('startTime', isGreaterThanOrEqualTo: Timestamp.fromDate(startOfDay))
              .where('startTime', isLessThan: Timestamp.fromDate(endOfDay));
        }
      }

      var snapshot = await query.get();

      if (FeatureFlags.dualReadFallbackEnabled && snapshot.docs.isEmpty) {
        final fbQuery = _rootAppointments
            .where('clinicId', isEqualTo: id)
            .where('startTime', isGreaterThanOrEqualTo: Timestamp.fromDate(startOfDay))
            .where('startTime', isLessThan: Timestamp.fromDate(endOfDay));
        snapshot = await fbQuery.get();
      }

      return snapshot.docs
          .map((doc) => AppointmentModel.fromFirestore(doc))
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

      final id = _effectiveClinicId;
      if (!(FeatureFlags.useNestedCollections && id != null && id.isNotEmpty)) {
        if (id != null && id.isNotEmpty) {
          query = _rootAppointments
              .where('clinicId', isEqualTo: id)
              .where('startTime', isLessThan: Timestamp.fromDate(endTime))
              .where('endTime', isGreaterThan: Timestamp.fromDate(startTime));
        }
      }

      var querySnapshot = await query.get();

      if (FeatureFlags.dualReadFallbackEnabled && querySnapshot.docs.isEmpty) {
        final fbQuery = _rootAppointments
            .where('clinicId', isEqualTo: id)
            .where('startTime', isLessThan: Timestamp.fromDate(endTime))
            .where('endTime', isGreaterThan: Timestamp.fromDate(startTime));
        querySnapshot = await fbQuery.get();
      }

      if (querySnapshot.docs.isEmpty) return false;

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

    final id = _effectiveClinicId;
    if (!(FeatureFlags.useNestedCollections && id != null && id.isNotEmpty)) {
      if (id != null && id.isNotEmpty) {
        query = _rootAppointments
            .where('clinicId', isEqualTo: id)
            .where('startTime', isGreaterThanOrEqualTo: Timestamp.fromDate(startOfDay))
            .where('startTime', isLessThan: Timestamp.fromDate(endOfDay))
            .orderBy('startTime');
      }
    }

    return query.snapshots().map((snapshot) {
      return snapshot.docs
          .map((doc) => AppointmentModel.fromFirestore(doc))
          .toList();
    });
  }

  Future<Patient?> getPatientById(String patientId) async {
    final PatientService patientService = PatientService(clinicId: _effectiveClinicId);
    return await patientService.getPatientById(patientId);
  }

  Future<void> deleteAppointment(String appointmentId) async {
    try {
      final futures = <Future>[];
      futures.add(_primaryAppointments.doc(appointmentId).delete());
      if (FeatureFlags.dualWriteEnabled) {
        futures.add(_rootAppointments.doc(appointmentId).delete());
        final nested = _nestedAppointmentsOrNull;
        if (nested != null) futures.add(nested.doc(appointmentId).delete());
      }
      await Future.wait(futures);
    } catch (e) {
      debugPrint('เกิดข้อผิดพลาดในการลบนัดหมาย: $e');
      rethrow;
    }
  }
}

