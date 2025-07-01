// 📁 daily_calendar_screen.dart

import 'dart:math';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:table_calendar/table_calendar.dart';
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

// Enum สำหรับจัดการสถานะของปุ่มเปลี่ยนมุมมอง
//enum _CalendarButtonMode { displayWeekly, displayDaily, displayMonthly }

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

class DailyCalendarScreen extends StatefulWidget {
  final DateTime selectedDate;
  const DailyCalendarScreen({super.key, required this.selectedDate});

  @override
  State<DailyCalendarScreen> createState() => _DailyCalendarScreenState();
}

class _DailyCalendarScreenState extends State<DailyCalendarScreen> {
  final AppointmentService _appointmentService = AppointmentService();
  final WorkingHoursService _workingHoursService = WorkingHoursService();

  List<Map<String, dynamic>> _appointmentsWithPatients = [];
  DayWorkingHours? _selectedDayWorkingHours;
  bool _isLoading = true;

  int _selectedIndex = 0;
  //_CalendarButtonMode _buttonModeForDailyView = _CalendarButtonMode.displayMonthly;
  final double _hourHeight = 120.0; // ความสูงของ 1 ชั่วโมงใน Timeline

  @override
  void initState() {
    super.initState();
    _fetchAppointmentsAndWorkingHoursForSelectedDay(widget.selectedDate);
  }

