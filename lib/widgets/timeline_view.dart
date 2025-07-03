// 📁 lib/widgets/timeline_view.dart (เฟอร์นิเจอร์ชิ้นใหม่ของเรา ✨)

import 'dart:math';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/working_hours_model.dart';
import '../screens/appointment_add.dart';
import 'appointment_card.dart';
import 'gap_card.dart';
import 'appointment_detail_dialog.dart';

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

// --- Widget หลักของ Timeline View ---
class TimelineView extends StatelessWidget {
  final DateTime selectedDate;
  final List<Map<String, dynamic>> appointments;
  final DayWorkingHours workingHours;
  final double hourHeight;
  final VoidCallback onDataChanged;

  const TimelineView({
    super.key,
    required this.selectedDate,
    required this.appointments,
    required this.workingHours,
    required this.onDataChanged,
    this.hourHeight = 120.0,
  });

  // --- Logic สำหรับสร้าง List และคำนวณ Layout ---
  
  DateTime _combineDateAndTime(DateTime date, TimeOfDay time) {
    return DateTime(date.year, date.month, date.day, time.hour, time.minute);
  }
  
  List<Map<String, dynamic>> _getCombinedList() {
    if (workingHours.isClosed || workingHours.timeSlots.isEmpty) {
      return appointments..sort((a,b) => (a['appointment']['startTime'] as Timestamp).compareTo(b['appointment']['startTime'] as Timestamp));
    }
    appointments.sort((a,b) => (a['appointment']['startTime'] as Timestamp).compareTo(b['appointment']['startTime'] as Timestamp));
    
    List<Map<String, dynamic>> finalCombinedList = [];
    DateTime lastEventEnd = _combineDateAndTime(selectedDate, workingHours.timeSlots.first.openTime);
    
    for(var apptData in appointments){
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
    
    final latestCloseTime = _combineDateAndTime(selectedDate, workingHours.timeSlots.last.closeTime);
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

  @override
  Widget build(BuildContext context) {
    final combinedList = _getCombinedList();
    if (combinedList.isEmpty) {
      return Center(child: Text('ไม่มีนัดหมายในวันนี้', style: TextStyle(color: Colors.grey.shade600, fontSize: 16)));
    }
    return LayoutBuilder(
      builder: (context, constraints) {
        return SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 4.0),
          child: Padding(
            padding: const EdgeInsets.only(top: 8.0),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildTimeline(workingHours),
                _buildContentArea(context, combinedList, workingHours, constraints),
              ],
            ),
          ),
        );
      },
    );
  }

  // --- Widget ผู้ช่วยสำหรับสร้าง UI ---
  
  Widget _buildTimeline(DayWorkingHours workingHours) {
    List<Widget> timeWidgets = [];
    final slots = workingHours.timeSlots;
    if (slots.isEmpty) return const SizedBox.shrink();
    final dayStart = slots.first.openTime;
    final dayEnd = slots.last.closeTime;
    int currentMinute = dayStart.hour * 60 + dayStart.minute;
    final endMinute = dayEnd.hour * 60 + dayEnd.minute;

    while (currentMinute <= endMinute) {
      final currentTime = DateTime(2024, 1, 1, currentMinute ~/ 60, currentMinute % 60);
      
      // ✨ [FIX] ปรับฟอนต์ให้เป็นตัวบางและขนาดเท่ากันทั้งหมดค่ะ! ✨
      final timeText = Text(
        DateFormat('HH:mm').format(currentTime),
        style: TextStyle(
          fontWeight: FontWeight.normal, // ตัวบางทั้งหมด
          fontSize: 12, // ขนาด 12 เท่ากันทั้งหมด
          color: Colors.grey.shade700, // สีเทาเหมือนกันทั้งหมด
        ),
      );

      timeWidgets.add(SizedBox(
        height: 30 * (hourHeight / 60),
        child: Align(
          alignment: Alignment.topRight,
          child: Transform.translate(
            offset: const Offset(0, -7),
            child: timeText,
          ),
        ),
      ));
      currentMinute += 30;
    }
    return Container(width: 60.0, padding: const EdgeInsets.only(right: 4), child: Column(children: timeWidgets));
  }

  Widget _buildContentArea(BuildContext context, List<Map<String, dynamic>> combinedList, DayWorkingHours workingHours, BoxConstraints constraints) {
    final appointmentOnlyList = combinedList.where((item) => item['isGap'] != true).toList();
    final appointmentLayouts = _calculateAppointmentLayouts(appointmentOnlyList);
    final pixelsPerMinute = hourHeight / 60.0;
    final dayStartTime = _combineDateAndTime(selectedDate, workingHours.timeSlots.first.openTime);
    final dayEndTime = _combineDateAndTime(selectedDate, workingHours.timeSlots.last.closeTime);
    final totalHeight = max(0.0, dayEndTime.difference(dayStartTime).inMinutes * pixelsPerMinute);
    
    final double contentWidth = constraints.maxWidth - 60.0; 
    
    List<Widget> positionedItems = [];
    final totalHours = dayEndTime.difference(dayStartTime).inHours;
    for (int i = 0; i <= totalHours; i++) {
      positionedItems.add(Positioned(top: i * hourHeight, left: 0, right: 0, child: Container(height: 1, color: Colors.purple.shade50)));
    }
    for (var item in combinedList) {
      final bool isGap = item['isGap'] == true;
      final DateTime itemStart = isGap ? item['start'] : (item['appointment']['startTime'] as Timestamp).toDate();
      final DateTime itemEnd = isGap ? item['end'] : (item['appointment']['endTime'] as Timestamp).toDate();
      final top = max(0.0, itemStart.difference(dayStartTime).inMinutes * pixelsPerMinute);
      final height = max(0.0, itemEnd.difference(itemStart).inMinutes * pixelsPerMinute);
      if (height <= 0) continue;
      if (isGap) {
        positionedItems.add(Positioned(top: top, left: 0, right: 0, height: height, child: GapCard(gapStart: itemStart, gapEnd: itemEnd, onTap: () => showDialog(context: context, builder: (_) => AppointmentAddDialog(initialDate: selectedDate, initialStartTime: itemStart)).then((_) => onDataChanged()))));
      } else {
        final layoutInfo = appointmentLayouts.firstWhere((l) => l.appointmentData == item, orElse: () => _AppointmentLayoutInfo(appointmentData: item, startTime: itemStart, endTime: itemEnd));
        final cardWidth = (contentWidth / layoutInfo.maxOverlaps) - 4;
        final left = layoutInfo.columnIndex * (cardWidth + 4);
        final appointmentId = (item['appointment'] as Map<String, dynamic>)['appointmentId'] ?? '';

        // คำนวณว่าเป็นนัดหมายแบบสั้นหรือไม่
        final durationInMinutes = itemEnd.difference(itemStart).inMinutes;
        final bool isShortAppointment = durationInMinutes <= 30;
        
        positionedItems.add(Positioned(top: top, left: left, width: cardWidth, height: height, child: AppointmentCard(appointment: item['appointment'], patient: item['patient'], onTap: () {
          if (appointmentId.isEmpty) return;
          showDialog(context: context, builder: (_) => AppointmentDetailDialog(appointmentId: appointmentId, appointment: item['appointment'], patient: item['patient'], onDataChanged: onDataChanged));
        }, isCompact: layoutInfo.maxOverlaps > 1, isShort: isShortAppointment)));
      }
    }
    return Expanded(child: SizedBox(height: totalHeight, child: Stack(children: positionedItems)));
  }
}
