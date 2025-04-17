import 'package:flutter/material.dart';

class HomeAdminScreen extends StatelessWidget {
  const HomeAdminScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFEFE0FF),
      appBar: AppBar(
        title: const Text(
          'MyDent Home',
          style: TextStyle(
            fontFamily: 'Poppins',
            fontWeight: FontWeight.bold,
            color: Color(0xFF6A4DBA),
          ),
        ),
        backgroundColor: const Color(0xFFFBEAFF),
        elevation: 0,
        centerTitle: true,
      ),
      body: ListView(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 36),
        children: [
          const Text(
            'Welcome Admin! 💼',
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              fontFamily: 'Poppins',
              color: Color(0xFF6A4DBA),
            ),
          ),
          const SizedBox(height: 12),
          const Text(
            'Please select an option below to manage the clinic.',
            style: TextStyle(fontSize: 14, fontFamily: 'Poppins'),
          ),
          const SizedBox(height: 32),
          _buildDashboardButton(context, 'Appointments', Icons.calendar_month, Colors.pinkAccent),
          const SizedBox(height: 16),
          _buildDashboardButton(context, 'Patients', Icons.people_alt, Colors.lightBlueAccent),
          const SizedBox(height: 16),
          _buildDashboardButton(context, 'Treatments', Icons.medical_services, Colors.greenAccent),
          const SizedBox(height: 16),
          _buildDashboardButton(context, 'Reports', Icons.bar_chart, Colors.orangeAccent),
          const SizedBox(height: 16),
          _buildDashboardButton(context, 'Settings', Icons.settings, Colors.deepPurpleAccent),
        ],
      ),
    );
  }

  Widget _buildDashboardButton(BuildContext context, String label, IconData icon, Color color) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8.0),
      child: ElevatedButton.icon(
        onPressed: () {
          // TODO: Add navigation
        },
        icon: Icon(icon, color: Colors.white),
        label: Text(
          label,
          style: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            fontFamily: 'Poppins',
          ),
        ),
        style: ElevatedButton.styleFrom(
          minimumSize: const Size.fromHeight(56),
          backgroundColor: color.withOpacity(0.8),
          foregroundColor: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
        ),
      ),
    );
  }
}
