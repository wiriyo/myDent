// 📁 lib/widgets/custom_bottom_nav_bar.dart

import 'package:flutter/material.dart';
import '../styles/app_theme.dart';
import '../screens/calendar_screen.dart';
import '../screens/patients_screen.dart';
import '../screens/reports_screen.dart';
import '../screens/setting_screen.dart';

class CustomBottomNavBar extends StatelessWidget {
  final int selectedIndex;

  const CustomBottomNavBar({
    super.key,
    required this.selectedIndex,
  });

  @override
  Widget build(BuildContext context) {
    return BottomAppBar(
      shape: const CircularNotchedRectangle(),
      notchMargin: 8.0,
      color: AppTheme.bottomNav,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: <Widget>[
          _buildNavIconButton(context, icon: Icons.calendar_today, tooltip: 'ปฏิทิน', index: 0),
          _buildNavIconButton(context, icon: Icons.people_alt, tooltip: 'คนไข้', index: 1),
          const SizedBox(width: 40), // The space for the FAB
          _buildNavIconButton(context, icon: Icons.bar_chart, tooltip: 'รายงาน', index: 3),
          _buildNavIconButton(context, icon: Icons.settings, tooltip: 'ตั้งค่า', index: 4),
        ],
      ),
    );
  }

  Widget _buildNavIconButton(BuildContext context, {required IconData icon, required String tooltip, required int index}) {
    return IconButton(
      icon: Icon(icon, size: 30),
      color: selectedIndex == index ? AppTheme.primary : AppTheme.primaryLight,
      onPressed: () => _onItemTapped(context, index),
      tooltip: tooltip,
    );
  }

  void _onItemTapped(BuildContext context, int index) {
    // ไม่ต้องทำอะไรถ้ากดที่หน้าเดิม
    if (selectedIndex == index) return;

    Widget page;
    switch (index) {
      case 0:
        page = const CalendarScreen();
        break;
      case 1:
        page = const PatientsScreen();
        break;
      case 3:
        page = const ReportsScreen();
        break;
      case 4:
        page = const SettingsScreen();
        break;
      default:
        return; // ไม่ควรเกิดขึ้น
    }
    
    // ใช้ pushReplacement เพื่อไม่ให้หน้าจอก่อนหน้าซ้อนทับกันค่ะ
    Navigator.pushReplacement(
      context,
      // ใช้ PageRouteBuilder เพื่อให้ไม่มี Animation ตอนเปลี่ยนหน้าค่ะ
      PageRouteBuilder(
        pageBuilder: (context, animation1, animation2) => page,
        transitionDuration: Duration.zero,
        reverseTransitionDuration: Duration.zero,
      ),
    );
  }
}