  // --- Data Fetching ---
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
      } catch (e) { dayWorkingHours = null; }
      if (!mounted) return;
      setState(() {
        _appointmentsWithPatients = appointmentsWithPatients;
        _selectedDayWorkingHours = dayWorkingHours;
      });
    } catch(e) {
       debugPrint('Error fetching data for daily screen: $e');
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
  
  // --- ✨ นำฟังก์ชันที่จำเป็นกลับมาค่ะ ✨ ---
  List<Map<String, dynamic>> _getCombinedList() {
    if (_selectedDayWorkingHours == null || _selectedDayWorkingHours!.isClosed || _selectedDayWorkingHours!.timeSlots.isEmpty) {
      return _appointmentsWithPatients..sort((a,b) => (a['appointment']['startTime'] as Timestamp).compareTo(b['appointment']['startTime'] as Timestamp));
    }
    _appointmentsWithPatients.sort((a,b) => (a['appointment']['startTime'] as Timestamp).compareTo(b['appointment']['startTime'] as Timestamp));
    List<Map<String, dynamic>> finalCombinedList = [];
    DateTime lastEventEnd = _combineDateAndTime(widget.selectedDate, _selectedDayWorkingHours!.timeSlots.first.openTime);
    for(var apptData in _appointmentsWithPatients){
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
    final latestCloseTime = _combineDateAndTime(widget.selectedDate, _selectedDayWorkingHours!.timeSlots.last.closeTime);
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
    for (var event in events) { event.columnIndex = 0; event.maxOverlaps = 1; }
    for (int i = 0; i < events.length; i++) {
      var currentEvent = events[i];
      List<_AppointmentLayoutInfo> overlappingPeers = [];
      for (int j = 0; j < i; j++) { if (currentEvent.overlaps(events[j])) { overlappingPeers.add(events[j]); } }
      var occupiedColumns = overlappingPeers.map((e) => e.columnIndex).toSet();
      int col = 0;
      while (occupiedColumns.contains(col)) { col++; }
      currentEvent.columnIndex = col;
    }
    for (var event in events) {
      var allOverlapping = events.where((peer) => peer.overlaps(event)).toList();
      int maxCol = 0;
      for (var item in allOverlapping) { if (item.columnIndex > maxCol) { maxCol = item.columnIndex; } }
      for (var item in allOverlapping) { item.maxOverlaps = max(item.maxOverlaps, maxCol + 1); }
    }
    return events;
  }
  // --- UI Building ---
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFEFE0FF),
      appBar: AppBar(
        backgroundColor: const Color(0xFFD9B8FF),
        elevation: 0,
        title: Text(
          'นัดหมายวันที่ ${DateFormat('d MMM yyyy', 'th_TH').format(widget.selectedDate)}',
          style: const TextStyle(color: Colors.black, fontSize: 20, fontWeight: FontWeight.bold),
        ),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 12, 12, 8),
            child: _buildViewModeSelector(),
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
                            padding: const EdgeInsets.symmetric(horizontal: 4.0),
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
      floatingActionButton: _buildFloatingActionButton(),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerDocked,
      bottomNavigationBar: _buildBottomAppBar(),
    );
  }

  // --- Timeline and Appointments Area ---
  Widget _buildTimeline(DayWorkingHours workingHours) {
    final timeFormat = DateFormat('HH:mm');
    final earliestOpen = workingHours.timeSlots.first.openTime;
    final latestClose = workingHours.timeSlots.last.closeTime;

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
    final dayStartTime = _combineDateAndTime(widget.selectedDate, workingHours.timeSlots.first.openTime);
    final dayEndTime = _combineDateAndTime(widget.selectedDate, workingHours.timeSlots.last.closeTime);
    final totalHeight = max(0.0, dayEndTime.difference(dayStartTime).inMinutes * pixelsPerMinute);
    final double contentWidth = constraints.maxWidth - 55.0; // 55.0 for timeline width
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
        positionedItems.add(Positioned(top: top, left: 0, right: 0, height: height, child: GapCard(gapStart: itemStart, gapEnd: itemEnd, onTap: () => showDialog(context: context, builder: (_) => AppointmentAddDialog(initialDate: widget.selectedDate, initialStartTime: itemStart)).then((_) => _fetchAppointmentsAndWorkingHoursForSelectedDay(widget.selectedDate)))));
      } else {
        final layoutInfo = appointmentLayouts.firstWhere((l) => l.appointmentData == item, orElse: () => _AppointmentLayoutInfo(appointmentData: item, startTime: itemStart, endTime: itemEnd));
        final cardWidth = (contentWidth / layoutInfo.maxOverlaps) - 4;
        final left = layoutInfo.columnIndex * (cardWidth + 4);
        final appointmentId = (item['appointment'] as Map<String, dynamic>)['appointmentId'] ?? '';
        positionedItems.add(Positioned(top: top, left: left, width: cardWidth, height: height, child: AppointmentCard(appointment: item['appointment'], patient: item['patient'], onTap: () {
          if (appointmentId.isEmpty) return;
          showDialog(context: context, builder: (_) => AppointmentDetailDialog(appointmentId: appointmentId, appointment: item['appointment'], patient: item['patient'], onDataChanged: () => _fetchAppointmentsAndWorkingHoursForSelectedDay(widget.selectedDate)));
        }, isCompact: layoutInfo.maxOverlaps > 1)));
      }
    }
    return Expanded(child: SizedBox(height: totalHeight, child: Stack(children: positionedItems)));
  }

  Widget _buildBottomAppBar() {
    return BottomAppBar(
      shape: const CircularNotchedRectangle(),
      notchMargin: 8.0,
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
    );
  }

    Widget _buildNavIconButton({required IconData icon, required String tooltip, required int index}) {
    return IconButton(
      icon: Icon(icon, size: 30),
      color: _selectedIndex == index ? Colors.purple : Colors.purple.shade200,
      onPressed: () => _onItemTapped(index),
      tooltip: tooltip,
    );
  }
  
  
  Widget _buildFloatingActionButton() {
    return FloatingActionButton(
      onPressed: () => showDialog(context: context, builder: (context) => AppointmentAddDialog(initialDate: widget.selectedDate)).then((_) => _fetchAppointmentsAndWorkingHoursForSelectedDay(widget.selectedDate)),
      backgroundColor: Colors.purple,
      tooltip: 'เพิ่มนัดหมายใหม่',
      child: const Icon(Icons.add, color: Colors.white, size: 36),
    );
  }

  void _onItemTapped(int index) {
    if (_selectedIndex == index) return;
    setState(() { _selectedIndex = index; });
    if (index == 0) { Navigator.pop(context); } 
    else if (index == 1) { Navigator.pushReplacement(context, MaterialPageRoute(builder: (context) => const PatientsScreen())); } 
    else if (index == 3) { Navigator.pushReplacement(context, MaterialPageRoute(builder: (context) => const ReportsScreen())); } 
    else if (index == 4) { Navigator.pushReplacement(context, MaterialPageRoute(builder: (context) => const SettingsScreen())); }
  }

  Widget _buildViewModeSelector() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.end,
      children: [
        _buildViewModeButton(label: 'เดือน', icon: Icons.calendar_month_outlined, isActive: false, onPressed: () => Navigator.pop(context, CalendarFormat.month)),
        _buildViewModeButton(label: 'สัปดาห์', icon: Icons.view_week_outlined, isActive: false, onPressed: () => Navigator.pop(context, CalendarFormat.week)),
        _buildViewModeButton(label: 'วัน', icon: Icons.calendar_view_day, isActive: true, onPressed: () => _fetchAppointmentsAndWorkingHoursForSelectedDay(widget.selectedDate)),
      ],
    );
  }
  
  Widget _buildViewModeButton({ required String label, required IconData icon, required bool isActive, required VoidCallback onPressed }) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4.0),
      child: TextButton.icon(
        onPressed: onPressed,
        icon: Icon(icon, color: isActive ? Colors.purple.shade800 : Colors.grey.shade600, size: 18),
        label: Text(label, style: TextStyle(color: isActive ? Colors.purple.shade800 : Colors.grey.shade700, fontWeight: isActive ? FontWeight.bold : FontWeight.normal)),
        style: TextButton.styleFrom(
          backgroundColor: isActive ? Colors.purple.shade100 : Colors.white,
          side: BorderSide(color: isActive ? Colors.purple.shade100 : Colors.grey.shade300),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          padding: const EdgeInsets.symmetric(horizontal: 16),
        ),
      ),
    );
  }
}

  // Widget _buildAppointmentsArea(List<Map<String, dynamic>> appointments, DayWorkingHours workingHours) {
  //   final pixelsPerMinute = _hourHeight / 60.0;
  //   final dayStartTime = workingHours.timeSlots.first.openTime;
  //   final dayEndTime = workingHours.timeSlots.last.closeTime;
  //   final totalMinutes = (dayEndTime.hour * 60 + dayEndTime.minute) - (dayStartTime.hour * 60 + dayStartTime.minute);
  //   final totalHeight = max(0.0, totalMinutes * pixelsPerMinute);

  //   final combinedList = buildAppointmentListWithGaps(appointments, workingHours, widget.selectedDate);
    
  //   return Expanded(
  //     child: LayoutBuilder(
  //       builder: (context, constraints) {
  //         final totalWidth = constraints.maxWidth;
  //         List<Widget> positionedItems = [];

  //         // Add background lines
  //         for (int i = 1; i <= (totalMinutes / 60).floor(); i++) {
  //           positionedItems.add(Positioned(
  //             top: i * 60 * pixelsPerMinute,
  //             left: 0,
  //             right: 0,
  //             child: Container(height: 1, color: Colors.purple.withOpacity(0.1)),
  //           ));
  //         }

  //         // Group overlapping events and layout them
  //         var i = 0;
  //         while (i < combinedList.length) {
  //           var currentEvent = combinedList[i];
  //           if (currentEvent['isGap'] == true) {
  //             // Handle gap
  //             final itemStart = currentEvent['start'] as DateTime;
  //             final itemEnd = currentEvent['end'] as DateTime;
  //             final startMinutesFromDayStart = (itemStart.hour * 60 + itemStart.minute) - (dayStartTime.hour * 60 + dayStartTime.minute);
  //             final durationMinutes = max(0, itemEnd.difference(itemStart).inMinutes);

  //             if (durationMinutes > 0) {
  //               positionedItems.add(Positioned(
  //                 key: ValueKey('gap_${itemStart.toIso8601String()}'),
  //                 top: startMinutesFromDayStart * pixelsPerMinute,
  //                 height: durationMinutes * pixelsPerMinute,
  //                 left: 0,
  //                 width: totalWidth,
  //                 child: GapCard(
  //                   gapStart: itemStart,
  //                   gapEnd: itemEnd,
  //                   onTap: () => showDialog(
  //                     context: context,
  //                     builder: (_) => AppointmentAddDialog(
  //                       initialDate: widget.selectedDate,
  //                       initialStartTime: itemStart,
  //                     ),
  //                   ).then((_) => _fetchAppointmentsAndWorkingHoursForSelectedDay(widget.selectedDate)),
  //                 ),
  //               ));
  //             }
  //             i++;
  //             continue;
  //           }

  //           // Find a group of overlapping appointments
  //           var group = [currentEvent];
  //           var groupEndTime = (currentEvent['appointment']['endTime'] as Timestamp).toDate();

  //           var j = i + 1;
  //           while (j < combinedList.length) {
  //             var nextEvent = combinedList[j];
  //             if (nextEvent['isGap'] == true) break;

  //             var nextStartTime = (nextEvent['appointment']['startTime'] as Timestamp).toDate();
  //             if (nextStartTime.isBefore(groupEndTime)) {
  //               group.add(nextEvent);
  //               var nextEndTime = (nextEvent['appointment']['endTime'] as Timestamp).toDate();
  //               if (nextEndTime.isAfter(groupEndTime)) {
  //                 groupEndTime = nextEndTime;
  //               }
  //               j++;
  //             } else {
  //               break;
  //             }
  //           }

  //           // Layout the found group
  //           _layoutAppointmentGroup(group, dayStartTime, pixelsPerMinute, totalWidth, positionedItems);

  //           // Move index to the next event after the group
  //           i = j;
  //         }

  //         return SizedBox(height: totalHeight, child: Stack(children: positionedItems));
  //       },
  //     ),
  //   );  
  // }

  // void _layoutAppointmentGroup(
  //   List<Map<String, dynamic>> group,
  //   TimeOfDay dayStartTime,
  //   double pixelsPerMinute,
  //   double totalWidth,
  //   List<Widget> positionedItems,
  // ) {
  //   if (group.isEmpty) return;

  //   group.sort((a, b) =>
  //       (a['appointment']['startTime'] as Timestamp)
  //           .toDate()
  //           .compareTo((b['appointment']['startTime'] as Timestamp).toDate()));

  //   List<List<Map<String, dynamic>>> columns = [];

  //   for (var event in group) {
  //     bool placed = false;
  //     for (var column in columns) {
  //       final lastEventInColumn = column.last;
  //       final lastEventEndTime = (lastEventInColumn['appointment']['endTime'] as Timestamp).toDate();
  //       final currentEventStartTime = (event['appointment']['startTime'] as Timestamp).toDate();

  //       if (!currentEventStartTime.isBefore(lastEventEndTime)) {
  //         column.add(event);
  //         placed = true;
  //         break;
  //       }
  //     }
  //     if (!placed) {
  //       columns.add([event]);
  //     }
  //   }

  //   final numColumns = columns.length;
  //   final colWidth = totalWidth / numColumns;

  //   for (int colIndex = 0; colIndex < numColumns; colIndex++) {
  //     final column = columns[colIndex];
  //     final left = colIndex * colWidth;

  //     for (var item in column) {
  //       final appointment = item['appointment'];
  //       final patient = item['patient'];
  //       final itemStart = (appointment['startTime'] as Timestamp).toDate();
  //       final itemEnd = (appointment['endTime'] as Timestamp).toDate();
  //       final card = AppointmentCard(
  //         appointment: appointment,
  //         patient: patient,
  //         onTap: () => showDialog(
  //           context: context,
  //           builder: (_) => AppointmentAddDialog(appointmentData: appointment),
  //         ).then((_) => _fetchAppointmentsAndWorkingHoursForSelectedDay(widget.selectedDate)),
  //       );

  //       final top = (itemStart.hour * 60 + itemStart.minute - (dayStartTime.hour * 60 + dayStartTime.minute)) * pixelsPerMinute;
  //       final height = itemEnd.difference(itemStart).inMinutes * pixelsPerMinute;

  //       if (height <= 0) continue;

  //       positionedItems.add(
  //         Positioned(
  //           key: ValueKey(appointment['appointmentId']),
  //           top: top,
  //           left: left,
  //           width: colWidth,
  //           height: height,
  //           child: Padding(
  //             padding: const EdgeInsets.only(right: 4.0),
  //             child: card,
  //           ),
  //         ),
  //       );
  //     }
  //   }
  // }

  // --- Helper Widgets and Functions ---
  // Widget _buildDailyScreenToggleButton() {
  //   IconData icon;
  //   String label;
  //   VoidCallback actionToPerform;

  //   if (_buttonModeForDailyView == _CalendarButtonMode.displayMonthly) {
  //     icon = Icons.calendar_month;
  //     label = 'ดูรายเดือน';
  //     actionToPerform = () => Navigator.pop(context, CalendarFormat.month);
  //   } else if (_buttonModeForDailyView == _CalendarButtonMode.displayWeekly) {
  //     icon = Icons.view_week;
  //     label = 'ดูรายสัปดาห์';
  //     actionToPerform = () => Navigator.pop(context, CalendarFormat.week);
  //   } else {
  //     icon = Icons.refresh;
  //     label = 'รีเฟรช';
  //     actionToPerform = () => _fetchAppointmentsAndWorkingHoursForSelectedDay(widget.selectedDate);
  //   }

  //   return TextButton.icon(
  //     onPressed: () {
  //       actionToPerform();
  //       setState(() {
  //         if (_buttonModeForDailyView == _CalendarButtonMode.displayMonthly) {
  //           _buttonModeForDailyView = _CalendarButtonMode.displayWeekly;
  //         } else if (_buttonModeForDailyView == _CalendarButtonMode.displayWeekly) {
  //           _buttonModeForDailyView = _CalendarButtonMode.displayDaily;
  //         } else {
  //           _buttonModeForDailyView = _CalendarButtonMode.displayMonthly;
  //         }
  //       });
  //     },
  //     icon: Icon(icon, color: Colors.purple),
  //     label: Text(label, style: const TextStyle(color: Colors.purple, fontWeight: FontWeight.bold)),
  //     style: TextButton.styleFrom(
  //       backgroundColor: Colors.purple.shade50,
  //       shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
  //     ),
  //   );
  // }

