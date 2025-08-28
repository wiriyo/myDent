// 📁 lib/main.dart
// v1.1.5 - Laila's 'Dev Login' Hiding Feature
// ไลลาได้ซ่อนปุ่ม Dev Login เพื่อให้แอปดูพร้อมใช้งานจริง
// โดยจะแสดงผลเฉพาะในโหมด Debug เท่านั้นค่ะ

// Dart & Flutter Packages
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter/foundation.dart' show kDebugMode;

// Project Files
import 'firebase_options.dart';
import 'auth/login_screen.dart';
import 'screens/calendar_screen.dart';
import 'screens/patient_add.dart';
import 'screens/patient_detail.dart';
import 'screens/patients_screen.dart';
import 'screens/reports_screen.dart';
import 'screens/setting_screen.dart';
import 'screens/treatment_list.dart';
import 'screens/working_hours_screen.dart';
import 'screens/appointment_search_screen.dart';
import 'models/patient.dart';
import 'dev/dev_entry.dart';
import 'home/home_admin.dart'; 
import 'home/home_dentist.dart'; 
import 'home/home_officer.dart'; 
import 'home/home_guest.dart';

final GlobalKey<ScaffoldMessengerState> scaffoldMessengerKey = GlobalKey<ScaffoldMessengerState>();

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  final prefs = await SharedPreferences.getInstance();
  final skipLogin = prefs.getBool('skipLogin') ?? false;

  if (FirebaseAuth.instance.currentUser == null) {
    try {
      await FirebaseAuth.instance.signInAnonymously();
      print('🎉 Anonymous sign-in success!');
    } catch (e) {
      print('❌ Failed to sign in anonymously: $e');
    }
  }

  runApp(MyApp(skipLogin: skipLogin));
}

class MyApp extends StatelessWidget {
  final bool skipLogin;
  const MyApp({super.key, required this.skipLogin});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'MyDent',
      debugShowCheckedModeBanner: false,
      scaffoldMessengerKey: scaffoldMessengerKey,
      
      // การตั้งค่า localization ที่สมบูรณ์แบบค่ะ
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: const [
        Locale('th', 'TH'), // ภาษาไทย
        Locale('en', 'US'), // ภาษาอังกฤษ (สำรอง)
      ],
      locale: const Locale('th', 'TH'), // ตั้งค่าภาษาหลักเป็นภาษาไทย

      theme: ThemeData(
        primaryColor: const Color(0xFFE0BBFF),
        scaffoldBackgroundColor: const Color(0xFFFFF5FC),
        fontFamily: 'Poppins',
        appBarTheme: const AppBarTheme(
          backgroundColor: Color(0xFFFFF5FC),
          elevation: 0,
          iconTheme: IconThemeData(color: Colors.black),
          titleTextStyle: TextStyle(
            color: Colors.black,
            fontSize: 20,
            fontWeight: FontWeight.bold,
          ),
        ),
        colorScheme: ColorScheme.fromSwatch(
          primarySwatch: Colors.purple,
        ).copyWith(secondary: const Color(0xFFB2F2FF)),
        textTheme: const TextTheme(
          bodyMedium: TextStyle(color: Colors.black87),
        ),
      ),
      initialRoute: '/',
      routes: {
        '/': (context) => skipLogin ? CalendarScreen(showReset: true) : const LoginScreen(),
        '/calendar': (context) {
          final args =
              ModalRoute.of(context)?.settings.arguments as Map<String, dynamic>?;
          final patient = args != null ? args['initialPatient'] as Patient? : null;
          return CalendarScreen(initialPatient: patient);
        },
        '/login': (context) => const LoginScreen(),
        '/patients': (context) => const PatientsScreen(),
        '/add_patient': (context) => const PatientAddScreen(),
        '/reports': (context) => const ReportsScreen(),
        '/settings': (context) => const SettingsScreen(),
        '/patient_detail': (context) => const PatientDetailScreen(),
        '/treatment_list': (context) => const TreatmentListScreen(),
        '/working_hours': (context) => const WorkingHoursScreen(),
        '/appointment_search': (context) => const AppointmentSearchScreen(),
        // ✨ Only show this route in debug mode
        if (kDebugMode)
          '/dev/preview': (_) => const DevEntry(),
        '/home_admin': (context) => const HomeAdminScreen(), 
        '/home_dentist': (context) => const HomeDentistScreen(),
        '/home_officer': (context) => const HomeOfficerScreen(),
        '/home_guest': (context) => const HomeGuestScreen(),
      },
    );
  }
}
