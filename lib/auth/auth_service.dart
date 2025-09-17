import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';

class AuthService {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseFunctions _functions = FirebaseFunctions.instance;

  Future<void> _ensureClinicMembership({
    required String clinicId,
    required String uid,
    String? role,
  }) async {
    if (clinicId.isEmpty || uid.isEmpty) return;

    final memberRef = _firestore
        .collection('clinics')
        .doc(clinicId)
        .collection('members')
        .doc(uid);

    await memberRef.set({
      'role': role ?? 'admin',
      'addedAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  Future<void> _syncClinicClaim(String clinicId) async {
    if (clinicId.isEmpty) return;

    try {
      final callable = _functions.httpsCallable('setClinicClaim');
      await callable.call(<String, dynamic>{'clinicId': clinicId});
    } on FirebaseFunctionsException catch (error) {
      debugPrint('Failed to sync clinic claim: ${error.code}');
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

  Future<void> _rollbackClinicSetup(
    User? user,
    DocumentReference<Map<String, dynamic>>? clinicRef,
  ) async {
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

  Future<UserCredential?> signUp(
    String email,
    String password,
    String name,
    String clinicName,
  ) async {
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
            message:
                'Unable to submit approval request. Please try again later.',
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
      final userCredential = await _auth.signInWithEmailAndPassword(
        email: email,
        password: password,
      );

      final user = userCredential.user;
      if (user == null) {
        return null;
      }

      final userDoc = await _firestore.collection('users').doc(user.uid).get();
      if (!userDoc.exists) {
        return null;
      }

      final data = userDoc.data();
      if (data == null) {
        return null;
      }

      final status = (data['status'] as String?) ?? 'approved';
      if (status != 'approved') {
        await _auth.signOut();
        if (status == 'pending') {
          throw FirebaseAuthException(
            code: 'account-pending',
            message: 'Account is waiting for approval.',
          );
        }
        if (status == 'rejected') {
          throw FirebaseAuthException(
            code: 'account-rejected',
            message: 'Account approval was rejected.',
          );
        }
        throw FirebaseAuthException(
          code: 'account-disabled',
          message: 'Account is not active.',
        );
      }

      final clinicId = (data['clinicId'] as String?) ?? '';
      if (clinicId.isEmpty) {
        return null;
      }

      await _ensureClinicMembership(
        clinicId: clinicId,
        uid: user.uid,
        role: data['role'] as String?,
      );

      await _syncClinicClaim(clinicId);
      return clinicId;
    } on FirebaseAuthException {
      rethrow;
    } catch (_) {
      return null;
    }
  }

  Future<String?> getUserRole(String uid) async {
    try {
      final userDoc = await _firestore.collection('users').doc(uid).get();
      if (!userDoc.exists) {
        return null;
      }

      final data = userDoc.data();
      return data?['role'] as String?;
    } catch (_) {
      return null;
    }
  }

  Future<String?> getUserName(String uid) async {
    try {
      final userDoc = await _firestore.collection('users').doc(uid).get();
      if (!userDoc.exists) {
        return null;
      }

      final data = userDoc.data();
      return data?['name'] as String?;
    } catch (_) {
      return null;
    }
  }

  Future<void> signOut() async {
    await _auth.signOut();
  }

  Future<void> resetPassword(String email) async {
    await _auth.sendPasswordResetEmail(email: email);
  }
}
