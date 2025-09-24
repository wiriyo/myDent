// 📁 lib/auth/login_screen.dart
// v2.2.0 - Laila's kDebugMode Fix
// ไลลาได้ลบการประกาศตัวแปร const bool kDebugMode ออกไป
// เพื่อแก้ไขปัญหาชื่อซ้ำ (ambiguous import) ค่ะ 💖

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart'; // เราจะใช้ kDebugMode จากที่นี่ค่ะ
import '../config/feature_flags.dart';
import '../auth/auth_service.dart';
import '../auth/auth_provider.dart';
import '../models/staff_model.dart';
import '../styles/app_theme.dart';
import 'signup_screen.dart';

// --- ✨💖 ไลลาลบบรรทัด 'const bool kDebugMode = true;' ออกจากตรงนี้แล้วนะคะ 💖✨ ---


class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final AuthService _authService = AuthService();
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  String errorMessage = '';
  bool _isLoading = false;
  bool _isPasswordVisible = false;

  @override
  void initState() {
    super.initState();
    _loadRememberedEmail();
  }

  Future<void> _loadRememberedEmail() async {
    final prefs = await SharedPreferences.getInstance();
    final savedEmail = prefs.getString('rememberedEmail');
    if (savedEmail != null) {
      _emailController.text = savedEmail;
    }
  }

  Future<void> _saveRememberedEmail(String email) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('rememberedEmail', email);
  }

  void _showSnackbar(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: AppTheme.primary),
    );
  }

  void _login() async {
    if (_emailController.text.isEmpty || _passwordController.text.isEmpty) {
      setState(() {
        errorMessage = 'กรุณากรอกอีเมลและรหัสผ่านให้ครบถ้วนนะคะ 😊';
      });
      _showSnackbar(errorMessage);
      return;
    }

    setState(() {
      _isLoading = true;
      errorMessage = '';
    });

    String email = _emailController.text.trim();
    String password = _passwordController.text;

    try {
      final SignInResult? result = await _authService.signIn(email, password);
      debugPrint('Super admin debug: SignInResult => $result');

      if (result != null) {
        await _saveRememberedEmail(email);

        if (!mounted) return;

        final authProvider = Provider.of<AppAuthProvider>(
          context,
          listen: false,
        );

        if (result.clinicId != null) {
          authProvider.setClinicVerified(result.clinicId!);
        }

        final uid = FirebaseAuth.instance.currentUser?.uid ?? 'admin';
        final fallbackName =
            (result.displayName != null && result.displayName!.isNotEmpty)
                ? result.displayName!
                : (result.role == 'super_admin'
                    ? 'Super Admin'
                    : 'Administrator');
        final staff = Staff(
          id: uid,
          name: fallbackName,
          username: email,
          role: result.role,
        );
        authProvider.setStaffLoggedIn(staff);

        if (mounted) {
          final route = _resolveRouteForRole(result.role);
          Navigator.pushReplacementNamed(context, route);
        }
      } else {
        setState(() {
          errorMessage = 'อีเมลหรือรหัสผ่านไม่ถูกต้องค่ะ 🥺';
        });
        _showSnackbar(errorMessage);
      }
    } on FirebaseAuthException catch (e) {
      setState(() {
        if (e.code == 'account-pending') {
          errorMessage =
              'บัญชีของคุณกำลังรอให้แอดมินอนุมัติอยู่นะคะ อดใจรออีกนิดน้า 💖';
        } else if (e.code == 'account-rejected') {
          errorMessage =
              'คำขอสมัครนี้ถูกปฏิเสธไปแล้วค่ะ หากสงสัยทักทีมซัพพอร์ตให้ไลลาช่วยดูได้เลยน้า 💌';
        } else if (e.code == 'account-revoked') {
          errorMessage =
              'บัญชีนี้ถูกระงับการใช้งานชั่วคราวนะคะ ติดต่อทีมซัพพอร์ตเพื่อให้ไลลาช่วยดูให้น้า 💬';
        } else if (e.code == 'account-disabled') {
          errorMessage =
              'บัญชีนี้ถูกปิดการใช้งานอยู่ค่ะ ถ้าอยากกลับมาใช้อีกครั้งแจ้งทีมซัพพอร์ตได้เลยนะคะ 🌸';
        } else {
          errorMessage =
              'เข้าสู่ระบบไม่สำเร็จค่ะ ลองใหม่อีกครั้งนะคะ ไลลาเป็นกำลังใจให้เสมอ 💪💜';
        }
      });
      _showSnackbar(errorMessage);
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  String _resolveRouteForRole(String role) {
    switch (role) {
      case 'admin':
        return '/calendar';
      case 'dentist':
        return '/home_dentist';
      case 'officer':
        return '/home_officer';
      case 'super_admin':
        return '/super_admin';
      default:
        return '/home_guest';
    }
  }

  void _resetPassword() async {
    if (_emailController.text.isEmpty) {
      _showSnackbar('กรุณากรอกอีเมลในช่องด้านบนก่อนนะคะ 😊');
      return;
    }
    try {
      await _authService.resetPassword(_emailController.text.trim());
      _showSnackbar(
        'ไลลาส่งอีเมลสำหรับตั้งรหัสผ่านใหม่ไปให้แล้วนะคะ! ลองเช็คในกล่องขาเข้าดูน้าา 💌',
      );
    } on FirebaseAuthException catch (e) {
      if (e.code == 'user-not-found') {
        _showSnackbar('ไลลาไม่พบอีเมลนี้ในระบบเลยค่ะ ลองตรวจสอบอีกครั้งน้า 💌');
      } else {
        _showSnackbar(
            'อุ๊ย...ระบบแอบงอแงนิดหน่อย ลองใหม่อีกครั้งหรือบอกทีมไลลาให้ช่วยได้เลยนะคะ 💜');
      }
    }
  }

  void _devSkipLogin() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('skipLogin', true);
    if (!mounted) return;
    Navigator.pushReplacementNamed(context, '/calendar');
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
              Image.asset('assets/images/tooth_logo.png', height: 160),
              const SizedBox(height: 24),
              Container(
                margin: const EdgeInsets.symmetric(horizontal: 24),
                padding: const EdgeInsets.symmetric(
                  horizontal: 24,
                  vertical: 64,
                ),
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
                      'เข้าสู่ระบบคลินิก',
                      style: TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF6A4DBA),
                      ),
                    ),
                    const SizedBox(height: 16),
                    _buildTextField('Email', _emailController),
                    const SizedBox(height: 16),
                    _buildPasswordTextField(),
                    const SizedBox(height: 24),
                    ElevatedButton(
                      onPressed: _isLoading ? null : _login,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFFBFA3FF),
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 100,
                          vertical: 14,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(32),
                        ),
                        textStyle: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      child:
                          _isLoading
                              ? const SizedBox(
                                height: 20,
                                width: 20,
                                child: CircularProgressIndicator(
                                  color: Colors.white,
                                  strokeWidth: 2,
                                ),
                              )
                              : const Text('Login'),
                    ),
                    const SizedBox(height: 12),
                    TextButton(
                      onPressed: _isLoading ? null : _resetPassword,
                      child: const Text(
                        'ลืมรหัสผ่าน?',
                        style: TextStyle(
                          color: Color(0xFFF47FA1),
                          fontWeight: FontWeight.bold,
                          fontFamily: 'Poppins',
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    if (kDebugMode &&
                        FeatureFlags
                            .showDevSkipLogin) // ซ่อนปุ่มด้วย flag เพิ่มเติม
                      TextButton(
                        onPressed: _isLoading ? null : _devSkipLogin,
                        child: const Text('Dev Login (Skip)'),
                      ),
                    const SizedBox(height: 16),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Text(
                          "ยังไม่มีบัญชี? ",
                          style: TextStyle(fontFamily: 'Poppins'),
                        ),
                        GestureDetector(
                          onTap:
                              _isLoading
                                  ? null
                                  : () => Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder:
                                          (context) => const SignUpScreen(),
                                    ),
                                  ),
                          child: const Text(
                            "Sign Up",
                            style: TextStyle(
                              color: Color(0xFFF47FA1),
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
                        child: Text(
                          errorMessage,
                          style: const TextStyle(color: Colors.red),
                        ),
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

  Widget _buildTextField(
    String label,
    TextEditingController controller, {
    bool obscure = false,
  }) {
    return TextField(
      controller: controller,
      obscureText: obscure,
      style: const TextStyle(fontFamily: 'Poppins'),
      decoration: InputDecoration(
        labelText: label,
        labelStyle: const TextStyle(
          color: Color(0xFF6A4DBA),
          fontWeight: FontWeight.bold,
        ),
        filled: true,
        fillColor: Colors.white,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 20,
          vertical: 16,
        ),
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

  Widget _buildPasswordTextField() {
    return TextField(
      controller: _passwordController,
      obscureText: !_isPasswordVisible,
      style: const TextStyle(fontFamily: 'Poppins'),
      decoration: InputDecoration(
        labelText: 'Password',
        labelStyle: const TextStyle(
          color: Color(0xFF6A4DBA),
          fontWeight: FontWeight.bold,
        ),
        filled: true,
        fillColor: Colors.white,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 20,
          vertical: 16,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: Color(0xFF6A4DBA)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: Color(0xFFBFA3FF), width: 2),
        ),
        suffixIcon: IconButton(
          icon: Icon(
            _isPasswordVisible ? Icons.visibility : Icons.visibility_off,
            color: const Color(0xFF6A4DBA),
          ),
          onPressed: () {
            setState(() {
              _isPasswordVisible = !_isPasswordVisible;
            });
          },
        ),
      ),
    );
  }
}
