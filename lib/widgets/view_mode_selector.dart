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
    return LayoutBuilder(
      builder: (context, constraints) {
        final isCompact = constraints.maxWidth < 320;
        return Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Expanded(
              child: _buildViewModeButton(
                label: '\u0e40\u0e14\u0e37\u0e2d\u0e19',
                icon: Icons.calendar_month,
                // ?????????? active ????????? format
                isActive: !isDailyViewActive &&
                    calendarFormat == CalendarFormat.month,
                onPressed: () => onFormatChanged(CalendarFormat.month),
                isCompact: isCompact,
              ),
            ),
            const SizedBox(width: 6),
            Expanded(
              child: _buildViewModeButton(
                label: '\u0e2a\u0e31\u0e1b\u0e14\u0e32\u0e2b\u0e4c',
                icon: Icons.view_week,
                // ?????????? active ????????? format
                isActive: !isDailyViewActive &&
                    calendarFormat == CalendarFormat.week,
                onPressed: () => onFormatChanged(CalendarFormat.week),
                isCompact: isCompact,
              ),
            ),
            const SizedBox(width: 6),
            Expanded(
              child: _buildViewModeButton(
                label: '\u0e27\u0e31\u0e19',
                icon: Icons.calendar_view_day_outlined,
                // ?????????? active ????????? daily view
                isActive: isDailyViewActive,
                onPressed: onDailyViewTapped,
                isCompact: isCompact,
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildViewModeButton({
    required String label,
    required IconData icon,
    required bool isActive,
    required VoidCallback onPressed,
    required bool isCompact,
  }) {
    final activeColor = Colors.purple.shade100;
    final activeTextColor = Colors.purple.shade800;
    final inactiveColor = Colors.grey.shade200;

    return TextButton.icon(
      onPressed: onPressed,
      icon: Icon(
        icon,
        color: isActive ? activeTextColor : Colors.grey.shade600,
        size: isCompact ? 16 : 18,
      ),
      label: Text(
        label,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: TextStyle(
          fontSize: isCompact ? 12 : 13,
          color: isActive ? activeTextColor : Colors.grey.shade700,
          fontWeight: isActive ? FontWeight.bold : FontWeight.normal,
        ),
      ),
      style: TextButton.styleFrom(
        backgroundColor: isActive ? activeColor : Colors.white,
        side: BorderSide(color: isActive ? Colors.transparent : inactiveColor),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        padding: EdgeInsets.symmetric(
          horizontal: isCompact ? 8 : 12,
          vertical: isCompact ? 6 : 8,
        ),
        visualDensity: VisualDensity.compact,
      ),
    );
  }
}
