// v1.1.0 - Restored Calendar View
// 📁 lib/screens/weekly_view_screen.dart

import 'dart:math';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:table_calendar/table_calendar.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

// 🌸 Imports from our project
import '../models/appointment_model.dart';
import '../models/patient.dart';
import '../models/working_hours_model.dart';
import '../services/appointment_service.dart';
import '../services/patient_service.dart';
import '../services/working_hours_service.dart';
import '../widgets/custom_bottom_nav_bar.dart';
import '../styles/app_theme.dart';
import 'appointment_add.dart';
import '../widgets/appointment_detail_dialog.dart';
import '../widgets/appointment_card.dart';
import '../widgets/gap_card.dart';
import '../widgets/view_mode_selector.dart';
import 'daily_calendar_screen.dart';

class _WeeklyAppointmentLayoutInfo {
  final Map<String, dynamic> appointmentData;
  final DateTime startTime;
  final DateTime endTime;
  int maxOverlaps = 1;
  int columnIndex = 0;

  _WeeklyAppointmentLayoutInfo({
    required this.appointmentData,
    required this.startTime,
    required this.endTime,
  });

  bool overlaps(_WeeklyAppointmentLayoutInfo other) {
    return startTime.isBefore(other.endTime) && endTime.isAfter(other.startTime);
  }
}


class WeeklyViewScreen extends StatefulWidget {
  final DateTime focusedDate;
  const WeeklyViewScreen({super.key, required this.focusedDate});

  @override
  State<WeeklyViewScreen> createState() => _WeeklyViewScreenState();
}

class _WeeklyViewScreenState extends State<WeeklyViewScreen> {
  final AppointmentService _appointmentService = AppointmentService();
  final PatientService _patientService = PatientService();
  final WorkingHoursService _workingHoursService = WorkingHoursService();
  late DateTime _focusedDay;
  DateTime? _selectedDay;
  bool _isLoading = true;

  Map<DateTime, Map<String, dynamic>> _weeklyData = {};

  final ScrollController _headerScrollController = ScrollController();
  final ScrollController _bodyScrollController = ScrollController();
  final ScrollController _timeAxisScrollController = ScrollController();
  final ScrollController _contentVerticalScrollController = ScrollController();


  final double _hourHeight = 120.0;
  final double _dayColumnWidth = 200.0;
  final double _timeAxisWidth = 60.0;
  final int _startHour = 9;
  final int _endHour = 21;

  @override
  void initState() {
    super.initState();
    _focusedDay = widget.focusedDate;
    _selectedDay = widget.focusedDate;

    // ... (listeners remain the same)
    _headerScrollController.addListener(() {
      if (_headerScrollController.hasClients && _bodyScrollController.hasClients) {
        if (_headerScrollController.offset != _bodyScrollController.offset) {
          _bodyScrollController.jumpTo(_headerScrollController.offset);
        }
      }
    });
    _bodyScrollController.addListener(() {
      if (_headerScrollController.hasClients && _bodyScrollController.hasClients) {
        if (_headerScrollController.offset != _bodyScrollController.offset) {
          _headerScrollController.jumpTo(_bodyScrollController.offset);
        }
      }
    });
    _timeAxisScrollController.addListener(() {
      if (_timeAxisScrollController.hasClients && _contentVerticalScrollController.hasClients) {
        if (_timeAxisScrollController.offset != _contentVerticalScrollController.offset) {
          _contentVerticalScrollController.jumpTo(_timeAxisScrollController.offset);
        }
      }
    });
    _contentVerticalScrollController.addListener(() {
      if (_contentVerticalScrollController.hasClients && _timeAxisScrollController.hasClients) {
        if (_contentVerticalScrollController.offset != _timeAxisScrollController.offset) {
          _timeAxisScrollController.jumpTo(_contentVerticalScrollController.offset);
        }
      }
    });

    _fetchDataForWeek(_focusedDay);
  }

  @override
  void dispose() {
    _headerScrollController.dispose();
    _bodyScrollController.dispose();
    _timeAxisScrollController.dispose();
    _contentVerticalScrollController.dispose();
    super.dispose();
  }

