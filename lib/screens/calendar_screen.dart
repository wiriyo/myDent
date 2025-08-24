// ----------------------------------------------------------------
// 📁 lib/screens/calendar_screen.dart (v2.1 - 💖 Laila's Routing Fix!)
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
import 'appointment_add.dart';
import 'daily_calendar_screen.dart';
import 'weekly_calendar_screen.dart';
import '../features/printing/domain/receipt_model.dart' as receipt;
import '../features/printing/domain/appointment_slip_model.dart';
import '../features/printing/render/appointment_slip_preview_page.dart';

class CalendarScreen extends StatefulWidget {
  // These are now optional, as data can come from ModalRoute
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

class _CalendarScreenState extends State<CalendarScreen> {
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
  
  // State variables that will hold the final data
  Patient? _chainedPatient;
  receipt.ReceiptModel? _receiptDraft;

  @override
  void initState() {
    super.initState();
    _selectedDay = _focusedDay;
    // We will now read properties in didChangeDependencies to have access to context
    debugPrint("💖 Laila Debug (Calendar): initState - initial patient from widget: ${widget.initialPatient?.name}");
    debugPrint("💖 Laila Debug (Calendar): initState - initial receipt from widget? ${widget.receiptDraft != null}");
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_isInitialLoad) {
      // 💖✨ THE ROUTING FIX v2.1: Read arguments from ModalRoute
      // This allows the screen to work with both pushNamed and MaterialPageRoute
      final arguments = ModalRoute.of(context)?.settings.arguments;
      
      if (arguments is Map) {
        // This handles the case from the new treatment_form using pushNamed
        _chainedPatient = arguments['initialPatient'] as Patient?;
        _receiptDraft = arguments['receiptDraft'] as receipt.ReceiptModel?;
        debugPrint("💖 Laila Debug (Calendar): Received arguments via ModalRoute!");
      } else {
        // This is a fallback for direct calls using MaterialPageRoute
        _chainedPatient = widget.initialPatient;
        _receiptDraft = widget.receiptDraft;
        debugPrint("💖 Laila Debug (Calendar): No ModalRoute args, using widget properties.");
      }
      
      debugPrint("💖 Laila Debug (Calendar): Final patient for this screen: ${_chainedPatient?.name}");
      debugPrint("💖 Laila Debug (Calendar): Final receipt draft for this screen? ${_receiptDraft != null}");

      _loadDataForMonth(_focusedDay);
      _isInitialLoad = false;
    }
  }

  Future<void> _handleDataChange() {
    debugPrint("📱 [CalendarScreen] Data change detected! Refetching data...");
    return _loadDataForMonth(_focusedDay);
  }

