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
      theme: ThemeData(primarySwatch: Colors.teal),
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
    // รับ role จาก arguments ของ Navigator
    final String? role = ModalRoute.of(context)!.settings.arguments as String?;
    String welcomeText;
    if (role == 'admin') {
      welcomeText = 'Welcome Admin! You can manage everything.';
    } else if (role == 'dentist') {
      welcomeText = 'Welcome Dentist! Here is your dashboard.';
    } else if (role == 'officer') {
      welcomeText = 'Welcome Officer! Please proceed with registrations.';
    } else {
      // ค่า default ให้กับ guest
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
