// ----------------------------------------------------------------
// 📁 lib/services/appointment_search_service.dart (‼️ NEW FILE)
// v1.0.0 - ✨ Service สำหรับค้นหานัดหมายโดยเฉพาะ
// ----------------------------------------------------------------
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import '../models/appointment_search_model.dart';
import '../config/feature_flags.dart';

class AppointmentSearchService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final CollectionReference _rootAppointments = FirebaseFirestore.instance.collection('appointments');

  CollectionReference<Map<String, dynamic>> _primaryRef(String? clinicId) {
    if (FeatureFlags.useNestedCollections && clinicId != null && clinicId.isNotEmpty) {
      return _firestore.collection('clinics').doc(clinicId).collection('appointments');
    }
    return _rootAppointments.withConverter<Map<String, dynamic>>(
      fromFirestore: (s, _) => s.data() ?? <String, dynamic>{},
      toFirestore: (m, _) => m,
    );
  }
  
  Future<Map<String, dynamic>> searchAppointments({
    required String query,
    required int limit,
    DocumentSnapshot? lastDocument,
    String? clinicId,
  }) async {
    if (query.isEmpty) {
      return {'appointments': [], 'lastDocument': null};
    }

    try {
      Query firestoreQuery = _primaryRef(clinicId)
          .where('searchKeywords', arrayContains: query.toLowerCase())
          .orderBy('startTime', descending: true)
          .limit(limit);

      if (!(FeatureFlags.useNestedCollections && clinicId != null && clinicId.isNotEmpty)) {
        if (clinicId != null && clinicId.isNotEmpty) {
          firestoreQuery = _rootAppointments
              .where('clinicId', isEqualTo: clinicId)
              .where('searchKeywords', arrayContains: query.toLowerCase())
              .orderBy('startTime', descending: true)
              .limit(limit);
        }
      }

      if (lastDocument != null) {
        firestoreQuery = firestoreQuery.startAfterDocument(lastDocument);
      }

      var snapshot = await firestoreQuery.get();

      if (FeatureFlags.dualReadFallbackEnabled && snapshot.docs.isEmpty && clinicId != null && clinicId.isNotEmpty) {
        final fbQuery = _rootAppointments
            .where('clinicId', isEqualTo: clinicId)
            .where('searchKeywords', arrayContains: query.toLowerCase())
            .orderBy('startTime', descending: true)
            .limit(limit);
        snapshot = await fbQuery.get();
      }
      
      final appointments = snapshot.docs.map((doc) {
        return AppointmentSearchModel.fromFirestore(doc);
      }).toList();

      return {
        'appointments': appointments,
        'lastDocument': snapshot.docs.isNotEmpty ? snapshot.docs.last : null,
      };

    } catch (e) {
      debugPrint("❌ Error searching appointments: $e");
      rethrow;
    }
  }
}