  Future<void> _fetchDataForWeek(DateTime focusedDay) async {
    setState(() { _isLoading = true; });

    DateTime firstDayOfWeek = focusedDay.subtract(Duration(days: focusedDay.weekday - 1));
    Map<DateTime, Map<String, dynamic>> weeklyData = {};
    
    final allWorkingHours = await _workingHoursService.loadWorkingHours();

    try {
      for (int i = 0; i < 7; i++) {
        DateTime currentDay = firstDayOfWeek.add(Duration(days: i));
        DateTime dayKey = DateTime(currentDay.year, currentDay.month, currentDay.day);

        final dailyAppointments = await _appointmentService.getAppointmentsByDate(currentDay);
        
        List<Map<String, dynamic>> appointmentsWithPatients = [];
        for (var appointment in dailyAppointments) {
          final patient = await _patientService.getPatientById(appointment.patientId);
          if (patient != null) {
            final appointmentData = appointment.toMap();
            appointmentData['appointmentId'] = appointment.appointmentId;
            appointmentsWithPatients.add({
              'appointment': appointmentData,
              'patient': patient.toMap(),
            });
          }
        }
        
        DayWorkingHours? dayWorkingHours;
        try {
          dayWorkingHours = allWorkingHours.firstWhere((day) => day.dayName == _getThaiDayName(currentDay.weekday));
        } catch (e) {
          dayWorkingHours = null;
        }

        weeklyData[dayKey] = {
          'appointments': appointmentsWithPatients,
          'workingHours': dayWorkingHours,
        };
      }

      if (!mounted) return;
      setState(() {
        _weeklyData = weeklyData;
        _isLoading = false;
      });

    } catch (e) {
      debugPrint("เกิดข้อผิดพลาดในการดึงข้อมูลรายสัปดาห์: $e");
      if (mounted) setState(() { _isLoading = false; });
    }
  }
  
  String _getThaiDayName(int weekday) {
    const days = ['จันทร์', 'อังคาร', 'พุธ', 'พฤหัสบดี', 'ศุกร์', 'เสาร์', 'อาทิตย์'];
    return days[weekday - 1];
  }

