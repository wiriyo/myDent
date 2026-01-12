// ----------------------------------------------------------------
// 📁 lib/screens/daily_calendar_screen.dart (v3.0 - 💖 Laila's Final Magic Spell!)
// ----------------------------------------------------------------
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:table_calendar/table_calendar.dart';

// 🌸 Imports from our project
import '../models/appointment_model.dart';
import '../models/patient.dart';
import '../services/appointment_service.dart';
import '../services/patient_service.dart';
import '../services/working_hours_service.dart';
import '../models/working_hours_model.dart';
import '../widgets/timeline_view.dart';
import '../widgets/view_mode_selector.dart';
import '../widgets/custom_bottom_nav_bar.dart';
import '../styles/app_theme.dart';

// 💖✨ START: FINAL MAGIC SPELL v3.0 ✨💖
// เราจะ import ผู้ช่วยคนใหม่และสิ่งที่จำเป็นเข้ามาค่ะ
import '../services/appointment_flow_service.dart';
import '../features/printing/domain/receipt_model.dart' as receipt;
import '../features/printing/render/combined_slip_preview_page.dart';
import '../features/printing/render/receipt_mapper.dart'
    show mapCalendarResultToApptInfo;
// 💖✨ END: FINAL MAGIC SPELL v3.0 ✨💖
import 'package:provider/provider.dart';
import '../auth/auth_provider.dart';


class DailyCalendarScreen extends StatefulWidget {
  final DateTime selectedDate;
  // 💖✨ START: FINAL MAGIC SPELL v3.0 ✨💖
  // เพิ่ม "กระเป๋าเวทมนตร์" ให้น้อง Daily ค่ะ
  final Patient? initialPatient;
  final receipt.ReceiptModel? receiptDraft;
  // 💖✨ END: FINAL MAGIC SPELL v3.0 ✨💖

  const DailyCalendarScreen({
    super.key, 
    required this.selectedDate,
    this.initialPatient,
    this.receiptDraft,
  });

  @override
  State<DailyCalendarScreen> createState() => _DailyCalendarScreenState();
}

class _DailyCalendarScreenState extends State<DailyCalendarScreen> {
  AppointmentService? _appointmentService;
  final PatientService _patientService = PatientService();
  final WorkingHoursService _workingHoursService = WorkingHoursService();
  final Map<String, Patient> _patientCache = {};
  List<DayWorkingHours>? _workingHoursCache;
  final Map<DateTime, DayWorkingHours> _dailyOverrides = {};
  bool _isClinicClosed = false;

  late DateTime _currentDate;
  
  List<AppointmentModel> _appointments = [];
  List<Patient> _patients = [];
  DayWorkingHours? _selectedDayWorkingHours;
  bool _isLoading = true;

  // 💖✨ START: FINAL MAGIC SPELL v3.0 ✨💖
  // เพิ่มตัวแปรสำหรับเก็บข้อมูลที่ได้รับมาค่ะ
  Patient? _chainedPatient;
  receipt.ReceiptModel? _receiptDraft;
  bool _isInitialLoad = true;
  // 💖✨ END: FINAL MAGIC SPELL v3.0 ✨💖

