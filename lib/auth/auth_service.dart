import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class AuthService {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  Future<UserCredential?> signUp(String email, String password) async {
    try {
      print("🚀 Calling createUserWithEmailAndPassword...");
      UserCredential result = await _auth.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );
      print("✅ Sign up success: ${result.user?.uid}");

      await _firestore
          .collection('users')
          .doc(result.user?.uid)
          .set({
            'email': email,
            'role': 'guest',
            'createdAt': FieldValue.serverTimestamp(),
          })
          .catchError((e) {
            print("🔥 Firestore write failed: $e");
          });

      return result;
    } catch (e) {
      print("🔥 Sign up error: $e");
      return null;
    }
  }

  Future<UserCredential?> signIn(String email, String password) async {
    try {
      UserCredential result = await _auth.signInWithEmailAndPassword(
        email: email,
        password: password,
      );
      return result;
    } catch (e) {
      print("🔥 Sign in error: $e");
      return null;
    }
  }

  Future<String?> getUserRole(String uid) async {
    try {
      DocumentSnapshot userDoc =
          await _firestore.collection('users').doc(uid).get();
      return userDoc['role'];
    } catch (e) {
      print("🔥 Get role error: $e");
      return null;
    }
  }
}