//   Widget _buildFloatingActionButton() {
//     return FloatingActionButton(
//       onPressed: () {
//         showDialog(
//           context: context,
//           builder: (context) => AppointmentAddDialog(initialDate: widget.selectedDate),
//         ).then((_) => _fetchAppointmentsAndWorkingHoursForSelectedDay(widget.selectedDate));
//       },
//       backgroundColor: Colors.purple,
//       shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
//       tooltip: 'เพิ่มนัดหมายใหม่',
//       child: const Icon(Icons.add, color: Colors.white, size: 36),
//     );
//   }

//   Widget _buildBottomAppBar() {
//     return BottomAppBar(
//       shape: const CircularNotchedRectangle(),
//       notchMargin: 8.0,
//       color: const Color(0xFFFBEAFF),
//       child: Padding(
//         padding: const EdgeInsets.symmetric(horizontal: 16.0),
//         child: Row(
//           mainAxisAlignment: MainAxisAlignment.spaceBetween,
//           children: <Widget>[
//             _buildNavIconButton(icon: Icons.calendar_today, tooltip: 'ปฏิทิน', index: 0),
//             _buildNavIconButton(icon: Icons.people_alt, tooltip: 'คนไข้', index: 1),
//             const SizedBox(width: 40),
//             _buildNavIconButton(icon: Icons.bar_chart, tooltip: 'รายงาน', index: 3),
//             _buildNavIconButton(icon: Icons.settings, tooltip: 'ตั้งค่า', index: 4),
//           ],
//         ),
//       ),
//     );
//   }

