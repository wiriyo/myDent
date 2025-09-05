// 📁 lib/auth/staff_login_screen.dart
// v1.0.0 - Laila's Staff Login UI
// หน้าจอสำหรับให้พนักงานล็อกอินด้วย Username & Password ค่ะ 💳

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'auth_provider.dart';
import 'staff_service.dart';
import '../models/staff_model.dart';
import '../styles/app_theme.dart';

class StaffLoginScreen extends StatefulWidget {
  const StaffLoginScreen({super.key});

  @override
  State<StaffLoginScreen> createState() => _StaffLoginScreenState();
}

class _StaffLoginScreenState extends State<StaffLoginScreen> {
  final StaffService _staffService = StaffService();
  final TextEditingController _usernameController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  String errorMessage = '';
  bool _isLoading = false;

  void _showSnackbar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: AppTheme.primary,
      ),
    );
  }

  void _loginStaff() async {
    if (_usernameController.text.isEmpty || _passwordController.text.isEmpty) {
      setState(() {
        errorMessage = 'กรุณากรอกชื่อผู้ใช้และรหัสผ่านนะคะ 😊';
      });
      _showSnackbar(errorMessage);
      return;
    }

    setState(() {
      _isLoading = true;
      errorMessage = '';
    });

    // ดึง clinicId จาก Provider ที่เราเก็บไว้ใน Phase 1
    final authProvider = Provider.of<AppAuthProvider>(context, listen: false);
    final String? clinicId = authProvider.verifiedClinicId;

    if (clinicId == null) {
      setState(() {
        errorMessage = 'เกิดข้อผิดพลาด: ไม่พบ ID ของคลินิกค่ะ';
        _isLoading = false;
      });
      _showSnackbar(errorMessage);
      return;
    }

    try {
      final Staff? staff = await _staffService.signInStaff(
        clinicId: clinicId,
        username: _usernameController.text.trim(),
        password: _passwordController.text,
      );

      if (staff != null) {
        // ✨💖 ล็อกอินสำเร็จ! 💖✨
        // เราจะเรียกฟังก์ชันใน Provider เพื่ออัปเดตสถานะและเก็บข้อมูลพนักงาน
        if (!mounted) return;
        authProvider.setStaffLoggedIn(staff);
        // AuthWrapper ใน main.dart จะจัดการเปลี่ยนหน้าให้เราเองค่ะ
      } else {
        setState(() {
          errorMessage = 'ชื่อผู้ใช้หรือรหัสผ่านไม่ถูกต้องค่ะ 🥺';
        });
        _showSnackbar(errorMessage);
      }
    } catch (e) {
      setState(() {
        errorMessage = 'เกิดข้อผิดพลาดบางอย่างค่ะ: $e';
      });
      _showSnackbar(errorMessage);
    } finally {
      if(mounted) {
        setState(() {
          _isLoading = false;
        });
      }
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
                'assets/images/staff_icon.png', // อาจจะต้องหาไอคอนน่ารักๆ มาใส่ตรงนี้นะคะ
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
                      'เข้าสู่ระบบสำหรับพนักงาน',
                      style: TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF6A4DBA),
                      ),
                    ),
                    const SizedBox(height: 24),
                    _buildTextField('ชื่อผู้ใช้ (Username)', _usernameController),
                    const SizedBox(height: 16),
                    _buildTextField('รหัสผ่าน (Password)', _passwordController, obscure: true),
                    const SizedBox(height: 24),
                    ElevatedButton(
                      onPressed: _isLoading ? null : _loginStaff,
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
                          : const Text('เข้าสู่ระบบ'),
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
    return TextField(
      controller: controller,
      obscureText: obscure,
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
      ),
    );
  }
}
