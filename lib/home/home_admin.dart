import 'package:flutter/material.dart';


class HomeAdminScreen extends StatelessWidget {
  const HomeAdminScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFEFE0FF), // พื้นหลังม่วงอ่อน
      body: SingleChildScrollView(
        child: Column(
          children: [
            const SizedBox(height: 40),
            Image.asset('assets/images/tooth_logo.png', height: 120),
            const SizedBox(height: 12),
            const Text(
              'Admin',
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                fontFamily: 'Poppins',
                color: Color(0xFF6A4DBA),
              ),
            ),
            const SizedBox(height: 32),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Column(
                children: [
                  _buildDashboardButton(
                    icon: Icons.calendar_month,
                    label: 'Appointments',
                    color: Colors.pinkAccent,
                    onPressed: () => Navigator.pushNamed(context, '/appointments'),
                  ),
                  _buildDashboardButton(
                    icon: Icons.people,
                    label: 'Patients',
                    color: Colors.lightBlueAccent,
                    onPressed: () =>  Navigator.pushNamed(context, '/patients'),
                  ),
                  _buildDashboardButton(
                    icon: Icons.medical_services,
                    label: 'Treatments',
                    color: Colors.greenAccent,
                    onPressed: () =>  Navigator.pushNamed(context, '/treatments'),
                  ),
                  _buildDashboardButton(
                    icon: Icons.bar_chart,
                    label: 'Reports',
                    color: Colors.orangeAccent,
                    onPressed: () =>  Navigator.pushNamed(context, '/reports'),
                  ),
                  _buildDashboardButton(
                    icon: Icons.settings,
                    label: 'Settings',
                    color: Colors.deepPurpleAccent,
                    onPressed: () =>  Navigator.pushNamed(context, '/settings'),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }

  Widget _buildDashboardButton({
    required IconData icon,
    required String label,
    required Color color,
    required VoidCallback onPressed,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: ElevatedButton.icon(
        icon: Icon(icon, color: Colors.white),
        label: Text(
          label,
          style: const TextStyle(
            fontFamily: 'Poppins',
            fontSize: 16,
            fontWeight: FontWeight.bold,
          ),
        ),
        onPressed: onPressed,
        style: ElevatedButton.styleFrom(
          backgroundColor: color.withOpacity(0.85),
          foregroundColor: Colors.white,
          minimumSize: const Size.fromHeight(56),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
        ),
      ),
    );
  }
}
