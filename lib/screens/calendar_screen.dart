// ----------------------------------------------------------------
// 📁 lib/screens/calendar_screen.dart (v3.1 - 💖 Laila's Daily Link Fix!)
// ----------------------------------------------------------------
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:table_calendar/table_calendar.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:intl/intl.dart';
import 'package:flutter/foundation.dart' show kDebugMode;

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
  final AppointmentService _appointmentService = AppointmentService();
  final PatientService _patientService = PatientService();
  final WorkingHoursService _workingHoursService = WorkingHoursService();

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
    return _loadDataForMonth(_focusedDay);
  }

  Future<void> _loadDataForMonth(DateTime month) async {
    if (!mounted) return;
    setState(() { _isLoading = true; });

    final firstDayOfMonth = DateTime(month.year, month.month, 1);
    final lastDayOfMonth = DateTime(month.year, month.month + 1, 0);
    final List<Future> fetchTasks = [];
    final Map<DateTime, List<AppointmentModel>> events = {};

    for (int i = 0; i < lastDayOfMonth.day; i++) {
      final day = firstDayOfMonth.add(Duration(days: i));
      fetchTasks.add(
        _appointmentService.getAppointmentsByDate(day).then((dailyAppointments) {
          if (dailyAppointments.isNotEmpty) {
            final dayKey = DateTime.utc(day.year, day.month, day.day);
            events[dayKey] = dailyAppointments;
          }
        }),
      );
    }

    await Future.wait(fetchTasks);
    if (!mounted) return;
    
    setState(() { _events = events; });
    
    await _populateTimelineForDay(_selectedDay);
  }

  Future<void> _populateTimelineForDay(DateTime day) async {
    final dayKey = DateTime.utc(day.year, day.month, day.day);
    final appointments = _events[dayKey] ?? [];
    
    appointments.sort((a, b) => a.startTime.compareTo(b.startTime));

    final patientIds = appointments.map((appt) => appt.patientId).toSet();
    final List<Patient> patients = [];

    if (patientIds.isNotEmpty) {
      for (String id in patientIds) {
        final patient = await _patientService.getPatientById(id);
        if (patient != null) {
          patients.add(patient);
        }
      }
    }

    DayWorkingHours? dayWorkingHours;
    try {
      final allWorkingHours = await _workingHoursService.loadWorkingHours();
      dayWorkingHours = allWorkingHours.firstWhere((d) => d.dayName == _getThaiDayName(day.weekday));
    } catch (e) {
      dayWorkingHours = null;
    }

    if (!mounted) return;
    setState(() {
      _selectedAppointments = appointments;
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
          if (kDebugMode)
            IconButton(
              icon: const Icon(Icons.bug_report, color: AppTheme.textSecondary),
              tooltip: 'Dev Preview',
              onPressed: () {
                Navigator.pushNamed(context, '/dev/preview');
              },
            ),
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
              // 💖✨ START: DAILY LINK FIX v3.1 ✨💖
              // ตอนนี้เราจะส่ง "กระเป๋าเวทมนตร์" ให้น้อง Daily ด้วยค่ะ
              onDailyViewTapped: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => DailyCalendarScreen(
                    selectedDate: _selectedDay,
                    initialPatient: _chainedPatient,
                    receiptDraft: _receiptDraft,
                  )),
                ).then((_) => _handleDataChange());
              },
              // 💖✨ END: DAILY LINK FIX v3.1 ✨💖
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
                : (_selectedDayWorkingHours == null || _selectedDayWorkingHours!.isClosed)
                    ? Center(child: Text('คลินิกปิดทำการ', style: TextStyle(color: AppTheme.textDisabled, fontSize: 16, fontFamily: AppTheme.fontFamily)))
                    : TimelineView(
                        selectedDate: _selectedDay,
                        appointments: _selectedAppointments,
                        patients: _patientsForAppointments,
                        workingHours: _selectedDayWorkingHours!,
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
