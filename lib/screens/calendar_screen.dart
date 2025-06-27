// 📁 lib/screens/calendar_screen.dart (Corrected)

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
import 'patients_screen.dart';
import 'setting_screen.dart';
import 'reports_screen.dart';
import 'appointment_add.dart';
import 'daily_calendar_screen.dart';


// --- Helper class for layout calculation ---
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
  }); // maxOverlaps and columnIndex are initialized to 1 and 0 respectively

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
    _calendarFormat = CalendarFormat.month;
    _buttonMode = _CalendarButtonMode.displayWeekly;
    _fetchAppointmentsAndWorkingHoursForSelectedDay(_selectedDay);
  }

  // --- Data Fetching and Helper functions ---
  Future<void> _fetchAppointmentsAndWorkingHoursForSelectedDay(DateTime selectedDay) async {
    setState(() { _isLoading = true; });
    try {
      List<Map<String, dynamic>> appointments = await _appointmentService.getAppointmentsByDate(selectedDay);
      List<Map<String, dynamic>> appointmentsWithPatients = [];
      for (var appointment in appointments) {
        final patientId = appointment['patientId'];
        Map<String, dynamic>? patient = await _appointmentService.getPatientById(patientId);
        if (patient != null) {
          appointmentsWithPatients.add({'appointment': appointment, 'patient': patient});
        }
      }
      DayWorkingHours? dayWorkingHours;
      try {
        final allWorkingHours = await _workingHoursService.loadWorkingHours();
        final dayName = _getThaiDayName(selectedDay.weekday);
        dayWorkingHours = allWorkingHours.firstWhere((day) => day.dayName == dayName);
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

  // --- Logic for creating the timeline view ---
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

  List<_AppointmentLayoutInfo> _calculateAppointmentLayouts(List<Map<String, dynamic>> appointments) {
     if (appointments.isEmpty) return [];
    var events = appointments.map((data) => _AppointmentLayoutInfo(
      appointmentData: data,
      startTime: (data['appointment']['startTime'] as Timestamp).toDate(),
      endTime: (data['appointment']['endTime'] as Timestamp).toDate(),
    )).toList();
    events.sort((a, b) => a.startTime.compareTo(b.startTime));
    List<List<_AppointmentLayoutInfo>> groups = [];
    if(events.isNotEmpty){
        groups.add([events.first]);
        for(int i = 1; i < events.length; i++){
            var currentEvent = events[i];
            bool placed = false;
            for(var group in groups){
                if(group.any((member) => currentEvent.overlaps(member))){
                    group.add(currentEvent);
                    placed = true;
                    break;
                }
            }
            if(!placed){
                groups.add([currentEvent]);
            }
        }
    }
    for (var group in groups) {
      group.sort((a, b) => a.startTime.compareTo(b.startTime));
      int maxColumnsInGroup = 0;
      for (var event in group) {
        List<int> occupiedColumns = [];
        for (var placedEvent in group) {
          if (event != placedEvent && event.overlaps(placedEvent)) {
            occupiedColumns.add(placedEvent.columnIndex);
          }
        }
        int currentCol = 0;
        while(occupiedColumns.contains(currentCol)) {
          currentCol++;
        }
        event.columnIndex = currentCol;
        if(maxColumnsInGroup < currentCol + 1) {
            maxColumnsInGroup = currentCol + 1;
        }
      }
      for (var event in group) {
        event.maxOverlaps = maxColumnsInGroup;
      }
    }
    return events;
  }

  // --- UI Building Widgets ---
  
  // FIX 3: Removed the duplicate build method. This is the only one now.
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFEFE0FF),
      appBar: AppBar(
        backgroundColor: const Color(0xFFD9B8FF),
        elevation: 0,
        titleTextStyle: const TextStyle(
          color: Colors.white,
          fontSize: 20,
          fontWeight: FontWeight.bold,
        ),
        title: const Text('Appointment Calendar'),
        actions: widget.showReset ? [
              IconButton(
                icon: const Icon(Icons.developer_mode, size: 30),
                // FIX 1: Added the missing onPressed handler
                onPressed: () async {
                  final prefs = await SharedPreferences.getInstance();
                  await prefs.remove('skipLogin');
                  if (!mounted) return;
                  Navigator.pushReplacementNamed(context, '/login');
                },
                tooltip: 'กลับไปหน้า Login',
                color: Colors.white,
              ),
            ]
          : null,
      ),
      body: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          children: [
            Container(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                    color: Colors.purple.withOpacity(0.1),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      _buildCalendarToggleButton(),
                    ],
                  ),
                  TableCalendar(
                    locale: 'th_TH',
                    firstDay: DateTime.utc(2020, 1, 1),
                    lastDay: DateTime.utc(2030, 12, 31),
                    focusedDay: _focusedDay,
                    selectedDayPredicate: (day) => isSameDay(_selectedDay, day),
                    onDaySelected: (selectedDay, focusedDay) {
                      setState(() {
                        _selectedDay = selectedDay;
                        _focusedDay = focusedDay;
                      });
                    _fetchAppointmentsAndWorkingHoursForSelectedDay(selectedDay);
                    },
                    calendarFormat: _calendarFormat,
                    onFormatChanged: (format) {
                      setState(() { _calendarFormat = format; });
                    },
                    calendarStyle: CalendarStyle(
                      todayDecoration: BoxDecoration(color: Colors.pink.shade100, shape: BoxShape.circle),
                      selectedDecoration: BoxDecoration(color: Colors.purple.shade300, shape: BoxShape.circle),
                      weekendTextStyle: TextStyle(color: Colors.purple.shade200),
                      outsideDaysVisible: false,
                    ),
                    headerStyle: const HeaderStyle(
                      formatButtonVisible: false,
                      titleCentered: true,
                      titleTextStyle: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                    ),
                    daysOfWeekStyle: const DaysOfWeekStyle(
                      weekendStyle: TextStyle(color: Colors.purple),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            Expanded(
              child: _isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : (_selectedDayWorkingHours == null || _selectedDayWorkingHours!.isClosed || _selectedDayWorkingHours!.timeSlots.isEmpty)
                      ? const Center(child: Text('ไม่มีนัดหมายและคลินิกปิดทำการ'))
                      : LayoutBuilder(
                          builder: (context, constraints) {
                            final combinedList = _getCombinedList();
                            return SingleChildScrollView(
                              child: Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  // FIX 4: Added '!' to assert non-null, as it's checked above.
                                  _buildTimeline(_selectedDayWorkingHours!),
                                  // FIX 5: Corrected method name from _buildAppointmentsArea to _buildContentArea
                                  _buildContentArea(combinedList, _selectedDayWorkingHours!, constraints),
                                ],
                              ),
                            );
                          },
                        ),
            ),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          showDialog(
            context: context,
            builder: (context) => AppointmentAddDialog(initialDate: _selectedDay),
          ).then((_) {
            _fetchAppointmentsAndWorkingHoursForSelectedDay(_selectedDay);
          });
        },
        backgroundColor: Colors.purple,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
        child: const Icon(Icons.add, color: Colors.white, size: 36),
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerDocked,
      bottomNavigationBar: BottomAppBar(
        shape: const CircularNotchedRectangle(),
        notchMargin: 8,
        color: const Color(0xFFFBEAFF),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16.0),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              IconButton(icon: const Icon(Icons.calendar_today, size: 30), color: _selectedIndex == 0 ? Colors.purple : Colors.purple.shade200, onPressed: () => _onItemTapped(0), tooltip: 'ปฏิทิน'),
              IconButton(icon: const Icon(Icons.people_alt, size: 30), color: _selectedIndex == 1 ? Colors.purple : Colors.purple.shade200, onPressed: () => _onItemTapped(1), tooltip: 'คนไข้'),
              const SizedBox(width: 40),
              IconButton(icon: const Icon(Icons.bar_chart, size: 30), color: _selectedIndex == 3 ? Colors.purple : Colors.purple.shade200, onPressed: () => _onItemTapped(3), tooltip: 'รายงาน'),
              IconButton(icon: const Icon(Icons.settings, size: 30), color: _selectedIndex == 4 ? Colors.purple : Colors.purple.shade200, onPressed: () => _onItemTapped(4), tooltip: 'ตั้งค่า'),
            ],
          ),
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
    final totalDurationMinutes = (latestClose.hour * 60 + latestClose.minute) - (earliestOpen.hour * 60 + earliestOpen.minute);
    final intervals = (totalDurationMinutes / 30).ceil();

    for (int i = 0; i <= intervals; i++) {
      final currentMinutes = (earliestOpen.hour * 60 + earliestOpen.minute) + (i * 30);
      final currentTime = TimeOfDay(hour: currentMinutes ~/ 60, minute: currentMinutes % 60);
      if (currentMinutes > (latestClose.hour * 60 + latestClose.minute)) break;

      timeLabels.add(
        SizedBox(
          height: 30 * (_hourHeight / 60),
          child: Align(
            alignment: Alignment.topRight,
            child: Transform.translate(
              offset: const Offset(0, -8),
              child: Text(
                timeFormat.format(DateTime(2022, 1, 1, currentTime.hour, currentTime.minute)),
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
      child: Column(crossAxisAlignment: CrossAxisAlignment.end, children: timeLabels),
    );
  }

  Widget _buildContentArea(List<Map<String, dynamic>> combinedList, DayWorkingHours workingHours, BoxConstraints constraints) {
    final appointmentOnlyList = combinedList.where((item) => item['isGap'] != true).toList();
    final appointmentLayouts = _calculateAppointmentLayouts(appointmentOnlyList);
    final pixelsPerMinute = _hourHeight / 60.0;
    final dayStartTime = _combineDateAndTime(_selectedDay, workingHours.timeSlots.first.openTime);
    final dayEndTime = _combineDateAndTime(_selectedDay, workingHours.timeSlots.last.closeTime);
    final totalHeight = max(0.0, dayEndTime.difference(dayStartTime).inMinutes * pixelsPerMinute);
    final double contentWidth = constraints.maxWidth - 50.0;
    List<Widget> positionedItems = [];
    final totalHours = dayEndTime.difference(dayStartTime).inHours;
    for (int i = 0; i <= totalHours; i++) {
      positionedItems.add(Positioned(top: i * _hourHeight, left: 0, right: 0, child: Container(height: 1, color: Colors.purple.shade50)));
    }
    for (var item in combinedList) {
      final bool isGap = item['isGap'] == true;
      final DateTime itemStart = isGap ? item['start'] : (item['appointment']['startTime'] as Timestamp).toDate();
      final DateTime itemEnd = isGap ? item['end'] : (item['appointment']['endTime'] as Timestamp).toDate();
      final top = max(0.0, itemStart.difference(dayStartTime).inMinutes * pixelsPerMinute);
      final height = max(0.0, itemEnd.difference(itemStart).inMinutes * pixelsPerMinute);
      if (height <= 0) continue;
      if (isGap) {
        positionedItems.add(Positioned(top: top, left: 0, right: 0, height: height, child: GapCard(gapStart: itemStart, gapEnd: itemEnd, onTap: () => showDialog(context: context, builder: (_) => AppointmentAddDialog(initialDate: _selectedDay, initialStartTime: itemStart)).then((_) => _fetchAppointmentsAndWorkingHoursForSelectedDay(_selectedDay)))));
      } else {
        final layoutInfo = appointmentLayouts.firstWhere((l) => l.appointmentData == item, orElse: () => _AppointmentLayoutInfo(appointmentData: item, startTime: itemStart, endTime: itemEnd));
        final cardWidth = (contentWidth / layoutInfo.maxOverlaps) - 4;
        final left = layoutInfo.columnIndex * (cardWidth + 4);
        positionedItems.add(Positioned(top: top, left: left, width: cardWidth, height: height, child: AppointmentCard(appointment: item['appointment'], patient: item['patient'], onTap: () => showDialog(context: context, builder: (_) => AppointmentAddDialog(appointmentData: item['appointment'])).then((_) => _fetchAppointmentsAndWorkingHoursForSelectedDay(_selectedDay)))));
      }
    }
    return Expanded(child: SizedBox(height: totalHeight, child: Stack(children: positionedItems)));
  }

  void _onItemTapped(int index) {
    setState(() {
      _selectedIndex = index;
    });
    if (index == 1) {
      Navigator.push(context, MaterialPageRoute(builder: (context) => const PatientsScreen()));
    } else if (index == 3) {
      Navigator.push(context, MaterialPageRoute(builder: (context) => const ReportsScreen()));
    } else if (index == 4) {
      Navigator.push(context, MaterialPageRoute(builder: (context) => const SettingsScreen()));
    }
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
        Navigator.push(context, MaterialPageRoute(builder: (context) => DailyCalendarScreen(selectedDate: _selectedDay))).then((returnedFormat) {
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
      label: Text(label, style: const TextStyle(color: Colors.purple, fontWeight: FontWeight.bold)),
      style: TextButton.styleFrom(backgroundColor: Colors.purple.shade50, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
    );
  }
}