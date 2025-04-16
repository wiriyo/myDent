import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'firebase_options.dart'; // <- ระบบสร้างให้ตอน run flutterfire configure

void main() async {
  WidgetsFlutterBinding.ensureInitialized(); // เตรียมความพร้อมก่อน run async
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  ); // เชื่อม Firebase!
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'MyDent',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.teal),
        useMaterial3: true,
      ),
      home: const HomeScreen(),
    );
  }
}

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('MyDent Home'),
      ),
      body: const Center(
        child: Text(
          'Connected to Firebase 🎉',
          style: TextStyle(fontSize: 20),
        ),
      ),
    );
  }
}
