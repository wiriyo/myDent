// ----------------------------------------------------------------
// 📁 lib/services/appointment_search_service.dart (‼️ NEW FILE)
// v1.0.0 - ✨ Service สำหรับค้นหานัดหมายโดยเฉพาะ
// ----------------------------------------------------------------
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import '../models/appointment_search_model.dart';

class AppointmentSearchService {
  final CollectionReference _appointmentsCollection = FirebaseFirestore.instance.collection('appointments');
  
  Future<Map<String, dynamic>> searchAppointments({
    required String query,
    required int limit,
    DocumentSnapshot? lastDocument,
  }) async {
    if (query.isEmpty) {
      return {'appointments': [], 'lastDocument': null};
    }

    try {
      Query firestoreQuery = _appointmentsCollection
          .where('searchKeywords', arrayContains: query.toLowerCase())
          .orderBy('startTime', descending: true)
          .limit(limit);

      if (lastDocument != null) {
        firestoreQuery = firestoreQuery.startAfterDocument(lastDocument);
      }

      final snapshot = await firestoreQuery.get();
      
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