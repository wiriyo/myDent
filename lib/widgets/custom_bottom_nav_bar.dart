// ----------------------------------------------------------------
// 📁 lib/widgets/custom_bottom_nav_bar.dart (UPGRADED)
// v1.3.0 - ✨ Update Navigation to AppointmentSearchScreen
// ----------------------------------------------------------------
import 'package:flutter/material.dart';
import '../styles/app_theme.dart';
import '../screens/calendar_screen.dart';
import '../screens/patients_screen.dart';
import '../screens/appointment_search_screen.dart'; // ✨ [CHANGED] import หน้าใหม่
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
          // ✨ [CHANGED] เปลี่ยนไอคอนและ tooltip ให้เข้ากับหน้าใหม่
          _buildNavIconButton(context, icon: Icons.search_rounded, tooltip: 'ค้นหานัดหมาย', index: 3),
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
    final String? currentRouteName = ModalRoute.of(context)?.settings.name;

    final Map<int, String> routeMap = {
      0: '/calendar',
      1: '/patients',
      3: '/appointment_search', // ✨ [CHANGED] เปลี่ยนเส้นทางไปหน้าใหม่
      4: '/settings',
    };

    final String targetRoute = routeMap[index] ?? '';

    if (currentRouteName == targetRoute) {
      return;
    }

    Widget page;
    switch (index) {
      case 0:
        page = const CalendarScreen();
        break;
      case 1:
        page = const PatientsScreen();
        break;
      case 3:
        page = const AppointmentSearchScreen(); // ✨ [CHANGED] เปลี่ยนไปเรียกหน้าใหม่
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
