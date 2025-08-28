// 📁 lib/home/home_admin.dart
// v1.0.6 - 💖 Laila's Firestore Name Fix
// ไลลาได้แก้ไขหน้าจอให้ดึงชื่อผู้ใช้จาก Firestore
// เพื่อให้แสดงชื่อที่ถูกต้องตามที่บันทึกไว้ค่ะ

import 'package:flutter/material.dart';
import '../styles/app_theme.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../auth/auth_service.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class HomeAdminScreen extends StatefulWidget {
  const HomeAdminScreen({super.key});

  @override
  State<HomeAdminScreen> createState() => _HomeAdminScreenState();
}

class _HomeAdminScreenState extends State<HomeAdminScreen> {
  String? _displayName;
  final AuthService _authService = AuthService();

  @override
  void initState() {
    super.initState();
    _fetchDisplayName();
  }

  Future<void> _fetchDisplayName() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      final String? name = await _authService.getUserName(user.uid);
      if (mounted) {
        setState(() {
          _displayName = name ?? 'ผู้ดูแลระบบ';
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    // ใช้ _displayName ที่ดึงมาจาก Firestore
    final String displayName = _displayName ?? 'ผู้ดูแลระบบ';

    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(
        title: const Text('หน้าจอผู้ดูแลระบบ'),
        backgroundColor: Colors.pink.shade100, // สีชมพูพาสเทลน่ารัก ๆ
        centerTitle: true,
        iconTheme: const IconThemeData(color: Color(0xFF5A2A69)),
      ),
      body: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Welcome Text
              Text(
                'ยินดีต้อนรับคุณ $displayName 👑',
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: AppTheme.textPrimary,
                ),
              ),
              const SizedBox(height: 32),
              
              // Appointment Button
              _buildFeatureButton(
                context,
                icon: Icons.calendar_month,
                label: 'นัดหมาย',
                onPressed: () => Navigator.pushNamed(context, '/calendar'),
                color: AppTheme.buttonCallFg, 
              ),
              const SizedBox(height: 16),
              
              // Patients Button
              _buildFeatureButton(
                context,
                icon: Icons.groups,
                label: 'คนไข้',
                onPressed: () => Navigator.pushNamed(context, '/patients'),
                color: AppTheme.buttonEditFg, 
              ),
              const SizedBox(height: 16),
              
              // Appointment Search Button
              _buildFeatureButton(
                context,
                icon: Icons.search,
                label: 'ค้นหานัดหมาย',
                onPressed: () => Navigator.pushNamed(context, '/appointment_search'),
                color: AppTheme.iconMaleColor, 
              ),
              const SizedBox(height: 16),
              
              // Settings Button
              _buildFeatureButton(
                context,
                icon: Icons.settings,
                label: 'ตั้งค่า',
                onPressed: () => Navigator.pushNamed(context, '/settings'),
                color: AppTheme.primaryLight, 
              ),
              const SizedBox(height: 16),
              
              // TODO: Add more admin-specific widgets here
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildFeatureButton(BuildContext context, {
    required IconData icon,
    required String label,
    required VoidCallback onPressed,
    required Color color,
  }) {
    return ElevatedButton(
      onPressed: onPressed,
      style: ElevatedButton.styleFrom(
        backgroundColor: color.withOpacity(0.8),
        foregroundColor: Colors.white,
        padding: const EdgeInsets.symmetric(vertical: 20),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
        elevation: 5,
        shadowColor: color.withOpacity(0.5),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, size: 40),
          const SizedBox(height: 8),
          Text(
            label,
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              fontFamily: 'Poppins',
            ),
          ),
        ],
      ),
    );
  }
}
