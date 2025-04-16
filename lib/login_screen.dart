import 'package:flutter/material.dart';
import 'auth_service.dart';
import 'signup_screen.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});
  @override
  _LoginScreenState createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final AuthService _authService = AuthService();
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  String errorMessage = '';

  void _login() async {
    String email = _emailController.text.trim();
    String password = _passwordController.text;
    var userCredential = await _authService.signIn(email, password);

    if (userCredential != null && userCredential.user != null) {
      // ดึง role จาก Firestore
      String? role = await _authService.getUserRole(userCredential.user!.uid);
      print("Logged in user's role: $role");

      // ตัวอย่างเช่น ถ้า role == 'admin' ให้ไปยังหน้า AdminDashboard,
      // ถ้า role == 'dentist' ให้ไปยัง DentistDashboard, อื่น ๆ สำหรับ officer และ guest
      // ตอนนี้เราจะนำผู้ใช้ไปยังหน้า HomeScreen ทั่วไปก่อน
      Navigator.pushReplacementNamed(context, '/home', arguments: role);
    } else {
      setState(() {
        errorMessage = 'Login failed. Please check your credentials.';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Login')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            TextField(
              controller: _emailController,
              decoration: const InputDecoration(
                  labelText: 'Email', hintText: 'you@example.com'),
            ),
            TextField(
              controller: _passwordController,
              decoration: const InputDecoration(labelText: 'Password'),
              obscureText: true,
            ),
            const SizedBox(height: 20),
            ElevatedButton(onPressed: _login, child: const Text('Login')),
            const SizedBox(height: 10),
            TextButton(
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                      builder: (context) => const SignUpScreen()),
                );
              },
              child: const Text("Don't have an account? Sign Up"),
            ),
            if (errorMessage.isNotEmpty) ...[
              const SizedBox(height: 10),
              Text(errorMessage, style: const TextStyle(color: Colors.red)),
            ]
          ],
        ),
      ),
    );
  }
}
