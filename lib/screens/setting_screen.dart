import 'package:flutter/material.dart';
// 💖 NEW: import หน้าตั้งค่าการพิมพ์ที่เราเพิ่งสร้างเข้ามา
import '../features/printing/render/printer_settings_page.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:firebase_auth/firebase_auth.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  int _selectedIndex = 4;

  void _onItemTapped(int index) {
    setState(() {
      _selectedIndex = index;
    });

    if (index == 0) {
      Navigator.pushReplacementNamed(context, '/calendar');
    } else if (index == 1) {
      Navigator.pushReplacementNamed(context, '/patients');
    } else if (index == 3) {
      Navigator.pushReplacementNamed(context, '/appointment_search');
    } else if (index == 4) {
      // stay on settings
    }
  }

  // Laila's new logout function
  Future<void> _logout() async {
    try {
      await FirebaseAuth.instance.signOut();
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove('skipLogin'); // Clear skip login flag
      if (!mounted) return;
      Navigator.pushNamedAndRemoveUntil(
        context,
        '/login',
        (Route<dynamic> route) => false,
      );
    } catch (e) {
      // TODO: Handle logout error
      print(e);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFEFE0FF),
      appBar: AppBar(
        title: const Text("ตั้งค่า"),
        backgroundColor: const Color(0xFFE0BBFF),
        elevation: 0,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: ListView(
          children: [
            _buildSettingCard(
              context,
              icon: Icons.healing,
              title: "รายการหัตถการ",
              subtitle: "ตั้งค่ารายการรักษาที่คลินิกมี",
              onTap: () {
                Navigator.pushNamed(context, '/treatment_list');
              },
            ),
            _buildSettingCard(
              context,
              icon: Icons.access_time,
              title: "เวลาทำการ",
              subtitle: "ตั้งค่าเวลาเปิด-ปิดคลินิกแต่ละวัน",
              onTap: () {
                Navigator.pushNamed(context, '/working_hours');
              },
            ),
            _buildSettingCard(
              context,
              icon: Icons.local_hospital_outlined,
              title: "ข้อมูลคลินิก",
              subtitle: "โลโก้ / ที่อยู่ / เบอร์โทร / Line ID",
              onTap: () {
                Navigator.pushNamed(context, '/clinic_settings');
              },
            ),
            _buildSettingCard(
              context,
              icon: Icons.badge_outlined,
              title: "คำนำหน้านาม",
              subtitle: "เพิ่ม/แก้ไข/ลบคำนำหน้านามของคลินิก",
              onTap: () {
                Navigator.pushNamed(context, '/prefix_settings');
              },
            ),
            // 💖 NEW: เพิ่มเมนู "ตั้งค่าการพิมพ์" เข้าไปตรงนี้เลยค่า
            _buildSettingCard(
              context,
              icon: Icons.print, // ไอคอนรูปเครื่องพิมพ์น่ารักๆ
              title: "ตั้งค่าการพิมพ์",
              subtitle: "ปรับขนาดและระยะห่างของสลิป",
              onTap: () {
                // ใช้ Navigator.push ธรรมดาเพื่อเปิดหน้าใหม่ขึ้นมาทับ
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => const PrinterSettingsPage()),
                );
              },
            ),
            const SizedBox(height: 32),
            // 💖 NEW: Laila's logout button
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: _logout,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFF47FA1),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                ),
                icon: const Icon(Icons.logout),
                label: const Text(
                  'ออกจากระบบ',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
      bottomNavigationBar: BottomAppBar(
        shape: const CircularNotchedRectangle(),
        notchMargin: 8,
        color: const Color(0xFFFBEAFF),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16.0),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              IconButton(
                icon: const Icon(Icons.calendar_today, size: 30),
                color: _selectedIndex == 0 ? Colors.purple : Colors.purple.shade200,
                onPressed: () => _onItemTapped(0),
              ),
              IconButton(
                icon: const Icon(Icons.people_alt, size: 30),
                color: _selectedIndex == 1 ? Colors.purple : Colors.purple.shade200,
                onPressed: () => _onItemTapped(1),
              ),
              const SizedBox(width: 40),
              IconButton(
                icon: const Icon(Icons.search_rounded, size: 30),
                color: _selectedIndex == 3 ? Colors.purple : Colors.purple.shade200,
                onPressed: () => _onItemTapped(3),
              ),
              IconButton(
                icon: const Icon(Icons.settings, size: 30),
                color: _selectedIndex == 4 ? Colors.purple : Colors.purple.shade200,
                onPressed: () => _onItemTapped(4),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSettingCard(
    BuildContext context, {
    required IconData icon,
    required String title,
    String? subtitle,
    required VoidCallback onTap,
  }) {
    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      color: Colors.white,
      elevation: 3,
      margin: const EdgeInsets.only(bottom: 16),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: Colors.purple.shade100,
          child: Icon(icon, color: Colors.purple),
        ),
        title: Text(title, style: const TextStyle(fontWeight: FontWeight.bold)),
        subtitle: subtitle != null ? Text(subtitle) : null,
        trailing: const Icon(Icons.arrow_forward_ios, size: 18),
        onTap: onTap,
      ),
    );
  }
}
