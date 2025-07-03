// 📁 lib/widgets/view_mode_selector.dart (เฟอร์นิเจอร์ชิ้นที่สองของเรา ✨)

import 'package:flutter/material.dart';
import 'package:table_calendar/table_calendar.dart';

class ViewModeSelector extends StatelessWidget {
  final CalendarFormat calendarFormat;
  final Function(CalendarFormat) onFormatChanged;
  final VoidCallback onDailyViewTapped;

  const ViewModeSelector({
    super.key,
    required this.calendarFormat,
    required this.onFormatChanged,
    required this.onDailyViewTapped,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        _buildViewModeButton(
          label: 'เดือน',
          icon: Icons.calendar_month,
          isActive: calendarFormat == CalendarFormat.month,
          onPressed: () => onFormatChanged(CalendarFormat.month),
        ),
        _buildViewModeButton(
          label: 'สัปดาห์',
          icon: Icons.view_week,
          isActive: calendarFormat == CalendarFormat.week,
          onPressed: () => onFormatChanged(CalendarFormat.week),
        ),
        _buildViewModeButton(
          label: 'วัน',
          icon: Icons.calendar_view_day_outlined,
          isActive: false, // ปุ่มนี้ไม่เคย active เพราะเป็นการนำทาง
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