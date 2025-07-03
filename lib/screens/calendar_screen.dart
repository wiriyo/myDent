// 📁 lib/screens/calendar_screen.dart (ฉบับรีโนเวทด้วย Widget ใหม่ ✨)

import 'package:flutter/material.dart';
import 'package:table_calendar/table_calendar.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../services/appointment_service.dart';
import '../services/working_hours_service.dart';
import '../models/working_hours_model.dart';
import '../widgets/timeline_view.dart'; // ✨ 1. import เฟอร์นิเจอร์ชิ้นที่ 1
import '../widgets/view_mode_selector.dart'; // ✨ 2. import เฟอร์นิเจอร์ชิ้นที่ 2
import 'patients_screen.dart';
import 'setting_screen.dart';
import 'reports_screen.dart';
import 'appointment_add.dart';
import 'daily_calendar_screen.dart';



class CalendarScreen extends StatefulWidget {
  final bool showReset;
  const CalendarScreen({super.key, this.showReset = false});

  @override
  State<CalendarScreen> createState() => _CalendarScreenState();
}

class _CalendarScreenState extends State<CalendarScreen> {
  final AppointmentService _appointmentService = AppointmentService();
  List<Map<String, dynamic>> _selectedAppointmentsWithPatients = [];
  DateTime _focusedDay = DateTime.now();
  late DateTime _selectedDay;
  DayWorkingHours? _selectedDayWorkingHours;
  final WorkingHoursService _workingHoursService = WorkingHoursService();
  CalendarFormat _calendarFormat = CalendarFormat.month;
  int _selectedIndex = 0;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _selectedDay = _focusedDay;
    _fetchAppointmentsAndWorkingHoursForSelectedDay(_selectedDay);
  }

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
      }
      if (!mounted) return;
      setState(() {
        _selectedAppointmentsWithPatients = appointmentsWithPatients;
        _selectedDayWorkingHours = dayWorkingHours;
      });
    } catch(e) {
       debugPrint('Error fetching data for calendar screen: $e');
    } finally {
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
      backgroundColor: const Color(0xFFEFE0FF),
      appBar: AppBar(
        backgroundColor: const Color(0xFFD9B8FF),
        elevation: 0,
        title: const Text('ปฏิทินนัดหมาย'),
        actions: widget.showReset ? [
          IconButton(
            icon: const Icon(Icons.developer_mode),
            onPressed: () async {
              final prefs = await SharedPreferences.getInstance();
              await prefs.remove('skipLogin');
              if (mounted) Navigator.pushReplacementNamed(context, '/login');
            },
          ),
        ] : null,
      ),
      // ✅✅✅ วางโค้ด body ชุดใหม่นี้เข้าไปแทนที่ค่ะ ✅✅✅

body: Column(
  children: [
    // ✨ 1. ย้ายปุ่มเลือกมุมมองออกมานอก Container ของปฏิทิน ✨
    Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
      child: ViewModeSelector(
        calendarFormat: _calendarFormat,
        onFormatChanged: (format) {
          if (_calendarFormat != format) {
            setState(() { _calendarFormat = format; });
          }
        },
        onDailyViewTapped: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => DailyCalendarScreen(selectedDate: _selectedDay),
            ),
          ).then((_) => _fetchAppointmentsAndWorkingHoursForSelectedDay(_selectedDay));
        },
      ),
    ),
    
    // ✨ 2. ให้ Container หุ้มเฉพาะปฏิทินเท่านั้น ✨
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
          headerStyle: const HeaderStyle(
            formatButtonVisible: false,
            titleCentered: true,
            titleTextStyle: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          calendarStyle: CalendarStyle(
            todayDecoration: BoxDecoration(color: Colors.purple.shade100, shape: BoxShape.circle),
            selectedDecoration: BoxDecoration(color: Colors.purple.shade300, shape: BoxShape.circle),
          ),
          onDaySelected: (selectedDay, focusedDay) {
            if (!isSameDay(_selectedDay, selectedDay)) {
              setState(() {
                _selectedDay = selectedDay;
                _focusedDay = focusedDay;
              });
              _fetchAppointmentsAndWorkingHoursForSelectedDay(selectedDay);
            }
          },
          onPageChanged: (focusedDay) {
            _focusedDay = focusedDay;
          },
        ),
      ),
    ),
    
    const SizedBox(height: 12),
    
    // ✨ 3. ส่วน Timeline และรายการนัดหมาย (ไม่มีการเปลี่ยนแปลง) ✨
    Expanded(
      child: _isLoading
          ? const Center(child: CircularProgressIndicator(color: Colors.purple))
          : (_selectedDayWorkingHours == null || _selectedDayWorkingHours!.isClosed)
              ? Center(child: Text('คลินิกปิดทำการ', style: TextStyle(color: Colors.grey.shade600, fontSize: 16)))
              : TimelineView(
                  selectedDate: _selectedDay,
                  appointments: _selectedAppointmentsWithPatients,
                  workingHours: _selectedDayWorkingHours!,
                  onDataChanged: () => _fetchAppointmentsAndWorkingHoursForSelectedDay(_selectedDay),
                ),
    ),
  ],
),
      floatingActionButton: FloatingActionButton(
        onPressed: () => showDialog(context: context, builder: (_) => AppointmentAddDialog(initialDate: _selectedDay)).then((_) => _fetchAppointmentsAndWorkingHoursForSelectedDay(_selectedDay)),
        backgroundColor: Colors.purple,
        child: const Icon(Icons.add, color: Colors.white),
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerDocked,
      bottomNavigationBar: BottomAppBar(
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
      ),
    );
  }

  void _onItemTapped(int index) {
    setState(() { _selectedIndex = index; });
    if (index == 1) {
      Navigator.push(context, MaterialPageRoute(builder: (context) => const PatientsScreen()));
    } else if (index == 3) Navigator.push(context, MaterialPageRoute(builder: (context) => const ReportsScreen()));
    else if (index == 4) Navigator.push(context, MaterialPageRoute(builder: (context) => const SettingsScreen()));
  }

  Widget _buildNavIconButton({required IconData icon, required String tooltip, required int index}) {
    return IconButton(
      icon: Icon(icon, size: 30),
      color: _selectedIndex == index ? Colors.purple : Colors.purple.shade200,
      onPressed: () => _onItemTapped(index),
      tooltip: tooltip,
    );
  }
}