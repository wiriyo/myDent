import 'package:flutter/material.dart';

// Data model for a single time slot (e.g., 9:00 - 12:00)
class TimeSlot {
  TimeOfDay openTime;
  TimeOfDay closeTime;

  TimeSlot({required this.openTime, required this.closeTime});

  Map<String, dynamic> toJson() => {
        'openTime': '${openTime.hour.toString().padLeft(2, '0')}:${openTime.minute.toString().padLeft(2, '0')}',
        'closeTime': '${closeTime.hour.toString().padLeft(2, '0')}:${closeTime.minute.toString().padLeft(2, '0')}',
      };

  factory TimeSlot.fromJson(Map<String, dynamic> json) {
    final openTimeParts = (json['openTime'] as String).split(':');
    final closeTimeParts = (json['closeTime'] as String).split(':');
    return TimeSlot(
      openTime: TimeOfDay(hour: int.parse(openTimeParts[0]), minute: int.parse(openTimeParts[1])),
      closeTime: TimeOfDay(hour: int.parse(closeTimeParts[0]), minute: int.parse(closeTimeParts[1])),
    );
  }
}

// Data model for working hours of a single day
class DayWorkingHours {
  final String dayName;
  bool isClosed;
  List<TimeSlot> timeSlots; // Changed to a list of TimeSlot

  DayWorkingHours({
    required this.dayName,
    this.isClosed = false,
    required this.timeSlots,
  });

  // Convert DayWorkingHours object to a JSON-compatible Map
  Map<String, dynamic> toJson() => {
        'dayName': dayName,
        'isClosed': isClosed,
        'timeSlots': timeSlots.map((slot) => slot.toJson()).toList(),
      };

  // Create a DayWorkingHours object from a JSON Map
  factory DayWorkingHours.fromJson(Map<String, dynamic> json) {
    return DayWorkingHours(
      dayName: json['dayName'] as String,
      isClosed: json['isClosed'] as bool,
      timeSlots: (json['timeSlots'] as List<dynamic>)
          .map((slotJson) => TimeSlot.fromJson(slotJson))
          .toList(),
    );
  }
}