// v2.5.3 - 🏗️ Refactored Layout to Reliably Fill Height
// 📁 lib/screens/daily_calendar_screen.dart

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
import 'appointment_add.dart';


class DailyCalendarScreen extends StatefulWidget {
  final DateTime selectedDate;
  const DailyCalendarScreen({super.key, required this.selectedDate});

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

  @override
  void initState() {
    super.initState();
    _currentDate = widget.selectedDate;
    _fetchDataForSelectedDay(_currentDate);
  }

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
      // 💖 [LAYOUT-FIX v2.5.3] ไลลาปรับโครงสร้างตรงนี้นะคะ
      // เราจะใช้ Column เป็น Body หลัก แล้วใช้ Expanded เพื่อให้ Timeline ยืดเต็มพื้นที่ที่เหลือ
      // วิธีนี้จะแก้ปัญหาพื้นที่ว่างด้านล่างได้อย่างถาวรเลยค่ะ!
      body: Column(
        children: [
          // ส่วนหัว (ตัวเลือก View Mode) จะอยู่เหมือนเดิม
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
          // ส่วนหัว (ตัวเลือกวัน) ก็อยู่เหมือนเดิมค่ะ
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
          // ✨ Expanded Widget จะเข้ามาทำหน้าที่ขยายส่วนนี้ให้เต็มพื้นที่ที่เหลือในแนวตั้ง
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator(color: AppTheme.primary))
                // ✨ เราใช้ SingleChildScrollView ห่อเฉพาะส่วนนี้
                // เพื่อให้ Timeline สามารถเลื่อนได้ในกรณีที่เนื้อหายาวเกินพื้นที่ที่ Expanded จัดให้
                : SingleChildScrollView(
                    child: (_selectedDayWorkingHours == null || _selectedDayWorkingHours!.isClosed)
                        ? Padding(
                            // เพิ่ม Padding ให้ข้อความ "ปิดทำการ" ไม่ชิดขอบบนเกินไปค่ะ
                            padding: const EdgeInsets.only(top: 48.0),
                            child: Center(child: Text('คลินิกปิดทำการ', style: TextStyle(color: AppTheme.textDisabled, fontSize: 16, fontFamily: AppTheme.fontFamily))),
                          )
                        : TimelineView(
                            selectedDate: _currentDate,
                            appointments: _appointments,
                            patients: _patients,
                            workingHours: _selectedDayWorkingHours!,
                            onDataChanged: _handleDataChange,
                          ),
                  ),
          ),
        ],
      ),
      floatingActionButton: _buildFloatingActionButton(),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerDocked,
      bottomNavigationBar: const CustomBottomNavBar(selectedIndex: 0),
    );
  }

  Widget _buildFloatingActionButton() {
    return FloatingActionButton(
      onPressed: () => showDialog(
        context: context, 
        builder: (context) => AppointmentAddDialog(initialDate: _currentDate)
      ).then((value) {
        if (value == true) {
          _handleDataChange();
        }
      }),
      backgroundColor: AppTheme.primary,
      tooltip: 'เพิ่มนัดหมายใหม่',
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
      child: const Icon(Icons.add, color: Colors.white, size: 36),
    );
  }
}
