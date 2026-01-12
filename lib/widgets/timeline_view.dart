// ----------------------------------------------------------------
// 📁 lib/widgets/timeline_view.dart (v2.9 - 💖 Laila's Centralized Logic Fix!)
// ----------------------------------------------------------------
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../models/working_hours_model.dart';
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

class _TimelineSegment {
  final DateTime start;
  final DateTime end;
  final int offsetMinutes;
  final double offsetPixels;

  const _TimelineSegment({
    required this.start,
    required this.end,
    required this.offsetMinutes,
    required this.offsetPixels,
  });
}

class TimelineView extends StatelessWidget {
  static const double _segmentDividerThickness = 3.0;
  static const double _segmentDividerPaddingFactor = 5.0;
  final DateTime selectedDate;
  final List<AppointmentModel> appointments;
  final List<Patient> patients;
  final DayWorkingHours workingHours;
  final double hourHeight;
  final VoidCallback onDataChanged;
  final Patient? initialPatient;
  // 💖✨ START: THE CENTRALIZED LOGIC FIX v2.9 ✨💖
  // เพิ่ม callback ตัวใหม่สำหรับรับ "คำสั่ง" จาก GapCard ค่ะ
  final Function(DateTime startTime)? onGapAddTapped;
  // 💖✨ END: THE CENTRALIZED LOGIC FIX v2.9 ✨💖
  final bool enableChainedSelection;
  final Patient? chainedPatient;
  final Future<void> Function(AppointmentModel appointment, Patient patient)?
      onExistingAppointmentSelected;

