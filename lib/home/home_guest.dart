import 'package:flutter/material.dart';

class HomeGuestScreen extends StatelessWidget {
  const HomeGuestScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      backgroundColor: Color(0xFFEFE0FF),
      body: Center(
        child: Text(
          'Guest Dashboard - Coming Soon 💖',
          style: TextStyle(fontFamily: 'Poppins', fontSize: 16),
        ),
      ),
    );
  }
}
