// 📁 lib/auth/signup_screen.dart
// v2.0.0 - Laila's Multi-Tenant Update (Phase 1)
// ไลลาได้ปรับปรุงหน้าจอนี้เพื่อรองรับการสมัครสมาชิกของ "เจ้าของคลินิก" ค่ะ
// - เพิ่มช่องสำหรับกรอก "ชื่อคลินิก" (Clinic Name)
// - อัปเดตฟังก์ชัน _signUp ให้ส่งข้อมูล clinicName ไปที่ AuthService

import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../auth/auth_service.dart';
import '../styles/app_theme.dart';

class SignUpScreen extends StatefulWidget {
  const SignUpScreen({super.key});

  @override
  State<SignUpScreen> createState() => _SignUpScreenState();
}

class _SignUpScreenState extends State<SignUpScreen> {
  final AuthService _authService = AuthService();
  final TextEditingController _nameController = TextEditingController();
  // ✨ ไลลาเพิ่ม Controller สำหรับชื่อคลินิกค่ะ
  final TextEditingController _clinicNameController = TextEditingController();
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  String errorMessage = '';
  bool _isLoading = false;
  bool _isPasswordVisible = false;

  void _showSnackbar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: AppTheme.primary,
      ),
    );
  }

  void _signUp() async {
    // 💖 ไลลาอัปเดตการเช็คข้อมูลให้ครบถ้วนค่ะ
    if (_nameController.text.isEmpty ||
        _clinicNameController.text.isEmpty ||
        _emailController.text.isEmpty ||
        _passwordController.text.isEmpty) {
      setState(() {
        errorMessage = 'กรุณากรอกข้อมูลให้ครบถ้วนนะคะ 😊';
      });
      _showSnackbar(errorMessage);
      return;
    }

    setState(() {
      _isLoading = true;
      errorMessage = '';
    });

    try {
      // 💖 ไลลาอัปเดตการเรียกใช้ฟังก์ชัน signUp ให้ส่ง clinicName ไปด้วยค่ะ
      final userCredential = await _authService.signUp(
        _emailController.text.trim(),
        _passwordController.text,
        _nameController.text.trim(),
        _clinicNameController.text.trim(), // <--- ส่งชื่อคลินิกไปด้วยน้าา
      );

      if (userCredential != null) {
        if (!mounted) return;
        _showSnackbar('Sign up complete. Please wait for admin approval via email.');
        Navigator.pop(context);
      }
    } on FirebaseAuthException catch (e) {
      setState(() {
        if (e.code == 'email-already-in-use') {
          errorMessage = 'This email is already in use.';
        } else if (e.code == 'weak-password') {
          errorMessage = 'Password must be at least 6 characters.';
        } else if (e.code == 'approval-request-failed') {
          errorMessage = 'Could not send the approval request. Please try again later.';
        } else {
          errorMessage = e.message ?? 'Sign up failed. Please try again.';
        }
      });
      _showSnackbar(errorMessage);
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFEFE0FF),
      body: Center(
        child: SingleChildScrollView(
          child: Column(
            children: [
              const SizedBox(height: 20),
              Image.asset(
                'assets/images/tooth_logo.png',
                height: 160,
              ),
              const SizedBox(height: 24),
              Container(
                margin: const EdgeInsets.symmetric(horizontal: 24),
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 64),
                decoration: BoxDecoration(
                  color: const Color(0xFFFBEAFF),
                  borderRadius: BorderRadius.circular(32),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black12,
                      blurRadius: 10,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Text(
                      'สร้างบัญชีเจ้าของคลินิก', // 💖 ไลลาเปลี่ยนข้อความนิดหน่อยค่ะ
                      style: TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF6A4DBA),
                      ),
                    ),
                    const SizedBox(height: 16),
                    _buildTextField('ชื่อผู้สมัคร', _nameController), // 💖
                    const SizedBox(height: 16),
                    // ✨ ไลลาเพิ่มช่องกรอกชื่อคลินิกตรงนี้ค่ะ
                    _buildTextField('ชื่อคลินิก', _clinicNameController),
                    const SizedBox(height: 16),
                    _buildTextField('Email', _emailController),
                    const SizedBox(height: 16),
                    _buildTextField('Password', _passwordController, obscure: true),
                    const SizedBox(height: 24),
                    ElevatedButton(
                      onPressed: _isLoading ? null : _signUp,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFFF47FA1),
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(horizontal: 100, vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(32),
                        ),
                        textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                      ),
                      child: _isLoading
                          ? const SizedBox(
                              height: 20,
                              width: 20,
                              child: CircularProgressIndicator(
                                color: Colors.white,
                                strokeWidth: 2,
                              ),
                            )
                          : const Text('Sign Up'),
                    ),
                    const SizedBox(height: 16),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Text(
                          "Already have an account? ",
                          style: TextStyle(fontFamily: 'Poppins'),
                        ),
                        GestureDetector(
                          onTap: _isLoading ? null : () => Navigator.pop(context),
                          child: const Text(
                            "Login",
                            style: TextStyle(
                              color: Color(0xFFBFA3FF),
                              fontWeight: FontWeight.bold,
                              fontFamily: 'Poppins',
                            ),
                          ),
                        ),
                      ],
                    ),
                    if (errorMessage.isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.only(top: 12),
                        child: Text(errorMessage, style: const TextStyle(color: Colors.red)),
                      ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTextField(String label, TextEditingController controller, {bool obscure = false}) {
    final bool isPasswordField = obscure;
    return TextField(
      controller: controller,
      obscureText: isPasswordField ? !_isPasswordVisible : false,
      style: const TextStyle(fontFamily: 'Poppins'),
      decoration: InputDecoration(
        labelText: label,
        labelStyle: const TextStyle(color: Color(0xFF6A4DBA), fontWeight: FontWeight.bold),
        filled: true,
        fillColor: Colors.white,
        contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: Color(0xFF6A4DBA)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: Color(0xFFBFA3FF), width: 2),
        ),
        suffixIcon: isPasswordField
            ? IconButton(
                icon: Icon(
                  _isPasswordVisible ? Icons.visibility : Icons.visibility_off,
                  color: const Color(0xFF6A4DBA),
                ),
                onPressed: () {
                  setState(() {
                    _isPasswordVisible = !_isPasswordVisible;
                  });
                },
              )
            : null,
      ),
    );
  }
}
