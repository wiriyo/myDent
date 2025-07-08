// v2.0.0 - ✨ Major Upgrade to Handle Models & Patient Data
// 📁 lib/widgets/timeline_view.dart

import 'dart:math';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../models/working_hours_model.dart';
import '../screens/appointment_add.dart';
import '../models/appointment_model.dart';
import '../models/patient.dart'; // ✨ 1. เพิ่ม import สำหรับ Patient Model
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
  // ✨ 2. อัปเกรดพารามิเตอร์ให้รับ List ของ Model โดยตรง
  final List<AppointmentModel> appointments;
  final List<Patient> patients; // รับ List ของ Patient Model เข้ามาด้วย
  final DayWorkingHours workingHours;
  final double hourHeight;
  final VoidCallback onDataChanged;

  const TimelineView({
    super.key,
    required this.selectedDate,
    required this.appointments,
    required this.patients, // เพิ่ม required parameter
    required this.workingHours,
    required this.onDataChanged,
    this.hourHeight = 120.0,
  });
  
  DateTime _combineDateAndTime(DateTime date, TimeOfDay time) {
    return DateTime(date.year, date.month, date.day, time.hour, time.minute);
  }
  
  // ฟังก์ชันนี้จะรวมรายการนัดหมายกับช่องว่าง (Gap) เพื่อแสดงผลบนไทม์ไลน์
  List<Map<String, dynamic>> _getCombinedList() {
    // เรียงนัดหมายตามเวลาเริ่มต้นก่อนเสมอ
    appointments.sort((a, b) => a.startTime.compareTo(b.startTime));

    // ถ้าวันนั้นเป็นวันหยุดหรือไม่มีช่วงเวลาทำงาน ก็แสดงแค่นัดหมายอย่างเดียว
    if (workingHours.isClosed || workingHours.timeSlots.isEmpty) {
      return appointments.map((appt) => {'isGap': false, 'appointment': appt}).toList();
    }
    
    List<Map<String, dynamic>> finalCombinedList = [];
    // จุดเริ่มต้นของวันทำงาน
    DateTime lastEventEnd = _combineDateAndTime(selectedDate, workingHours.timeSlots.first.openTime);
    
    for(var appt in appointments){
      // ถ้านัดนี้เริ่มหลังนัดที่แล้วจบ ให้สร้าง "ช่องว่าง" (GapCard)
      if(appt.startTime.isAfter(lastEventEnd)){
        finalCombinedList.add({'isGap': true, 'start': lastEventEnd, 'end': appt.startTime});
      }
      // เพิ่ม "นัดหมาย" (AppointmentCard)
      finalCombinedList.add({'isGap': false, 'appointment': appt});
      // อัปเดตเวลาสิ้นสุดล่าสุด
      if (appt.endTime.isAfter(lastEventEnd)) {
        lastEventEnd = appt.endTime;
      }
    }
    
    // ตรวจสอบช่องว่างสุดท้ายของวัน
    final latestCloseTime = _combineDateAndTime(selectedDate, workingHours.timeSlots.last.closeTime);
    if(latestCloseTime.isAfter(lastEventEnd)){
        finalCombinedList.add({'isGap': true, 'start': lastEventEnd, 'end': latestCloseTime});
    }
    return finalCombinedList;
  }

  // ฟังก์ชันคำนวณการซ้อนทับกันของนัดหมาย (ส่วนนี้ไม่ต้องแก้ไขค่ะ)
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
  
  // ส่วนของการสร้างเส้นเวลา (ส่วนนี้ไม่ต้องแก้ไขค่ะ)
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
      
      final timeText = Text(
        DateFormat('HH:mm').format(currentTime),
        style: const TextStyle(
          fontWeight: FontWeight.normal,
          fontSize: 12,
          color: Color(0xFF6A4DBA),
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

  // ✨ 3. หัวใจของการแก้ไขอยู่ที่นี่ค่ะ!
  Widget _buildContentArea(BuildContext context, List<Map<String, dynamic>> combinedList, DayWorkingHours workingHours, BoxConstraints constraints) {
    final appointmentLayouts = _calculateAppointmentLayouts(appointments);
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

    // สร้าง Map เพื่อให้ค้นหา Patient จาก patientId ได้เร็วขึ้นค่ะ
    final patientMap = {for (var p in patients) p.patientId: p};

    for (var item in combinedList) {
      final bool isGap = item['isGap'] == true;
      final DateTime itemStart = isGap ? item['start'] : (item['appointment'] as AppointmentModel).startTime;
      final DateTime itemEnd = isGap ? item['end'] : (item['appointment'] as AppointmentModel).endTime;
      final top = max(0.0, itemStart.difference(dayStartTime).inMinutes * pixelsPerMinute);
      final height = max(0.0, itemEnd.difference(itemStart).inMinutes * pixelsPerMinute);
      if (height <= 0) continue;

      if (isGap) {
        positionedItems.add(Positioned(top: top, left: 0, right: 0, height: height, child: GapCard(gapStart: itemStart, gapEnd: itemEnd, onTap: () => showDialog(context: context, builder: (_) => AppointmentAddDialog(initialDate: selectedDate, initialStartTime: itemStart)).then((_) => onDataChanged()))));
      } else {
        final appointmentModel = item['appointment'] as AppointmentModel;
        
        // ✨ 4. ค้นหา Patient ที่เป็นเจ้าของนัดหมายนี้
        final patientModel = patientMap[appointmentModel.patientId];

        // ถ้าหาคนไข้ไม่เจอ (ซึ่งไม่ควรจะเกิดขึ้น) เราจะไม่แสดงการ์ดนั้น
        if (patientModel == null) {
          debugPrint('Warning: Patient not found for appointment ${appointmentModel.appointmentId}');
          continue;
        }

        final layoutInfo = appointmentLayouts.firstWhere((l) => l.appointment.appointmentId == appointmentModel.appointmentId, orElse: () => _AppointmentLayoutInfo(appointment: appointmentModel, startTime: itemStart, endTime: itemEnd));
        final cardWidth = (contentWidth / layoutInfo.maxOverlaps) - 4;
        final left = layoutInfo.columnIndex * (cardWidth + 4);
        
        final durationInMinutes = itemEnd.difference(itemStart).inMinutes;
        final bool isShortAppointment = durationInMinutes <= 30;
        
        positionedItems.add(Positioned(top: top, left: left, width: cardWidth, height: height, child: AppointmentCard(
          // ✨ 5. ส่ง Model ทั้งสองตัวไปให้ AppointmentCard
          appointment: appointmentModel, 
          patient: patientModel,
          onTap: () {
            showDialog(context: context, builder: (_) => AppointmentDetailDialog(
                // ✨ 6. ส่ง Model ทั้งสองตัวไปให้ AppointmentDetailDialog
                appointment: appointmentModel,
                patient: patientModel,
                onDataChanged: onDataChanged
            ));
          }, 
          isCompact: layoutInfo.maxOverlaps > 1, 
          isShort: isShortAppointment
        )));
      }
    }
    return Expanded(child: SizedBox(height: totalHeight, child: Stack(children: positionedItems)));
  }
}
