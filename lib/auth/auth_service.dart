// 📁 lib/auth/auth_service.dart
// v2.0.0 - Laila's Multi-Tenant Update (Phase 1)
// ไลลาได้ปรับปรุง Service นี้เพื่อรองรับระบบ Multi-Tenant ตามแผนของเราค่ะ
// - signUp: เพิ่มการสร้าง clinic และผูก clinicId กับ user ใหม่
// - signIn: เปลี่ยนให้คืนค่า clinicId เพื่อใช้ใน Login ด่านแรก

import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import 'package:cloud_functions/cloud_functions.dart';

class AuthService {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  final FirebaseFunctions _functions = FirebaseFunctions.instance;

  Future<void> _ensureClinicMembership({required String clinicId, required String uid, String? role}) async {
    if (clinicId.isEmpty || uid.isEmpty) return;
    final memberRef = _firestore.collection('clinics').doc(clinicId).collection('members').doc(uid);
    await memberRef.set({
      'role': role ?? 'admin',
      'addedAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }


  // --- 💖 ไลลาปรับปรุงฟังก์ชัน signUp สำหรับ Multi-Tenant 💖 ---
  // เพิ่ม clinicName และ Logic การสร้างคลินิกใหม่ค่ะ
  Future<UserCredential?> signUp(String email, String password, String name, String clinicName) async {
    UserCredential? userCredential;
    DocumentReference<Map<String, dynamic>>? clinicRef;
    try {
      userCredential = await _auth.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );

      final user = userCredential.user;
      if (user == null) {
        return userCredential;
      }

      clinicRef = await _firestore.collection('clinics').add({
        'name': clinicName,
        'owner_uid': user.uid,
        'created_at': Timestamp.now(),
      });

      final clinicId = clinicRef.id;

      await _firestore.collection('users').doc(user.uid).set({
        'name': name,
        'email': email,
        'role': 'admin',
        'clinicId': clinicId,
        'status': 'pending',
        'createdAt': Timestamp.now(),
      });

      try {
        await _requestClinicApproval(
          clinicId: clinicId,
          clinicName: clinicName,
          userName: name,
          userEmail: email,
        );
      } on FirebaseFunctionsException catch (error, stackTrace) {
        await _rollbackClinicSetup(user, clinicRef);
        Error.throwWithStackTrace(
          FirebaseAuthException(
            code: 'approval-request-failed',
            message: 'Unable to submit approval request. Please try again later.',
          ),
          stackTrace,
        );
      }

      await _auth.signOut();
      return userCredential;
    } on FirebaseAuthException {
      await _rollbackClinicSetup(userCredential?.user, clinicRef);
      rethrow;
    } on FirebaseException catch (error, stackTrace) {
      await _rollbackClinicSetup(userCredential?.user, clinicRef);
      Error.throwWithStackTrace(
        FirebaseAuthException(
          code: error.code,
          message: error.message ?? 'Sign up failed. Please try again.',
        ),
        stackTrace,
      );
    }
  }

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
          if (data != null) {
            final status = (data['status'] as String?) ?? 'approved';
            if (status != 'approved') {
              await _auth.signOut();
              if (status == 'pending') {
                throw FirebaseAuthException(
                  code: 'account-pending',
                  message: '????????????????????????????????????',
                );
              }
              if (status == 'rejected') {
                throw FirebaseAuthException(
                  code: 'account-rejected',
                  message: '???????????????????????? ?????????????????????',
                );
              }
              throw FirebaseAuthException(
                code: 'account-disabled',
                message: '????????????????????????? ??????????????????????',
              );
            }

            if (data.containsKey('clinicId')) {
              final clinicId = (data['clinicId'] as String?) ?? '';
              if (clinicId.isNotEmpty) {
                await _ensureClinicMembership(
                  clinicId: clinicId,
                  uid: userCredential.user!.uid,
                  role: data['role'] as String?,
                );

                await _syncClinicClaim(clinicId);
                return clinicId;
              }
            }
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

  Future<void> _rollbackClinicSetup(User? user, DocumentReference<Map<String, dynamic>>? clinicRef) async {
    if (user == null) {
      return;
    }
    try {
      await _firestore.collection('users').doc(user.uid).delete();
    } catch (_) {}
    if (clinicRef != null) {
      try {
        await clinicRef.delete();
      } catch (_) {}
    }
    try {
      await user.delete();
    } catch (_) {}
    final currentUser = _auth.currentUser;
    if (currentUser != null && currentUser.uid == user.uid) {
      try {
        await _auth.signOut();
      } catch (_) {}
    }
  }

  Future<void> _requestClinicApproval({
    required String clinicId,
    required String clinicName,
    required String userName,
    required String userEmail,
  }) async {
    final callable = _functions.httpsCallable('requestClinicApproval');
    await callable.call(<String, dynamic>{
      'clinicId': clinicId,
      'clinicName': clinicName,
      'userName': userName,
      'userEmail': userEmail,
    });
  }

  Future<void> _syncClinicClaim(String clinicId) async {
    try {
      final callable = _functions.httpsCallable('setClinicClaim');
      await callable.call(<String, dynamic>{
        'clinicId': clinicId,
      });
    } on FirebaseFunctionsException catch (error) {
      // ignore: avoid_print
      print('Failed to sync clinic claim: ${error.code}');
    }
  }

}








