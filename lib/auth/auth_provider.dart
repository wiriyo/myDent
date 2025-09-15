// 📁 lib/auth/auth_provider.dart
// v2.1.0 - Laila's Stream Upgrade
// เราจะเพิ่ม "โทรศัพท์สายตรง" (Stream) เพื่อแก้ปัญหา UI ไม่อัปเดตค่ะ! 💖

import 'dart:async'; // 1. ✨ Import 'dart:async' สำหรับ StreamController
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/staff_model.dart';
import '../config/clinic_context.dart';

enum AuthStatus {
  loggedOut,
  clinicVerified,
  loggedIn,
}

class AppAuthProvider extends ChangeNotifier {
  AuthStatus _status = AuthStatus.loggedOut;
  AuthStatus get status => _status;

  String? _verifiedClinicId;
  String? get verifiedClinicId => _verifiedClinicId;

  Staff? _currentStaff;
  Staff? get currentStaff => _currentStaff;

  // 2. ✨ สร้าง StreamController หรือ "ชุมสายโทรศัพท์" ของเรา
  // .broadcast ทำให้มีคน "ดักฟัง" สายนี้ได้หลายคนพร้อมกันค่ะ
  final _statusStreamController = StreamController<AuthStatus>.broadcast();
  Stream<AuthStatus> get statusStream => _statusStreamController.stream;

  @override
  void dispose() {
    _statusStreamController.close(); // 3. ✨ อย่าลืมปิดสายโทรศัพท์เมื่อไม่ใช้แล้วนะคะ
    super.dispose();
  }

  // 4. ✨ ทุกครั้งที่เราเปลี่ยนสถานะ เราจะ "โทรออก" ผ่าน Stream ด้วย
  void setClinicVerified(String clinicId) {
    _verifiedClinicId = clinicId;
    _status = AuthStatus.clinicVerified;
    ClinicContext.activeClinicId = clinicId;
    _statusStreamController.add(_status); // โทรออก!
    notifyListeners();
    // Persist last used clinic id for splash/logo loading before login
    SharedPreferences.getInstance().then((prefs) {
      prefs.setString('mydent.lastClinicId', clinicId);
    });
  }

  void setStaffLoggedIn(Staff staff) {
    _currentStaff = staff;
    _status = AuthStatus.loggedIn;
    _statusStreamController.add(_status); // โทรออก!
    notifyListeners();
  }

  void logout() {
    _verifiedClinicId = null;
    _currentStaff = null;
    _status = AuthStatus.loggedOut;
    ClinicContext.activeClinicId = null;
    _statusStreamController.add(_status); // โทรออก!
    notifyListeners();
    // Clear persisted clinic id
    SharedPreferences.getInstance().then((prefs) {
      prefs.remove('mydent.lastClinicId');
    });
  }
}

