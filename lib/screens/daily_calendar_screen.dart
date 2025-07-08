// v2.2.0 - ✨ Connected Refresh Signal
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
                  DateFormat('d MMMM yyyy', 'th_TH').format(_currentDate),
                  style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppTheme.textSecondary),
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
                : (_selectedDayWorkingHours == null || _selectedDayWorkingHours!.isClosed)
                    ? Center(child: Text('คลินิกปิดทำการ', style: TextStyle(color: AppTheme.textDisabled, fontSize: 16, fontFamily: AppTheme.fontFamily)))
                    : TimelineView(
                        selectedDate: _currentDate,
                        appointments: _appointments,
                        patients: _patients,
                        workingHours: _selectedDayWorkingHours!,
                        onDataChanged: _handleDataChange,
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
        // ✨ [CONNECTED] เชื่อมท่อส่งสัญญาณรีเฟรชที่นี่ค่ะ!
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
