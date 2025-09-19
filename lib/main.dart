// 📁 lib/main.dart
// v4.0.0 - Laila's StreamBuilder Solution
// เปลี่ยนมาใช้ StreamBuilder เพื่อรับ "โทรศัพท์สายตรง" จาก Provider ค่ะ! 💖

// Dart & Flutter Packages
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

// Project Files
import 'firebase_options.dart';
import 'auth/auth_provider.dart';
import 'auth/login_screen.dart';
import 'auth/staff_login_screen.dart';
import 'screens/calendar_screen.dart';
import 'screens/patient_add.dart';
import 'screens/patient_detail.dart';
import 'screens/patients_screen.dart';
import 'screens/reports_screen.dart';
import 'screens/setting_screen.dart';
import 'screens/treatment_list.dart';
import 'screens/working_hours_screen.dart';
import 'screens/prefix_settings_screen.dart';
import 'screens/appointment_search_screen.dart';
import 'screens/splash_screen.dart';
import 'config/feature_flags.dart';
import 'screens/clinic_settings_screen.dart';
import 'models/patient.dart';
import 'dev/dev_entry.dart';
import 'home/home_admin.dart';
import 'home/home_dentist.dart';
import 'home/home_officer.dart';
import 'home/home_guest.dart';
import 'home/home_super_admin.dart';
import 'package:flutter/foundation.dart' show kDebugMode;

final GlobalKey<ScaffoldMessengerState> scaffoldMessengerKey =
    GlobalKey<ScaffoldMessengerState>();
final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);

  bool? welcomeScreenEnabled;
  try {
    final prefs = await SharedPreferences.getInstance();
    welcomeScreenEnabled = prefs.getBool('mydent.welcomeScreenEnabled');
  } catch (_) {}

  runApp(
    ChangeNotifierProvider(
      create: (context) => AppAuthProvider(),
      child: MyApp(initialWelcomeScreenEnabled: welcomeScreenEnabled),
    ),
  );
}

class MyApp extends StatefulWidget {
  const MyApp({super.key, this.initialWelcomeScreenEnabled});

  final bool? initialWelcomeScreenEnabled;

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  late bool _showSplash;
  bool _splashFlowScheduled = false;

  @override
  void initState() {
    super.initState();
    _showSplash = widget.initialWelcomeScreenEnabled ?? FeatureFlags.showInAppSplash;
    if (_showSplash) {
      _scheduleSplashNavigation();
    }
  }

  void _scheduleSplashNavigation() {
    if (_splashFlowScheduled) return;
    _splashFlowScheduled = true;
    // แสดง Splash สั้นๆ ให้ดูน่ารักก่อนเข้าแอป
    WidgetsBinding.instance.addPostFrameCallback((_) {
      Future.delayed(const Duration(milliseconds: 3000), () {
        if (!mounted) return;
        final authProvider = Provider.of<AppAuthProvider>(
          context,
          listen: false,
        );
        final next = _buildHomeScreen(authProvider);
        setState(() => _showSplash = false);
        // Use global navigatorKey since this context is above MaterialApp's Navigator
        navigatorKey.currentState?.pushReplacement(
          MaterialPageRoute(builder: (_) => next),
        );
      });
    });
  }

  // ฟังก์ชันผู้ช่วยสำหรับเลือกหน้าจอที่จะแสดง
  Widget _buildHomeScreen(AppAuthProvider authProvider) {
    print(
      '🕵️‍♀️ Laila Debug: _buildHomeScreen is deciding! Status is: ${authProvider.status}',
    );
    switch (authProvider.status) {
      case AuthStatus.loggedOut:
        return const LoginScreen();
      case AuthStatus.clinicVerified:
        return const StaffLoginScreen();
      case AuthStatus.loggedIn:
        final staffRole = authProvider.currentStaff?.role;
        print(
          '🕵️‍♀️ Laila Debug: Staff role is: $staffRole. Navigating to home screen...',
        );
        switch (staffRole) {
          case 'super_admin':
            return const HomeSuperAdminScreen();
          case 'admin':
            // เปลี่ยนให้ admin เข้าหน้า Calendar เป็นหน้าแรกตามที่ต้องการ
            return const CalendarScreen();
          case 'dentist':
            return const HomeDentistScreen();
          case 'officer':
            return const HomeOfficerScreen();
          default:
            return const HomeGuestScreen();
        }
      // All AuthStatus cases are covered above; no default needed
    }
  }

  @override
  Widget build(BuildContext context) {
    // 1. ✨ เราจะดึง Provider มาแค่ครั้งเดียว โดยไม่ต้อง "ฟัง" แล้ว
    final authProvider = Provider.of<AppAuthProvider>(context, listen: false);

    // 2. ✨ เราจะใช้ StreamBuilder เป็นตัว "ฟัง" สัญญาณโทรศัพท์สายตรงแทน
    return StreamBuilder<AuthStatus>(
      stream: authProvider.statusStream,
      initialData: authProvider.status, // กำหนดสถานะเริ่มต้น
      builder: (context, snapshot) {
        // เรายังสามารถใช้ authProvider ตัวเดิมได้เลย
        final homeScreen = _buildHomeScreen(authProvider);

        // 3. ✨ เราจะสร้าง MaterialApp ขึ้นมาใหม่ทุกครั้งที่มีสัญญาณโทรศัพท์เข้ามา
        return MaterialApp(
          // Key จะช่วยให้ Flutter รู้ว่านี่คือ MaterialApp "คนใหม่"
          key: ValueKey(snapshot.data),

          title: 'MyDent',
          debugShowCheckedModeBanner: false,
          scaffoldMessengerKey: scaffoldMessengerKey,
          navigatorKey: navigatorKey,

          localizationsDelegates: const [
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          supportedLocales: const [Locale('th', 'TH'), Locale('en', 'US')],
          locale: const Locale('th', 'TH'),

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

          home: _showSplash ? const SplashScreen() : homeScreen,

          routes: {
            '/login': (context) => const LoginScreen(),
            '/staff_login': (context) => const StaffLoginScreen(),
            '/calendar': (context) {
              final args =
                  ModalRoute.of(context)?.settings.arguments
                      as Map<String, dynamic>?;
              final patient =
                  args != null ? args['initialPatient'] as Patient? : null;
              return CalendarScreen(initialPatient: patient);
            },
            '/patients': (context) => const PatientsScreen(),
            '/add_patient': (context) => const PatientAddScreen(),
            '/reports': (context) => const ReportsScreen(),
            '/settings': (context) => const SettingsScreen(),
            '/patient_detail': (context) => const PatientDetailScreen(),
            '/treatment_list': (context) => const TreatmentListScreen(),
            '/working_hours': (context) => const WorkingHoursScreen(),
            '/prefix_settings': (context) => const PrefixSettingsScreen(),
            '/appointment_search': (context) => const AppointmentSearchScreen(),
            '/clinic_settings': (context) => const ClinicSettingsScreen(),
            if (kDebugMode) '/dev/preview': (_) => const DevEntry(),
            '/home_admin': (context) => const HomeAdminScreen(),
            '/super_admin': (context) => const HomeSuperAdminScreen(),
            '/home_dentist': (context) => const HomeDentistScreen(),
            '/home_officer': (context) => const HomeOfficerScreen(),
            '/home_guest': (context) => const HomeGuestScreen(),
          },
        );
      },
    );
  }
}
