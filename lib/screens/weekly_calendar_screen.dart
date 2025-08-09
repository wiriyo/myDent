// v2.5.0 - ✨ Added Event Counters & Fixed Label Cropping
// 📁 lib/screens/weekly_calendar_screen.dart

import 'dart:math';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:table_calendar/table_calendar.dart';

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
  final AppointmentModel appointment;
  final Patient patient;
  final DateTime startTime;
  final DateTime endTime;
  int maxOverlaps = 1;
  int columnIndex = 0;

  _WeeklyAppointmentLayoutInfo({
    required this.appointment,
    required this.patient,
    required this.startTime,
    required this.endTime,
  });

  bool overlaps(_WeeklyAppointmentLayoutInfo other) {
    return startTime.isBefore(other.endTime) &&
        endTime.isAfter(other.startTime);
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

  Map<
    DateTime,
    ({
      List<AppointmentModel> appointments,
      List<Patient> patients,
      DayWorkingHours? workingHours,
    })
  >
  _weeklyData = {};

  final ScrollController _headerScrollController = ScrollController();
  final ScrollController _bodyScrollController = ScrollController();
  final ScrollController _timeAxisScrollController = ScrollController();
  final ScrollController _contentVerticalScrollController = ScrollController();

  final double _hourHeight = 120.0;
  final double _dayColumnWidth = 200.0;
  final double _timeAxisWidth = 60.0;

  int _dynamicStartHour = 9;
  int _dynamicEndHour = 17;

  @override
  void initState() {
    super.initState();
    _focusedDay = widget.focusedDate;
    _selectedDay = widget.focusedDate;

    _headerScrollController.addListener(() {
      if (_headerScrollController.hasClients &&
          _bodyScrollController.hasClients &&
          _headerScrollController.offset != _bodyScrollController.offset) {
        _bodyScrollController.jumpTo(_headerScrollController.offset);
      }
    });
    _bodyScrollController.addListener(() {
      if (_headerScrollController.hasClients &&
          _bodyScrollController.hasClients &&
          _headerScrollController.offset != _bodyScrollController.offset) {
        _headerScrollController.jumpTo(_bodyScrollController.offset);
      }
    });
    _timeAxisScrollController.addListener(() {
      if (_timeAxisScrollController.hasClients &&
          _contentVerticalScrollController.hasClients &&
          _timeAxisScrollController.offset !=
              _contentVerticalScrollController.offset) {
        _contentVerticalScrollController.jumpTo(
          _timeAxisScrollController.offset,
        );
      }
    });
    _contentVerticalScrollController.addListener(() {
      if (_contentVerticalScrollController.hasClients &&
          _timeAxisScrollController.hasClients &&
          _contentVerticalScrollController.offset !=
              _timeAxisScrollController.offset) {
        _timeAxisScrollController.jumpTo(
          _contentVerticalScrollController.offset,
        );
      }
    });

    _fetchDataForWeek(_focusedDay);
  }

  @override
  void didUpdateWidget(WeeklyViewScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!isSameDay(widget.focusedDate, oldWidget.focusedDate)) {
      _focusedDay = widget.focusedDate;
      _selectedDay = widget.focusedDate;
      _fetchDataForWeek(_focusedDay);
    }
  }

  @override
  void dispose() {
    _headerScrollController.dispose();
    _bodyScrollController.dispose();
    _timeAxisScrollController.dispose();
    _contentVerticalScrollController.dispose();
    super.dispose();
  }

  void _handleDataChange() {
    debugPrint(
      "📱 [WeeklyViewScreen] Data change detected! Refetching data...",
    );
    _fetchDataForWeek(_focusedDay);
  }

  void _calculateAndSetWeekHourRange() {
    if (_weeklyData.isEmpty) {
      setState(() {
        _dynamicStartHour = 9;
        _dynamicEndHour = 17;
      });
      return;
    }

    int minHour = 24;
    int maxHour = 0;
    bool hasData = false;

    for (var dayData in _weeklyData.values) {
      if (dayData.workingHours != null &&
          !dayData.workingHours!.isClosed &&
          dayData.workingHours!.timeSlots.isNotEmpty) {
        hasData = true;
        for (var slot in dayData.workingHours!.timeSlots) {
          minHour = min(minHour, slot.openTime.hour);
          maxHour = max(
            maxHour,
            slot.closeTime.hour + (slot.closeTime.minute > 0 ? 1 : 0),
          );
        }
      }
      if (dayData.appointments.isNotEmpty) {
        hasData = true;
        for (var appt in dayData.appointments) {
          minHour = min(minHour, appt.startTime.hour);
          maxHour = max(
            maxHour,
            appt.endTime.hour + (appt.endTime.minute > 0 ? 1 : 0),
          );
        }
      }
    }

    if (!hasData) {
      minHour = 9;
      maxHour = 17;
    } else {
      minHour = max(0, minHour - 1);
      maxHour = min(24, maxHour + 1);
    }

    if (maxHour - minHour < 8) {
      maxHour = min(24, minHour + 8);
    }

    if (_dynamicStartHour != minHour || _dynamicEndHour != maxHour) {
      setState(() {
        _dynamicStartHour = minHour;
        _dynamicEndHour = maxHour;
      });
    }
  }

  Future<void> _fetchDataForWeek(DateTime focusedDay) async {
    setState(() {
      _isLoading = true;
    });

    DateTime firstDayOfWeek = focusedDay.subtract(
      Duration(days: focusedDay.weekday - 1),
    );
    Map<
      DateTime,
      ({
        List<AppointmentModel> appointments,
        List<Patient> patients,
        DayWorkingHours? workingHours,
      })
    >
    weeklyData = {};

    final allWorkingHours = await _workingHoursService.loadWorkingHours();

    final List<Future> fetchTasks = [];

    for (int i = 0; i < 7; i++) {
      DateTime currentDay = firstDayOfWeek.add(Duration(days: i));
      DateTime dayKey = DateTime(
        currentDay.year,
        currentDay.month,
        currentDay.day,
      );

      fetchTasks.add(
        _appointmentService.getAppointmentsByDate(currentDay).then((
          dailyAppointments,
        ) async {
          final patientIds = dailyAppointments.map((a) => a.patientId).toSet();

          final List<Patient> dailyPatients = [];
          if (patientIds.isNotEmpty) {
            for (final id in patientIds) {
              final patient = await _patientService.getPatientById(id);
              if (patient != null) {
                dailyPatients.add(patient);
              }
            }
          }

          DayWorkingHours? dayWorkingHours;
          try {
            dayWorkingHours = allWorkingHours.firstWhere(
              (day) => day.dayName == _getThaiDayName(currentDay.weekday),
            );
          } catch (e) {
            dayWorkingHours = null;
          }

          weeklyData[dayKey] = (
            appointments: dailyAppointments,
            patients: dailyPatients,
            workingHours: dayWorkingHours,
          );
        }),
      );
    }

    await Future.wait(fetchTasks);

    if (!mounted) return;
    setState(() {
      _weeklyData = weeklyData;
      _isLoading = false;
    });

    _calculateAndSetWeekHourRange();
  }

  String _getThaiDayName(int weekday) {
    const days = [
      'จันทร์',
      'อังคาร',
      'พุธ',
      'พฤหัสบดี',
      'ศุกร์',
      'เสาร์',
      'อาทิตย์',
    ];
    return days[weekday - 1];
  }

  List<_WeeklyAppointmentLayoutInfo> _calculateAppointmentLayouts(
    List<AppointmentModel> appointments,
    List<Patient> patients,
  ) {
    if (appointments.isEmpty) return [];
    final patientMap = {for (var p in patients) p.patientId: p};

    var events =
        appointments.map((appt) {
          final patient =
              patientMap[appt.patientId] ??
              Patient(patientId: 'unknown', name: 'Unknown', prefix: '');
          return _WeeklyAppointmentLayoutInfo(
            appointment: appt,
            patient: patient,
            startTime: appt.startTime,
            endTime: appt.endTime,
          );
        }).toList();

    events.sort((a, b) => a.startTime.compareTo(b.startTime));
    for (var event in events) {
      event.columnIndex = 0;
      event.maxOverlaps = 1;
    }
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
    return events;
  }

  List<Map<String, dynamic>> _getCombinedListForDay(
    List<AppointmentModel> appointments,
    DayWorkingHours workingHours,
    DateTime selectedDate,
  ) {
    appointments.sort((a, b) => a.startTime.compareTo(b.startTime));

    List<Map<String, dynamic>> finalCombinedList = [];

    for (final slot in workingHours.timeSlots) {
      DateTime lastEventEnd = DateTime(
        selectedDate.year,
        selectedDate.month,
        selectedDate.day,
        slot.openTime.hour,
        slot.openTime.minute,
      );
      final slotCloseTime = DateTime(
        selectedDate.year,
        selectedDate.month,
        selectedDate.day,
        slot.closeTime.hour,
        slot.closeTime.minute,
      );

      final appointmentsInSlot =
          appointments.where((appt) {
            return appt.startTime.isAfter(
                  lastEventEnd.subtract(const Duration(minutes: 1)),
                ) &&
                appt.startTime.isBefore(slotCloseTime);
          }).toList();

      for (var appt in appointmentsInSlot) {
        if (appt.startTime.isAfter(lastEventEnd)) {
          finalCombinedList.add({
            'isGap': true,
            'start': lastEventEnd,
            'end': appt.startTime,
          });
        }
        finalCombinedList.add({'isGap': false, 'appointment': appt});
        if (appt.endTime.isAfter(lastEventEnd)) {
          lastEventEnd = appt.endTime;
        }
      }

      if (slotCloseTime.isAfter(lastEventEnd)) {
        finalCombinedList.add({
          'isGap': true,
          'start': lastEventEnd,
          'end': slotCloseTime,
        });
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
      body:
          _isLoading
              ? const Center(
                child: CircularProgressIndicator(color: AppTheme.primary),
              )
              : SingleChildScrollView(
                child: Column(
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
                              builder:
                                  (context) => DailyCalendarScreen(
                                    selectedDate:
                                        _selectedDay ?? DateTime.now(),
                                  ),
                            ),
                          ).then((_) => _handleDataChange());
                        },
                      ),
                    ),
                    _buildCalendar(),
                    const SizedBox(height: 12),
                    _buildWeekDayHeader(),
                    SizedBox(
                      height:
                          _hourHeight * (_dynamicEndHour - _dynamicStartHour),
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
                                    final firstDayOfWeek = _focusedDay.subtract(
                                      Duration(days: _focusedDay.weekday - 1),
                                    );
                                    final day = firstDayOfWeek.add(
                                      Duration(days: index),
                                    );
                                    final dayKey = DateTime(
                                      day.year,
                                      day.month,
                                      day.day,
                                    );
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
              ),
      floatingActionButton: FloatingActionButton(
        onPressed:
            () => showDialog(
              context: context,
              builder:
                  (_) => AppointmentAddDialog(
                    initialDate: _selectedDay ?? DateTime.now(),
                  ),
            ).then((value) {
              if (value == true) {
                _handleDataChange();
              }
            }),
        backgroundColor: AppTheme.primary,
        tooltip: 'เพิ่มนัดหมายใหม่',
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
        child: const Icon(Icons.add, color: Colors.white, size: 36),
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerDocked,
      bottomNavigationBar: const CustomBottomNavBar(selectedIndex: 0),
    );
  }

  Widget _buildCalendar() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12.0),
      child: Container(
        padding: const EdgeInsets.all(8.0),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.05),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: TableCalendar(
          locale: 'th_TH',
          firstDay: DateTime.utc(2020, 1, 1),
          lastDay: DateTime.utc(2030, 12, 31),
          focusedDay: _focusedDay,
          calendarFormat: CalendarFormat.week,
          availableCalendarFormats: const {CalendarFormat.week: 'Week'},
          selectedDayPredicate: (day) => isSameDay(_selectedDay, day),
          daysOfWeekHeight: 22.0,
          headerStyle: const HeaderStyle(
            titleCentered: true,
            titleTextStyle: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              fontFamily: AppTheme.fontFamily,
              
            ),
            formatButtonVisible: false,
            
          ),
          calendarBuilders: CalendarBuilders(
            headerTitleBuilder: (context, date) {
              final year = date.year + 543;
              final month = DateFormat.MMMM('th_TH').format(date);
              return Center(
                child: Text(
                  '$month $year',
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    fontFamily: AppTheme.fontFamily,
                    color: AppTheme.textPrimary,
                  ),
                ),
              );
            },
            dowBuilder: (context, day) {
              final text = DateFormat.E('th_TH').format(day);
              return Center(
                child: Text(
                  text,
                  style: const TextStyle(
                    fontSize: 14, // เพิ่มขนาดตัวอักษร
                    fontWeight: FontWeight.bold,
                    color: AppTheme.textSecondary,
                  ),
                ),
              );
            },
          ),
          calendarStyle: CalendarStyle(
            todayDecoration: BoxDecoration(
              color: AppTheme.primaryLight.withOpacity(0.5),
              shape: BoxShape.circle,
            ),
            selectedDecoration: BoxDecoration(
              color: AppTheme.primary,
              shape: BoxShape.circle,
            ),
            defaultTextStyle: const TextStyle(
              fontSize: 14, // เพิ่มขนาดตัวอักษร
              color: AppTheme.textPrimary,
            ),
            weekendTextStyle: const TextStyle(
              fontSize: 14, // เพิ่มขนาดตัวอักษร
              color: AppTheme.textSecondary,
            ),
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

  // 💖 [UPDATE v2.5.0] ไลลาอัปเดต Widget นี้ให้แสดงป้ายนับนัดหมายและแก้ปัญหาตัวอักษรโดนตัดค่ะ
  Widget _buildWeekDayHeader() {
    final firstDayOfWeek = _focusedDay.subtract(
      Duration(days: _focusedDay.weekday - 1),
    );
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
            final dayKey = DateTime(day.year, day.month, day.day);
            final eventCount = _weeklyData[dayKey]?.appointments.length ?? 0;
            final isToday = isSameDay(day, DateTime.now());

            return Container(
              width: _dayColumnWidth,
              // ✨ [CROP-FIX] เพิ่ม Padding ด้านล่างเพื่อให้ตัวอักษรมีพื้นที่หายใจค่ะ
              padding: const EdgeInsets.fromLTRB(8.0, 8.0, 8.0, 8.0),
              decoration: BoxDecoration(
                color:
                    isToday
                        ? AppTheme.primaryLight.withOpacity(0.3)
                        : Colors.transparent,
                border: Border(
                  right: BorderSide(color: Colors.grey.shade200),
                  bottom: BorderSide(color: Colors.grey.shade300, width: 2),
                ),
              ),
              // ✨ [EVENT-COUNT] ใช้ Stack เพื่อวางป้ายตัวเลขไว้บนหัวข้อวันค่ะ
              child: Stack(
                clipBehavior: Clip.none,
                alignment: Alignment.center,
                children: [
                  Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        dayFormatter.format(day),
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color:
                              isToday ? AppTheme.primary : AppTheme.textPrimary,
                        ),
                      ),
                      Text(
                        dateFormatter.format(day),
                        style: TextStyle(
                          color:
                              isToday
                                  ? AppTheme.primary
                                  : AppTheme.textSecondary,
                        ),
                      ),
                    ],
                  ),
                  if (eventCount > 0)
                    Positioned(
                      top: -6,
                      right: 8,
                      child: Container(
                        padding: const EdgeInsets.all(2),
                        decoration: const BoxDecoration(
                          shape: BoxShape.circle,
                          color: Color(0xFFF06292),
                        ),
                        constraints: const BoxConstraints(
                          minWidth: 18,
                          minHeight: 18,
                        ),
                        child: Center(
                          child: Text(
                            '$eventCount',
                            textAlign: TextAlign.center,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ),
                    ),
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
        itemCount: _dynamicEndHour - _dynamicStartHour,
        itemBuilder: (context, index) {
          final hour = _dynamicStartHour + index;
          return Container(
            height: _hourHeight,
            decoration: BoxDecoration(
              border: Border(bottom: BorderSide(color: Colors.grey.shade200)),
            ),
            child: Align(
              alignment: Alignment.topCenter,
              child: Padding(
                padding: const EdgeInsets.only(top: 4.0),
                child: Text(
                  '${hour.toString().padLeft(2, '0')}:00',
                  style: const TextStyle(
                    color: AppTheme.textSecondary,
                    fontSize: 12,
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildDayColumn(
    DateTime day,
    ({
      List<AppointmentModel> appointments,
      List<Patient> patients,
      DayWorkingHours? workingHours,
    })?
    dayData,
  ) {
    final pixelsPerMinute = _hourHeight / 60.0;
    final dayStartTime = DateTime(
      day.year,
      day.month,
      day.day,
      _dynamicStartHour,
    );

    final appointments = dayData?.appointments ?? [];
    final patients = dayData?.patients ?? [];
    final workingHours = dayData?.workingHours;

    if (workingHours == null || workingHours.isClosed) {
      return Container(
        width: _dayColumnWidth,
        height: _hourHeight * (_dynamicEndHour - _dynamicStartHour),
        decoration: BoxDecoration(
          color: Colors.grey.shade50,
          border: Border(right: BorderSide(color: Colors.grey.shade200)),
        ),
        child: Center(
          child: Text(
            'ปิดทำการ',
            style: TextStyle(color: AppTheme.textDisabled),
          ),
        ),
      );
    }

    final combinedList = _getCombinedListForDay(
      appointments,
      workingHours,
      day,
    );
    final appointmentLayouts = _calculateAppointmentLayouts(
      appointments,
      patients,
    );
    final patientMap = {for (var p in patients) p.patientId: p};

    return Container(
      width: _dayColumnWidth,
      height: _hourHeight * (_dynamicEndHour - _dynamicStartHour),
      decoration: BoxDecoration(
        border: Border(right: BorderSide(color: Colors.grey.shade200)),
      ),
      child: Stack(
        children: [
          ...List.generate(
            _dynamicEndHour - _dynamicStartHour,
            (i) => Positioned(
              top: i * _hourHeight,
              left: 0,
              right: 0,
              child: Container(height: 1, color: Colors.grey.shade200),
            ),
          ),
          ...combinedList.map((item) {
            final bool isGap = item['isGap'] == true;
            final DateTime itemStart =
                isGap
                    ? item['start']
                    : (item['appointment'] as AppointmentModel).startTime;
            final DateTime itemEnd =
                isGap
                    ? item['end']
                    : (item['appointment'] as AppointmentModel).endTime;

            final top = max(
              0.0,
              itemStart.difference(dayStartTime).inMinutes * pixelsPerMinute,
            );
            final height = max(
              0.0,
              itemEnd.difference(itemStart).inMinutes * pixelsPerMinute,
            );

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
                  onTap:
                      () => showDialog(
                        context: context,
                        builder:
                            (_) => AppointmentAddDialog(
                              initialDate: day,
                              initialStartTime: itemStart,
                            ),
                      ).then((value) {
                        if (value == true) {
                          _handleDataChange();
                        }
                      }),
                ),
              );
            } else {
              final appointmentModel = item['appointment'] as AppointmentModel;
              final patientModel = patientMap[appointmentModel.patientId];
              if (patientModel == null) return const SizedBox.shrink();

              final layoutInfo = appointmentLayouts.firstWhere(
                (l) =>
                    l.appointment.appointmentId ==
                    appointmentModel.appointmentId,
              );
              final cardWidth = (_dayColumnWidth / layoutInfo.maxOverlaps) - 4;
              final left = layoutInfo.columnIndex * (cardWidth + 4);

              return Positioned(
                top: top,
                left: left,
                width: cardWidth,
                height: height,
                child: AppointmentCard(
                  appointment: appointmentModel,
                  patient: patientModel,
                  isCompact: layoutInfo.maxOverlaps > 1,
                  isShort: height < 60,
                  onTap:
                      () => showDialog(
                        context: context,
                        builder:
                            (_) => AppointmentDetailDialog(
                              appointment: appointmentModel,
                              patient: patientModel,
                              onDataChanged: _handleDataChange,
                            ),
                      ),
                ),
              );
            }
          }),
        ],
      ),
    );
  }
}
