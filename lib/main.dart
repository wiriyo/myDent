// v1.1.0 - ✨ Fully Enabled Thai Localization
// 📁 lib/main.dart

import 'package:flutter/material.dart';
// ✨ [พ.ศ. FIX] เพิ่ม import ที่จำเป็นสำหรับ localization ค่ะ
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'firebase_options.dart';
import 'package:firebase_auth/firebase_auth.dart';

import 'auth/login_screen.dart';
import 'screens/calendar_screen.dart';
import 'screens/patients_screen.dart';
import 'screens/patient_add.dart';
import 'screens/reports_screen.dart';
import 'screens/setting_screen.dart';
import 'screens/patient_detail.dart';
import 'screens/treatment_list.dart';
import 'screens/working_hours_screen.dart';
import 'screens/appointment_search_screen.dart';

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
      
      // ✨ [พ.ศ. FIX] การตั้งค่า localization ที่สมบูรณ์แบบค่ะ
      // การตั้งค่าชุดนี้จะทำให้ทุกส่วนของแอป รวมถึง DatePicker
      // แสดงผลเป็นภาษาไทยและปี พ.ศ. ได้อย่างถูกต้องค่ะ
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
        '/calendar': (context) => const CalendarScreen(),
        '/login': (context) => const LoginScreen(),
        '/patients': (context) => const PatientsScreen(),
        '/add_patient': (context) => const PatientAddScreen(),
        '/reports': (context) => const ReportsScreen(),
        '/settings': (context) => const SettingsScreen(),
        '/patient_detail': (context) => const PatientDetailScreen(),
        '/treatment_list': (context) => const TreatmentListScreen(),
        '/working_hours': (context) => const WorkingHoursScreen(),
        '/appointment_search': (context) => const AppointmentSearchScreen(),
      },
      
    );
  }
}
