import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'firebase_options.dart';
import 'login_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'MyDent',
      theme: ThemeData(
        fontFamily: 'Poppins', // ต้องแน่ใจว่ามีเพิ่มใน pubspec.yaml แล้ว
        scaffoldBackgroundColor: const Color(0xFFF3E5F5), // พื้นหลังม่วงอ่อน
        primarySwatch: Colors.deepPurple,
        inputDecorationTheme: InputDecorationTheme(
          filled: true,
          fillColor: Colors.white,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.pinkAccent,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
            textStyle: const TextStyle(fontSize: 16),
          ),
        ),
        textButtonTheme: TextButtonThemeData(
          style: TextButton.styleFrom(
            foregroundColor: Colors.deepPurple,
            textStyle: const TextStyle(fontSize: 14),
          ),
        ),
      ),
      initialRoute: '/',
      routes: {
        '/': (context) => const LoginScreen(),
        '/home': (context) => const RoleBasedHomeScreen(),
      },
    );
  }
}

class RoleBasedHomeScreen extends StatelessWidget {
  const RoleBasedHomeScreen({super.key});
  @override
  Widget build(BuildContext context) {
    final String? role = ModalRoute.of(context)!.settings.arguments as String?;
    String welcomeText;
    if (role == 'admin') {
      welcomeText = 'Welcome Admin! You can manage everything.';
    } else if (role == 'dentist') {
      welcomeText = 'Welcome Dentist! Here is your dashboard.';
    } else if (role == 'officer') {
      welcomeText = 'Welcome Officer! Please proceed with registrations.';
    } else {
      welcomeText = 'Welcome Guest! Your personal records are here.';
    }
    return Scaffold(
      appBar: AppBar(title: const Text('MyDent Home')),
      body: Center(
        child: Text(
          welcomeText,
          style: const TextStyle(fontSize: 20),
          textAlign: TextAlign.center,
        ),
      ),
    );
  }
}
