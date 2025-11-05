// 📁 lib/main.dart
// v4.1.0 - Laila's Release Optimisation
// ลดภาระงานในเฟรมเวิร์กด้วย AnimatedBuilder ให้ลื่นไหลสุด ๆ ค่ะ! 💖

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
import 'package:flutter/foundation.dart' show debugPrint, kDebugMode, kIsWeb;

import 'core/widgets/responsive_shell.dart';
import 'firebase_web_loader.dart';

final GlobalKey<ScaffoldMessengerState> scaffoldMessengerKey =
    GlobalKey<ScaffoldMessengerState>();
final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await _ensureFirebaseInitialized();

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

Future<void> _ensureFirebaseInitialized() async {
  if (kIsWeb) {
    await ensureFirebaseWebLoaded();
    await _initializeFirebase(ignoreDuplicateApp: true);
    return;
  }

  if (Firebase.apps.isNotEmpty) {
    return;
  }

  await _initializeFirebase(ignoreDuplicateApp: false);
}

Future<void> _initializeFirebase({required bool ignoreDuplicateApp}) async {
  try {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
  } on FirebaseException catch (e) {
    if (ignoreDuplicateApp && e.code == 'duplicate-app') {
      return;
    }
    rethrow;
  } catch (error) {
    if (ignoreDuplicateApp && _shouldIgnoreFirebaseAppsError(error)) {
      return;
    }
    rethrow;
  }
}

bool _shouldIgnoreFirebaseAppsError(Object error) {
  if (!kIsWeb) {
    return false;
  }
  final message = error.toString().toLowerCase();
  if (message.isEmpty) {
    return false;
  }
  if (message.contains('firebase_core is not defined')) {
    return true;
  }
  if (message.contains("cannot read properties of undefined") &&
      message.contains('getapps')) {
    return true;
  }
  if (message.contains('firebase_core.getapps') &&
      (message.contains('is not a function') || message.contains('is undefined'))) {
    return true;
  }
  if (message.contains('no firebase app') && message.contains('initializeapp')) {
    return true;
  }
  return false;
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
    _showSplash =
        widget.initialWelcomeScreenEnabled ?? FeatureFlags.showInAppSplash;
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
    if (kDebugMode) {
      debugPrint(
        '🕵️‍♀️ Laila Debug: _buildHomeScreen is deciding! Status is: ${authProvider.status}',
      );
    }
    switch (authProvider.status) {
      case AuthStatus.loggedOut:
        return const LoginScreen();
      case AuthStatus.clinicVerified:
        return const StaffLoginScreen();
      case AuthStatus.loggedIn:
        final staffRole = authProvider.currentStaff?.role;
        if (kDebugMode) {
          debugPrint(
            '🕵️‍♀️ Laila Debug: Staff role is: $staffRole. Navigating to home screen...',
          );
        }
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

  bool _shouldBypassResponsiveShell(Widget widget) {
    // Allow dialogs to retain their built-in dimensions
    return widget is Dialog || widget is AlertDialog || widget is SimpleDialog;
  }

  @override
  Widget build(BuildContext context) {
    // 1. ✨ เราจะดึง Provider มาแค่ครั้งเดียว โดยไม่ต้อง "ฟัง" แล้ว
    final authProvider = Provider.of<AppAuthProvider>(context, listen: false);

    // 2. ✨ ใช้ AnimatedBuilder เพื่อฟังสัญญาณจาก Provider แบบเบาแรง
    return AnimatedBuilder(
      animation: authProvider,
      builder: (context, _) {
        final homeScreen = _buildHomeScreen(authProvider);

        return MaterialApp(
          key: ValueKey(authProvider.status),
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

          builder: (context, child) {
            final media = MediaQuery.of(context);
            final clampedTextScaler = media.textScaler.clamp(
              minScaleFactor: 1.0,
              maxScaleFactor: 1.2,
            );
            final mediaWithClamp = media.copyWith(
              textScaler: clampedTextScaler,
            );
            final effectiveChild = child ?? const SizedBox.shrink();

            if (_shouldBypassResponsiveShell(effectiveChild)) {
              return MediaQuery(
                data: mediaWithClamp,
                child: effectiveChild,
              );
            }

            return MediaQuery(
              data: mediaWithClamp,
              child: ResponsiveShell(
                // responsive for web
                child: effectiveChild,
              ),
            );
          },

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
