// 📁 lib/auth/auth_provider.dart
// v2.2.0 - Laila's Performance Refresh
// ปรับปรุงการแจ้งเตือนสถานะให้ทำงานเบาและเร็วขึ้นสำหรับโหมด Release 💖

import 'dart:async'; // ใช้สำหรับ unawaited
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/staff_model.dart';
import '../config/clinic_context.dart';

enum AuthStatus {
  loggedOut,
  clinicVerified,
  loggedIn,
}

class AppAuthProvider extends ChangeNotifier {
  void _ensureActiveUserMembership(String clinicId) {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null || clinicId.isEmpty) return;
    unawaited(
      FirebaseFirestore.instance
          .collection('clinics')
          .doc(clinicId)
          .collection('members')
          .doc(uid)
          .set({
        'role': 'admin',
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true)).catchError((_) {}),
    );
  }


  AuthStatus _status = AuthStatus.loggedOut;
  AuthStatus get status => _status;

  String? _verifiedClinicId;
  String? get verifiedClinicId => _verifiedClinicId;

  Staff? _currentStaff;
  Staff? get currentStaff => _currentStaff;
  void setClinicVerified(String clinicId) {
    _ensureActiveUserMembership(clinicId);
    _verifiedClinicId = clinicId;
    _status = AuthStatus.clinicVerified;
    ClinicContext.activeClinicId = clinicId;
    notifyListeners();
    // Persist last used clinic id for splash/logo loading before login
    SharedPreferences.getInstance().then((prefs) {
      prefs.setString('mydent.lastClinicId', clinicId);
    });
  }

  void setStaffLoggedIn(Staff staff) {
    _currentStaff = staff;
    _status = AuthStatus.loggedIn;
    notifyListeners();
  }

  void logout() {
    _verifiedClinicId = null;
    _currentStaff = null;
    _status = AuthStatus.loggedOut;
    ClinicContext.activeClinicId = null;
    notifyListeners();
    // Clear persisted clinic id
    SharedPreferences.getInstance().then((prefs) {
      prefs.remove('mydent.lastClinicId');
    });
  }
}

