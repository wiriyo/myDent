// ----------------------------------------------------------------
// 📁 lib/screens/calendar_screen.dart (v3.3 - 💖 Laila's Dev Preview Removal!)
// ----------------------------------------------------------------
// ไลลาได้นำปุ่ม 'Dev Preview' ที่ใช้สำหรับการดีบักออกไปแล้วนะคะ
// เพื่อให้หน้าจอสะอาดตาและพร้อมสำหรับการใช้งานจริงค่ะ!
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:table_calendar/table_calendar.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:intl/intl.dart';

import '../models/appointment_model.dart';
import '../models/patient.dart';
import '../services/appointment_service.dart';
import '../services/working_hours_service.dart';
import '../services/patient_service.dart';
import '../models/working_hours_model.dart';
import '../widgets/timeline_view.dart';
import '../widgets/view_mode_selector.dart';
import '../widgets/custom_bottom_nav_bar.dart';
import '../styles/app_theme.dart';
import 'daily_calendar_screen.dart';
import 'weekly_calendar_screen.dart';
import '../features/printing/domain/receipt_model.dart' as receipt;
import '../services/appointment_flow_service.dart';
import 'package:provider/provider.dart';
import '../auth/auth_provider.dart';


class CalendarScreen extends StatefulWidget {
  final bool showReset;
  final Patient? initialPatient;
  final receipt.ReceiptModel? receiptDraft;

  const CalendarScreen({
    super.key,
    this.showReset = false,
    this.initialPatient,
    this.receiptDraft,
  });

  @override
  State<CalendarScreen> createState() => _CalendarScreenState();
}

class _CalendarScreenState extends State<CalendarScreen> with WidgetsBindingObserver {
  AppointmentService? _appointmentService;
  final PatientService _patientService = PatientService();
  final WorkingHoursService _workingHoursService = WorkingHoursService();

  final Map<String, Patient> _patientCache = {};
  List<DayWorkingHours>? _workingHoursCache;

  Map<DateTime, List<AppointmentModel>> _events = {};
  List<AppointmentModel> _selectedAppointments = [];
  List<Patient> _patientsForAppointments = [];
  DateTime _focusedDay = DateTime.now();
  late DateTime _selectedDay;
  DayWorkingHours? _selectedDayWorkingHours;
  CalendarFormat _calendarFormat = CalendarFormat.month;
  bool _isLoading = true;
  bool _isInitialLoad = true;
  
  Patient? _chainedPatient;
  receipt.ReceiptModel? _receiptDraft;

