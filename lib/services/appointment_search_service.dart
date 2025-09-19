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

  Future<Map<String, dynamic>> searchAppointments({
    required String query,
    required int limit,
    DocumentSnapshot? lastDocument,
    String? clinicId,
  }) async {
    final String normalizedQuery = query.trim().toLowerCase();
    if (normalizedQuery.isEmpty) {
      return {'appointments': [], 'lastDocument': null};
    }

    try {
      final List<String> searchTerms = _buildSearchTerms(normalizedQuery);
      if (searchTerms.isEmpty) {
        return {'appointments': [], 'lastDocument': null};
      }

      Query firestoreQuery = _buildBaseQuery(clinicId);
      firestoreQuery = _applySearchFilter(firestoreQuery, searchTerms)
          .orderBy('startTime', descending: true)
          .limit(limit);

      if (lastDocument != null) {
        firestoreQuery = firestoreQuery.startAfterDocument(lastDocument);
      }

      var snapshot = await firestoreQuery.get();

      if (FeatureFlags.dualReadFallbackEnabled && snapshot.docs.isEmpty && clinicId != null && clinicId.isNotEmpty) {
        Query fallbackQuery = _rootAppointments.where('clinicId', isEqualTo: clinicId);
        fallbackQuery = _applySearchFilter(fallbackQuery, searchTerms)
            .orderBy('startTime', descending: true)
            .limit(limit);

        if (lastDocument != null) {
          fallbackQuery = fallbackQuery.startAfterDocument(lastDocument);
        }

        snapshot = await fallbackQuery.get();
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

  Query _buildBaseQuery(String? clinicId) {
    if (FeatureFlags.useNestedCollections && clinicId != null && clinicId.isNotEmpty) {
      return _firestore.collection('clinics').doc(clinicId).collection('appointments');
    }

    Query query = _rootAppointments;
    if (clinicId != null && clinicId.isNotEmpty) {
      query = query.where('clinicId', isEqualTo: clinicId);
    }
    return query;
  }

  Query _applySearchFilter(Query query, List<String> searchTerms) {
    final List<String> limitedTerms = searchTerms.length > 10 ? searchTerms.sublist(0, 10) : searchTerms;

    if (limitedTerms.length == 1) {
      return query.where('searchKeywords', arrayContains: limitedTerms.first);
    }

    return query.where('searchKeywords', arrayContainsAny: limitedTerms);
  }

  List<String> _buildSearchTerms(String normalizedQuery) {
    final Set<String> terms = normalizedQuery
        .split(RegExp(r'\s+'))
        .where((value) => value.trim().isNotEmpty)
        .map((value) => value.trim())
        .toSet();

    if (normalizedQuery.isNotEmpty) {
      terms.add(normalizedQuery);

      final String condensed = normalizedQuery.replaceAll(RegExp(r'\s+'), '');
      if (condensed.isNotEmpty) {
        terms.add(condensed);
      }

      final String numericOnly = normalizedQuery.replaceAll(RegExp(r'[^0-9]'), '');
      if (numericOnly.isNotEmpty) {
        terms.add(numericOnly);
      }
    }

    return terms.toList();
  }
}