//   Widget _buildNavIconButton({required IconData icon, required String tooltip, required int index}) {
//     return IconButton(
//       icon: Icon(icon, size: 30),
//       color: _selectedIndex == index ? Colors.purple : Colors.purple.shade200,
//       onPressed: () => _onItemTapped(index),
//       tooltip: tooltip,
//     );
//   }

//   void _onItemTapped(int index) {
//     if (_selectedIndex == index) return;
//     setState(() { _selectedIndex = index; });

//     if (index == 0) {
//       Navigator.pop(context);
//     } else if (index == 1) {
//       Navigator.pushReplacement(context, MaterialPageRoute(builder: (context) => const PatientsScreen()));
//     } else if (index == 3) {
//       Navigator.pushReplacement(context, MaterialPageRoute(builder: (context) => const ReportsScreen()));
//     } else if (index == 4) {
//       Navigator.pushReplacement(context, MaterialPageRoute(builder: (context) => const SettingsScreen()));
//     }
//   }

//   // --- Utility Functions ---
//   String _getThaiDayName(int weekday) {
//     const days = ['จันทร์', 'อังคาร', 'พุธ', 'พฤหัสบดี', 'ศุกร์', 'เสาร์', 'อาทิตย์'];
//     return days[weekday - 1];
//   }