  List<_WeeklyAppointmentLayoutInfo> _calculateAppointmentLayouts(List<Map<String, dynamic>> appointments) {
    if (appointments.isEmpty) return [];

    var events = appointments.map((data) {
      final apptMap = data['appointment'] as Map<String, dynamic>;
      return _WeeklyAppointmentLayoutInfo(
        appointmentData: data,
        startTime: (apptMap['startTime'] as Timestamp).toDate(),
        endTime: (apptMap['endTime'] as Timestamp).toDate(),
      );
    }).toList();

    events.sort((a, b) => a.startTime.compareTo(b.startTime));

    for (var event in events) { event.columnIndex = 0; event.maxOverlaps = 1; }

    for (int i = 0; i < events.length; i++) {
      var currentEvent = events[i];
      List<_WeeklyAppointmentLayoutInfo> overlappingPeers = [];
      for (int j = 0; j < i; j++) {
        if (currentEvent.overlaps(events[j])) {
          overlappingPeers.add(events[j]);
        }
      }
      var occupiedColumns = overlappingPeers.map((e) => e.columnIndex).toSet();
      int col = 0;
      while (occupiedColumns.contains(col)) {
        col++;
      }
      currentEvent.columnIndex = col;
    }

    for (var event in events) {
      var allOverlapping = events.where((peer) => peer.overlaps(event)).toList();
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
    return events;
  }

  List<Map<String, dynamic>> _getCombinedListForDay(List<Map<String, dynamic>> appointments, DayWorkingHours workingHours, DateTime selectedDate) {
    if (workingHours.isClosed || workingHours.timeSlots.isEmpty) {
      return [];
    }

    appointments.sort((a,b) => (a['appointment']['startTime'] as Timestamp).compareTo(b['appointment']['startTime'] as Timestamp));
    
    List<Map<String, dynamic>> finalCombinedList = [];
    
    for (final slot in workingHours.timeSlots) {
      DateTime lastEventEnd = DateTime(selectedDate.year, selectedDate.month, selectedDate.day, slot.openTime.hour, slot.openTime.minute);
      final slotCloseTime = DateTime(selectedDate.year, selectedDate.month, selectedDate.day, slot.closeTime.hour, slot.closeTime.minute);

      final appointmentsInSlot = appointments.where((appt) {
        final startTime = (appt['appointment']['startTime'] as Timestamp).toDate();
        return startTime.isAfter(lastEventEnd.subtract(const Duration(minutes: 1))) && startTime.isBefore(slotCloseTime);
      }).toList();

      for(var apptData in appointmentsInSlot){
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
      
      if(slotCloseTime.isAfter(lastEventEnd)){
          finalCombinedList.add({'isGap': true, 'start': lastEventEnd, 'end': slotCloseTime});
      }
    }
    return finalCombinedList;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(
        automaticallyImplyLeading: false,
        backgroundColor: AppTheme.primaryLight,
        elevation: 0,
        title: const Text('ภาพรวมสัปดาห์'),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: AppTheme.primary))
          : Column(
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
                  child: ViewModeSelector(
                    calendarFormat: CalendarFormat.week, 
                    onFormatChanged: (format) {
                      if (format == CalendarFormat.month) {
                        Navigator.pop(context);
                      }
                    },
                    onDailyViewTapped: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => DailyCalendarScreen(selectedDate: _selectedDay ?? DateTime.now()),
                        ),
                      ).then((_) => _fetchDataForWeek(_focusedDay));
                    },
                  ),
                ),
                // ✨ The Fix! นำปฏิทินกลับมาแสดงผลเหมือนเดิมค่ะ
                _buildCalendar(),
                const SizedBox(height: 12),
                _buildWeekDayHeader(), 
                Expanded(
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildTimeAxis(), 
                      Expanded(
                        child: SingleChildScrollView(
                          controller: _contentVerticalScrollController,
                          child: SingleChildScrollView(
                            controller: _bodyScrollController,
                            scrollDirection: Axis.horizontal,
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: List.generate(7, (index) {
                                final firstDayOfWeek = _focusedDay.subtract(Duration(days: _focusedDay.weekday - 1));
                                final day = firstDayOfWeek.add(Duration(days: index));
                                final dayKey = DateTime(day.year, day.month, day.day);
                                final dayData = _weeklyData[dayKey];
                                return _buildDayColumn(day, dayData);
                              }),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => showDialog(
          context: context,
          builder: (_) => AppointmentAddDialog(initialDate: _selectedDay ?? DateTime.now())
        ).then((_) => _fetchDataForWeek(_focusedDay)),
        backgroundColor: AppTheme.primary,
        tooltip: 'เพิ่มนัดหมายใหม่',
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
        child: const Icon(Icons.add, color: Colors.white, size: 36),
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerDocked,
      bottomNavigationBar: const CustomBottomNavBar(selectedIndex: 0),
    );
  }

  /// 🎨 Widget สำหรับสร้างปฏิทินด้านบน (โหมดสัปดาห์)
  Widget _buildCalendar() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12.0),
      child: Container(
        padding: const EdgeInsets.all(8.0),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10, offset: const Offset(0, 4))],
        ),
        child: TableCalendar(
          locale: 'th_TH',
          firstDay: DateTime.utc(2020, 1, 1),
          lastDay: DateTime.utc(2030, 12, 31),
          focusedDay: _focusedDay,
          calendarFormat: CalendarFormat.week,
          availableCalendarFormats: const {
            CalendarFormat.week: 'Week',
          },
          selectedDayPredicate: (day) => isSameDay(_selectedDay, day),
          headerStyle: const HeaderStyle(
            titleCentered: true,
            titleTextStyle: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, fontFamily: AppTheme.fontFamily),
            formatButtonVisible: false,
          ),
          calendarStyle: CalendarStyle(
            todayDecoration: BoxDecoration(color: AppTheme.primaryLight.withOpacity(0.5), shape: BoxShape.circle),
            selectedDecoration: BoxDecoration(color: AppTheme.primary, shape: BoxShape.circle),
          ),
          onDaySelected: (selectedDay, focusedDay) {
            if (!isSameDay(_selectedDay, selectedDay)) {
              setState(() {
                _selectedDay = selectedDay;
                _focusedDay = focusedDay;
              });
            }
          },
          onPageChanged: (focusedDay) {
            setState(() {
              _focusedDay = focusedDay;
              _selectedDay = focusedDay;
            });
            _fetchDataForWeek(focusedDay);
          },
        ),
      ),
    );
  }
  
  Widget _buildWeekDayHeader() {
    final firstDayOfWeek = _focusedDay.subtract(Duration(days: _focusedDay.weekday - 1));
    final dayFormatter = DateFormat('E', 'th_TH');
    final dateFormatter = DateFormat('d', 'th_TH');

    return SingleChildScrollView(
      controller: _headerScrollController,
      scrollDirection: Axis.horizontal,
      physics: const NeverScrollableScrollPhysics(), 
      child: Row(
        children: [
          SizedBox(width: _timeAxisWidth), 
          ...List.generate(7, (index) {
            final day = firstDayOfWeek.add(Duration(days: index));
            final isToday = isSameDay(day, DateTime.now());
            return Container(
              width: _dayColumnWidth,
              padding: const EdgeInsets.all(8.0),
              decoration: BoxDecoration(
                color: isToday ? AppTheme.primaryLight.withOpacity(0.3) : Colors.transparent,
                border: Border(
                  right: BorderSide(color: Colors.grey.shade200),
                  bottom: BorderSide(color: Colors.grey.shade300, width: 2),
                )
              ),
              child: Column(
                children: [
                  Text(dayFormatter.format(day), style: TextStyle(fontWeight: FontWeight.bold, color: isToday ? AppTheme.primary : AppTheme.textPrimary)),
                  Text(dateFormatter.format(day), style: TextStyle(color: isToday ? AppTheme.primary : AppTheme.textSecondary)),
                ],
              ),
            );
          }),
        ],
      ),
    );
  }

  Widget _buildTimeAxis() {
    return SizedBox(
      width: _timeAxisWidth,
      child: ListView.builder(
        controller: _timeAxisScrollController,
        itemCount: _endHour - _startHour,
        itemBuilder: (context, index) {
          final hour = _startHour + index;
          return Container(
            height: _hourHeight,
            decoration: BoxDecoration(
              border: Border(bottom: BorderSide(color: Colors.grey.shade200))
            ),
            child: Align(
              alignment: Alignment.topCenter,
              child: Padding(
                padding: const EdgeInsets.only(top: 4.0),
                child: Text(
                  '${hour.toString().padLeft(2, '0')}:00',
                  style: const TextStyle(color: AppTheme.textSecondary, fontSize: 12),
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildDayColumn(DateTime day, Map<String, dynamic>? dayData) {
    final pixelsPerMinute = _hourHeight / 60.0;
    final dayStartTime = DateTime(day.year, day.month, day.day, _startHour);
    
    final appointments = dayData?['appointments'] as List<Map<String, dynamic>>? ?? [];
    final workingHours = dayData?['workingHours'] as DayWorkingHours?;

    if (workingHours == null || workingHours.isClosed) {
      return Container(
        width: _dayColumnWidth,
        height: _hourHeight * (_endHour - _startHour),
        decoration: BoxDecoration(
          color: Colors.grey.shade50,
          border: Border(right: BorderSide(color: Colors.grey.shade200))
        ),
        child: Center(child: Text('ปิดทำการ', style: TextStyle(color: AppTheme.textDisabled))),
      );
    }
    
    final combinedList = _getCombinedListForDay(appointments, workingHours, day);
    final appointmentLayouts = _calculateAppointmentLayouts(appointments);

    return Container(
      width: _dayColumnWidth,
      height: _hourHeight * (_endHour - _startHour),
      decoration: BoxDecoration(
        border: Border(right: BorderSide(color: Colors.grey.shade200))
      ),
      child: Stack(
        children: [
          ...List.generate(_endHour - _startHour, (index) {
            return Positioned(
              top: index * _hourHeight,
              left: 0,
              right: 0,
              child: Container(height: 1, color: Colors.grey.shade200),
            );
          }),
          ...combinedList.map((item) {
            final bool isGap = item['isGap'] == true;
            final DateTime itemStart = isGap ? item['start'] : (item['appointment']['startTime'] as Timestamp).toDate();
            final DateTime itemEnd = isGap ? item['end'] : (item['appointment']['endTime'] as Timestamp).toDate();
            
            final top = max(0.0, itemStart.difference(dayStartTime).inMinutes * pixelsPerMinute);
            final height = max(0.0, itemEnd.difference(itemStart).inMinutes * pixelsPerMinute);
            
            if (height <= 0.1) return const SizedBox.shrink();

            if (isGap) {
              return Positioned(
                top: top,
                left: 0,
                right: 0,
                height: height,
                child: GapCard(
                  gapStart: itemStart,
                  gapEnd: itemEnd,
                  onTap: () => showDialog(
                    context: context, 
                    builder: (_) => AppointmentAddDialog(
                      initialDate: day, 
                      initialStartTime: itemStart
                    )
                  ).then((_) => _fetchDataForWeek(_focusedDay))
                ),
              );
            } else {
              final layoutInfo = appointmentLayouts.firstWhere((l) => l.appointmentData == item, orElse: () {
                final apptMap = item['appointment'] as Map<String, dynamic>;
                return _WeeklyAppointmentLayoutInfo(
                  appointmentData: item,
                  startTime: (apptMap['startTime'] as Timestamp).toDate(),
                  endTime: (apptMap['endTime'] as Timestamp).toDate(),
                );
              });
              final cardWidth = (_dayColumnWidth / layoutInfo.maxOverlaps) - 4;
              final left = layoutInfo.columnIndex * (cardWidth + 4);

              return Positioned(
                top: top,
                left: left,
                width: cardWidth,
                height: height,
                child: AppointmentCard(
                  appointment: item['appointment'],
                  patient: item['patient'],
                  isCompact: layoutInfo.maxOverlaps > 1,
                  isShort: height < 60,
                  onTap: () {
                    final appointmentModel = AppointmentModel.fromMap(
                      item['appointment']['appointmentId'], 
                      item['appointment']
                    );
                    showDialog(
                      context: context, 
                      builder: (_) => AppointmentDetailDialog(
                        appointment: appointmentModel, 
                        patient: item['patient'], 
                        onDataChanged: () => _fetchDataForWeek(_focusedDay)
                      )
                    );
                  },
                ),
              );
            }
          }).toList(),
        ],
      ),
    );
  }
}
