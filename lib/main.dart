// 📁 lib/main.dart
// v2.0.0 - Laila's Multi-Tenant Setup
// ไลลาได้เพิ่มการตั้งค่า Provider และ AuthWrapper
// เพื่อรองรับระบบ Login 2 ชั้นของเราค่ะ 💖

// Dart & Flutter Packages
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:provider/provider.dart'; // ✨ 1. Import provider มาก่อนเลยค่ะ

// Project Files
import 'firebase_options.dart';
import 'auth/auth_provider.dart'; // ✨ 2. Import "กระเป๋า" ของเรามาด้วย
import 'auth/login_screen.dart';
// import 'auth/staff_login_screen.dart'; // เดี๋ยวเราต้องมาสร้างหน้านี้กันต่อนะคะ
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
import 'package:flutter/foundation.dart' show kDebugMode;

// GlobalKey ยังคงอยู่เหมือนเดิมค่ะ
final GlobalKey<ScaffoldMessengerState> scaffoldMessengerKey = GlobalKey<ScaffoldMessengerState>();

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  
  // ✨ 3. เราจะเปลี่ยนการรันแอปมาอยู่ในรูปแบบใหม่ที่รองรับ Provider ค่ะ
  runApp(
    ChangeNotifierProvider(
      create: (context) => AppAuthProvider(),
      child: const MyApp(),
    ),
  );
}

class MyApp extends StatelessWidget {
  // ไม่ต้องรับค่า skipLogin แล้วนะคะ เพราะ AuthWrapper จะจัดการให้เอง
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'MyDent',
      debugShowCheckedModeBanner: false,
      scaffoldMessengerKey: scaffoldMessengerKey,
      
      // การตั้งค่า localization ยังอยู่ครบถ้วนค่ะ
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: const [
        Locale('th', 'TH'),
        Locale('en', 'US'),
      ],
      locale: const Locale('th', 'TH'),

      // Theme สวยๆ ของเราก็ยังอยู่ครบค่ะ
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
      
      // ✨ 4. เราจะให้ AuthWrapper เป็นหน้าจอเริ่มต้นเสมอ
      home: const AuthWrapper(),

      // Routes ทั้งหมดยังคงอยู่เหมือนเดิม เพื่อให้หน้าอื่น ๆ ทำงานได้ปกติ
      routes: {
        '/login': (context) => const LoginScreen(),
        '/calendar': (context) {
          final args =
              ModalRoute.of(context)?.settings.arguments as Map<String, dynamic>?;
          final patient = args != null ? args['initialPatient'] as Patient? : null;
          return CalendarScreen(initialPatient: patient);
        },
        '/patients': (context) => const PatientsScreen(),
        '/add_patient': (context) => const PatientAddScreen(),
        '/reports': (context) => const ReportsScreen(),
        '/settings': (context) => const SettingsScreen(),
        '/patient_detail': (context) => const PatientDetailScreen(),
        '/treatment_list': (context) => const TreatmentListScreen(),
        '/working_hours': (context) => const WorkingHoursScreen(),
        '/appointment_search': (context) => const AppointmentSearchScreen(),
        if (kDebugMode)
          '/dev/preview': (_) => const DevEntry(),
        '/home_admin': (context) => const HomeAdminScreen(), 
        '/home_dentist': (context) => const HomeDentistScreen(),
        '/home_officer': (context) => const HomeOfficerScreen(),
        '/home_guest': (context) => const HomeGuestScreen(),
        // '/staff_login': (context) => const StaffLoginScreen(), // <-- เดี๋ยวเราต้องมาสร้างหน้านี้กันค่ะ
      },
    );
  }
}

// ✨ 5. นี่คือ "ยามเฝ้าประตู" คนใหม่ของเราค่ะ!
class AuthWrapper extends StatelessWidget {
  const AuthWrapper({super.key});

  @override
  Widget build(BuildContext context) {
    // ให้ AuthWrapper คอย "ฟัง" การเปลี่ยนแปลงใน AppAuthProvider
    final authProvider = Provider.of<AppAuthProvider>(context);

    // ใช้ switch-case เพื่อจัดการสถานะที่แตกต่างกัน
    switch (authProvider.status) {
      case AuthStatus.loggedOut:
        // ถ้ายังไม่ได้ Login เลย -> ไปหน้า LoginScreen
        return const LoginScreen();
      case AuthStatus.clinicVerified:
        // ถ้าผ่านด่านแรกแล้ว -> ไปหน้า StaffLoginScreen (ที่เรากำลังจะสร้าง)
        // ✨💖 สำหรับตอนนี้ ให้แสดงหน้าจอชั่วคราวไปก่อนนะคะ 💖✨
        return const Scaffold(
          backgroundColor: Color(0xFFEFE0FF),
          body: Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  'Phase 1 สำเร็จแล้วค่ะ! 🥳',
                  style: TextStyle(fontSize: 22, color: Color(0xFF6A4DBA), fontWeight: FontWeight.bold),
                ),
                SizedBox(height: 20),
                Text(
                  'กำลังเตรียมตัวไปหน้า Staff Login...',
                  style: TextStyle(fontSize: 16, color: Color(0xFF6A4DBA)),
                ),
                SizedBox(height: 20),
                CircularProgressIndicator(color: Color(0xFFF47FA1)),
              ],
            ),
          ),
        );
      case AuthStatus.loggedIn:
        // ถ้า Login ครบ 2 ด่านแล้ว -> ไปหน้า HomeAdminScreen (หรือหน้าหลักอื่น ๆ)
        // เดี๋ยวเราจะมาทำ Logic เลือกหน้าตาม Role ตรงนี้กันอีกทีนะคะ
        return const HomeAdminScreen();
      default:
        // กรณีอื่น ๆ ให้กลับไปหน้า Login ก่อน
        return const LoginScreen();
    }
  }
}