//   DateTime _combineDateAndTime(DateTime date, TimeOfDay time) {
//     return DateTime(date.year, date.month, date.day, time.hour, time.minute);
//   }

//   List<Map<String, dynamic>> buildAppointmentListWithGaps(
//     List<Map<String, dynamic>> rawAppointments,
//     DayWorkingHours dayWorkingHours,
//     DateTime selectedDate,
//   ) {
//     List<Map<String, dynamic>> finalCombinedList = [];
//     List<Map<String, dynamic>> events = [];

//     for (var slot in dayWorkingHours.timeSlots) {
//       events.add({'time': _combineDateAndTime(selectedDate, slot.openTime), 'type': 'clinic_open'});
//       events.add({'time': _combineDateAndTime(selectedDate, slot.closeTime), 'type': 'clinic_close'});
//     }

//     for (var appt in rawAppointments) {
//       events.add({'time': (appt['appointment']['startTime'] as Timestamp).toDate(), 'type': 'appointment_start', 'data': appt});
//       events.add({'time': (appt['appointment']['endTime'] as Timestamp).toDate(), 'type': 'appointment_end'});
//     }

//     events.sort((a, b) {
//       int compare = (a['time'] as DateTime).compareTo(b['time'] as DateTime);
//       if (compare == 0) {
//         if (a['type'] == 'clinic_open' || a['type'] == 'appointment_start') return -1;
//         if (b['type'] == 'clinic_open' || b['type'] == 'appointment_start') return 1;
//       }
//       return compare;
//     });

