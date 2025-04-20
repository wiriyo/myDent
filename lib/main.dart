import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'auth/login_screen.dart';
import 'auth/signup_screen.dart';
import 'home/home_admin.dart';
import 'home/home_dentist.dart';
import 'home/home_officer.dart';
import 'home/home_guest.dart';
import 'screens/appointments_screen.dart';
import 'screens/patients_screen.dart';
import 'screens/reports_screen.dart';
import 'screens/setting_screen.dart';
import 'screens/treatments_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp();
  runApp(const MyDentAppInitializer());
}

class MyDentAppInitializer extends StatelessWidget {
  const MyDentAppInitializer({super.key});

  Future<bool> _checkSkipLogin() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool('skipLogin') ?? false;
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<bool>(
      future: _checkSkipLogin(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return const MaterialApp(
            home: Scaffold(body: Center(child: CircularProgressIndicator())),
          );
        }

        final skipLogin = snapshot.data!;

        return MyApp(skipLogin: skipLogin);
      },
    );
  }
}

class MyApp extends StatelessWidget {
  final bool skipLogin;
  const MyApp({super.key, required this.skipLogin});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'MyDent',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        fontFamily: 'Poppins',
        scaffoldBackgroundColor: const Color(0xFFF3E5F5),
        primarySwatch: Colors.deepPurple,
        appBarTheme: const AppBarTheme(
          backgroundColor: Color(0xFFFBEAFF),
          foregroundColor: Color(0xFF6A4DBA),
          elevation: 0,
          centerTitle: true,
          titleTextStyle: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
            fontFamily: 'Poppins',
          ),
        ),
        inputDecorationTheme: InputDecorationTheme(
          filled: true,
          fillColor: Colors.white,
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
        ),
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.purpleAccent,
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
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
      home: skipLogin
          ? const AppointmentsScreen()
          : StreamBuilder<User?>(
              stream: FirebaseAuth.instance.authStateChanges(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Scaffold(
                    body: Center(child: CircularProgressIndicator()),
                  );
                } else if (snapshot.hasData) {
                  return const AppointmentsScreen();
                } else {
                  return const LoginScreen();
                }
              },
            ),
      routes: {
        '/signup': (context) => const SignUpScreen(),
        '/home': (context) => const RoleBasedHomeScreen(),
        '/home/admin': (context) => const HomeAdminScreen(),
        '/home/dentist': (context) => const HomeDentistScreen(),
        '/home/officer': (context) => const HomeOfficerScreen(),
        '/home/guest': (context) => const HomeGuestScreen(),
        '/appointments': (context) => const AppointmentsScreen(),
        '/patients': (context) => const PatientsScreen(),
        '/reports': (context) => const ReportsScreen(),
        '/settings': (context) => const SettingsScreen(),
        '/treatments': (context) => const TreatmentsScreen(),
      },
    );
  }
}


class RoleBasedHomeScreen extends StatelessWidget {
  const RoleBasedHomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final String? role = ModalRoute.of(context)!.settings.arguments as String?;

    if (role == null) {
      Future.microtask(() {
        Navigator.pushReplacementNamed(context, '/');
      });
      return const Scaffold();
    }

    if (role == 'admin') {
      return const HomeAdminScreen();
    } else if (role == 'dentist') {
      return const HomeDentistScreen();
    } else if (role == 'officer') {
      return const HomeOfficerScreen();
    } else {
      return const HomeGuestScreen();
    }
  }
}
