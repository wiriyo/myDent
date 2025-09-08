// 📁 lib/auth/auth_service.dart
// v2.0.0 - Laila's Multi-Tenant Update (Phase 1)
// ไลลาได้ปรับปรุง Service นี้เพื่อรองรับระบบ Multi-Tenant ตามแผนของเราค่ะ
// - signUp: เพิ่มการสร้าง clinic และผูก clinicId กับ user ใหม่
// - signIn: เปลี่ยนให้คืนค่า clinicId เพื่อใช้ใน Login ด่านแรก

import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class AuthService {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // --- 💖 ไลลาปรับปรุงฟังก์ชัน signUp สำหรับ Multi-Tenant 💖 ---
  // เพิ่ม clinicName และ Logic การสร้างคลินิกใหม่ค่ะ
  Future<UserCredential?> signUp(String email, String password, String name, String clinicName) async {
    try {
      // 1. สร้างผู้ใช้ใน Firebase Authentication เหมือนเดิมเลยค่ะ
      UserCredential userCredential = await _auth.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );

      if (userCredential.user != null) {
        // ✨ ส่วนใหม่! ✨
        // 2. สร้าง document ใหม่ใน collection 'clinics'
        // เพื่อเก็บข้อมูลของคลินิกและรับ clinicId ใหม่
        DocumentReference clinicRef = await _firestore.collection('clinics').add({
          'name': clinicName,
          'owner_uid': userCredential.user!.uid, // เก็บ uid เจ้าของไว้ด้วยเลย
          'created_at': Timestamp.now(),
        });
        
        // 3. ตอนนี้เราได้ clinicId มาแล้ว!
        String clinicId = clinicRef.id;

        // 4. บันทึกข้อมูล user พร้อมกับ clinicId และ role ใหม่
        await _firestore.collection('users').doc(userCredential.user!.uid).set({
          'name': name,
          'email': email,
          'role': 'subscriber', // กำหนด role เป็น 'subscriber' สำหรับเจ้าของ
          'clinicId': clinicId, // ผูก user คนนี้เข้ากับ clinic ที่เพิ่งสร้าง
        });
      }
      return userCredential;
    } on FirebaseAuthException {
      rethrow;
    }
  }

  // --- 💖 ไลลาปรับปรุงฟังก์ชัน signIn สำหรับ Multi-Tenant 💖 ---
  // เปลี่ยนให้คืนค่าเป็น clinicId (String?) แทน UserCredential นะคะ
  Future<String?> signIn(String email, String password) async {
    try {
      // 1. Sign in เหมือนเดิมเพื่อยืนยันตัวตน
      UserCredential userCredential = await _auth.signInWithEmailAndPassword(
        email: email,
        password: password,
      );

      if (userCredential.user != null) {
        // ✨ ส่วนใหม่! ✨
        // 2. ใช้ uid ไปค้นหาข้อมูลใน 'users' collection
        DocumentSnapshot userDoc = await _firestore.collection('users').doc(userCredential.user!.uid).get();
        
        if (userDoc.exists) {
          // 3. ถ้าเจอ... ก็ดึง clinicId ออกมาแล้วส่งคืนกลับไปเลยค่ะ!
          final data = userDoc.data() as Map<String, dynamic>?;
          if (data != null && data.containsKey('clinicId')) {
             return data['clinicId'] as String?;
          }
        }
      }
      // ถ้าไม่เจอ userDoc หรือไม่มี clinicId ก็จะคืนค่า null ค่ะ
      return null;
    } on FirebaseAuthException {
      // ถ้า Login ไม่ผ่าน (เช่น รหัสผิด) ก็คืนค่า null เช่นกันค่ะ
      return null;
    }
  }

  // Get user role from Firestore - โค้ดเดิมยังใช้ได้ค่ะ
  Future<String?> getUserRole(String uid) async {
    try {
      DocumentSnapshot userDoc = await _firestore.collection('users').doc(uid).get();
      if (userDoc.exists) {
        // ใช้ .data() เพื่อความปลอดภัย
        final data = userDoc.data() as Map<String, dynamic>?;
        return data?['role'] as String?;
      }
      return null;
    } catch (e) {
      return null;
    }
  }

  // Laila's new method to get user name from Firestore - โค้ดเดิมยังใช้ได้ค่ะ
  Future<String?> getUserName(String uid) async {
    try {
      DocumentSnapshot userDoc = await _firestore.collection('users').doc(uid).get();
      if (userDoc.exists) {
        final data = userDoc.data() as Map<String, dynamic>?;
        return data?['name'] as String?;
      }
      return null;
    } catch (e) {
      return null;
    }
  }

  // Sign out - โค้ดเดิมยังใช้ได้ค่ะ
  Future<void> signOut() async {
    await _auth.signOut();
  }

  // Laila's new method to reset password - โค้ดเดิมยังใช้ได้ค่ะ
  Future<void> resetPassword(String email) async {
    await _auth.sendPasswordResetEmail(email: email);
  }
}

