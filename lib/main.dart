import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'firebase_options.dart';

import 'auth/login_screen.dart';
import 'screens/calendar_screen.dart';
import 'screens/patients_screen.dart';
import 'screens/patient_add.dart';
import 'screens/reports_screen.dart';
import 'screens/setting_screen.dart';
import 'screens/patient_detail.dart';
//import 'screens/treatment_add.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  final prefs = await SharedPreferences.getInstance();
  final skipLogin = prefs.getBool('skipLogin') ?? false;
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
      locale: const Locale('th', 'TH'),
      supportedLocales: const [Locale('th', 'TH'), Locale('en', 'US')],
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
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
        '/':
            (context) =>
                skipLogin
                    ? CalendarScreen(showReset: true)
                    : const LoginScreen(),
        '/calendar': (context) => const CalendarScreen(),
        '/login': (context) => const LoginScreen(),
        '/patients': (context) => const PatientsScreen(),
        '/add_patient': (context) => const PatientAddScreen(),
        '/reports': (context) => const ReportsScreen(),
        '/settings': (context) => const SettingsScreen(),
        '/patient_detail': (context) => const PatientDetailScreen(),
        // '/treatment_add': (context) {
        //   final args =
        //       ModalRoute.of(context)?.settings.arguments
        //           as Map<String, dynamic>?;
        //   final String patientId = args?['patientId'] ?? '';
        //   final Map<String, dynamic>? treatmentMap = args?['treatment'];

        //   return TreatmentAddScreen(
        //     patientId: patientId,
        //     treatment: treatmentMap,
        //   );
        // },
      },
    );
  }
}