  @override
  void initState() {
    super.initState();
    _selectedDay = _focusedDay;
    WidgetsBinding.instance.addObserver(this);
  }
  
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);
    if (state == AppLifecycleState.resumed) {
      if (!_isInitialLoad) {
        _handleDataChange();
      }
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_isInitialLoad) {
      // ✅ เตรียม AppointmentService ด้วย clinicId จาก Provider
      final authProvider = Provider.of<AppAuthProvider>(context, listen: false);
      final clinicId = authProvider.verifiedClinicId;
      if (clinicId != null && clinicId.isNotEmpty) {
        _appointmentService = AppointmentService(clinicId: clinicId);
      }

      final arguments = ModalRoute.of(context)?.settings.arguments;
      
      if (arguments is Map) {
        _chainedPatient = arguments['initialPatient'] as Patient?;
        _receiptDraft = arguments['receiptDraft'] as receipt.ReceiptModel?;
      } else {
        _chainedPatient = widget.initialPatient;
        _receiptDraft = widget.receiptDraft;
      }
      
      _loadDataForMonth(_focusedDay);
      _isInitialLoad = false;
    }
  }

  Future<void> _handleDataChange() {
    _patientCache.clear();
    _workingHoursCache = null;
    return _loadDataForMonth(_focusedDay);
  }

  Future<void> _loadDataForMonth(DateTime month) async {
    if (!mounted) return;
    setState(() { _isLoading = true; });

    if (_appointmentService == null) {
      // หากยังไม่มี clinicId ให้หยุดและแจ้งเตือนสั้นๆ
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('ไม่พบรหัสคลินิก กรุณาเข้าสู่ระบบใหม่')),
        );
      }
      setState(() { _isLoading = false; });
      return;
    }

    final startOfMonth = DateTime(month.year, month.month, 1);
    final endOfMonth = DateTime(month.year, month.month + 1, 1);

    try {
      var appointments =
          await _appointmentService!.getAppointmentsInRange(startOfMonth, endOfMonth);

      final initialCount = appointments.length;
      appointments =
          appointments.where((appt) => appt.patientId.isNotEmpty).toList();
      final removedMissingIds = initialCount - appointments.length;
      if (removedMissingIds > 0) {
        debugPrint(
            'Removed $removedMissingIds appointments without patient references.');
      }

      final patientIds = appointments.map((appt) => appt.patientId).toSet();

      if (patientIds.isNotEmpty) {
        final missingIds =
            patientIds.where((id) => !_patientCache.containsKey(id)).toList();
        if (missingIds.isNotEmpty) {
          final fetchedPatients =
              await _patientService.fetchPatientsByIds(missingIds);
          for (final patient in fetchedPatients) {
            _patientCache[patient.patientId] = patient;
          }
        }
      }

      final orphanedPatientIds = patientIds
          .where((id) => !_patientCache.containsKey(id))
          .toSet();
      if (orphanedPatientIds.isNotEmpty) {
        final beforeFilterCount = appointments.length;
        appointments = appointments
            .where((appt) => !orphanedPatientIds.contains(appt.patientId))
            .toList();
        final removedOrphans = beforeFilterCount - appointments.length;
        if (removedOrphans > 0) {
          debugPrint(
              'Removed $removedOrphans orphaned appointments with missing patients.');
        }
      }

      final Map<DateTime, List<AppointmentModel>> events = {};
      for (final appointment in appointments) {
        final dayKey = DateTime.utc(
          appointment.startTime.year,
          appointment.startTime.month,
          appointment.startTime.day,
        );
        (events[dayKey] ??= []).add(appointment);
      }

      if (!mounted) return;

      setState(() {
        _events = events;
      });

      await _populateTimelineForDay(_selectedDay);
    } catch (e) {
      debugPrint('Error loading monthly appointments: $e');
      if (!mounted) return;
      setState(() {
        _events = {};
        _selectedAppointments = [];
        _patientsForAppointments = [];
        _selectedDayWorkingHours = null;
        _isLoading = false;
      });
    }
  }

  Future<void> _populateTimelineForDay(DateTime day) async {
    final dayKey = DateTime.utc(day.year, day.month, day.day);
    final appointments = List<AppointmentModel>.from(_events[dayKey] ?? []);

    appointments.sort((a, b) => a.startTime.compareTo(b.startTime));

    final patientIds = appointments
        .map((appt) => appt.patientId)
        .where((id) => id.isNotEmpty)
        .toSet();

    if (patientIds.isNotEmpty) {
      final missingIds = patientIds.where((id) => !_patientCache.containsKey(id)).toList();
      if (missingIds.isNotEmpty) {
        final fetchedPatients =
            await _patientService.fetchPatientsByIds(missingIds);
        for (final patient in fetchedPatients) {
          _patientCache[patient.patientId] = patient;
        }
      }
    }

    final patients = patientIds
        .map((id) => _patientCache[id])
        .whereType<Patient>()
        .toList();

    final validPatientIds = patients.map((p) => p.patientId).toSet();
    final filteredAppointments = appointments
        .where((appt) => validPatientIds.contains(appt.patientId))
        .toList();
    final removedCount = appointments.length - filteredAppointments.length;
    if (removedCount > 0) {
      debugPrint(
          'Skipped $removedCount orphaned appointments on ${day.toIso8601String()}');
    }

    List<DayWorkingHours>? allWorkingHours = _workingHoursCache;
    if (allWorkingHours == null) {
      try {
        allWorkingHours = await _workingHoursService.loadWorkingHours();
        _workingHoursCache = allWorkingHours;
      } catch (e) {
        allWorkingHours = null;
      }
    }

    DayWorkingHours? dayWorkingHours;
    if (allWorkingHours != null) {
      try {
        dayWorkingHours = allWorkingHours.firstWhere(
          (d) => d.dayName == _getThaiDayName(day.weekday),
        );
      } catch (e) {
        dayWorkingHours = null;
      }
    }

    if (!mounted) return;
    setState(() {
      if (removedCount > 0) {
        _events = {
          ..._events,
          dayKey: filteredAppointments,
        };
      }
      _selectedAppointments = filteredAppointments;
      _patientsForAppointments = patients;
      _selectedDayWorkingHours = dayWorkingHours;
      _isLoading = false;
    });
  }

  String _getThaiDayName(int weekday) {
    const days = ['จันทร์', 'อังคาร', 'พุธ', 'พฤหัสบดี', 'ศุกร์', 'เสาร์', 'อาทิตย์'];
    return days[weekday - 1];
  }

  void _onAppointmentFlowComplete({bool clearPatient = false}) {
    if (clearPatient && mounted) {
      setState(() {
        _chainedPatient = null;
        _receiptDraft = null;
        debugPrint("💖 Laila Debug (Calendar): Chained patient and receipt draft cleared by Helper!");
      });
    }
    _handleDataChange();
  }

  void _handleAddAppointment({DateTime? initialStartTime}) {
    final flowService = AppointmentFlowService(
      context: context,
      onFlowComplete: _onAppointmentFlowComplete,
    );

    flowService.startAddAppointmentFlow(
      day: _selectedDay,
      initialStartTime: initialStartTime,
      chainedPatient: _chainedPatient,
      receiptDraft: _receiptDraft,
    );
  }

  @override
  Widget build(BuildContext context) {
    double timelineHeight = 200;
    if (!_isLoading &&
        _selectedDayWorkingHours != null &&
        !_selectedDayWorkingHours!.isClosed &&
        _selectedDayWorkingHours!.timeSlots.isNotEmpty) {
      final dayStartTime = DateTime(
        _selectedDay.year, _selectedDay.month, _selectedDay.day,
        _selectedDayWorkingHours!.timeSlots.first.openTime.hour,
        _selectedDayWorkingHours!.timeSlots.first.openTime.minute,
      );
      final dayEndTime = DateTime(
        _selectedDay.year, _selectedDay.month, _selectedDay.day,
        _selectedDayWorkingHours!.timeSlots.last.closeTime.hour,
        _selectedDayWorkingHours!.timeSlots.last.closeTime.minute,
      );
      const double hourHeight = 120.0;
      final double pixelsPerMinute = hourHeight / 60.0;
      const double verticalPadding = 28.0;

      timelineHeight = max(0.0, dayEndTime.difference(dayStartTime).inMinutes * pixelsPerMinute) + verticalPadding;
    } else if (!_isLoading && _selectedAppointments.isNotEmpty) {
      // Fallback height when clinic is closed but there are appointments
      final earliest = _selectedAppointments.map((a) => a.startTime).reduce((a, b) => a.isBefore(b) ? a : b);
      final latest = _selectedAppointments.map((a) => a.endTime).reduce((a, b) => a.isAfter(b) ? a : b);
      const double hourHeight = 120.0;
      final double pixelsPerMinute = hourHeight / 60.0;
      const double verticalPadding = 28.0;
      timelineHeight = max(0.0, latest.difference(earliest).inMinutes * pixelsPerMinute) + verticalPadding;
    }

    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(
        automaticallyImplyLeading: false,
        backgroundColor: AppTheme.primaryLight,
        elevation: 0,
        title: const Text('ปฏิทินนัดหมาย'),
        actions: [
          if (widget.showReset)
            IconButton(
              icon: const Icon(Icons.developer_mode, color: AppTheme.textSecondary),
              tooltip: 'ออกจากโหมดข้ามล็อกอิน',
              onPressed: () async {
                final prefs = await SharedPreferences.getInstance();
                await prefs.remove('skipLogin');
                if (mounted) {
                  Navigator.pushReplacementNamed(context, '/login');
                }
              },
            ),
          // 💖 ไลลาเอาปุ่ม Dev Preview ออกแล้วนะคะ!
        ],
      ),
      body: ListView(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
            child: ViewModeSelector(
              calendarFormat: _calendarFormat,
              onFormatChanged: (format) {
                if (format == CalendarFormat.week) {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => WeeklyViewScreen(
                        focusedDate: _focusedDay,
                        initialPatient: _chainedPatient,
                        receiptDraft: _receiptDraft,
                      ),
                    ),
                  ).then((_) => _handleDataChange());
                } else {
                  if (_calendarFormat != format) {
                    setState(() { _calendarFormat = format; });
                  }
                }
              },
              // 💖✨ START: NAVIGATION FIX v3.2 ✨💖
              // เราจะรอ "คำตอบ" จากหน้าน้อง Daily ค่ะ
              onDailyViewTapped: () async {
                final result = await Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => DailyCalendarScreen(
                    selectedDate: _selectedDay,
                    initialPatient: _chainedPatient,
                    receiptDraft: _receiptDraft,
                  )),
                );

                // ถ้าคำตอบคือ "อยากไปหน้ารายสัปดาห์"
                if (result is CalendarFormat && result == CalendarFormat.week) {
                  if (!mounted) return;
                  // เราก็จะเปิดประตูมิติไปหน้ารายสัปดาห์ให้เลยค่ะ!
                  await Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => WeeklyViewScreen(
                        focusedDate: _focusedDay,
                        initialPatient: _chainedPatient,
                        receiptDraft: _receiptDraft,
                      ),
                    ),
                  );
                }
                // ไม่ว่าจะเกิดอะไรขึ้น เราจะรีเฟรชข้อมูลเสมอค่ะ
                _handleDataChange();
              },
              // 💖✨ END: NAVIGATION FIX v3.2 ✨💖
            ),
          ),
          Padding(
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
                selectedDayPredicate: (day) => isSameDay(_selectedDay, day),
                calendarFormat: _calendarFormat,
                daysOfWeekHeight: 22,
                eventLoader: (day) {
                  final dayKey = DateTime.utc(day.year, day.month, day.day);
                  return _events[dayKey] ?? [];
                },
                headerStyle: const HeaderStyle(
                  formatButtonVisible: false,
                  titleCentered: true,
                  titleTextStyle: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, fontFamily: AppTheme.fontFamily),
                ),
                calendarBuilders: CalendarBuilders(
                  headerTitleBuilder: (context, date) {
                    final year = date.year + 543;
                    final month = DateFormat.MMMM('th_TH').format(date);
                    return Center(child: Text('$month $year', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, fontFamily: AppTheme.fontFamily, color: AppTheme.textPrimary)));
                  },
                  markerBuilder: (context, day, events) {
                    if (events.isNotEmpty) {
                      return Positioned(
                        right: 1,
                        bottom: 1,
                        child: Container(
                          padding: const EdgeInsets.all(1.0),
                          decoration: const BoxDecoration(shape: BoxShape.circle, color: Color(0xFFF06292)),
                          constraints: const BoxConstraints(minWidth: 16, minHeight: 16),
                          child: Center(child: Text('${events.length}', textAlign: TextAlign.center, style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold, fontFamily: AppTheme.fontFamily))),
                        ),
                      );
                    }
                    return null;
                  },
                ),
                calendarStyle: CalendarStyle(
                  todayDecoration: BoxDecoration(color: AppTheme.primaryLight.withOpacity(0.5), shape: BoxShape.circle),
                  selectedDecoration: const BoxDecoration(color: AppTheme.primary, shape: BoxShape.circle),
                ),
                onDaySelected: (selectedDay, focusedDay) {
                  if (!isSameDay(_selectedDay, selectedDay)) {
                    setState(() {
                      _selectedDay = selectedDay;
                      _focusedDay = focusedDay;
                      _isLoading = true;
                    });
                    _populateTimelineForDay(selectedDay);
                  }
                },
                onPageChanged: (focusedDay) {
                  setState(() {
                    _focusedDay = focusedDay;
                    _selectedDay = focusedDay;
                  });
                  _loadDataForMonth(focusedDay);
                },
              ),
            ),
          ),
          const SizedBox(height: 12),
          SizedBox(
            height: timelineHeight,
            child: _isLoading
                ? const Center(child: CircularProgressIndicator(color: AppTheme.primary))
                : TimelineView(
                    selectedDate: _selectedDay,
                    appointments: _selectedAppointments,
                    patients: _patientsForAppointments,
                    workingHours: _selectedDayWorkingHours ?? DayWorkingHours(dayName: _getThaiDayName(_selectedDay.weekday), isClosed: true, timeSlots: []),
                    onDataChanged: _handleDataChange,
                    initialPatient: _chainedPatient,
                    onGapAddTapped: (startTime) => _handleAddAppointment(initialStartTime: startTime),
                  ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _handleAddAppointment(),
        backgroundColor: AppTheme.primary,
        tooltip: 'เพิ่มนัดหมายใหม่',
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
        child: const Icon(Icons.add, color: Colors.white, size: 36),
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerDocked,
      bottomNavigationBar: const CustomBottomNavBar(selectedIndex: 0),
    );
  }
}
