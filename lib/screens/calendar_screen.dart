// 📁 lib/screens/calendar_screen.dart (ฉบับแก้ไขสมบูรณ์ที่สุด!)

import 'dart:math';
import 'package:flutter/material.dart';
import 'package:table_calendar/table_calendar.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:intl/intl.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import '../services/appointment_service.dart';
import '../services/working_hours_service.dart';
import '../models/working_hours_model.dart';
import '../widgets/appointment_card.dart';
import '../widgets/gap_card.dart';
import '../widgets/appointment_detail_dialog.dart';
import 'patients_screen.dart';
import 'setting_screen.dart';
import 'reports_screen.dart';
import 'appointment_add.dart';
import 'daily_calendar_screen.dart';

// --- คลาสผู้ช่วยสำหรับคำนวณ Layout ---
class _AppointmentLayoutInfo {
  final Map<String, dynamic> appointmentData;
  final DateTime startTime;
  final DateTime endTime;
  int maxOverlaps = 1;
  int columnIndex = 0;

  _AppointmentLayoutInfo({
    required this.appointmentData,
    required this.startTime,
    required this.endTime,
  });

  bool overlaps(_AppointmentLayoutInfo other) {
    return startTime.isBefore(other.endTime) && endTime.isAfter(other.startTime);
  }
}

enum _CalendarButtonMode { displayWeekly, displayDaily }

class CalendarScreen extends StatefulWidget {
  final bool showReset;
  const CalendarScreen({super.key, this.showReset = false});

  @override
  State<CalendarScreen> createState() => _CalendarScreenState();
}

