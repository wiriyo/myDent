import 'package:flutter/material.dart';

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
      Navigator.pushReplacementNamed(context, '/reports');
    } else if (index == 4) {
      // stay on settings
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
            // เพิ่มเมนูอื่น ๆ ได้อีกในอนาคต
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
                icon: const Icon(Icons.bar_chart, size: 30),
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
