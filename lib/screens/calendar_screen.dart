// ----------------------------------------------------------------
// 📁 lib/screens/calendar_screen.dart (v4.1 - 💖 Laila's Count Fix!)
// ----------------------------------------------------------------
// ไลลาปรับปรุงหน้าปฏิทินใหม่ทั้งหมด!
// ตอนนี้เราจะโหลดข้อมูลเฉพาะวันที่เลือกเท่านั้น ทำให้เร็วขึ้นมากค่ะ
// v4.1: นำตัวเลขจำนวนนัดกลับมาแสดงแล้วค่ะ!
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
import '../services/daily_override_service.dart';
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
  final DailyOverrideService _dailyOverrideService = DailyOverrideService();

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
  final Map<DateTime, DayWorkingHours> _dailyOverrides = {};
  bool _overridesLoaded = false;
  String? _clinicId;
  
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
        _clinicId = clinicId;
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
    await _ensureOverridesLoaded();
    await _loadEventMarkersForMonth(_focusedDay);
    await _loadAppointmentsForDay(_selectedDay);
  }

  Future<void> _handleDataChange() async {
    _patientCache.clear();
    _workingHoursCache = null;
    _overridesLoaded = false;
    await _loadInitialData();
  }

  Future<void> _ensureOverridesLoaded() async {
    if (_overridesLoaded) return;
    final overrides =
        await _dailyOverrideService.loadOverrides(clinicId: _clinicId);
    if (!mounted) return;
    setState(() {
      _dailyOverrides
        ..clear()
        ..addAll(overrides);
      _overridesLoaded = true;
    });
  }

  Future<void> _persistDailyOverride(
    DateTime day,
    DayWorkingHours override,
  ) {
    return _dailyOverrideService.saveOverride(
      day,
      override,
      clinicId: _clinicId,
    );
  }

  Future<void> _clearDailyOverride(DateTime day) {
    return _dailyOverrideService.removeOverride(day, clinicId: _clinicId);
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
      final baseWorkingHours = dayWorkingHours;
      final dayKey = _dayKey(day);
      final override = _dailyOverrides[dayKey];
      final hasOverride = override != null;
      if (override != null) {
        dayWorkingHours = override;
      }
      final updatedAppointments = _applyClosedOverlay(
        filteredAppointments,
        day,
        baseWorkingHours,
        override,
      );

      if (!mounted) return;
      setState(() {
        _selectedAppointments = updatedAppointments;
        _selectedDayWorkingHours = dayWorkingHours;
        _isClinicClosed =
            dayWorkingHours == null ||
            dayWorkingHours.isClosed ||
            (!hasOverride && dayWorkingHours.timeSlots.isEmpty);
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
    const days = [
      '\u0e08\u0e31\u0e19\u0e17\u0e23\u0e4c',
      '\u0e2d\u0e31\u0e07\u0e04\u0e32\u0e23',
      '\u0e1e\u0e38\u0e18',
      '\u0e1e\u0e24\u0e2b\u0e31\u0e2a\u0e1a\u0e14\u0e35',
      '\u0e28\u0e38\u0e01\u0e23\u0e4c',
      '\u0e40\u0e2a\u0e32\u0e23\u0e4c',
      '\u0e2d\u0e32\u0e17\u0e34\u0e15\u0e22\u0e4c',
    ];
    return days[weekday - 1];
  }


  DateTime _dayKey(DateTime day) => DateTime(day.year, day.month, day.day);

  List<AppointmentModel> _applyClosedOverlay(
    List<AppointmentModel> appointments,
    DateTime day,
    DayWorkingHours? baseWorkingHours,
    DayWorkingHours? override,
  ) {
    if (override == null || !override.isClosed) {
      return appointments;
    }
    if (baseWorkingHours == null || baseWorkingHours.timeSlots.isEmpty) {
      return appointments;
    }
    final closedAppointments = <AppointmentModel>[];
    for (int i = 0; i < baseWorkingHours.timeSlots.length; i++) {
      final slot = baseWorkingHours.timeSlots[i];
      final start = DateTime(day.year, day.month, day.day, slot.openTime.hour, slot.openTime.minute);
      final end = DateTime(day.year, day.month, day.day, slot.closeTime.hour, slot.closeTime.minute);
      if (!end.isAfter(start)) {
        continue;
      }
      final id = '__clinic_closed_${_dayKey(day).toIso8601String()}_$i';
      closedAppointments.add(
        AppointmentModel(
          appointmentId: id,
          userId: '',
          patientId: id,
          patientName: '\u0e1b\u0e34\u0e14\u0e17\u0e33\u0e01\u0e32\u0e23',
          treatment: '\u0e1b\u0e34\u0e14',
          duration: end.difference(start).inMinutes,
          status: '\u0e1b\u0e34\u0e14\u0e17\u0e33\u0e01\u0e32\u0e23',
          startTime: start,
          endTime: end,
        ),
      );
      _patientCache[id] = Patient(
        patientId: id,
        name: '\u0e1b\u0e34\u0e14\u0e17\u0e33\u0e01\u0e32\u0e23',
        prefix: '',
        rating: 0.0,
        gender: '',
      );
    }
    final combined = [...appointments, ...closedAppointments];
    combined.sort((a, b) => a.startTime.compareTo(b.startTime));
    return combined;
  }

  DayWorkingHours _cloneDayWorkingHours(DayWorkingHours? source, String dayName) {
    if (source == null) {
      return DayWorkingHours(dayName: dayName, isClosed: true, timeSlots: []);
    }
    return DayWorkingHours(
      dayName: dayName,
      isClosed: source.isClosed,
      timeSlots: source.timeSlots
          .map((slot) => TimeSlot(openTime: slot.openTime, closeTime: slot.closeTime))
          .toList(),
    );
  }

  void _toggleClinicOpenClosed() {
    final key = _dayKey(_selectedDay);
    final dayName = _getThaiDayName(_selectedDay.weekday);
    if (_isClinicClosed) {
      DayWorkingHours? baseWorkingHours;
      if (_workingHoursCache != null) {
        try {
          baseWorkingHours = _workingHoursCache!
              .firstWhere((d) => d.dayName == dayName);
        } catch (_) {
          baseWorkingHours = null;
        }
      }
      final bool baseClosed =
          baseWorkingHours == null ||
          baseWorkingHours.isClosed ||
          baseWorkingHours.timeSlots.isEmpty;
      if (baseClosed) {
        final override = _cloneDayWorkingHours(baseWorkingHours, dayName);
        override.isClosed = false;
        _dailyOverrides[key] = override;
        _persistDailyOverride(_selectedDay, override);
        setState(() {
          _selectedDayWorkingHours = override;
          _isClinicClosed = false;
        });
        _loadAppointmentsForDay(_selectedDay);
        _showDailyWorkingHoursDialog(override);
      } else {
        _dailyOverrides.remove(key);
        _clearDailyOverride(_selectedDay);
        setState(() {
          _selectedDayWorkingHours = baseWorkingHours;
          _isClinicClosed = false;
        });
        _loadAppointmentsForDay(_selectedDay);
        _showDailyWorkingHoursDialog(
          _cloneDayWorkingHours(baseWorkingHours, dayName),
        );
      }
    } else {
      final override = _dailyOverrides[key] ??
          DayWorkingHours(dayName: dayName, isClosed: true, timeSlots: []);
      override.isClosed = true;
      _dailyOverrides[key] = override;
      _persistDailyOverride(_selectedDay, override);
      setState(() {
        _isClinicClosed = true;
        _selectedDayWorkingHours = override;
      });
      _loadAppointmentsForDay(_selectedDay);
    }
  }

  int _timeToMinutes(TimeOfDay time) => time.hour * 60 + time.minute;

  bool _hasOverlap(List<TimeSlot> slots, TimeSlot newSlot, [int? excludeIndex]) {
    final newOpenMinutes = _timeToMinutes(newSlot.openTime);
    final newCloseMinutes = _timeToMinutes(newSlot.closeTime);
    for (int i = 0; i < slots.length; i++) {
      if (excludeIndex != null && i == excludeIndex) {
        continue;
      }
      final existingSlot = slots[i];
      final existingOpenMinutes = _timeToMinutes(existingSlot.openTime);
      final existingCloseMinutes = _timeToMinutes(existingSlot.closeTime);
      if (newOpenMinutes < existingCloseMinutes && newCloseMinutes > existingOpenMinutes) {
        return true;
      }
    }
    return false;
  }

  Future<void> _pickTime(
    BuildContext context,
    DayWorkingHours day,
    TimeSlot slot,
    bool isOpeningTime,
    int slotIndex, {
    VoidCallback? onChanged,
  }
  ) async {
    final initialTime = isOpeningTime ? slot.openTime : slot.closeTime;
    final TimeOfDay? picked = await showTimePicker(
      context: context,
      initialTime: initialTime,
      builder: (BuildContext context, Widget? child) {
        return MediaQuery(
          data: MediaQuery.of(context).copyWith(alwaysUse24HourFormat: false),
          child: child!,
        );
      },
    );

    if (!context.mounted) return;
    if (picked != null && mounted) {
      final tempSlot = TimeSlot(
        openTime: isOpeningTime ? picked : slot.openTime,
        closeTime: isOpeningTime ? slot.closeTime : picked,
      );
      if (_timeToMinutes(tempSlot.openTime) >= _timeToMinutes(tempSlot.closeTime)) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('\u0e0a\u0e48\u0e27\u0e07\u0e40\u0e27\u0e25\u0e32\u0e44\u0e21\u0e48\u0e16\u0e39\u0e01\u0e15\u0e49\u0e2d\u0e07'),
          ),
        );
        return;
      }
      if (_hasOverlap(day.timeSlots, tempSlot, slotIndex)) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('\u0e0a\u0e48\u0e27\u0e07\u0e40\u0e27\u0e25\u0e32\u0e17\u0e33\u0e01\u0e32\u0e23\u0e17\u0e31\u0e1a\u0e0b\u0e49\u0e2d\u0e19\u0e01\u0e31\u0e19'),
          ),
        );
        return;
      }
      setState(() {
        if (isOpeningTime) {
          slot.openTime = picked;
        } else {
          slot.closeTime = picked;
        }
        day.timeSlots.sort((a, b) => _timeToMinutes(a.openTime) - _timeToMinutes(b.openTime));
        _dailyOverrides[_dayKey(_selectedDay)] = day;
      });
      _persistDailyOverride(_selectedDay, day);
      onChanged?.call();
    }
  }

  Widget _buildTimePickerButton(
    BuildContext context,
    String label,
    TimeOfDay time,
    VoidCallback onPressed,
  ) {
    return ElevatedButton(
      onPressed: onPressed,
      style: ElevatedButton.styleFrom(
        backgroundColor: Colors.white,
        foregroundColor: Colors.black87,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
          side: BorderSide(color: Colors.grey.shade300, width: 1),
        ),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
        elevation: 0,
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(fontSize: 14, color: Colors.grey)),
          Text(time.format(context), style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
          const Icon(Icons.access_time, size: 18, color: Colors.grey),
        ],
      ),
    );
  }

  Future<void> _showDailyWorkingHoursDialog(DayWorkingHours day) async {
    if (!mounted) return;
    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, dialogSetState) {
            void refreshDialog() {
              dialogSetState(() {});
            }

            return Dialog(
              insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              child: SingleChildScrollView(
                child: _buildDailyWorkingHoursCard(
                  day,
                  onChanged: refreshDialog,
                  onConfirm: () {
                    Navigator.of(context).pop();
                    _loadAppointmentsForDay(_selectedDay);
                  },
                ),
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildDailyWorkingHoursCard(
    DayWorkingHours day, {
    VoidCallback? onConfirm,
    VoidCallback? onChanged,
  }) {
    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      color: Colors.white,
      elevation: 3,
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  day.dayName,
                  style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                ElevatedButton(
                  onPressed: () {
                    setState(() {
                      day.isClosed = !day.isClosed;
                      _isClinicClosed = day.isClosed;
                      _dailyOverrides[_dayKey(_selectedDay)] = day;
                    });
                    _persistDailyOverride(_selectedDay, day);
                    onChanged?.call();
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor:
                        day.isClosed ? Colors.red.shade300 : const Color(0xFFE0BBFF),
                    foregroundColor:
                        day.isClosed ? Colors.white : Colors.purple.shade900,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                      side: BorderSide(
                        color: day.isClosed ? Colors.red.shade500 : Colors.purple.shade700,
                        width: 1.5,
                      ),
                    ),
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    elevation: 2,
                  ),
                  child: Text(
                    day.isClosed ? '\u0e2b\u0e22\u0e38\u0e14' : '\u0e40\u0e1b\u0e34\u0e14',
                    style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                ),
              ],
            ),
            if (!day.isClosed) ...[
              ...day.timeSlots.asMap().entries.map((entry) {
                final int slotIndex = entry.key;
                final TimeSlot slot = entry.value;
                return Padding(
                  padding: const EdgeInsets.only(top: 8.0),
                  child: Row(
                    children: [
                      Expanded(
                        child: _buildTimePickerButton(
                          context,
                          '\u0e40\u0e1b\u0e34\u0e14',
                          slot.openTime,
                          () => _pickTime(
                            context,
                            day,
                            slot,
                            true,
                            slotIndex,
                            onChanged: onChanged,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: _buildTimePickerButton(
                          context,
                          '\u0e1b\u0e34\u0e14',
                          slot.closeTime,
                          () => _pickTime(
                            context,
                            day,
                            slot,
                            false,
                            slotIndex,
                            onChanged: onChanged,
                          ),
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.delete_outline, color: Colors.red),
                        onPressed: () {
                          setState(() {
                            day.timeSlots.removeAt(slotIndex);
                            _dailyOverrides[_dayKey(_selectedDay)] = day;
                          });
                          _persistDailyOverride(_selectedDay, day);
                          onChanged?.call();
                        },
                        tooltip: '\u0e25\u0e1a\u0e0a\u0e48\u0e27\u0e07\u0e40\u0e27\u0e25\u0e32',
                      ),
                    ],
                  ),
                );
              }),
              const SizedBox(height: 10),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  ElevatedButton.icon(
                    onPressed: () {
                      final newSlot = TimeSlot(
                        openTime: const TimeOfDay(hour: 9, minute: 0),
                        closeTime: const TimeOfDay(hour: 17, minute: 0),
                      );
                      if (_hasOverlap(day.timeSlots, newSlot)) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('\u0e0a\u0e48\u0e27\u0e07\u0e40\u0e27\u0e25\u0e32\u0e17\u0e33\u0e01\u0e32\u0e23\u0e17\u0e31\u0e1a\u0e0b\u0e49\u0e2d\u0e19\u0e01\u0e31\u0e19'),
                          ),
                        );
                        return;
                      }
                      setState(() {
                        day.timeSlots.add(newSlot);
                        day.timeSlots.sort((a, b) => _timeToMinutes(a.openTime) - _timeToMinutes(b.openTime));
                        _dailyOverrides[_dayKey(_selectedDay)] = day;
                      });
                      _persistDailyOverride(_selectedDay, day);
                      onChanged?.call();
                    },
                    icon: const Icon(Icons.add),
                    label: const Text('\u0e40\u0e1e\u0e34\u0e48\u0e21\u0e0a\u0e48\u0e27\u0e07\u0e40\u0e27\u0e25\u0e32\u0e17\u0e33\u0e01\u0e32\u0e23'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.green.shade100,
                      foregroundColor: Colors.green.shade800,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    ),
                  ),
                ],
              ),
              if (onConfirm != null) ...[
                const SizedBox(height: 12),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: onConfirm,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.green.shade600,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                    child: const Text('\u0e22\u0e37\u0e19\u0e22\u0e31\u0e19', style: TextStyle(fontWeight: FontWeight.bold)),
                  ),
                ),
              ],
            ],
          ],
        ),
      ),
    );
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
                    onFormatChanged: (format) async {
                      if (format == CalendarFormat.week) {
                        final navigator = Navigator.of(context);
                        final result = await navigator.push(
                          MaterialPageRoute(
                            builder: (context) => WeeklyViewScreen(
                              focusedDate: _selectedDay,
                              initialPatient: _chainedPatient,
                              receiptDraft: _receiptDraft,
                            ),
                          ),
                        );

                        DateTime? selectedDate;
                        if (result is Map) {
                          final rawDate = result['selectedDate'];
                          if (rawDate is DateTime) {
                            selectedDate = rawDate;
                          }
                        }
                        if (selectedDate != null && mounted) {
                          final resolvedDate = selectedDate;
                          setState(() {
                            _selectedDay = resolvedDate;
                            _focusedDay = resolvedDate;
                          });
                        }

                        if (!mounted) return;
                        _handleDataChange();
                      } else {
                        if (_calendarFormat != format) {
                          setState(() {
                            _calendarFormat = format;
                          });
                        }
                      }
                    },
                    onDailyViewTapped: () async {
                      final navigator = Navigator.of(context);
                      final result = await navigator.push(
                        MaterialPageRoute(builder: (context) => DailyCalendarScreen(
                          selectedDate: _selectedDay,
                          returnFormatOnPop: CalendarFormat.month,
                          initialPatient: _chainedPatient,
                          receiptDraft: _receiptDraft,
                        )),
                      );

                      if (!mounted) return;

                      DateTime? selectedDate;
                      CalendarFormat? format;
                      if (result is Map) {
                        final rawFormat = result['format'];
                        final rawDate = result['selectedDate'];
                        if (rawFormat is CalendarFormat) {
                          format = rawFormat;
                        }
                        if (rawDate is DateTime) {
                          selectedDate = rawDate;
                        }
                      } else if (result is CalendarFormat) {
                        format = result;
                      }

                      if (selectedDate != null && mounted) {
                        final resolvedDate = selectedDate;
                        setState(() {
                          _selectedDay = resolvedDate;
                          _focusedDay = resolvedDate;
                        });
                      }

                      if (format == CalendarFormat.week) {
                        await navigator.push(
                          MaterialPageRoute(
                            builder: (context) => WeeklyViewScreen(
                              focusedDate: selectedDate ?? _selectedDay,
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
                    onPressed: _toggleClinicOpenClosed,
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
                      _isClinicClosed ? '\u0e2b\u0e22\u0e38\u0e14' : '\u0e40\u0e1b\u0e34\u0e14',
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
