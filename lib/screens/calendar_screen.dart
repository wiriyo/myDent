// ----------------------------------------------------------------
// 📁 lib/screens/calendar_screen.dart (v4.1 - 💖 Laila's Count Fix!)
// ----------------------------------------------------------------
// ไลลาปรับปรุงหน้าปฏิทินใหม่ทั้งหมด!
// ตอนนี้เราจะโหลดข้อมูลเฉพาะวันที่เลือกเท่านั้น ทำให้เร็วขึ้นมากค่ะ
// v4.1: นำตัวเลขจำนวนนัดกลับมาแสดงแล้วค่ะ!
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
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
import '../features/printing/render/combined_slip_preview_page.dart';
import '../features/printing/render/receipt_mapper.dart'
    show mapCalendarResultToApptInfo;
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

  // 💖 UPDATED: Store event counts
  Map<DateTime, List<dynamic>> _events = {};
  List<AppointmentModel> _selectedAppointments = [];
  DateTime _focusedDay = DateTime.now();
  late DateTime _selectedDay;
  DayWorkingHours? _selectedDayWorkingHours;
  CalendarFormat _calendarFormat = CalendarFormat.month;
  bool _isLoading = true;
  bool _isInitialLoad = true;
  bool _isClinicClosed = false;
  
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
      
      _loadInitialData();
      _isInitialLoad = false;
    }
  }

  Future<void> _loadInitialData() async {
    await _loadEventMarkersForMonth(_focusedDay);
    await _loadAppointmentsForDay(_selectedDay);
  }

  Future<void> _handleDataChange() {
    _patientCache.clear();
    _workingHoursCache = null;
    return _loadInitialData();
  }

  // 💖 UPDATED: Load event counts for the visible month
  Future<void> _loadEventMarkersForMonth(DateTime month) async {
    if (_appointmentService == null) return;
    if (!mounted) return;

    final startOfMonth = DateTime(month.year, month.month, 1);
    final endOfMonth = DateTime(month.year, month.month + 1, 0);

    try {
      final eventCounts = await _appointmentService!.getDaysWithAppointments(startOfMonth, endOfMonth);
      final Map<DateTime, List<dynamic>> events = {};
      
      eventCounts.forEach((day, count) {
        final dayKey = DateTime.utc(day.year, day.month, day.day);
        events[dayKey] = [count]; // Store the count
      });

      if (!mounted) return;
      setState(() {
        _events = events;
      });
    } catch (e) {
      debugPrint('Error loading event markers: $e');
    }
  }

  Future<void> _loadAppointmentsForDay(DateTime day) async {
    if (_appointmentService == null) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('ไม่พบรหัสคลินิก กรุณาเข้าสู่ระบบใหม่')),
        );
      }
      return;
    }
    if (!mounted) return;
    setState(() { _isLoading = true; });

    try {
      final appointments = await _appointmentService!.getAppointmentsByDate(day);
      
      final patientIds = appointments.map((appt) => appt.patientId).where((id) => id.isNotEmpty).toSet();
      if (patientIds.isNotEmpty) {
        final missingIds = patientIds.where((id) => !_patientCache.containsKey(id)).toList();
        if (missingIds.isNotEmpty) {
          final fetchedPatients = await _patientService.fetchPatientsByIds(missingIds);
          for (final patient in fetchedPatients) {
            _patientCache[patient.patientId] = patient;
          }
        }
      }
      final validPatients = patientIds.map((id) => _patientCache[id]).whereType<Patient>().toList();
      final validPatientIds = validPatients.map((p) => p.patientId).toSet();
      final filteredAppointments = appointments.where((appt) => validPatientIds.contains(appt.patientId)).toList();
      
      filteredAppointments.sort((a, b) => a.startTime.compareTo(b.startTime));

      _workingHoursCache ??= await _workingHoursService.loadWorkingHours();
      final allWorkingHours = _workingHoursCache!;

      DayWorkingHours? dayWorkingHours;
      try {
        dayWorkingHours = allWorkingHours.firstWhere((d) => d.dayName == _getThaiDayName(day.weekday));
      } catch (e) {
        dayWorkingHours = null;
      }

      if (!mounted) return;
      setState(() {
        _selectedAppointments = filteredAppointments;
        _selectedDayWorkingHours = dayWorkingHours;
        _isClinicClosed =
            dayWorkingHours == null ||
            dayWorkingHours.isClosed ||
            dayWorkingHours.timeSlots.isEmpty;
        _isLoading = false;
      });

    } catch (e) {
      debugPrint('Error loading appointments for day: $e');
      if (!mounted) return;
      setState(() {
        _selectedAppointments = [];
        _selectedDayWorkingHours = null;
        _isClinicClosed = true;
        _isLoading = false;
      });
    }
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

  Future<void> _handleExistingAppointmentSelection(
    AppointmentModel appointment,
    Patient patient,
  ) async {
    if (_receiptDraft == null) {
      return;
    }

    if (_chainedPatient == null) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('ไม่พบข้อมูลคนไข้จากการรักษาค่ะ')),
        );
      }
      return;
    }

    if (_chainedPatient!.patientId != patient.patientId) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('นัดหมายนี้เป็นของคนไข้คนละคนกับการรักษาค่ะ')),
        );
      }
      return;
    }

    final apptInfo = mapCalendarResultToApptInfo(appointment);

    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => CombinedSlipPreviewPage(
          receipt: _receiptDraft!,
          nextAppointment: apptInfo,
        ),
      ),
    );

    if (!mounted) return;

    _onAppointmentFlowComplete(clearPatient: true);
  }

  @override
  Widget build(BuildContext context) {
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
                final navigator = Navigator.of(context);
                final prefs = await SharedPreferences.getInstance();
                await prefs.remove('skipLogin');
                if (!mounted) return;
                navigator.pushReplacementNamed('/login');
              },
            ),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
            child: Row(
              children: [
                Expanded(
                  child: ViewModeSelector(
                    calendarFormat: _calendarFormat,
                    onFormatChanged: (format) {
                      if (format == CalendarFormat.week) {
                        final navigator = Navigator.of(context);
                        navigator.push(
                          MaterialPageRoute(
                            builder: (context) => WeeklyViewScreen(
                              focusedDate: _focusedDay,
                              initialPatient: _chainedPatient,
                              receiptDraft: _receiptDraft,
                            ),
                          ),
                        ).then((_) {
                          if (!mounted) return;
                          _handleDataChange();
                        });
                      } else {
                        if (_calendarFormat != format) {
                          setState(() { _calendarFormat = format; });
                        }
                      }
                    },
                    onDailyViewTapped: () async {
                      final navigator = Navigator.of(context);
                      final result = await navigator.push(
                        MaterialPageRoute(builder: (context) => DailyCalendarScreen(
                          selectedDate: _selectedDay,
                          initialPatient: _chainedPatient,
                          receiptDraft: _receiptDraft,
                        )),
                      );

                      if (result is CalendarFormat && result == CalendarFormat.week) {
                        if (!mounted) return;
                        await navigator.push(
                          MaterialPageRoute(
                            builder: (context) => WeeklyViewScreen(
                              focusedDate: _focusedDay,
                              initialPatient: _chainedPatient,
                              receiptDraft: _receiptDraft,
                            ),
                          ),
                        );
                      }
                      if (!mounted) return;
                      _handleDataChange();
                    },
                  ),
                ),
                if (_calendarFormat == CalendarFormat.month) ...[
                  const SizedBox(width: 8),
                  ElevatedButton(
                    onPressed: () {
                      setState(() { _isClinicClosed = !_isClinicClosed; });
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: _isClinicClosed
                          ? Colors.red.shade300
                          : const Color(0xFFE0BBFF),
                      foregroundColor: _isClinicClosed
                          ? Colors.white
                          : Colors.purple.shade900,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                        side: BorderSide(
                          color: _isClinicClosed
                              ? Colors.red.shade500
                              : Colors.purple.shade700,
                          width: 1.5,
                        ),
                      ),
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      elevation: 2,
                    ),
                    child: Text(
                      _isClinicClosed ? 'หยุด' : 'เปิด',
                      style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                    ),
                  ),
                ],
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12.0),
            child: Container(
              padding: const EdgeInsets.all(8.0),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(20),
                boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 10, offset: const Offset(0, 4))],
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
                  // 💖 UPDATED: Marker builder now shows the count!
                  markerBuilder: (context, day, events) {
                    if (events.isNotEmpty) {
                      final bool isWeb = kIsWeb;
                      final double rightInset = 1.0;
                      final double bottomInset = 1.0;
                      final double horizontalShift = isWeb ? -35.0 : 0.0; // responsive for web
                      return Positioned(
                        right: rightInset,
                        bottom: bottomInset,
                        child: Transform.translate(
                          offset: Offset(horizontalShift, 0),
                          child: Container(
                            padding: const EdgeInsets.all(1.0),
                            decoration: const BoxDecoration(shape: BoxShape.circle, color: Color(0xFFF06292)),
                            constraints: const BoxConstraints(minWidth: 16, minHeight: 16),
                            child: Center(
                              child: Text(
                                '${events.first}',
                                textAlign: TextAlign.center,
                                style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold, fontFamily: AppTheme.fontFamily),
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
                  todayDecoration: BoxDecoration(color: AppTheme.primaryLight.withValues(alpha: 0.5), shape: BoxShape.circle),
                  selectedDecoration: const BoxDecoration(color: AppTheme.primary, shape: BoxShape.circle),
                ),
                onDaySelected: (selectedDay, focusedDay) {
                  if (!isSameDay(_selectedDay, selectedDay)) {
                    setState(() {
                      _selectedDay = selectedDay;
                      _focusedDay = focusedDay; // Keep focused day in sync
                    });
                    _loadAppointmentsForDay(selectedDay);
                  }
                },
                onPageChanged: (focusedDay) {
                  _focusedDay = focusedDay;
                  if (!isSameDay(_selectedDay, focusedDay)) {
                     setState(() {
                       _selectedDay = focusedDay;
                     });
                  }
                  _loadEventMarkersForMonth(focusedDay);
                  _loadAppointmentsForDay(focusedDay); // Load data for the first visible day
                },
              ),
            ),
          ),
          const SizedBox(height: 12),
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator(color: AppTheme.primary))
                : TimelineView(
                    selectedDate: _selectedDay,
                    appointments: _selectedAppointments,
                    patients: _selectedAppointments.map((appt) => _patientCache[appt.patientId]).whereType<Patient>().toList(),
                    workingHours: _selectedDayWorkingHours ?? DayWorkingHours(dayName: _getThaiDayName(_selectedDay.weekday), isClosed: true, timeSlots: []),
                    onDataChanged: _handleDataChange,
                    initialPatient: _chainedPatient,
                    onGapAddTapped: (startTime) => _handleAddAppointment(initialStartTime: startTime),
                    enableChainedSelection: _receiptDraft != null && _chainedPatient != null,
                    chainedPatient: _chainedPatient,
                    onExistingAppointmentSelected:
                        (_receiptDraft != null && _chainedPatient != null)
                            ? _handleExistingAppointmentSelection
                            : null,
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
