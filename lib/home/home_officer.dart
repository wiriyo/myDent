import 'package:flutter/material.dart';

class HomeOfficerScreen extends StatelessWidget {
  const HomeOfficerScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      backgroundColor: Color(0xFFEFE0FF),
      body: Center(
        child: Text(
          'Officer Dashboard - Coming Soon 💙',
          style: TextStyle(fontFamily: 'Poppins', fontSize: 16),
        ),
      ),
    );
  }
}
