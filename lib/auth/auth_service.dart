import 'dart:convert';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:mydent_app/config/feature_flags.dart';

class SignInResult {
  final String? clinicId;
  final String role;
  final String? displayName;

  const SignInResult({this.clinicId, required this.role, this.displayName});
}

class AuthService {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseFunctions _functions = FirebaseFunctions.instance;

  Future<Map<String, dynamic>?> _loadUserProfile(String uid) async {
    Map<String, dynamic>? nestedData;
    try {
      final snapshot = await _firestore.collection('users').doc(uid).get();
      if (snapshot.exists) {
        final data = snapshot.data();
        return data == null ? null : Map<String, dynamic>.from(data);
      }

      nestedData = await _loadProfileFromNestedCollections(uid);
      if (nestedData != null) {
        return nestedData;
      }

      return null;
    } on FirebaseException catch (error) {
      if (error.code == 'permission-denied') {
        nestedData ??= await _loadProfileFromNestedCollections(uid);
        if (nestedData != null) {
          return nestedData;
        }

        debugPrint(
          'Direct profile read denied, using callable fallback: ${error.message}',
        );

        try {
          return await _loadProfileViaHttpsCallable(uid);
        } on MissingPluginException catch (missingPluginError, stackTrace) {
          debugPrint(
            'Firebase Functions not available on this platform: '
            '$missingPluginError',
          );
          debugPrint('$stackTrace');
          return null;
        }
      }
      rethrow;
    }
  }

  Future<Map<String, dynamic>?> _loadProfileFromNestedCollections(
    String uid,
  ) async {
    if (!FeatureFlags.useNestedCollections &&
        !FeatureFlags.dualReadFallbackEnabled) {
      return null;
    }

    try {
      final nestedUserQuery =
          await _firestore
              .collectionGroup('users')
              .where(FieldPath.documentId, isEqualTo: uid)
              .limit(1)
              .get();

      if (nestedUserQuery.docs.isNotEmpty) {
        final doc = nestedUserQuery.docs.first;
        final data = Map<String, dynamic>.from(doc.data());
        data.putIfAbsent('clinicId', () => doc.reference.parent.parent?.id);
        data.putIfAbsent('status', () => 'approved');
        return data;
      }
    } catch (error, stackTrace) {
      debugPrint('Nested users lookup failed: $error');
      debugPrint('$stackTrace');
    }

    try {
      final nestedMembersQuery =
          await _firestore
              .collectionGroup('members')
              .where(FieldPath.documentId, isEqualTo: uid)
              .limit(1)
              .get();

      if (nestedMembersQuery.docs.isNotEmpty) {
        final doc = nestedMembersQuery.docs.first;
        final data = Map<String, dynamic>.from(doc.data());
        data.putIfAbsent('clinicId', () => doc.reference.parent.parent?.id);
        data.putIfAbsent('status', () => 'approved');
        return data;
      }
    } catch (error, stackTrace) {
      debugPrint('Nested members lookup failed: $error');
      debugPrint('$stackTrace');
    }

    return null;
  }

