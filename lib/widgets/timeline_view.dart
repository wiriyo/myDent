// v2.4.0 - ✨ Major Fix for Timeline Axis to Respect Working Hours
// 📁 lib/widgets/timeline_view.dart

import 'dart:math';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../models/working_hours_model.dart';
import '../screens/appointment_add.dart';
import '../models/appointment_model.dart';
import '../models/patient.dart';
import 'appointment_card.dart';
import 'gap_card.dart';
import 'appointment_detail_dialog.dart';

class _AppointmentLayoutInfo {
  final AppointmentModel appointment;
  final DateTime startTime;
  final DateTime endTime;
  int maxOverlaps = 1;
  int columnIndex = 0;

  _AppointmentLayoutInfo({
    required this.appointment,
    required this.startTime,
    required this.endTime,
  });

  bool overlaps(_AppointmentLayoutInfo other) {
    return startTime.isBefore(other.endTime) && endTime.isAfter(other.startTime);
  }
}

class TimelineView extends StatelessWidget {
  final DateTime selectedDate;
  final List<AppointmentModel> appointments;
  final List<Patient> patients;
  final DayWorkingHours workingHours;
  final double hourHeight;
  final VoidCallback onDataChanged;

  const TimelineView({
    super.key,
    required this.selectedDate,
    required this.appointments,
    required this.patients,
    required this.workingHours,
    required this.onDataChanged,
    this.hourHeight = 120.0,
  });
  
  DateTime _combineDateAndTime(DateTime date, TimeOfDay time) {
    return DateTime(date.year, date.month, date.day, time.hour, time.minute);
  }
  
  List<Map<String, dynamic>> _getCombinedList() {
    if (workingHours.isClosed || workingHours.timeSlots.isEmpty) {
      return appointments.map((appt) => {'isGap': false, 'appointment': appt}).toList();
    }

    appointments.sort((a, b) => a.startTime.compareTo(b.startTime));
    
    List<Map<String, dynamic>> finalCombinedList = [];
    int appointmentIndex = 0;

    for (final slot in workingHours.timeSlots) {
      DateTime slotStart = _combineDateAndTime(selectedDate, slot.openTime);
      DateTime slotEnd = _combineDateAndTime(selectedDate, slot.closeTime);
      DateTime timelineCursor = slotStart;

      while (appointmentIndex < appointments.length) {
        final appt = appointments[appointmentIndex];
        if (appt.startTime.isAfter(slotEnd) || appt.startTime.isAtSameMomentAs(slotEnd)) {
            break; 
        }
        if (appt.startTime.isAfter(timelineCursor)) {
          finalCombinedList.add({'isGap': true, 'start': timelineCursor, 'end': appt.startTime});
        }
        finalCombinedList.add({'isGap': false, 'appointment': appt});
        if (appt.endTime.isAfter(timelineCursor)) {
          timelineCursor = appt.endTime;
        }
        appointmentIndex++;
      }

      if (slotEnd.isAfter(timelineCursor)) {
        finalCombinedList.add({'isGap': true, 'start': timelineCursor, 'end': slotEnd});
      }
    }

    while(appointmentIndex < appointments.length) {
      finalCombinedList.add({'isGap': false, 'appointment': appointments[appointmentIndex]});
      appointmentIndex++;
    }

    return finalCombinedList;
  }