class _CalendarScreenState extends State<CalendarScreen> {
  final AppointmentService _appointmentService = AppointmentService();
  List<Map<String, dynamic>> _selectedAppointmentsWithPatients = [];
  DateTime _focusedDay = DateTime.now();
  late DateTime _selectedDay;
  DayWorkingHours? _selectedDayWorkingHours;
  final WorkingHoursService _workingHoursService = WorkingHoursService();
  CalendarFormat _calendarFormat = CalendarFormat.month;
  int _selectedIndex = 0;
  _CalendarButtonMode _buttonMode = _CalendarButtonMode.displayWeekly;
  final double _hourHeight = 120.0;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _selectedDay = _focusedDay;
    _fetchAppointmentsAndWorkingHoursForSelectedDay(_selectedDay);
  }

  // --- (ฟังก์ชันดึงข้อมูลและ Helper เหมือนเดิม) ---
  Future<void> _fetchAppointmentsAndWorkingHoursForSelectedDay(DateTime selectedDay) async {
    setState(() { _isLoading = true; });
    try {
      final appointments = await _appointmentService.getAppointmentsByDate(selectedDay);
      List<Map<String, dynamic>> appointmentsWithPatients = [];
      for (var appointment in appointments) {
        final patient = await _appointmentService.getPatientById(appointment['patientId']);
        if (patient != null) {
          appointmentsWithPatients.add({'appointment': appointment, 'patient': patient});
        }
      }
      DayWorkingHours? dayWorkingHours;
      try {
        final allWorkingHours = await _workingHoursService.loadWorkingHours();
        dayWorkingHours = allWorkingHours.firstWhere((day) => day.dayName == _getThaiDayName(selectedDay.weekday));
      } catch (e) {
        dayWorkingHours = null;
      }
      if (!mounted) return;
      setState(() {
        _selectedAppointmentsWithPatients = appointmentsWithPatients;
        _selectedDayWorkingHours = dayWorkingHours;
      });
    } catch(e) {
       debugPrint('Error fetching data for calendar screen: $e');
    } finally {
        if(mounted) setState(() { _isLoading = false; });
    }
  }
  
  String _getThaiDayName(int weekday) {
    const days = ['จันทร์', 'อังคาร', 'พุธ', 'พฤหัสบดี', 'ศุกร์', 'เสาร์', 'อาทิตย์'];
    return days[weekday - 1];
  }

  DateTime _combineDateAndTime(DateTime date, TimeOfDay time) {
    return DateTime(date.year, date.month, date.day, time.hour, time.minute);
  }
  
  List<Map<String, dynamic>> _getCombinedList() {
    if (_selectedDayWorkingHours == null || _selectedDayWorkingHours!.isClosed || _selectedDayWorkingHours!.timeSlots.isEmpty) {
      return _selectedAppointmentsWithPatients..sort((a,b) => (a['appointment']['startTime'] as Timestamp).compareTo(b['appointment']['startTime'] as Timestamp));
    }
    _selectedAppointmentsWithPatients.sort((a,b) => (a['appointment']['startTime'] as Timestamp).compareTo(b['appointment']['startTime'] as Timestamp));
    List<Map<String, dynamic>> finalCombinedList = [];
    DateTime lastEventEnd = _combineDateAndTime(_selectedDay, _selectedDayWorkingHours!.timeSlots.first.openTime);
    for(var apptData in _selectedAppointmentsWithPatients){
      final startTime = (apptData['appointment']['startTime'] as Timestamp).toDate();
      final endTime = (apptData['appointment']['endTime'] as Timestamp).toDate();
      if(startTime.isAfter(lastEventEnd)){
        finalCombinedList.add({'isGap': true, 'start': lastEventEnd, 'end': startTime});
      }
      finalCombinedList.add(apptData);
      if (endTime.isAfter(lastEventEnd)) {
        lastEventEnd = endTime;
      }
    }
    final latestCloseTime = _combineDateAndTime(_selectedDay, _selectedDayWorkingHours!.timeSlots.last.closeTime);
    if(latestCloseTime.isAfter(lastEventEnd)){
        finalCombinedList.add({'isGap': true, 'start': lastEventEnd, 'end': latestCloseTime});
    }
    return finalCombinedList;
  }
  
  List<_AppointmentLayoutInfo> _calculateAppointmentLayouts(
    List<Map<String, dynamic>> appointments,
  ) {
    if (appointments.isEmpty) return [];

    var events =
        appointments
            .map(
              (data) => _AppointmentLayoutInfo(
                appointmentData: data,
                startTime:
                    (data['appointment']['startTime'] as Timestamp).toDate(),
                endTime: (data['appointment']['endTime'] as Timestamp).toDate(),
              ),
            )
            .toList();

    // 1. เรียงนัดหมายทั้งหมดตามเวลาเริ่มก่อนเสมอ
    events.sort((a, b) => a.startTime.compareTo(b.startTime));

    // 2. ล้างข้อมูลคอลัมน์เก่าทิ้งไปก่อน เพื่อความปลอดภัย
    for (var event in events) {
      event.columnIndex = 0;
      event.maxOverlaps = 1;
    }

    // 3. จัดการทีละ Event โดยยึดหลัก "มาก่อน ได้อยู่ซ้ายก่อน"
    for (int i = 0; i < events.length; i++) {
      var currentEvent = events[i];
      List<_AppointmentLayoutInfo> overlappingPeers = [];
      for (int j = 0; j < i; j++) {
        var peer = events[j];
        if (currentEvent.overlaps(peer)) {
          overlappingPeers.add(peer);
        }
      }
      var occupiedColumns = overlappingPeers.map((e) => e.columnIndex).toSet();
      int col = 0;
      while (occupiedColumns.contains(col)) {
        col++;
      }
      currentEvent.columnIndex = col;
    }

    // 4. รอบสุดท้าย: อัปเดตจำนวนคอลัมน์สูงสุดสำหรับแต่ละกลุ่ม
    for (var event in events) {
      var allOverlapping =
          events.where((peer) => peer.overlaps(event)).toList();
      int maxCol = 0;
      for (var item in allOverlapping) {
        if (item.columnIndex > maxCol) {
          maxCol = item.columnIndex;
        }
      }
      for (var item in allOverlapping) {
        item.maxOverlaps = max(item.maxOverlaps, maxCol + 1);
      }
    }

    // ✨✨✨ เพิ่มคำสั่ง return ที่หายไปตรงนี้ค่ะ! ✨✨✨
    return events;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFFAFAFA),
      appBar: AppBar( /* ... AppBar ไม่เปลี่ยนแปลง ... */ ),
      body: Column(
        children: [
          Container(
            padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
            decoration: const BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.vertical(bottom: Radius.circular(20)),
              boxShadow: [BoxShadow(color: Colors.black12, blurRadius: 5, offset: Offset(0,2))]
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                _buildCalendarToggleButton(),
                // ✨✨✨ เติมโค้ด TableCalendar ที่หายไปตรงนี้นะคะ ✨✨✨
                TableCalendar(
                  locale: 'th_TH',
                  firstDay: DateTime.utc(2020, 1, 1),
                  lastDay: DateTime.utc(2030, 12, 31),
                  focusedDay: _focusedDay,
                  selectedDayPredicate: (day) => isSameDay(_selectedDay, day),
                  calendarFormat: _calendarFormat,
                  onDaySelected: (selectedDay, focusedDay) {
                    if (!isSameDay(_selectedDay, selectedDay)) {
                      setState(() {
                        _selectedDay = selectedDay;
                        _focusedDay = focusedDay;
                      });
                      _fetchAppointmentsAndWorkingHoursForSelectedDay(selectedDay);
                    }
                  },
                  onFormatChanged: (format) {
                    if (_calendarFormat != format) {
                      setState(() { _calendarFormat = format; });
                    }
                  },
                  onPageChanged: (focusedDay) {
                    _focusedDay = focusedDay;
                  },
                  calendarStyle: CalendarStyle(
                    todayDecoration: BoxDecoration(color: Colors.purple.shade100, shape: BoxShape.circle),
                    selectedDecoration: BoxDecoration(color: Colors.purple.shade300, shape: BoxShape.circle),
                    weekendTextStyle: TextStyle(color: Colors.purple.shade200),
                  ),
                   headerStyle: const HeaderStyle(
                    formatButtonVisible: false, // ซ่อนปุ่ม format ของ library
                    titleCentered: true,
                    titleTextStyle: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator(color: Colors.purple))
                : (_selectedDayWorkingHours == null || _selectedDayWorkingHours!.isClosed)
                    ? Center(child: Text('คลินิกปิดทำการ', style: TextStyle(color: Colors.grey.shade600, fontSize: 16)))
                    : LayoutBuilder(
                        builder: (context, constraints) {
                          final combinedList = _getCombinedList();
                           if (combinedList.isEmpty) {
                            return Center(child: Text('ไม่มีนัดหมายในวันนี้', style: TextStyle(color: Colors.grey.shade600, fontSize: 16)));
                          }
                          return SingleChildScrollView(
                            padding: const EdgeInsets.only(top: 12, left: 4, right: 4),
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                _buildTimeline(_selectedDayWorkingHours!),
                                _buildContentArea(combinedList, _selectedDayWorkingHours!, constraints),
                              ],
                            ),
                          );
                        },
                      ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => showDialog(context: context, builder: (_) => AppointmentAddDialog(initialDate: _selectedDay)).then((_) => _fetchAppointmentsAndWorkingHoursForSelectedDay(_selectedDay)),
        backgroundColor: Colors.purple,
        child: const Icon(Icons.add, color: Colors.white),
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerDocked,
      bottomNavigationBar: BottomAppBar(
        shape: const CircularNotchedRectangle(),
        notchMargin: 8,
        color: Colors.white,
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: <Widget>[
            _buildNavIconButton(icon: Icons.calendar_today, tooltip: 'ปฏิทิน', index: 0),
            _buildNavIconButton(icon: Icons.people_alt, tooltip: 'คนไข้', index: 1),
            const SizedBox(width: 40),
            _buildNavIconButton(icon: Icons.bar_chart, tooltip: 'รายงาน', index: 3),
            _buildNavIconButton(icon: Icons.settings, tooltip: 'ตั้งค่า', index: 4),
          ],
        ),
      ),
    );
  }

  // --- Helper Widgets for building the timeline view ---

  Widget _buildTimeline(DayWorkingHours workingHours) {
    final timeFormat = DateFormat('HH:mm');
    final slots = workingHours.timeSlots;
    if (slots.isEmpty) return const SizedBox.shrink();

    final earliestOpen = slots.first.openTime;
    final latestClose = slots.last.closeTime;

    List<Widget> timeLabels = [];
    final totalDurationMinutes =
        (latestClose.hour * 60 + latestClose.minute) -
        (earliestOpen.hour * 60 + earliestOpen.minute);
    final intervals = (totalDurationMinutes / 30).ceil();

    for (int i = 0; i <= intervals; i++) {
      final currentMinutes =
          (earliestOpen.hour * 60 + earliestOpen.minute) + (i * 30);
      final currentTime = TimeOfDay(
        hour: currentMinutes ~/ 60,
        minute: currentMinutes % 60,
      );
      if (currentMinutes > (latestClose.hour * 60 + latestClose.minute)) break;

      timeLabels.add(
        SizedBox(
          height: 30 * (_hourHeight / 60),
          child: Align(
            alignment: Alignment.topRight,
            child: Transform.translate(
              offset: const Offset(0, -8),
              child: Text(
                timeFormat.format(
                  DateTime(2022, 1, 1, currentTime.hour, currentTime.minute),
                ),
                style: TextStyle(fontSize: 12, color: Colors.grey.shade700),
              ),
            ),
          ),
        ),
      );
    }
    return Container(
      width: 50,
      padding: const EdgeInsets.only(right: 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: timeLabels,
      ),
    );
  }

  Widget _buildContentArea(
    List<Map<String, dynamic>> combinedList,
    DayWorkingHours workingHours,
    BoxConstraints constraints,
  ) {
    final appointmentOnlyList =
        combinedList.where((item) => item['isGap'] != true).toList();
    final appointmentLayouts = _calculateAppointmentLayouts(
      appointmentOnlyList,
    );
    final pixelsPerMinute = _hourHeight / 60.0;
    final dayStartTime = _combineDateAndTime(
      _selectedDay,
      workingHours.timeSlots.first.openTime,
    );
    final dayEndTime = _combineDateAndTime(
      _selectedDay,
      workingHours.timeSlots.last.closeTime,
    );
    final totalHeight = max(
      0.0,
      dayEndTime.difference(dayStartTime).inMinutes * pixelsPerMinute,
    );
    final double contentWidth = constraints.maxWidth - 50.0;
    List<Widget> positionedItems = [];
    final totalHours = dayEndTime.difference(dayStartTime).inHours;
    for (int i = 0; i <= totalHours; i++) {
      positionedItems.add(
        Positioned(
          top: i * _hourHeight,
          left: 0,
          right: 0,
          child: Container(height: 1, color: Colors.purple.shade50),
        ),
      );
    }
    for (var item in combinedList) {
      final bool isGap = item['isGap'] == true;
      final DateTime itemStart =
          isGap
              ? item['start']
              : (item['appointment']['startTime'] as Timestamp).toDate();
      final DateTime itemEnd =
          isGap
              ? item['end']
              : (item['appointment']['endTime'] as Timestamp).toDate();
      final top = max(
        0.0,
        itemStart.difference(dayStartTime).inMinutes * pixelsPerMinute,
      );
      final height = max(
        0.0,
        itemEnd.difference(itemStart).inMinutes * pixelsPerMinute,
      );
      if (height <= 0) continue;
      if (isGap) {
        positionedItems.add(
          Positioned(
            top: top,
            left: 0,
            right: 0,
            height: height,
            child: GapCard(
              gapStart: itemStart,
              gapEnd: itemEnd,
              onTap:
                  () => showDialog(
                    context: context,
                    builder:
                        (_) => AppointmentAddDialog(
                          initialDate: _selectedDay,
                          initialStartTime: itemStart,
                        ),
                  ).then(
                    (_) => _fetchAppointmentsAndWorkingHoursForSelectedDay(
                      _selectedDay,
                    ),
                  ),
            ),
          ),
        );
      } else {
  final layoutInfo = appointmentLayouts.firstWhere((l) => l.appointmentData == item, orElse: () => _AppointmentLayoutInfo(appointmentData: item, startTime: itemStart, endTime: itemEnd));
  final cardWidth = (contentWidth / layoutInfo.maxOverlaps) - 4;
  final left = layoutInfo.columnIndex * (cardWidth + 4);

  // ✨ เพิ่มการดึง ID ของนัดหมายออกมาอย่างปลอดภัย ✨
  final appointmentData = item['appointment'] as Map<String, dynamic>;
  final String appointmentId = appointmentData['appointmentId'] ?? '';
  
  positionedItems.add(Positioned(
    top: top, left: left, width: cardWidth, height: height,
    child: AppointmentCard(
      appointment: item['appointment'],
      patient: item['patient'],
      // 👇✨ นี่คือป้ายบอกทางใหม่ที่ถูกต้องค่ะ! ✨👇
      onTap: () {
        if (appointmentId.isEmpty) {
            print("Error: Appointment ID is missing!");
            return; // ป้องกันการกดถ้าไม่มี ID
        }
        showDialog(
          context: context,
          builder: (_) => AppointmentDetailDialog(
            appointmentId: appointmentId,
            appointment: item['appointment'],
            patient: item['patient'],
            onDataChanged: () {
              // เมื่อมีการเปลี่ยนแปลงข้อมูล ให้หน้านี้ refresh ตัวเองค่ะ
              _fetchAppointmentsAndWorkingHoursForSelectedDay(_selectedDay);
            },
          ),
        );
      },
      isCompact: layoutInfo.maxOverlaps > 1
    )
  ));
}
    } // Closing brace for the 'else' block (isGap == false)
    return Expanded(
      child: SizedBox(
        height: totalHeight,
        child: Stack(children: positionedItems),
      ),
    );
  }

  void _onItemTapped(int index) {
    setState(() {
      _selectedIndex = index;
    });
    if (index == 1) {
      Navigator.push(
        context,
        MaterialPageRoute(builder: (context) => const PatientsScreen()),
      );
    } else if (index == 3) {
      Navigator.push(
        context,
        MaterialPageRoute(builder: (context) => const ReportsScreen()),
      );
    } else if (index == 4) {
      Navigator.push(
        context,
        MaterialPageRoute(builder: (context) => const SettingsScreen()),
      );
    }
  }

    Widget _buildNavIconButton({required IconData icon, required String tooltip, required int index}) {
    return IconButton(
      icon: Icon(icon, size: 30),
      color: _selectedIndex == index ? Colors.purple : Colors.purple.shade200,
      onPressed: () => _onItemTapped(index),
      tooltip: tooltip,
    );
  }

  Widget _buildCalendarToggleButton() {
    IconData icon = Icons.error;
    String label = '';
    VoidCallback onPressedAction = () {};
    if (_buttonMode == _CalendarButtonMode.displayWeekly) {
      icon = Icons.view_week;
      label = 'ดูรายสัปดาห์';
      onPressedAction = () {
        setState(() {
          _calendarFormat = CalendarFormat.week;
          _buttonMode = _CalendarButtonMode.displayDaily;
        });
      };
    } else if (_buttonMode == _CalendarButtonMode.displayDaily) {
      icon = Icons.calendar_view_day;
      label = 'ดูรายวัน';
      onPressedAction = () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder:
                (context) => DailyCalendarScreen(selectedDate: _selectedDay),
          ),
        ).then((returnedFormat) {
          if (mounted) {
            setState(() {
              if (returnedFormat is CalendarFormat) {
                _calendarFormat = returnedFormat;
                if (returnedFormat == CalendarFormat.month) {
                  _buttonMode = _CalendarButtonMode.displayWeekly;
                } else {
                  _buttonMode = _CalendarButtonMode.displayDaily;
                }
              } else {
                _calendarFormat = CalendarFormat.month;
                _buttonMode = _CalendarButtonMode.displayWeekly;
              }
            });
          }
        });
      };
    }
    return TextButton.icon(
      onPressed: onPressedAction,
      icon: Icon(icon, color: Colors.purple),
      label: Text(
        label,
        style: const TextStyle(
          color: Colors.purple,
          fontWeight: FontWeight.bold,
        ),
      ),
      style: TextButton.styleFrom(
        backgroundColor: Colors.purple.shade50,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }
}
