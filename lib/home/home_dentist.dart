import 'package:flutter/material.dart';

class HomeDentistScreen extends StatelessWidget {
  const HomeDentistScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      backgroundColor: Color(0xFFEFE0FF),
      body: Center(
        child: Text(
          'Dentist Dashboard - Coming Soon 💜',
          style: TextStyle(fontFamily: 'Poppins', fontSize: 16),
        ),
      ),
    );
  }
}
