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
// 💖✨ END: FINAL MAGIC SPELL v3.0 ✨💖


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
  final AppointmentService _appointmentService = AppointmentService();
  final PatientService _patientService = PatientService();
  final WorkingHoursService _workingHoursService = WorkingHoursService();

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
    _fetchDataForSelectedDay(_currentDate);
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

  Future<void> _fetchDataForSelectedDay(DateTime selectedDay) async {
    if (!mounted) return;
    setState(() { _isLoading = true; });

    try {
      final appointments = await _appointmentService.getAppointmentsByDate(selectedDay);
      final patientIds = appointments.map((appt) => appt.patientId).toSet();
      
      List<Patient> patients = [];
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
        dayWorkingHours = allWorkingHours.firstWhere((day) => day.dayName == _getThaiDayName(selectedDay.weekday));
      } catch (e) { 
        dayWorkingHours = null; 
        debugPrint("Could not find working hours for this day.");
      }

      if (!mounted) return;

      setState(() {
        _appointments = appointments;
        _patients = patients;
        _selectedDayWorkingHours = dayWorkingHours;
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
            child: ViewModeSelector(
              isDailyViewActive: true, 
              calendarFormat: CalendarFormat.month,
              onFormatChanged: (format) {
                Navigator.pop(context, format);
              },
              onDailyViewTapped: _handleDataChange,
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
                    child: (_selectedDayWorkingHours == null || _selectedDayWorkingHours!.isClosed)
                        ? Padding(
                            padding: const EdgeInsets.only(top: 48.0),
                            child: Center(child: Text('คลินิกปิดทำการ', style: TextStyle(color: AppTheme.textDisabled, fontSize: 16, fontFamily: AppTheme.fontFamily))),
                          )
                        // 💖✨ START: FINAL MAGIC SPELL v3.0 ✨💖
                        // อัปเกรด TimelineView ให้ส่งต่อข้อมูลและคำสั่งได้
                        : TimelineView(
                            selectedDate: _currentDate,
                            appointments: _appointments,
                            patients: _patients,
                            workingHours: _selectedDayWorkingHours!,
                            onDataChanged: _handleDataChange,
                            initialPatient: _chainedPatient,
                            onGapAddTapped: (startTime) => _handleAddAppointment(initialStartTime: startTime),
                          ),
                        // 💖✨ END: FINAL MAGIC SPELL v3.0 ✨💖
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
