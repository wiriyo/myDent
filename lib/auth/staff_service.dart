// 📁 lib/auth/staff_service.dart
// v1.0.0 - Laila's Staff Service
// Service สำหรับจัดการ Logic การล็อกอินของพนักงานค่ะ 💳

import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/staff_model.dart';

class StaffService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // ฟังก์ชันสำหรับล็อกอินของพนักงาน
  // จะรับ clinicId, username, และ password เข้ามาตรวจสอบ
  Future<Staff?> signInStaff({
    required String clinicId,
    required String username,
    required String password,
  }) async {
    try {
      // 1. ค้นหาพนักงานจาก username ภายใน sub-collection 'staff' ของคลินิกนั้นๆ
      final querySnapshot = await _firestore
          .collection('clinics')
          .doc(clinicId)
          .collection('staff')
          .where('username', isEqualTo: username)
          .limit(1) // เราต้องการแค่คนเดียว
          .get();

      // 2. ถ้าไม่เจอพนักงานเลย ให้ return null
      if (querySnapshot.docs.isEmpty) {
        print('StaffService: ไม่พบ username นี้ในระบบ');
        return null;
      }

      // 3. ถ้าเจอ... ให้ดึงข้อมูลมาตรวจสอบรหัสผ่าน
      final staffDoc = querySnapshot.docs.first;
      final staffData = staffDoc.data();

      // ✨💖 หมายเหตุ: การเก็บรหัสผ่านเป็น plain text ไม่ปลอดภัยนะคะ
      // ในแอปจริง เราควรจะเข้ารหัส (hash) รหัสผ่านก่อนเก็บลง Firestore ค่ะ
      // แต่เพื่อการพัฒนาระยะแรก เราจะเปรียบเทียบตรงๆ ไปก่อนนะคะ
      if (staffData['password'] == password) {
        // 4. ถ้ารหัสผ่านถูกต้อง! สร้าง Staff object แล้วส่งกลับไป
        return Staff.fromFirestore(staffData, staffDoc.id);
      } else {
        // 5. ถ้ารหัสผ่านไม่ถูกต้อง
        print('StaffService: รหัสผ่านไม่ถูกต้อง');
        return null;
      }
    } catch (e) {
      print('StaffService Error: เกิดข้อผิดพลาดในการล็อกอินของพนักงาน - $e');
      return null;
    }
  }
}