  Future<Map<String, dynamic>?> _loadProfileViaHttpsCallable(String uid) async {
    final user = _auth.currentUser;
    if (user == null) {
      return null;
    }

    final FirebaseApp app = _auth.app;
    final String projectId = app.options.projectId ?? '';
    if (projectId.isEmpty) {
      debugPrint('Unable to resolve Firebase projectId for callable fallback.');
      return null;
    }

    const String region = 'us-central1';
    final Uri url = Uri.https(
      '$region-$projectId.cloudfunctions.net',
      'getUserProfileForLogin',
    );

    final String? idToken = await user.getIdToken();
    if (idToken == null || idToken.isEmpty) {
      return null;
    }

    try {
      final http.Response response = await http.post(
        url,
        headers: <String, String>{
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $idToken',
        },
        body: jsonEncode(<String, dynamic>{'data': <String, dynamic>{}}),
      );

      if (response.statusCode == 200) {
        final dynamic decoded = jsonDecode(response.body);
        if (decoded is Map<String, dynamic>) {
          final dynamic resultPayload = decoded['result'];
          if (resultPayload is Map<String, dynamic>) {
            return Map<String, dynamic>.from(resultPayload);
          }
        }
      } else {
        debugPrint(
          'Callable HTTPS fallback failed: ${response.statusCode} ${response.body}',
        );
      }
    } on MissingPluginException {
      rethrow;
    } catch (callError, stackTrace) {
      debugPrint('Callable HTTPS fallback error: $callError');
      debugPrint('$stackTrace');
    }

    return null;
  }

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
    } on MissingPluginException catch (error, stackTrace) {
      debugPrint(
        'Firebase Functions setClinicClaim not available on this platform: '
        '$error',
      );
      debugPrint('$stackTrace');
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
    try {
      final callable = _functions.httpsCallable('requestClinicApproval');
      await callable.call(<String, dynamic>{
        'clinicId': clinicId,
        'clinicName': clinicName,
        'userName': userName,
        'userEmail': userEmail,
      });
    } on MissingPluginException catch (error, stackTrace) {
      debugPrint(
        'Firebase Functions requestClinicApproval not available on this '
        'platform: $error',
      );
      debugPrint('$stackTrace');
    }
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

      final String trimmedClinicName = clinicName.trim();
      final String storedClinicName =
          trimmedClinicName.isNotEmpty ? trimmedClinicName : clinicName;

      clinicRef = await _firestore.collection('clinics').add({
        'name': storedClinicName,
        'owner_uid': user.uid,
        'created_at': Timestamp.now(),
      });

      final clinicId = clinicRef.id;

      await _ensureClinicMembership(
        clinicId: clinicId,
        uid: user.uid,
        role: 'admin',
      );

      if (trimmedClinicName.isNotEmpty) {
        final clinicProfileData = <String, dynamic>{
          'name': trimmedClinicName,
          'showLineId': true,
          'showTaxId': false,
          'updatedAt': FieldValue.serverTimestamp(),
        };

        final nestedProfileRef = _firestore
            .collection('clinics')
            .doc(clinicId)
            .collection('settings')
            .doc('clinicProfile');
        final rootProfileRef = _firestore
            .collection('settings')
            .doc('clinicProfile');

        final List<Future<void>> settingsWrites = <Future<void>>[];

        if (FeatureFlags.useNestedCollections) {
          settingsWrites.add(
            nestedProfileRef.set(clinicProfileData, SetOptions(merge: true)),
          );
          if (FeatureFlags.dualWriteEnabled) {
            settingsWrites.add(
              rootProfileRef.set(clinicProfileData, SetOptions(merge: true)),
            );
          }
        } else {
          settingsWrites.add(
            rootProfileRef.set(clinicProfileData, SetOptions(merge: true)),
          );
          if (FeatureFlags.dualWriteEnabled) {
            settingsWrites.add(
              nestedProfileRef.set(clinicProfileData, SetOptions(merge: true)),
            );
          }
        }

        if (settingsWrites.isNotEmpty) {
          await Future.wait(settingsWrites);
        }
      }

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
          clinicName: storedClinicName,
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

  Future<SignInResult?> signIn(String email, String password) async {
    try {
      final userCredential = await _auth.signInWithEmailAndPassword(
        email: email,
        password: password,
      );

      final user = userCredential.user;
      if (user == null) {
        return null;
      }

      final Map<String, dynamic>? data = await _loadUserProfile(user.uid);
      if (data == null || data.isEmpty) {
        return null;
      }

      final role = (data['role'] as String?) ?? 'guest';
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
        if (status == 'revoked') {
          throw FirebaseAuthException(
            code: 'account-revoked',
            message: 'This account has been revoked by an administrator.',
          );
        }
        throw FirebaseAuthException(
          code: 'account-disabled',
          message: 'Account is not active.',
        );
      }

      final clinicId = (data['clinicId'] as String?)?.trim();
      final bool isSuperAdmin = role == 'super_admin';
      final bool hasClinic = clinicId != null && clinicId.isNotEmpty;
      if (!hasClinic && !isSuperAdmin) {
        return null;
      }

      if (clinicId != null && clinicId.isNotEmpty) {
        await _syncClinicClaim(clinicId);
        await _auth.currentUser?.getIdToken(true);
        try {
          await _ensureClinicMembership(
            clinicId: clinicId,
            uid: user.uid,
            role: role,
          );
        } on FirebaseException catch (firebaseError) {
          if (firebaseError.code != 'permission-denied') {
            rethrow;
          }
          debugPrint('Membership sync skipped: ${firebaseError.message}');
        }
      }

      return SignInResult(
        clinicId: hasClinic ? clinicId : null,
        role: role,
        displayName: (data['name'] as String?) ?? user.displayName,
      );
    } on FirebaseAuthException {
      rethrow;
    } catch (error) {
      debugPrint('Sign in failed: $error');
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
