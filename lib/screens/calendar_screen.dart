// 📁 lib/screens/calendar_screen.dart

import 'package:flutter/material.dart';
import 'package:table_calendar/table_calendar.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../services/appointment_service.dart';
import 'patients_screen.dart';
import 'appointment_add.dart';

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
  DateTime? _selectedDay;
  CalendarFormat _calendarFormat = CalendarFormat.month;
  int _selectedIndex = 0;

  @override
  void initState() {
    super.initState();
    _selectedDay = _focusedDay;
    _fetchAppointmentsForSelectedDay(_selectedDay!);
  }

  void _fetchAppointmentsForSelectedDay(DateTime selectedDay) async {
    List<Map<String, dynamic>> appointments = await _appointmentService
        .getAppointmentsByDate(selectedDay);

    List<Map<String, dynamic>> appointmentsWithPatients = [];

    for (var appointment in appointments) {
      final patientId = appointment['patientId'];
      Map<String, dynamic>? patient = await _appointmentService.getPatientById(
        patientId,
      );

      if (patient != null) {
        appointmentsWithPatients.add({
          'appointment': appointment,
          'patient': patient,
        });
      }
    }

    if (!mounted) return;
    setState(() {
      _selectedAppointmentsWithPatients = appointmentsWithPatients;
    });
  }

  void _onItemTapped(int index) {
    setState(() {
      _selectedIndex = index;
    });

    if (index == 1) {
      Navigator.push(
        context,
        MaterialPageRoute(builder: (context) => const PatientsScreen()),
      );
    } else if (index == 3) {
      // Report screen - to be implemented
    } else if (index == 4) {
      // Settings screen - to be implemented
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFEFE0FF),
      appBar: AppBar(
        backgroundColor: const Color(0xFFD9B8FF),
        elevation: 0,
        titleTextStyle: const TextStyle(
          color: Colors.white,
          fontSize: 20,
          fontWeight: FontWeight.bold,
        ),
        title: const Text('Appointment Calendar'),
        actions:
            widget.showReset
                ? [
                  IconButton(
                    icon: Icon(Icons.developer_mode, size: 30),
                    onPressed: () async {
                      final prefs = await SharedPreferences.getInstance();
                      await prefs.remove('skipLogin');
                      if (!mounted) return;
                      Navigator.pushReplacementNamed(context, '/login');
                    },
                    tooltip: 'กลับไปหน้า Login',
                    color: Colors.white,
                  ),
                ]
                : null,
      ),
      body: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          children: [
            Container(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                    color: Colors.purple.withOpacity(0.1),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  TextButton.icon(
                    onPressed: () {
                      setState(() {
                        _calendarFormat =
                            _calendarFormat == CalendarFormat.month
                                ? CalendarFormat.week
                                : CalendarFormat.month;
                      });
                    },
                    icon: Icon(
                      _calendarFormat == CalendarFormat.month
                          ? Icons.view_week
                          : Icons.calendar_month,
                      color: Colors.purple,
                    ),
                    label: Text(
                      _calendarFormat == CalendarFormat.month
                          ? 'ดูรายสัปดาห์'
                          : 'ดูรายเดือน',
                      style: const TextStyle(
                        color: Colors.purple,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    style: TextButton.styleFrom(
                      backgroundColor: Colors.purple.shade50,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 8,
                      ),
                    ),
                  ),
                  TableCalendar(
                    locale: 'th_TH',
                    firstDay: DateTime.utc(2020, 1, 1),
                    lastDay: DateTime.utc(2030, 12, 31),
                    focusedDay: _focusedDay,
                    selectedDayPredicate: (day) => isSameDay(_selectedDay, day),
                    onDaySelected: (selectedDay, focusedDay) {
                      setState(() {
                        _selectedDay = selectedDay;
                        _focusedDay = focusedDay;
                      });
                      _fetchAppointmentsForSelectedDay(selectedDay);
                    },
                    calendarFormat: _calendarFormat,
                    onFormatChanged: (format) {
                      setState(() {
                        _calendarFormat = format;
                      });
                    },
                    calendarStyle: CalendarStyle(
                      todayDecoration: BoxDecoration(
                        color: Colors.pink.shade100,
                        shape: BoxShape.circle,
                      ),
                      selectedDecoration: BoxDecoration(
                        color: Colors.purple.shade300,
                        shape: BoxShape.circle,
                      ),
                      weekendTextStyle: TextStyle(
                        color: Colors.purple.shade200,
                      ),
                      outsideDaysVisible: false,
                    ),
                    headerStyle: const HeaderStyle(
                      formatButtonVisible: false,
                      titleCentered: true,
                      titleTextStyle: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    daysOfWeekStyle: const DaysOfWeekStyle(
                      weekendStyle: TextStyle(color: Colors.purple),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            Expanded(
              child:
                  _selectedAppointmentsWithPatients.isEmpty
                      ? const Center(child: Text('ไม่มีนัดหมาย'))
                      : ListView.builder(
                        itemCount: _selectedAppointmentsWithPatients.length,
                        itemBuilder: (context, index) {
                          final appointment =
                              _selectedAppointmentsWithPatients[index]['appointment'];
                          final patient =
                              _selectedAppointmentsWithPatients[index]['patient'];

                          return Card(
                            color: Colors.pink.shade50,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(16),
                            ),
                            margin: const EdgeInsets.symmetric(
                              vertical: 8.0,
                              horizontal: 4.0,
                            ),
                            child: ListTile(
                              title: Text(
                                'ชื่อคนไข้: ${patient['name'] ?? 'ไม่ระบุ'}',
                              ),
                              subtitle: Text(
                                'เวลา: ${appointment['time'] ?? '-'}\nประเภท: ${appointment['type'] ?? '-'}',
                              ),
                            ),
                          );
                        },
                      ),
            ),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          // TODO: handle new appointment action
          showDialog(
            context: context,
            builder: (context) => const AppointmentAddDialog(),
          );
        },
        backgroundColor: Colors.purple,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
        child: Icon(Icons.add, color: Colors.white, size: 36),
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerDocked,
      bottomNavigationBar: BottomAppBar(
        shape: const CircularNotchedRectangle(),
        notchMargin: 8,
        color: const Color(0xFFFBEAFF),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16.0),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              IconButton(
                icon: Icon(Icons.calendar_today, size: 30),
                color:
                    _selectedIndex == 0
                        ? Colors.purple
                        : Colors.purple.shade200,
                onPressed: () => _onItemTapped(0),
              ),
              IconButton(
                icon: Icon(Icons.people_alt, size: 30),
                color:
                    _selectedIndex == 1
                        ? Colors.purple
                        : Colors.purple.shade200,
                onPressed: () => _onItemTapped(1),
              ),
              const SizedBox(width: 40),
              IconButton(
                icon: Icon(Icons.bar_chart, size: 30),
                color:
                    _selectedIndex == 3
                        ? Colors.purple
                        : Colors.purple.shade200,
                onPressed: () => _onItemTapped(3),
              ),
              IconButton(
                icon: Icon(Icons.settings, size: 30),
                color:
                    _selectedIndex == 4
                        ? Colors.purple
                        : Colors.purple.shade200,
                onPressed: () => _onItemTapped(4),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
