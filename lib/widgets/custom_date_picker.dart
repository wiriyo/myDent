// v1.3.0 - ✨ Added Sequential Month Picker After Year Selection
// 📁 lib/widgets/custom_date_picker.dart

import 'dart:math';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:table_calendar/table_calendar.dart';
import '../styles/app_theme.dart';

Future<DateTime?> showBuddhistDatePicker({
  required BuildContext context,
  required DateTime initialDate,
  required DateTime firstDate,
  required DateTime lastDate,
}) {
  return showDialog<DateTime>(
    context: context,
    builder: (BuildContext context) {
      return BuddhistDatePickerDialog(
        initialDate: initialDate,
        firstDate: firstDate,
        lastDate: lastDate,
      );
    },
  );
}

class BuddhistDatePickerDialog extends StatefulWidget {
  final DateTime initialDate;
  final DateTime firstDate;
  final DateTime lastDate;

  const BuddhistDatePickerDialog({
    super.key,
    required this.initialDate,
    required this.firstDate,
    required this.lastDate,
  });

  @override
  State<BuddhistDatePickerDialog> createState() => _BuddhistDatePickerDialogState();
}

class _BuddhistDatePickerDialogState extends State<BuddhistDatePickerDialog> {
  late DateTime _focusedDay;
  late DateTime _selectedDay;

  @override
  void initState() {
    super.initState();
    _focusedDay = widget.initialDate;
    _selectedDay = widget.initialDate;
  }

  // 💖 [SEQUENTIAL-PICKER v1.3.0] ไลลาเปลี่ยนชื่อฟังก์ชันและปรับปรุงกระบวนการทั้งหมดเลยค่ะ
  void _selectYearAndMonth(BuildContext context) async {
    // --- ขั้นตอนที่ 1: เลือกปี ---
    final int initialBuddhistYear = _focusedDay.year + 543;
    final int firstBuddhistYear = widget.firstDate.year + 543;
    final int lastBuddhistYear = widget.lastDate.year + 543;
    
    final pickedBuddhistYear = await _showYearPicker(context, initialBuddhistYear, firstBuddhistYear, lastBuddhistYear);

    // ถ้าผู้ใช้ไม่ได้เลือกปี (กด 'ยกเลิก') ก็ไม่ต้องทำอะไรต่อค่ะ
    if (pickedBuddhistYear == null) return;

    // --- ขั้นตอนที่ 2: เลือกเดือน ---
    // ถ้าเลือกปีสำเร็จ ให้แสดงตัวเลือกเดือนต่อทันที
    final pickedMonth = await _showMonthPicker(context, pickedBuddhistYear);

    // ถ้าผู้ใช้ไม่ได้เลือกเดือน ก็ไม่ต้องทำอะไรต่อค่ะ
    if (pickedMonth == null) return;

    // --- ขั้นตอนที่ 3: อัปเดตปฏิทิน ---
    final gregorianYear = pickedBuddhistYear - 543;
    setState(() {
      _focusedDay = DateTime(
        gregorianYear,
        pickedMonth,
        // ป้องกันวันที่ผิดพลาด (เช่น 29 ก.พ. ในปีที่ไม่มี)
        min(_selectedDay.day, DateUtils.getDaysInMonth(gregorianYear, pickedMonth)),
      );
      // อัปเดตวันที่ที่เลือกไว้ด้วย เผื่อผู้ใช้กด "ตกลง" เลย
      _selectedDay = _focusedDay;
    });
  }

