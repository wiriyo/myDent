// 📁 lib/auth/login_screen.dart
// v1.2.6 - Laila's 'Dev Login' Restoration
// ไลลาได้แก้ไขโค้ดเพื่อให้ปุ่ม Dev Login กลับมาแสดงผลอีกครั้งค่ะ

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import '../auth/auth_service.dart';
import '../styles/app_theme.dart';
import 'signup_screen.dart';

// ✨ To show the Dev Login button again, set kDebugMode to true here.
// To hide it, just comment out or remove this line.
//const bool kDebugMode = true;

// Add ScaffoldMessengerKey for global snackbar
final GlobalKey<ScaffoldMessengerState> scaffoldMessengerKey = GlobalKey<ScaffoldMessengerState>();


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
  // Variable to toggle password visibility
  bool _isPasswordVisible = false;

  @override
  void initState() {
    super.initState();
    _loadRememberedEmail();
  }

  // Laila's new function to load the saved email
  Future<void> _loadRememberedEmail() async {
    final prefs = await SharedPreferences.getInstance();
    final savedEmail = prefs.getString('rememberedEmail');
    if (savedEmail != null) {
      _emailController.text = savedEmail;
    }
  }
  
  // Laila's new function to save the email
  Future<void> _saveRememberedEmail(String email) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('rememberedEmail', email);
  }

  void _showSnackbar(String message) {
    if (scaffoldMessengerKey.currentState != null) {
      scaffoldMessengerKey.currentState!.showSnackBar(
        SnackBar(
          content: Text(message),
          backgroundColor: AppTheme.primary,
        ),
      );
    }
  }

  void _login() async {
    // Check if email and password are not empty
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
      final userCredential = await _authService.signIn(email, password);
      if (userCredential != null) {
        // Save the email when login is successful
        await _saveRememberedEmail(email);

        final String? role = await _authService.getUserRole(userCredential.user!.uid);
        
        // Navigate based on user role
        if (!mounted) return;
        if (role == 'admin') {
          Navigator.pushReplacementNamed(context, '/home_admin');
        } else if (role == 'dentist') {
          Navigator.pushReplacementNamed(context, '/home_dentist');
        } else if (role == 'officer') {
          Navigator.pushReplacementNamed(context, '/home_officer');
        } else {
          // Default to guest screen
          Navigator.pushReplacementNamed(context, '/home_guest');
        }
      } else {
        setState(() {
          errorMessage = 'ชื่อผู้ใช้หรือรหัสผ่านไม่ถูกต้องค่ะ 🥺';
        });
        _showSnackbar(errorMessage);
      }
    } on FirebaseAuthException catch (e) {
      setState(() {
        if (e.code == 'user-not-found') {
          errorMessage = 'ไม่พบผู้ใช้นี้ในระบบค่ะ';
        } else if (e.code == 'wrong-password') {
          errorMessage = 'รหัสผ่านไม่ถูกต้องนะคะ';
        } else {
          errorMessage = 'เกิดข้อผิดพลาด: ${e.message}';
        }
      });
      _showSnackbar(errorMessage);
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  // Laila's new function for password reset!
  void _resetPassword() async {
    if (_emailController.text.isEmpty) {
      _showSnackbar('กรุณากรอกอีเมลในช่องด้านบนก่อนนะคะ 😊');
      return;
    }
    try {
      await _authService.resetPassword(_emailController.text.trim());
      _showSnackbar('ไลลาส่งอีเมลสำหรับตั้งรหัสผ่านใหม่ไปให้แล้วนะคะ! ลองเช็คในกล่องขาเข้าดูน้าา 💌');
    } on FirebaseAuthException catch (e) {
      if (e.code == 'user-not-found') {
        _showSnackbar('ไม่พบผู้ใช้นี้ในระบบค่ะ');
      } else {
        _showSnackbar('เกิดข้อผิดพลาด: ${e.message}');
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
                    _buildTextField('Email', _emailController),
                    const SizedBox(height: 16),
                    _buildPasswordTextField(),
                    const SizedBox(height: 24),
                    ElevatedButton(
                      onPressed: _isLoading ? null : _login,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFFBFA3FF),
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
                    // ✨ Laila's conditional rendering for dev login button
                    // assert is used here to hide the button in release mode
                    if (kDebugMode)
                      TextButton(
                        onPressed: _isLoading ? null : _devSkipLogin,
                        child: const Text('Dev Login (Skip)'),
                      ),
                    const SizedBox(height: 16),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Text(
                          "Don't have an account? ",
                          style: TextStyle(fontFamily: 'Poppins'),
                        ),
                        GestureDetector(
                          onTap: _isLoading ? null : () => Navigator.push(
                            context,
                            MaterialPageRoute(builder: (context) => const SignUpScreen()),
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

  // Password Text Field with visibility toggle
  Widget _buildPasswordTextField() {
    return TextField(
      controller: _passwordController,
      obscureText: !_isPasswordVisible,
      style: const TextStyle(fontFamily: 'Poppins'),
      decoration: InputDecoration(
        labelText: 'Password',
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
        // The eye icon
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