  const TimelineView({
    super.key,
    required this.selectedDate,
    required this.appointments,
    required this.patients,
    required this.workingHours,
    required this.onDataChanged,
    this.hourHeight = 120.0,
    this.initialPatient,
    this.onGapAddTapped, // เพิ่มใน constructor ด้วยนะคะ
    this.enableChainedSelection = false,
    this.chainedPatient,
    this.onExistingAppointmentSelected,
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
        final gapCursor = timelineCursor.isBefore(slotStart) ? slotStart : timelineCursor;
        if (appt.startTime.isAfter(gapCursor)) {
          finalCombinedList.add({'isGap': true, 'start': gapCursor, 'end': appt.startTime});
        }
        finalCombinedList.add({'isGap': false, 'appointment': appt});
        if (appt.endTime.isAfter(timelineCursor)) {
          timelineCursor = appt.endTime;
        }
        appointmentIndex++;
      }

      final gapCursor = timelineCursor.isBefore(slotStart) ? slotStart : timelineCursor;
      if (slotEnd.isAfter(gapCursor)) {
        finalCombinedList.add({'isGap': true, 'start': gapCursor, 'end': slotEnd});
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

  double _getDisplayPixels(DateTime time, List<_TimelineSegment> segments, double pixelsPerMinute) {
    for (final segment in segments) {
      if ((time.isAfter(segment.start) || time.isAtSameMomentAs(segment.start)) &&
          (time.isBefore(segment.end) || time.isAtSameMomentAs(segment.end))) {
        return segment.offsetPixels +
            (segment.offsetMinutes + time.difference(segment.start).inMinutes.toDouble()) *
                pixelsPerMinute;
      }
    }
    if (segments.isEmpty) {
      return 0;
    }
    if (time.isBefore(segments.first.start)) {
      return 0;
    }
    final last = segments.last;
    return last.offsetPixels +
        (last.offsetMinutes + last.end.difference(last.start).inMinutes.toDouble()) *
            pixelsPerMinute;
  }

  @override
  Widget build(BuildContext context) {
    // Determine effective time slots for rendering
    List<TimeSlot> effectiveSlots = workingHours.timeSlots;
    bool useFallbackSlots = workingHours.isClosed || workingHours.timeSlots.isEmpty;

    if (useFallbackSlots) {
      if (appointments.isEmpty) {
        return Center(child: Text('คลินิกปิดทำการ', style: TextStyle(color: Colors.grey.shade600, fontSize: 16)));
      }
      // Create a single slot spanning from earliest start to latest end among appointments
      DateTime earliest = appointments.map((a) => a.startTime).reduce((a, b) => a.isBefore(b) ? a : b);
      DateTime latest = appointments.map((a) => a.endTime).reduce((a, b) => a.isAfter(b) ? a : b);
      // Ensure at least 30 minutes window
      if (!latest.isAfter(earliest)) {
        latest = earliest.add(const Duration(minutes: 30));
      }
      effectiveSlots = [
        TimeSlot(
          openTime: TimeOfDay(hour: earliest.hour, minute: earliest.minute),
          closeTime: TimeOfDay(hour: latest.hour, minute: latest.minute),
        )
      ];
    }

    final combinedList = _getCombinedList();

    final List<_TimelineSegment> segments = [];
    int totalDisplayMinutes = 0;
    double totalDividerPixels = 0;
    const double dividerThickness = _segmentDividerThickness;
    const double dividerPaddingFactor = _segmentDividerPaddingFactor;
    final double dividerPadding = dividerThickness * dividerPaddingFactor;
    final double dividerGap = dividerThickness + (dividerPadding * 2);
    void addSegment(DateTime start, DateTime end) {
      if (!end.isAfter(start)) {
        end = start.add(const Duration(minutes: 30));
      }
      if (segments.isNotEmpty && start.isAfter(segments.last.end)) {
        totalDividerPixels += dividerGap;
      }
      segments.add(_TimelineSegment(
        start: start,
        end: end,
        offsetMinutes: totalDisplayMinutes,
        offsetPixels: totalDividerPixels,
      ));
      totalDisplayMinutes += end.difference(start).inMinutes;
    }

    List<List<DateTime>> buildRanges(List<AppointmentModel> appts) {
      if (appts.isEmpty) {
        return [];
      }
      appts.sort((a, b) => a.startTime.compareTo(b.startTime));
      final ranges = <List<DateTime>>[];
      DateTime currentStart = appts.first.startTime;
      DateTime currentEnd = appts.first.endTime;
      for (final appt in appts.skip(1)) {
        if (appt.startTime.isAfter(currentEnd)) {
          ranges.add([currentStart, currentEnd]);
          currentStart = appt.startTime;
          currentEnd = appt.endTime;
        } else if (appt.endTime.isAfter(currentEnd)) {
          currentEnd = appt.endTime;
        }
      }
      ranges.add([currentStart, currentEnd]);
      return ranges;
    }

    if (useFallbackSlots) {
      for (final range in buildRanges(appointments)) {
        addSegment(range[0], range[1]);
      }
    } else if (effectiveSlots.isNotEmpty) {
      final workingStart =
          _combineDateAndTime(selectedDate, effectiveSlots.first.openTime);
      final workingEnd =
          _combineDateAndTime(selectedDate, effectiveSlots.last.closeTime);

      final beforeAppts =
          appointments.where((a) => a.startTime.isBefore(workingStart)).toList();
      for (final range in buildRanges(beforeAppts)) {
        addSegment(range[0], range[1]);
      }
      addSegment(workingStart, workingEnd);
      final afterAppts =
          appointments
              .where((a) =>
                  a.startTime.isAfter(workingEnd) ||
                  a.startTime.isAtSameMomentAs(workingEnd))
              .toList();
      for (final range in buildRanges(afterAppts)) {
        addSegment(range[0], range[1]);
      }
    }

    final pixelsPerMinute = hourHeight / 60.0;
    final totalHeight = max(0.0, totalDisplayMinutes * pixelsPerMinute + totalDividerPixels);
    
    const double topPadding = 14.0; 
    const double bottomPadding = 14.0; 
    final containerHeight = totalHeight + topPadding + bottomPadding;

    return LayoutBuilder(
      builder: (context, constraints) {
        return SingleChildScrollView(
          primary: false,
          physics: const ClampingScrollPhysics(),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4.0),
            child: SizedBox(
              height: containerHeight,
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildTimeline(segments, containerHeight, pixelsPerMinute, topPadding),
                  _buildContentArea(context, combinedList, segments, containerHeight, pixelsPerMinute, topPadding, constraints),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
  
  Widget _buildTimeline(List<_TimelineSegment> segments, double containerHeight, double pixelsPerMinute, double topPadding) {
    List<Widget> children = [];
    const double dividerThickness = _segmentDividerThickness;
    const double dividerPaddingFactor = _segmentDividerPaddingFactor;
    final double dividerPadding = dividerThickness * dividerPaddingFactor;
    for (var i = 1; i < segments.length; i++) {
      final prev = segments[i - 1];
      final current = segments[i];
      if (current.start.isAfter(prev.end)) {
        final endPixels = prev.offsetPixels +
            (prev.offsetMinutes + prev.end.difference(prev.start).inMinutes) *
                pixelsPerMinute;
        children.add(Positioned(
          top: endPixels + dividerPadding + topPadding,
          left: 0,
          right: 0,
          height: dividerThickness,
          child: Container(color: Colors.white),
        ));
      }
    }
    for (final segment in segments) {
      int currentMinute = segment.start.hour * 60 + segment.start.minute;
      final endMinute = segment.end.hour * 60 + segment.end.minute;

      while (currentMinute <= endMinute) {
        if (currentMinute % 60 == 0) {
          final currentTime = DateTime(selectedDate.year, selectedDate.month, selectedDate.day, currentMinute ~/ 60, 0);
          final topPosition = segment.offsetPixels +
              (segment.offsetMinutes + currentTime.difference(segment.start).inMinutes) *
                  pixelsPerMinute;
          children.add(Positioned(
            top: topPosition + topPadding,
            left: 0,
            right: 0,
            child: Container(height: 1, color: Colors.purple.shade50),
          ));
        }
        currentMinute += 30;
      }
    }
    
    for (final segment in segments) {
      int currentMinute = segment.start.hour * 60 + segment.start.minute;
      final endMinute = segment.end.hour * 60 + segment.end.minute;

      while (currentMinute <= endMinute) {
        final currentTime = DateTime(selectedDate.year, selectedDate.month, selectedDate.day, currentMinute ~/ 60, currentMinute % 60);
        final topPosition = segment.offsetPixels +
            (segment.offsetMinutes + currentTime.difference(segment.start).inMinutes) *
                pixelsPerMinute;

        children.add(
          Positioned(
            top: topPosition + topPadding - 7,
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
        currentMinute += 30;
      }
    }

    return SizedBox(
      width: 60.0,
      height: containerHeight,
      child: Stack(children: children),
    );
  }

  Widget _buildContentArea(BuildContext context, List<Map<String, dynamic>> combinedList, List<_TimelineSegment> segments, double containerHeight, double pixelsPerMinute, double topPadding, BoxConstraints constraints) {
    final appointmentLayouts = _calculateAppointmentLayouts(appointments);
    final double contentWidth = constraints.maxWidth - 60.0; 
    
    List<Widget> positionedItems = [];
    const double dividerThickness = _segmentDividerThickness;
    const double dividerPaddingFactor = _segmentDividerPaddingFactor;
    final double dividerPadding = dividerThickness * dividerPaddingFactor;
    for (var i = 1; i < segments.length; i++) {
      final prev = segments[i - 1];
      final current = segments[i];
      if (current.start.isAfter(prev.end)) {
        final endPixels = prev.offsetPixels +
            (prev.offsetMinutes + prev.end.difference(prev.start).inMinutes) *
                pixelsPerMinute;
        positionedItems.add(Positioned(
          top: endPixels + dividerPadding + topPadding,
          left: 0,
          right: 0,
          height: dividerThickness,
          child: Container(color: Colors.white),
        ));
      }
    }
    final patientMap = {for (var p in patients) p.patientId: p};

    for (var item in combinedList) {
      final bool isGap = item['isGap'] == true;
      final DateTime itemStart = isGap ? item['start'] : (item['appointment'] as AppointmentModel).startTime;
      final DateTime itemEnd = isGap ? item['end'] : (item['appointment'] as AppointmentModel).endTime;
      
      final displayStart = _getDisplayPixels(itemStart, segments, pixelsPerMinute);
      final displayEnd = _getDisplayPixels(itemEnd, segments, pixelsPerMinute);
      final top = max(0.0, displayStart) + topPadding;
      final height = max(0.0, displayEnd - displayStart);
      if (height <= 0.1) continue;

      if (isGap) {
        positionedItems.add(Positioned(
          top: top, left: 0, right: 0, height: height, 
          child: GapCard(
            gapStart: itemStart, gapEnd: itemEnd, 
            // 💖✨ START: THE CENTRALIZED LOGIC FIX v2.9 ✨💖
            // ตอนนี้ GapCard จะไม่เปิดหน้าต่างเองแล้วค่ะ
            // แต่จะเรียกใช้ `onGapAddTapped` ที่ได้รับมาจาก calendar_screen แทน
            // เป็นการส่งสัญญาณกลับไปให้ "หัวหน้า" จัดการค่ะ
            onTap: () => onGapAddTapped?.call(itemStart),
            // 💖✨ END: THE CENTRALIZED LOGIC FIX v2.9 ✨💖
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
            onTap: () async {
              final allowSelection =
                  enableChainedSelection && onExistingAppointmentSelected != null;
              final result = await showDialog<Map<String, dynamic>>(
                context: context,
                builder:
                    (_) => AppointmentDetailDialog(
                      appointment: appointmentModel,
                      patient: patientModel,
                      onDataChanged: onDataChanged,
                      enableChainedSelection: allowSelection,
                      chainedPatient: chainedPatient,
                    ),
              );

              if (allowSelection &&
                  result is Map<String, dynamic> &&
                  result['useChainedFlow'] == true) {
                final selectedAppointment =
                    result['appointment'] as AppointmentModel? ??
                        appointmentModel;
                final selectedPatient =
                    result['patient'] as Patient? ?? patientModel;
                await onExistingAppointmentSelected!(
                  selectedAppointment,
                  selectedPatient,
                );
              }
            }, 
            isCompact: layoutInfo.maxOverlaps > 1, 
            isShort: isShortAppointment
          )
        ));
      }
    }
    return Expanded(
      child: SizedBox(
        height: containerHeight,
        child: Stack(children: positionedItems)
      )
    );
  }
}