  Future<void> _loadDataForMonth(DateTime month) async {
    if (!mounted) return;
    setState(() {
      _isLoading = true;
    });

    final firstDayOfMonth = DateTime(month.year, month.month, 1);
    final lastDayOfMonth = DateTime(month.year, month.month + 1, 0);
    final List<Future> fetchTasks = [];
    final Map<DateTime, List<AppointmentModel>> events = {};

    for (int i = 0; i < lastDayOfMonth.day; i++) {
      final day = firstDayOfMonth.add(Duration(days: i));
      fetchTasks.add(
        _appointmentService.getAppointmentsByDate(day).then((
          dailyAppointments,
        ) {
          if (dailyAppointments.isNotEmpty) {
            final dayKey = DateTime.utc(day.year, day.month, day.day);
            events[dayKey] = dailyAppointments;
          }
        }),
      );
    }

    await Future.wait(fetchTasks);
    if (!mounted) return;
    
    setState(() {
      _events = events;
    });
    
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
      dayWorkingHours = allWorkingHours.firstWhere(
        (d) => d.dayName == _getThaiDayName(day.weekday),
      );
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

  void _onAddAppointmentPressed() {
    showDialog(
      context: context,
      builder: (_) => AppointmentAddDialog(
        initialDate: _selectedDay,
        initialPatient: _chainedPatient,
      ),
    ).then((result) async { 
      debugPrint("💖 Laila Debug (Calendar): Dialog closed with result: $result");
      
      if (result is Map<String, dynamic>) {
        final newAppointment = result['appointment'] as AppointmentModel;
        final newPatient = result['patient'] as Patient;

        await _handleDataChange();

        if (!mounted) return;

        if (_receiptDraft != null) {
          // --- Flow การรักษา ---
          debugPrint("💖 Laila Debug (Calendar): Refresh complete! Popping with new appointment.");
          Navigator.of(context).pop(newAppointment);
          return; 
        }

        // --- Flow ปกติ (สร้างนัดจากหน้าปฏิทิน) ---
        debugPrint("💖 Laila Debug (Calendar): No receipt draft. Standard flow.");
        final slip = AppointmentSlipModel(
          clinic: const receipt.ClinicInfo(
            name: 'คลินิกทันตกรรม\nหมอกุสุมาภรณ์',
            address: '304 ม.1 ต.หนองพอก\nอ.หนองพอก จ.ร้อยเอ็ด',
            phone: '094-5639334',
          ),
          patient: receipt.PatientInfo(
            name: newPatient.name,
            hn: newPatient.hnNumber ?? '',
          ),
          appointment: AppointmentInfo(
            startAt: newAppointment.startTime,
            note: newAppointment.notes?.trim().isEmpty ?? true
                ? newAppointment.treatment
                : newAppointment.notes,
          ),
        );

        Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) => AppointmentSlipPreviewPage(slip: slip, useSampleData: false),
          ),
        );
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    double timelineHeight = 200;
    if (!_isLoading &&
        _selectedDayWorkingHours != null &&
        !_selectedDayWorkingHours!.isClosed &&
        _selectedDayWorkingHours!.timeSlots.isNotEmpty) {
      final dayStartTime = DateTime(
        _selectedDay.year,
        _selectedDay.month,
        _selectedDay.day,
        _selectedDayWorkingHours!.timeSlots.first.openTime.hour,
        _selectedDayWorkingHours!.timeSlots.first.openTime.minute,
      );
      final dayEndTime = DateTime(
        _selectedDay.year,
        _selectedDay.month,
        _selectedDay.day,
        _selectedDayWorkingHours!.timeSlots.last.closeTime.hour,
        _selectedDayWorkingHours!.timeSlots.last.closeTime.minute,
      );
      const double hourHeight = 120.0;
      final double pixelsPerMinute = hourHeight / 60.0;
      const double verticalPadding = 28.0;

      timelineHeight =
          max(
            0.0,
            dayEndTime.difference(dayStartTime).inMinutes * pixelsPerMinute,
          ) +
          verticalPadding;
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
              icon: const Icon(
                Icons.developer_mode,
                color: AppTheme.textSecondary,
              ),
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
                      builder:
                          (context) =>
                              WeeklyViewScreen(focusedDate: _focusedDay),
                    ),
                  ).then((_) => _handleDataChange());
                } else {
                  if (_calendarFormat != format) {
                    setState(() {
                      _calendarFormat = format;
                    });
                  }
                }
              },
              onDailyViewTapped: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder:
                        (context) =>
                            DailyCalendarScreen(selectedDate: _selectedDay),
                  ),
                ).then((_) => _handleDataChange());
              },
            ),
          ),
          Padding(
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
                  titleTextStyle: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    fontFamily: AppTheme.fontFamily,
                  ),
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
                  markerBuilder: (context, day, events) {
                    if (events.isNotEmpty) {
                      return Positioned(
                        right: 1,
                        bottom: 1,
                        child: Container(
                          padding: const EdgeInsets.all(1.0),
                          decoration: const BoxDecoration(
                            shape: BoxShape.circle,
                            color: Color(0xFFF06292),
                          ),
                          constraints: const BoxConstraints(
                            minWidth: 16,
                            minHeight: 16,
                          ),
                          child: Center(
                            child: Text(
                              '${events.length}',
                              textAlign: TextAlign.center,
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                                fontFamily: AppTheme.fontFamily,
                              ),
                            ),
                          ),
                        ),
                      );
                    }
                    return null;
                  },
                ),
                calendarStyle: CalendarStyle(
                  todayDecoration: BoxDecoration(
                    color: AppTheme.primaryLight.withOpacity(0.5),
                    shape: BoxShape.circle,
                  ),
                  selectedDecoration: const BoxDecoration(
                    color: AppTheme.primary,
                    shape: BoxShape.circle,
                  ),
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
            child:
                _isLoading
                    ? const Center(
                        child: CircularProgressIndicator(color: AppTheme.primary),
                      )
                    : (_selectedDayWorkingHours == null ||
                            _selectedDayWorkingHours!.isClosed)
                        ? Center(
                            child: Text(
                              'คลินิกปิดทำการ',
                              style: TextStyle(
                                color: AppTheme.textDisabled,
                                fontSize: 16,
                                fontFamily: AppTheme.fontFamily,
                              ),
                            ),
                          )
                        : TimelineView(
                            selectedDate: _selectedDay,
                            appointments: _selectedAppointments,
                            patients: _patientsForAppointments,
                            workingHours: _selectedDayWorkingHours!,
                            onDataChanged: _handleDataChange,
                            initialPatient: widget.initialPatient,
                          ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _onAddAppointmentPressed,
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
