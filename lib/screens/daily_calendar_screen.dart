// 📁 lib/screens/daily_calendar_screen.dart

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:table_calendar/table_calendar.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import '../services/appointment_service.dart';
import '../services/working_hours_service.dart';
import '../models/working_hours_model.dart';
import '../widgets/timeline_view.dart';
import '../widgets/view_mode_selector.dart'; // ✨ [FIX] import Widget ใหม่ของเราเข้ามาค่ะ
import 'patients_screen.dart';
import 'setting_screen.dart';
import 'reports_screen.dart';
import 'appointment_add.dart';


class DailyCalendarScreen extends StatefulWidget {
  final DateTime selectedDate;
  const DailyCalendarScreen({super.key, required this.selectedDate});

  @override
  State<DailyCalendarScreen> createState() => _DailyCalendarScreenState();
}

class _DailyCalendarScreenState extends State<DailyCalendarScreen> {
  final AppointmentService _appointmentService = AppointmentService();
  final WorkingHoursService _workingHoursService = WorkingHoursService();

  List<Map<String, dynamic>> _appointmentsWithPatients = [];
  DayWorkingHours? _selectedDayWorkingHours;
  bool _isLoading = true;
  int _selectedIndex = 0;

  @override
  void initState() {
    super.initState();
    _fetchAppointmentsAndWorkingHoursForSelectedDay(widget.selectedDate);
  }

  // --- ✨ ระบบจัดการข้อมูล ✨ ---
  Future<void> _fetchAppointmentsAndWorkingHoursForSelectedDay(DateTime selectedDay) async {
    setState(() { _isLoading = true; });

    try {
      final appointments = await _appointmentService.getAppointmentsByDate(selectedDay);
      List<Map<String, dynamic>> appointmentsWithPatients = [];
      for (var appointment in appointments) {
        final patient = await _appointmentService.getPatientById(appointment['patientId']);
        if (patient != null) {
          appointmentsWithPatients.add({'appointment': appointment, 'patient': patient});
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
      });
    } catch(e) {
        debugPrint('Error fetching data for daily screen: $e');
    } finally {
        if(mounted) setState(() { _isLoading = false; });
    }
  }

  String _getThaiDayName(int weekday) {
    const days = ['จันทร์', 'อังคาร', 'พุธ', 'พฤหัสบดี', 'ศุกร์', 'เสาร์', 'อาทิตย์'];
    return days[weekday - 1];
  }

  // --- ✨ ส่วนประกอบของ UI ✨ ---
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF3E5F5), // ✨ สีม่วงพาสเทลอ่อนๆ น่ารัก
      appBar: AppBar(
        backgroundColor: const Color(0xFFE1BEE7), // ✨ สีม่วงที่เข้มขึ้นมาหน่อย
        elevation: 0,
        title: Text(
          'นัดหมายวันที่ ${DateFormat('d MMMM yyyy', 'th_TH').format(widget.selectedDate)}',
          style: const TextStyle(color: Colors.black, fontSize: 20, fontWeight: FontWeight.bold),
        ),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 12, 12, 8),
            // ✨ [FIX] เรียกใช้ ViewModeSelector ที่เราสร้างไว้ และจัดให้อยู่ตรงกลางค่ะ
            child: ViewModeSelector(
              // ในหน้านี้ calendarFormat จะไม่ถูกใช้ แต่เราต้องส่งค่าไปให้ครบค่ะ
              calendarFormat: CalendarFormat.month, 
              onFormatChanged: (format) {
                Navigator.pop(context, format);
              },
              // ปุ่ม 'วัน' จะทำการ refresh ข้อมูลในหน้านี้ค่ะ
              onDailyViewTapped: () {
                 _fetchAppointmentsAndWorkingHoursForSelectedDay(widget.selectedDate);
              },
            ),
          ),
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator(color: Colors.purple))
                : (_selectedDayWorkingHours == null || _selectedDayWorkingHours!.isClosed)
                    ? Center(child: Text('คลินิกปิดทำการ', style: TextStyle(color: Colors.grey.shade600, fontSize: 16)))
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
      bottomNavigationBar: _buildBottomAppBar(),
    );
  }

  // ✨ [FIX] เราไม่ต้องใช้ _buildViewModeSelector และ _buildViewModeButton ในหน้านี้แล้วค่ะ!

  Widget _buildBottomAppBar() {
    return BottomAppBar(
      shape: const CircularNotchedRectangle(),
      notchMargin: 8.0,
      color: Colors.white,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: <Widget>[
          _buildNavIconButton(icon: Icons.calendar_today, tooltip: 'ปฏิทิน', index: 0),
          _buildNavIconButton(icon: Icons.people_alt, tooltip: 'คนไข้', index: 1),
          const SizedBox(width: 40),
          _buildNavIconButton(icon: Icons.bar_chart, tooltip: 'รายงาน', index: 3),
          _buildNavIconButton(icon: Icons.settings, tooltip: 'ตั้งค่า', index: 4),
        ],
      ),
    );
  }

  Widget _buildNavIconButton({required IconData icon, required String tooltip, required int index}) {
    return IconButton(
      icon: Icon(icon, size: 30),
      color: _selectedIndex == index ? Colors.purple : Colors.purple.shade200,
      onPressed: () => _onItemTapped(index),
      tooltip: tooltip,
    );
  }
  
  Widget _buildFloatingActionButton() {
    return FloatingActionButton(
      onPressed: () => showDialog(context: context, builder: (context) => AppointmentAddDialog(initialDate: widget.selectedDate)).then((_) => _fetchAppointmentsAndWorkingHoursForSelectedDay(widget.selectedDate)),
      backgroundColor: Colors.purple,
      tooltip: 'เพิ่มนัดหมายใหม่',
      child: const Icon(Icons.add, color: Colors.white, size: 36),
    );
  }

  void _onItemTapped(int index) {
    if (_selectedIndex == index) return;
    setState(() { _selectedIndex = index; });
    if (index == 0) { Navigator.pop(context); } 
    else if (index == 1) { Navigator.pushReplacement(context, MaterialPageRoute(builder: (context) => const PatientsScreen())); } 
    else if (index == 3) { Navigator.pushReplacement(context, MaterialPageRoute(builder: (context) => const ReportsScreen())); } 
    else if (index == 4) { Navigator.pushReplacement(context, MaterialPageRoute(builder: (context) => const SettingsScreen())); }
  }
}
