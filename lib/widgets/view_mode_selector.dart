// v1.0.1
// 📁 lib/widgets/view_mode_selector.dart (เฟอร์นิเจอร์ชิ้นที่สองของเรา ✨)

import 'package:flutter/material.dart';
import 'package:table_calendar/table_calendar.dart';

class ViewModeSelector extends StatelessWidget {
  final CalendarFormat calendarFormat;
  final Function(CalendarFormat) onFormatChanged;
  final VoidCallback onDailyViewTapped;
  // ✨ [FIX] เพิ่มตัวแปรใหม่เพื่อบอกว่าตอนนี้เราอยู่ในหน้ารายวันหรือเปล่า
  final bool isDailyViewActive;

  const ViewModeSelector({
    super.key,
    required this.calendarFormat,
    required this.onFormatChanged,
    required this.onDailyViewTapped,
    this.isDailyViewActive = false, // ✨ ค่าเริ่มต้นคือ false
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        _buildViewModeButton(
          label: 'เดือน',
          icon: Icons.calendar_month,
          // ✨ [FIX] จะไฮไลท์ก็ต่อเมื่อไม่ได้อยู่ในหน้ารายวัน และ format เป็น month
          isActive: !isDailyViewActive && calendarFormat == CalendarFormat.month,
          onPressed: () => onFormatChanged(CalendarFormat.month),
        ),
        _buildViewModeButton(
          label: 'สัปดาห์',
          icon: Icons.view_week,
          // ✨ [FIX] จะไฮไลท์ก็ต่อเมื่อไม่ได้อยู่ในหน้ารายวัน และ format เป็น week
          isActive: !isDailyViewActive && calendarFormat == CalendarFormat.week,
          onPressed: () => onFormatChanged(CalendarFormat.week),
        ),
        _buildViewModeButton(
          label: 'วัน',
          icon: Icons.calendar_view_day_outlined,
          // ✨ [FIX] จะไฮไลท์ก็ต่อเมื่อเราอยู่ในหน้ารายวัน!
          isActive: isDailyViewActive,
          onPressed: onDailyViewTapped,
        ),
      ],
    );
  }

  Widget _buildViewModeButton({
    required String label,
    required IconData icon,
    required bool isActive,
    required VoidCallback onPressed,
  }) {
    final activeColor = Colors.purple.shade100;
    final activeTextColor = Colors.purple.shade800;
    final inactiveColor = Colors.grey.shade200;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4.0),
      child: TextButton.icon(
        onPressed: onPressed,
        icon: Icon(icon, color: isActive ? activeTextColor : Colors.grey.shade600, size: 18),
        label: Text(
          label,
          style: TextStyle(
            color: isActive ? activeTextColor : Colors.grey.shade700,
            fontWeight: isActive ? FontWeight.bold : FontWeight.normal,
          ),
        ),
        style: TextButton.styleFrom(
          backgroundColor: isActive ? activeColor : Colors.white,
          side: BorderSide(color: isActive ? Colors.transparent : inactiveColor),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          padding: const EdgeInsets.symmetric(horizontal: 16),
        ),
      ),
    );
  }
}
