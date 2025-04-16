import 'package:flutter/material.dart';
import 'auth_service.dart';

class SignUpScreen extends StatefulWidget {
  const SignUpScreen({super.key});

  @override
  _SignUpScreenState createState() => _SignUpScreenState();
}

class _SignUpScreenState extends State<SignUpScreen> {
  final AuthService _authService = AuthService();
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  String errorMessage = '';

  void _signUp() async {
    String email = _emailController.text.trim();
    String password = _passwordController.text;

    print("📩 Trying sign up with $email");

    var userCredential = await _authService.signUp(email, password);

    if (userCredential != null) {
      // สมัครสมาชิกสำเร็จ
      // หลังจาก Sign Up เสร็จ เราจะกลับหน้าล็อกอินก่อน (หรือเปลี่ยนตาม Flow ที่ต้องการ)
      print("✅ SignUp Success");
      Navigator.pop(context);
    } else {
      print("❌ Sign up failed in signup_screen.dart");
      setState(() {
        errorMessage = 'Sign Up failed. Please try again.';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Sign Up")),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // ฟิลด์กรอกอีเมล์
            TextField(
              controller: _emailController,
              decoration: const InputDecoration(
                labelText: "Email",
                hintText: "you@example.com",
              ),
            ),
            const SizedBox(height: 16),
            // ฟิลด์กรอกรหัสผ่าน
            TextField(
              controller: _passwordController,
              decoration: const InputDecoration(labelText: "Password"),
              obscureText: true,
            ),
            const SizedBox(height: 20),
            // ปุ่ม Sign Up
            ElevatedButton(onPressed: _signUp, child: const Text("Sign Up")),
            if (errorMessage.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 10),
                child: Text(
                  errorMessage,
                  style: const TextStyle(color: Colors.red),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