  // ✨ [YEAR-PICKER-HELPER v1.3.0] ไลลาย้ายโค้ดการแสดงตัวเลือกปีมาไว้ในฟังก์ชันนี้ให้เป็นระเบียบค่ะ
  Future<int?> _showYearPicker(BuildContext context, int initialBuddhistYear, int firstBuddhistYear, int lastBuddhistYear) {
    final int yearCount = lastBuddhistYear - firstBuddhistYear + 1;
    int initialIndex = initialBuddhistYear - firstBuddhistYear;
    if (initialIndex < 0 || initialIndex >= yearCount) initialIndex = 0;
    
    final scrollController = ScrollController(initialScrollOffset: (initialIndex - 2.5) * 52.0);

    return showDialog<int>(
      context: context,
      builder: (BuildContext dialogContext) {
        return Dialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20.0)),
          child: SizedBox(
            height: 350,
            width: 300,
            child: Column(
              children: [
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 20.0),
                  child: Text('เลือกปี (พ.ศ.)', style: TextStyle(fontFamily: AppTheme.fontFamily, fontWeight: FontWeight.bold, fontSize: 18, color: AppTheme.primary)),
                ),
                Expanded(
                  child: GridView.builder(
                    controller: scrollController,
                    padding: const EdgeInsets.all(8),
                    gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: 3, childAspectRatio: 2.2, mainAxisSpacing: 8, crossAxisSpacing: 8),
                    itemCount: yearCount,
                    itemBuilder: (context, index) {
                      final int year = firstBuddhistYear + index;
                      final bool isSelected = year == initialBuddhistYear;
                      return Material(
                        color: isSelected ? AppTheme.primaryLight.withOpacity(0.6) : Colors.transparent,
                        borderRadius: BorderRadius.circular(30),
                        child: InkWell(
                          onTap: () => Navigator.of(dialogContext).pop(year),
                          borderRadius: BorderRadius.circular(30),
                          child: Center(
                            child: Text(year.toString(), style: TextStyle(fontFamily: AppTheme.fontFamily, fontSize: 16, fontWeight: isSelected ? FontWeight.bold : FontWeight.normal, color: isSelected ? AppTheme.primary : AppTheme.textPrimary)),
                          ),
                        ),
                      );
                    },
                  ),
                ),
                Align(
                  alignment: Alignment.centerRight,
                  child: Padding(
                    padding: const EdgeInsets.only(bottom: 8.0, right: 8.0),
                    child: TextButton(onPressed: () => Navigator.of(dialogContext).pop(), child: const Text('ยกเลิก', style: TextStyle(fontFamily: AppTheme.fontFamily, color: AppTheme.textSecondary))),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  // ✨ [MONTH-PICKER-HELPER v1.3.0] และนี่คือฟังก์ชันสำหรับเลือกเดือนที่เราสร้างขึ้นมาใหม่ค่ะ
  Future<int?> _showMonthPicker(BuildContext context, int selectedBuddhistYear) {
    final List<String> months = ['มกราคม', 'กุมภาพันธ์', 'มีนาคม', 'เมษายน', 'พฤษภาคม', 'มิถุนายน', 'กรกฎาคม', 'สิงหาคม', 'กันยายน', 'ตุลาคม', 'พฤศจิกายน', 'ธันวาคม'];
    final int currentMonth = _focusedDay.year == (selectedBuddhistYear - 543) ? _focusedDay.month : -1;

    return showDialog<int>(
      context: context,
      builder: (BuildContext dialogContext) {
        return Dialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20.0)),
          child: SizedBox(
            height: 450, // เพิ่มความสูงให้แสดงผลได้ครบ
            width: 300,
            child: Column(
              children: [
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 20.0),
                  child: Text('เลือกเดือน ปี $selectedBuddhistYear', style: const TextStyle(fontFamily: AppTheme.fontFamily, fontWeight: FontWeight.bold, fontSize: 18, color: AppTheme.primary)),
                ),
                Expanded(
                  child: ListView.builder(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    itemCount: months.length,
                    itemBuilder: (context, index) {
                      final monthName = months[index];
                      final monthNumber = index + 1;
                      final bool isSelected = monthNumber == currentMonth;
                      return ListTile(
                        title: Center(
                          child: Text(monthName, style: TextStyle(fontFamily: AppTheme.fontFamily, fontSize: 16, color: isSelected ? AppTheme.primary : AppTheme.textPrimary, fontWeight: isSelected ? FontWeight.bold : FontWeight.normal)),
                        ),
                        onTap: () => Navigator.of(dialogContext).pop(monthNumber),
                      );
                    },
                  ),
                ),
                Align(
                  alignment: Alignment.centerRight,
                  child: Padding(
                    padding: const EdgeInsets.only(bottom: 8.0, right: 8.0),
                    child: TextButton(onPressed: () => Navigator.of(dialogContext).pop(), child: const Text('ยกเลิก', style: TextStyle(fontFamily: AppTheme.fontFamily, color: AppTheme.textSecondary))),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }


  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20.0)),
      child: Container(
        constraints: const BoxConstraints(maxWidth: 400),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TableCalendar(
              locale: 'th_TH',
              focusedDay: _focusedDay,
              selectedDayPredicate: (day) => isSameDay(_selectedDay, day),
              firstDay: widget.firstDate,
              lastDay: widget.lastDate,
              calendarFormat: CalendarFormat.month,
              daysOfWeekHeight: 22.0,
              headerStyle: const HeaderStyle(
                titleCentered: true,
                titleTextStyle: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, fontFamily: AppTheme.fontFamily, color: AppTheme.textPrimary),
                formatButtonVisible: false,
                leftChevronIcon: Icon(Icons.chevron_left, color: AppTheme.primary),
                rightChevronIcon: Icon(Icons.chevron_right, color: AppTheme.primary),
              ),
              calendarStyle: CalendarStyle(
                selectedDecoration: const BoxDecoration(color: AppTheme.primary, shape: BoxShape.circle),
                todayDecoration: BoxDecoration(color: AppTheme.primaryLight.withOpacity(0.5), shape: BoxShape.circle),
                outsideDaysVisible: false,
              ),
              calendarBuilders: CalendarBuilders(
                headerTitleBuilder: (context, date) {
                  final buddhistYear = date.year + 543;
                  final month = DateFormat.MMMM('th_TH').format(date);
                  return InkWell(
                    // 💖 [SEQUENTIAL-PICKER v1.3.0] เปลี่ยนให้เรียกใช้ฟังก์ชันใหม่ของเราค่ะ
                    onTap: () => _selectYearAndMonth(context),
                    borderRadius: BorderRadius.circular(8),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 8.0),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Flexible(
                            child: Text('$month $buddhistYear', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, fontFamily: AppTheme.fontFamily, color: AppTheme.textPrimary), overflow: TextOverflow.ellipsis, softWrap: false),
                          ),
                          const SizedBox(width: 8),
                          const Icon(Icons.arrow_drop_down, color: AppTheme.textSecondary),
                        ],
                      ),
                    ),
                  );
                },
              ),
              onDaySelected: (selectedDay, focusedDay) {
                setState(() {
                  _selectedDay = selectedDay;
                  _focusedDay = focusedDay;
                });
              },
              onPageChanged: (focusedDay) {
                setState(() {
                  _focusedDay = focusedDay;
                });
              },
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: () => Navigator.of(context).pop(),
                    child: const Text('ยกเลิก', style: TextStyle(fontFamily: AppTheme.fontFamily, color: AppTheme.textSecondary)),
                  ),
                  const SizedBox(width: 8),
                  ElevatedButton(
                    style: ElevatedButton.styleFrom(backgroundColor: AppTheme.primary, foregroundColor: Colors.white, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16))),
                    onPressed: () {
                      Navigator.of(context).pop(_selectedDay);
                    },
                    child: const Text('ตกลง', style: TextStyle(fontFamily: AppTheme.fontFamily)),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
