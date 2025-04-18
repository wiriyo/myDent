import 'package:flutter/material.dart';
import 'package:mydent_app/screens/calendar_screen.dart';

class AppointmentsScreen extends StatelessWidget {
  const AppointmentsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Appoinments")),
      body: CalendarScreen(),
    );
  }
}
