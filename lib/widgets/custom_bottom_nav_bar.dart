// v1.1.0 - ✨ Smarter Navigation Logic
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
    // ✨ [LOGIC-UPGRADE v1.1] ทำให้การนำทางฉลาดขึ้น!
    // เราจะเช็กชื่อ Route ของหน้าปัจจุบัน
    final String? currentRouteName = ModalRoute.of(context)?.settings.name;

    // กำหนด Route เป้าหมายของแต่ละไอคอน
    final Map<int, String> routeMap = {
      0: '/calendar',
      1: '/patients',
      3: '/reports',
      4: '/settings',
    };

    final String targetRoute = routeMap[index] ?? '';

    // ถ้าเราอยู่ที่หน้าเป้าหมายแล้ว (เช่น อยู่หน้า /patients แล้วกดไอคอน patients)
    // เราจะไม่ทำอะไรเลย เพื่อป้องกันการโหลดหน้าซ้ำซ้อนค่ะ
    if (currentRouteName == targetRoute) {
      print('🐞 Already on route: $targetRoute. Navigation cancelled.');
      return;
    }

    // ถ้าไม่ได้อยู่หน้าเป้าหมาย ก็จะนำทางไปหน้าใหม่ค่ะ
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
        return;
    }
    
    Navigator.pushReplacement(
      context,
      PageRouteBuilder(
        pageBuilder: (context, animation1, animation2) => page,
        transitionDuration: Duration.zero,
        reverseTransitionDuration: Duration.zero,
      ),
    );
  }
}