//     DateTime? lastProcessedTime;
//     int openClinicCount = 0;
//     int activeAppointmentCount = 0;

//     for (var event in events) {
//       final currentTime = event['time'] as DateTime;
//       if (lastProcessedTime != null && currentTime.isAfter(lastProcessedTime)) {
//         if (openClinicCount > 0 && activeAppointmentCount == 0) {
//           finalCombinedList.add({'isGap': true, 'start': lastProcessedTime, 'end': currentTime});
//         }
//       }

//       if (event['type'] == 'clinic_open') {
//         openClinicCount++;
//       } else if (event['type'] == 'clinic_close') openClinicCount--;
//       else if (event['type'] == 'appointment_start') {
//         activeAppointmentCount++;
//         finalCombinedList.add(event['data']);
//       } else if (event['type'] == 'appointment_end') activeAppointmentCount--;
      
//       lastProcessedTime = currentTime;
//     }

//     finalCombinedList.sort((a, b) {
//       DateTime aStart = a['isGap'] == true ? a['start'] : (a['appointment']['startTime'] as Timestamp).toDate();
//       DateTime bStart = b['isGap'] == true ? b['start'] : (b['appointment']['startTime'] as Timestamp).toDate();
//       return aStart.compareTo(bStart);
//     });

//     return finalCombinedList;
//   }
//    Widget _buildViewModeSelector() {
//     return Row(
//       mainAxisAlignment: MainAxisAlignment.end, // จัดชิดขวาเหมือนเดิม
//       children: [
//         _buildViewModeButton(
//           label: 'เดือน',
//           icon: Icons.calendar_month_outlined,
//           isActive: false, // ปุ่มนี้ไม่ active เพราะเป็นแค่ทางกลับบ้าน
//           onPressed: () {
//             Navigator.pop(context, CalendarFormat.month); // ส่งสัญญาณกลับไปให้หน้าหลักแสดงผลแบบรายเดือน
//           },
//         ),
//         _buildViewModeButton(
//           label: 'สัปดาห์',
//           icon: Icons.view_week_outlined,
//           isActive: false, // ปุ่มนี้ไม่ active เพราะเป็นแค่ทางกลับบ้าน
//           onPressed: () {
//             Navigator.pop(context, CalendarFormat.week); // ส่งสัญญาณกลับไปให้หน้าหลักแสดงผลแบบรายสัปดาห์
//           },
//         ),
//         _buildViewModeButton(
//           label: 'วัน',
//           icon: Icons.calendar_view_day, // ใช้ไอคอนที่ดู active
//           isActive: true, // ปุ่มนี้ active เพราะเราอยู่ในหน้ารายวัน
//           onPressed: () {
//             // อาจจะใช้สำหรับ refresh ข้อมูลก็ได้ค่ะ
//             _fetchAppointmentsAndWorkingHoursForSelectedDay(widget.selectedDate);
//           },
//         ),
//       ],
//     );
//   }
  
//   // ✨✨✨ ฟังก์ชันผู้ช่วยสำหรับสร้างปุ่มแต่ละอัน (เหมือนกับใน calendar_screen) ✨✨✨
//   Widget _buildViewModeButton({
//     required String label,
//     required IconData icon,
//     required bool isActive,
//     required VoidCallback onPressed,
//   }) {
//     final activeColor = Colors.purple.shade100;
//     final activeTextColor = Colors.purple.shade800;
//     final inactiveColor = Colors.grey.shade200;

//     return Padding(
//       padding: const EdgeInsets.symmetric(horizontal: 4.0),
//       child: TextButton.icon(
//         onPressed: onPressed,
//         icon: Icon(icon, color: isActive ? activeTextColor : Colors.grey.shade600, size: 18),
//         label: Text(label, style: TextStyle(color: isActive ? activeTextColor : Colors.grey.shade700, fontWeight: isActive ? FontWeight.bold : FontWeight.normal)),
//         style: TextButton.styleFrom(
//           backgroundColor: isActive ? activeColor : Colors.white,
//           side: BorderSide(color: isActive ? activeColor : inactiveColor),
//           shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
//           padding: const EdgeInsets.symmetric(horizontal: 16),
//         ),
//       ),
//     );
//   }
// }



