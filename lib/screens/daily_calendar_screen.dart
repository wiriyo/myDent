// v1.0.7 - Final Data Type Fix
// 📁 lib/screens/daily_calendar_screen.dart

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:table_calendar/table_calendar.dart';

import '../services/appointment_service.dart';
import '../services/patient_service.dart';
import '../services/working_hours_service.dart';
import '../models/appointment_model.dart';
import '../models/patient.dart';
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

  List<Map<String, dynamic>> _appointmentsWithPatients = [];
  DayWorkingHours? _selectedDayWorkingHours;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _fetchAppointmentsAndWorkingHoursForSelectedDay(widget.selectedDate);
  }

  Future<void> _fetchAppointmentsAndWorkingHoursForSelectedDay(DateTime selectedDay) async {
    setState(() { _isLoading = true; });

    try {
      final appointments = await _appointmentService.getAppointmentsByDate(selectedDay);
      List<Map<String, dynamic>> appointmentsWithPatients = [];

      for (var appointment in appointments) {
        final patient = await _patientService.getPatientById(appointment.patientId);
        if (patient != null) {
          final appointmentDataForTimeline = appointment.toMap();
          appointmentDataForTimeline['appointmentId'] = appointment.appointmentId;

          // ✨ The Fix! เอาตุ๊กตา Patient ใส่กล่อง .toMap() ก่อนส่งค่ะ
          appointmentsWithPatients.add({
            'appointment': appointmentDataForTimeline,
            'patient': patient.toMap() 
          });
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
        _appointmentsWithPatients = appointmentsWithPatients;
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
        automaticallyImplyLeading: true,
        backgroundColor: AppTheme.primaryLight,
        elevation: 0,
        title: Text(
          'นัดหมายวันที่ ${DateFormat('d MMMM yyyy', 'th_TH').format(widget.selectedDate)}',
          style: const TextStyle(fontFamily: AppTheme.fontFamily, color: AppTheme.textPrimary, fontWeight: FontWeight.bold),
        ),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 12, 12, 8),
            child: ViewModeSelector(
              isDailyViewActive: true, 
              calendarFormat: CalendarFormat.month,
              onFormatChanged: (format) {
                Navigator.pop(context);
              },
              onDailyViewTapped: () {
                  _fetchAppointmentsAndWorkingHoursForSelectedDay(widget.selectedDate);
              },
            ),
          ),
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator(color: AppTheme.primary))
                : (_selectedDayWorkingHours == null || _selectedDayWorkingHours!.isClosed)
                    ? Center(child: Text('คลินิกปิดทำการ', style: TextStyle(color: AppTheme.textDisabled, fontSize: 16, fontFamily: AppTheme.fontFamily)))
                    : TimelineView(
                        selectedDate: widget.selectedDate,
                        appointments: _appointmentsWithPatients,
                        workingHours: _selectedDayWorkingHours!,
                        onDataChanged: () => _fetchAppointmentsAndWorkingHoursForSelectedDay(widget.selectedDate),
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
      onPressed: () => showDialog(context: context, builder: (context) => AppointmentAddDialog(initialDate: widget.selectedDate)).then((_) => _fetchAppointmentsAndWorkingHoursForSelectedDay(widget.selectedDate)),
      backgroundColor: AppTheme.primary,
      tooltip: 'เพิ่มนัดหมายใหม่',
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
      child: const Icon(Icons.add, color: Colors.white, size: 36),
    );
  }
}
