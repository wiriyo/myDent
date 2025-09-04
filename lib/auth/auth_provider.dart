// 📁 lib/auth/auth_provider.dart
// v2.1.0 - Laila's Renaming Fix
// ไลลาเปลี่ยนชื่อคลาสจาก AuthProvider เป็น AppAuthProvider เพื่อแก้ปัญหาชื่อซ้ำ (ambiguous import) กับของ Firebase ค่ะ 💖

import 'package:flutter/foundation.dart';

// ✨ 1. สร้างโมเดลสำหรับเก็บข้อมูลพนักงาน (Staff) ค่ะ
// เราจะได้จัดการข้อมูลพนักงานที่ Login เข้ามาได้ง่าย ๆ ค่ะ
class Staff {
  final String uid; // อาจจะเป็น document ID ของ staff ใน Firestore
  final String name;
  final String username;
  final String role;

  Staff({
    required this.uid,
    required this.name,
    required this.username,
    required this.role,
  });

  // สร้าง factory constructor สำหรับแปลง Map จาก Firestore มาเป็น Object Staff
  factory Staff.fromMap(String uid, Map<String, dynamic> data) {
    return Staff(
      uid: uid,
      name: data['name'] ?? 'N/A',
      username: data['username'] ?? 'N/A',
      role: data['role'] ?? 'guest',
    );
  }
}


// ✨ 2. สร้าง Enum เพื่อบอกสถานะการ Login ของแอปค่ะ
// จะทำให้โค้ดของเราอ่านง่ายและจัดการสถานะได้ชัดเจนขึ้นเยอะเลย
enum AuthStatus {
  loggedOut,        // ยังไม่ได้ Login เลย (อยู่หน้าแรกสุด)
  clinicVerified,   // Login ด่านแรกผ่านแล้ว (อยู่หน้า Staff Login)
  loggedIn,         // Login ด่านสองผ่านแล้ว (เข้าสู่แอปเรียบร้อย)
}

// ✨ 3. นี่คือ Provider ของเราค่ะ ไลลาเปลี่ยนชื่อให้แล้วน้าา
class AppAuthProvider with ChangeNotifier {
  // --- สถานะภายใน (ของที่อยู่ในกระเป๋า) ---
  AuthStatus _status = AuthStatus.loggedOut;
  String? _verifiedClinicId;
  Staff? _currentStaff;

  // --- ช่องสำหรับให้คนอื่นดูของในกระเป๋า (Getters) ---
  AuthStatus get status => _status;
  String? get clinicId => _verifiedClinicId;
  Staff? get currentStaff => _currentStaff;

  // --- ฟังก์ชันสำหรับจัดการของในกระเป๋า ---

  // 💖 ฟังก์ชันนี้จะถูกเรียกเมื่อ Login ด่านแรก (เจ้าของคลินิก) สำเร็จ
  void setClinicVerified(String clinicId) {
    _verifiedClinicId = clinicId;
    _status = AuthStatus.clinicVerified;
    print('✨ AppAuthProvider: Clinic Verified! Clinic ID: $clinicId');
    notifyListeners(); // "ประกาศ!" บอกทุกคนว่าสถานะเปลี่ยนแล้วนะ!
  }

  // 💖 ฟังก์ชันนี้จะถูกเรียกเมื่อ Login ด่านที่สอง (พนักงาน) สำเร็จ
  void setStaffLoggedIn(Staff staff) {
    _currentStaff = staff;
    _status = AuthStatus.loggedIn;
    print('✨ AppAuthProvider: Staff Logged In! Welcome, ${staff.name} (${staff.role})');
    notifyListeners(); // "ประกาศ!" อีกครั้ง!
  }

  // 💖 ฟังก์ชันสำหรับ Logout ออกจากระบบทั้งหมด
  void logout() {
    _verifiedClinicId = null;
    _currentStaff = null;
    _status = AuthStatus.loggedOut;
    print('✨ AppAuthProvider: Logged out successfully.');
    notifyListeners(); // "ประกาศ!" ว่าเรากลับไปจุดเริ่มต้นแล้ว
  }
}