  @override
  void initState() {
    super.initState();
    _currentDate = widget.selectedDate;

    // ✅ เตรียม AppointmentService ด้วย clinicId จาก Provider
    // ใช้ listen:false ใน initState ได้
    final authProvider = Provider.of<AppAuthProvider>(context, listen: false);
    final clinicId = authProvider.verifiedClinicId;
    if (clinicId != null && clinicId.isNotEmpty) {
      _appointmentService = AppointmentService(clinicId: clinicId);
      _fetchDataForSelectedDay(_currentDate);
    } else {
      // ถ้าไม่มี clinicId ให้หยุดโหลดและรอจนกว่าจะพร้อม
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('ไม่พบรหัสคลินิก กรุณาเข้าสู่ระบบใหม่')),
          );
          setState(() { _isLoading = false; });
        }
      });
    }
  }

  // 💖✨ START: FINAL MAGIC SPELL v3.0 ✨💖
  // เพิ่ม didChangeDependencies เพื่อรับข้อมูลจาก "กระเป๋าเวทมนตร์" ค่ะ
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
      _isInitialLoad = false;
    }
  }
  // 💖✨ END: FINAL MAGIC SPELL v3.0 ✨💖

  @override
  void didUpdateWidget(DailyCalendarScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.selectedDate != oldWidget.selectedDate && !isSameDay(widget.selectedDate, _currentDate)) {
      setState(() {
        _currentDate = widget.selectedDate;
      });
      _fetchDataForSelectedDay(_currentDate);
    }
  }

  void _handleDataChange() {
    debugPrint("📱 [DailyCalendarScreen] Data change detected! Refetching data...");
    _patientCache.clear();
    _workingHoursCache = null;
    _fetchDataForSelectedDay(_currentDate);
  }

  // 💖✨ START: FINAL MAGIC SPELL v3.0 ✨💖
  // ฟังก์ชันนี้จะถูกเรียกโดยผู้ช่วยของเรา เมื่อ Flow การทำงานเสร็จสิ้น
  void _onAppointmentFlowComplete({bool clearPatient = false}) {
    if (clearPatient && mounted) {
      setState(() {
        _chainedPatient = null;
        _receiptDraft = null;
      });
    }
    _handleDataChange();
  }

  // คาถาบทหลักสำหรับเรียกใช้ผู้ช่วยคนเก่งของเราค่ะ
  void _handleAddAppointment({DateTime? initialStartTime}) {
    final flowService = AppointmentFlowService(
      context: context,
      onFlowComplete: _onAppointmentFlowComplete,
    );

    flowService.startAddAppointmentFlow(
      day: _currentDate,
      initialStartTime: initialStartTime,
      chainedPatient: _chainedPatient,
      receiptDraft: _receiptDraft,
    );
  }
  // 💖✨ END: FINAL MAGIC SPELL v3.0 ✨💖

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

  Future<void> _fetchDataForSelectedDay(DateTime selectedDay) async {
    if (!mounted) return;
    setState(() { _isLoading = true; });

    if (_appointmentService == null) {
      setState(() { _isLoading = false; });
      return;
    }

    try {
      var appointments =
          await _appointmentService!.getAppointmentsByDate(selectedDay);
      final initialCount = appointments.length;
      appointments =
          appointments.where((appt) => appt.patientId.isNotEmpty).toList();
      final removedMissingIds = initialCount - appointments.length;
      if (removedMissingIds > 0) {
        debugPrint(
            'Removed $removedMissingIds appointments without patient references.');
      }
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
            'Skipped $removedCount orphaned appointments on ${selectedDay.toIso8601String()}');
      }

      List<DayWorkingHours>? allWorkingHours = _workingHoursCache;
      if (allWorkingHours == null) {
        try {
          allWorkingHours = await _workingHoursService.loadWorkingHours();
          _workingHoursCache = allWorkingHours;
        } catch (e) {
          allWorkingHours = null;
          debugPrint("Could not find working hours for this day.");
        }
      }

      DayWorkingHours? dayWorkingHours;
      if (allWorkingHours != null) {
        try {
          dayWorkingHours = allWorkingHours.firstWhere(
            (day) => day.dayName == _getThaiDayName(selectedDay.weekday),
          );
        } catch (e) {
          dayWorkingHours = null;
        }
      }

      if (!mounted) return;

      setState(() {
        final baseWorkingHours = dayWorkingHours;
        final dayKey = _dayKey(selectedDay);
        final override = _dailyOverrides[dayKey];
        final hasOverride = override != null;
        if (override != null) {
          dayWorkingHours = override;
        }
        final updatedAppointments = _applyClosedOverlay(
          filteredAppointments,
          selectedDay,
          baseWorkingHours,
          override,
        );
        _appointments = updatedAppointments;
        _patients = updatedAppointments
            .map((appt) => _patientCache[appt.patientId])
            .whereType<Patient>()
            .toList();
        _selectedDayWorkingHours = dayWorkingHours;
        final hasSlots = dayWorkingHours?.timeSlots.isNotEmpty ?? false;
        final isClosed = dayWorkingHours?.isClosed ?? true;
        _isClinicClosed =
            dayWorkingHours == null ||
            isClosed ||
            (!hasOverride && !hasSlots);
        _isLoading = false;
      });
    } catch(e) {
        debugPrint('Error fetching data for daily screen: $e');
        if(mounted) setState(() { _isLoading = false; });
    }
  }

  String _getThaiDayName(int weekday) {
    const days = ['จันทร์', 'อังคาร', 'พุธ', 'พฤหัสบดี', 'ศุกร์', 'เสาร์', 'อาทิตย์'];
    return days[weekday - 1];
  }


  DateTime _dayKey(DateTime day) => DateTime(day.year, day.month, day.day);

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
          patientName: 'ปิดทำการ',
          treatment: 'ปิด',
          duration: end.difference(start).inMinutes,
          status: 'ปิดทำการ',
          startTime: start,
          endTime: end,
        ),
      );
      _patientCache[id] = Patient(
        patientId: id,
        name: 'ปิดทำการ',
        prefix: '',
        rating: 0.0,
        gender: '',
      );
    }
    final combined = [...appointments, ...closedAppointments];
    combined.sort((a, b) => a.startTime.compareTo(b.startTime));
    return combined;
  }

  void _toggleClinicOpenClosed() {
    final key = _dayKey(_currentDate);
    final dayName = _getThaiDayName(_currentDate.weekday);
    if (_isClinicClosed) {
      DayWorkingHours? baseWorkingHours;
      if (_workingHoursCache != null) {
        try {
          baseWorkingHours =
              _workingHoursCache!.firstWhere((d) => d.dayName == dayName);
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
        setState(() {
          _selectedDayWorkingHours = override;
          _isClinicClosed = false;
        });
        _fetchDataForSelectedDay(_currentDate);
        _showDailyWorkingHoursDialog(override);
      } else {
        _dailyOverrides.remove(key);
        setState(() {
          _selectedDayWorkingHours = baseWorkingHours;
          _isClinicClosed = false;
        });
        _fetchDataForSelectedDay(_currentDate);
        _showDailyWorkingHoursDialog(
          _cloneDayWorkingHours(baseWorkingHours, dayName),
        );
      }
    } else {
      final override = _dailyOverrides[key] ??
          DayWorkingHours(dayName: dayName, isClosed: true, timeSlots: []);
      override.isClosed = true;
      _dailyOverrides[key] = override;
      setState(() {
        _isClinicClosed = true;
        _selectedDayWorkingHours = override;
      });
      _fetchDataForSelectedDay(_currentDate);
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
  }) async {
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
            content: Text('ช่วงเวลาไม่ถูกต้อง'),
          ),
        );
        return;
      }
      if (_hasOverlap(day.timeSlots, tempSlot, slotIndex)) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('ช่วงเวลาทำการทับซ้อนกัน'),
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
        _dailyOverrides[_dayKey(_currentDate)] = day;
      });
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
                    _fetchDataForSelectedDay(_currentDate);
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
                      _dailyOverrides[_dayKey(_currentDate)] = day;
                    });
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
                    day.isClosed ? 'หยุด' : 'เปิด',
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
                          'เปิด',
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
                          'ปิด',
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
                            _dailyOverrides[_dayKey(_currentDate)] = day;
                          });
                          onChanged?.call();
                        },
                        tooltip: 'ลบช่วงเวลา',
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
                            content: Text('ช่วงเวลาทำการทับซ้อนกัน'),
                          ),
                        );
                        return;
                      }
                      setState(() {
                        day.timeSlots.add(newSlot);
                        day.timeSlots.sort((a, b) => _timeToMinutes(a.openTime) - _timeToMinutes(b.openTime));
                        _dailyOverrides[_dayKey(_currentDate)] = day;
                      });
                      onChanged?.call();
                    },
                    icon: const Icon(Icons.add),
                    label: const Text('เพิ่มช่วงเวลาทำการ'),
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
                    child: const Text(
                      'ยืนยัน',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                  ),
                ),
              ],
            ],
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(
        automaticallyImplyLeading: false, 
        backgroundColor: AppTheme.primaryLight,
        elevation: 0,
        title: const Text('รายวัน'),
        
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 12, 12, 8),
            child: Row(
              children: [
                Expanded(
                  child: ViewModeSelector(
                    isDailyViewActive: true, 
                    calendarFormat: CalendarFormat.month,
                    onFormatChanged: (format) {
                      Navigator.pop(context, format);
                    },
                    onDailyViewTapped: _handleDataChange,
                  ),
                ),
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
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                IconButton(
                  icon: const Icon(Icons.chevron_left, color: AppTheme.primary),
                  onPressed: () {
                    setState(() { _currentDate = _currentDate.subtract(const Duration(days: 1)); });
                    _fetchDataForSelectedDay(_currentDate);
                  },
                ),
                Text(
                  DateFormat('d MMMM yyyy', 'th_TH').format(
                    DateTime(_currentDate.year + 543, _currentDate.month, _currentDate.day)
                  ),
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: AppTheme.textSecondary,
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.chevron_right, color: AppTheme.primary),
                  onPressed: () {
                    setState(() { _currentDate = _currentDate.add(const Duration(days: 1)); });
                    _fetchDataForSelectedDay(_currentDate);
                  },
                ),
              ],
            ),
          ),
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator(color: AppTheme.primary))
                : SingleChildScrollView(
                    child: TimelineView(
                      selectedDate: _currentDate,
                      appointments: _appointments,
                      patients: _patients,
                      workingHours: _selectedDayWorkingHours ?? DayWorkingHours(dayName: _getThaiDayName(_currentDate.weekday), isClosed: true, timeSlots: []),
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
          ),
        ],
      ),
      // 💖✨ START: FINAL MAGIC SPELL v3.0 ✨💖
      // เปลี่ยนให้ปุ่ม + เรียกใช้ "คาถาบทหลัก" ของเราค่ะ
      floatingActionButton: FloatingActionButton(
        onPressed: () => _handleAddAppointment(),
        backgroundColor: AppTheme.primary,
        tooltip: 'เพิ่มนัดหมายใหม่',
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
        child: const Icon(Icons.add, color: Colors.white, size: 36),
      ),
      // 💖✨ END: FINAL MAGIC SPELL v3.0 ✨💖
      floatingActionButtonLocation: FloatingActionButtonLocation.centerDocked,
      bottomNavigationBar: const CustomBottomNavBar(selectedIndex: 0),
    );
  }
}