  List<_AppointmentLayoutInfo> _calculateAppointmentLayouts(List<AppointmentModel> appointments) {
    if (appointments.isEmpty) return [];
    var events = appointments.map((model) => _AppointmentLayoutInfo(
      appointment: model,
      startTime: model.startTime,
      endTime: model.endTime,
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
    if (workingHours.isClosed || workingHours.timeSlots.isEmpty) {
        return Center(child: Text('คลินิกปิดทำการ', style: TextStyle(color: Colors.grey.shade600, fontSize: 16)));
    }

    final combinedList = _getCombinedList();
    
    // ✨ [FIX v2.4.0] ย้ายการคำนวณตัวแปรส่วนกลางมาไว้ตรงนี้
    // เพื่อให้ทั้ง _buildTimeline และ _buildContentArea ใช้ค่าเดียวกันค่ะ
    final pixelsPerMinute = hourHeight / 60.0;
    final dayStartTime = _combineDateAndTime(selectedDate, workingHours.timeSlots.first.openTime);
    final dayEndTime = _combineDateAndTime(selectedDate, workingHours.timeSlots.last.closeTime);
    final totalHeight = max(0.0, dayEndTime.difference(dayStartTime).inMinutes * pixelsPerMinute);

    return LayoutBuilder(
      builder: (context, constraints) {
        return SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 4.0),
          child: Padding(
            padding: const EdgeInsets.only(top: 8.0),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildTimeline(dayStartTime, totalHeight, pixelsPerMinute),
                _buildContentArea(context, combinedList, dayStartTime, totalHeight, pixelsPerMinute, constraints),
              ],
            ),
          ),
        );
      },
    );
  }
  
  // ✨ [MAJOR FIX v2.4.0] แก้ไขการสร้างเส้นเวลาทั้งหมด ให้สอดคล้องกับเวลาทำการจริง
  Widget _buildTimeline(DateTime dayStartTime, double totalHeight, double pixelsPerMinute) {
    List<Widget> children = [];

    // 1. วาดเส้นแนวนอนสำหรับทุกๆ ชั่วโมงตามเวลาทำการ
    for (final slot in workingHours.timeSlots) {
      final slotStart = _combineDateAndTime(selectedDate, slot.openTime);
      final slotEnd = _combineDateAndTime(selectedDate, slot.closeTime);
      
      int currentMinute = slotStart.hour * 60 + slotStart.minute;
      final endMinute = slotEnd.hour * 60 + slotEnd.minute;

      while (currentMinute <= endMinute) {
        if (currentMinute % 60 == 0) { // วาดเส้นทุกๆ ชั่วโมงเต็ม
          final currentTime = DateTime(selectedDate.year, selectedDate.month, selectedDate.day, currentMinute ~/ 60, 0);
          final topPosition = currentTime.difference(dayStartTime).inMinutes * pixelsPerMinute;
          children.add(Positioned(
            top: topPosition,
            left: 0,
            right: 0,
            child: Container(height: 1, color: Colors.purple.shade50),
          ));
        }
        currentMinute += 30;
      }
    }
    
    // 2. เพิ่มป้ายบอกเวลา (09:00, 09:30, ...) ตามช่วงเวลาทำการ
    for (final slot in workingHours.timeSlots) {
      final slotStart = _combineDateAndTime(selectedDate, slot.openTime);
      final slotEnd = _combineDateAndTime(selectedDate, slot.closeTime);

      int currentMinute = slotStart.hour * 60 + slotStart.minute;
      final endMinute = slotEnd.hour * 60 + slotEnd.minute;

      while (currentMinute <= endMinute) {
        final currentTime = DateTime(selectedDate.year, selectedDate.month, selectedDate.day, currentMinute ~/ 60, currentMinute % 60);
        final topPosition = currentTime.difference(dayStartTime).inMinutes * pixelsPerMinute;

        children.add(
          Positioned(
            top: topPosition - 7, // จัดให้อยู่กึ่งกลางเส้น
            right: 8,
            child: Text(
              DateFormat('HH:mm').format(currentTime),
              style: const TextStyle(
                fontWeight: FontWeight.normal,
                fontSize: 12,
                color: Color(0xFF6A4DBA),
              ),
            ),
          ),
        );
        currentMinute += 30; // เพิ่มทีละครึ่งชั่วโมง
      }
    }

    return SizedBox(
      width: 60.0,
      height: totalHeight,
      child: Stack(children: children),
    );
  }

  Widget _buildContentArea(BuildContext context, List<Map<String, dynamic>> combinedList, DateTime dayStartTime, double totalHeight, double pixelsPerMinute, BoxConstraints constraints) {
    final appointmentLayouts = _calculateAppointmentLayouts(appointments);
    final double contentWidth = constraints.maxWidth - 60.0; 
    
    List<Widget> positionedItems = [];
    final patientMap = {for (var p in patients) p.patientId: p};

    for (var item in combinedList) {
      final bool isGap = item['isGap'] == true;
      final DateTime itemStart = isGap ? item['start'] : (item['appointment'] as AppointmentModel).startTime;
      final DateTime itemEnd = isGap ? item['end'] : (item['appointment'] as AppointmentModel).endTime;
      final top = max(0.0, itemStart.difference(dayStartTime).inMinutes * pixelsPerMinute);
      final height = max(0.0, itemEnd.difference(itemStart).inMinutes * pixelsPerMinute);
      if (height <= 0.1) continue;

      if (isGap) {
        positionedItems.add(Positioned(
          top: top, left: 0, right: 0, height: height, 
          child: GapCard(
            gapStart: itemStart, gapEnd: itemEnd, 
            onTap: () => showDialog(
              context: context, 
              builder: (_) => AppointmentAddDialog(initialDate: selectedDate, initialStartTime: itemStart)
            ).then((value) { if (value == true) { onDataChanged(); } })
          )
        ));
      } else {
        final appointmentModel = item['appointment'] as AppointmentModel;
        final patientModel = patientMap[appointmentModel.patientId];
        if (patientModel == null) {
          debugPrint('Warning: Patient not found for appointment ${appointmentModel.appointmentId}');
          continue;
        }

        final layoutInfo = appointmentLayouts.firstWhere((l) => l.appointment.appointmentId == appointmentModel.appointmentId, orElse: () => _AppointmentLayoutInfo(appointment: appointmentModel, startTime: itemStart, endTime: itemEnd));
        final cardWidth = (contentWidth / layoutInfo.maxOverlaps) - 4;
        final left = layoutInfo.columnIndex * (cardWidth + 4);
        
        final durationInMinutes = itemEnd.difference(itemStart).inMinutes;
        final bool isShortAppointment = durationInMinutes <= 30;
        
        positionedItems.add(Positioned(
          top: top, left: left, width: cardWidth, height: height, 
          child: AppointmentCard(
            appointment: appointmentModel, 
            patient: patientModel,
            onTap: () {
              showDialog(context: context, builder: (_) => AppointmentDetailDialog(
                  appointment: appointmentModel,
                  patient: patientModel,
                  onDataChanged: onDataChanged
              ));
            }, 
            isCompact: layoutInfo.maxOverlaps > 1, 
            isShort: isShortAppointment
          )
        ));
      }
    }
    return Expanded(child: SizedBox(height: totalHeight, child: Stack(children: positionedItems)));
  }
}
