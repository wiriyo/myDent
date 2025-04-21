// 📁 lib/screens/calendar_screen.dart

import 'package:flutter/material.dart';
import 'package:table_calendar/table_calendar.dart';
import '../services/appointment_service.dart';

class CalendarScreen extends StatefulWidget {
  const CalendarScreen({super.key});

  @override
  State<CalendarScreen> createState() => _CalendarScreenState();
}

class _CalendarScreenState extends State<CalendarScreen> {
  final AppointmentService _appointmentService = AppointmentService();
  List<Map<String, dynamic>> _selectedAppointmentsWithPatients = [];
  DateTime _focusedDay = DateTime.now();
  DateTime? _selectedDay;

  @override
  void initState() {
    super.initState();
    _selectedDay = _focusedDay;
    _fetchAppointmentsForSelectedDay(_selectedDay!);
  }

  void _fetchAppointmentsForSelectedDay(DateTime selectedDay) async {
    List<Map<String, dynamic>> appointments =
        await _appointmentService.getAppointmentsByDate(selectedDay);

    List<Map<String, dynamic>> appointmentsWithPatients = [];

    for (var appointment in appointments) {
      final patientId = appointment['patientId'];

      Map<String, dynamic>? patient =
          await _appointmentService.getPatientById(patientId);

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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Appointment Calendar'),
      ),
      body: Column(
        children: [
          TableCalendar(
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
            calendarStyle: const CalendarStyle(
              selectedDecoration: BoxDecoration(
                color: Colors.purple,
                shape: BoxShape.circle,
              ),
              todayDecoration: BoxDecoration(
                color: Colors.purpleAccent,
                shape: BoxShape.circle,
              ),
            ),
          ),
          const SizedBox(height: 16),
          Expanded(
            child: _selectedAppointmentsWithPatients.isEmpty
                ? const Center(child: Text('ไม่มีนัดหมาย'))
                : ListView.builder(
                    itemCount: _selectedAppointmentsWithPatients.length,
                    itemBuilder: (context, index) {
                      final appointment = _selectedAppointmentsWithPatients[index]['appointment'];
                      final patient = _selectedAppointmentsWithPatients[index]['patient'];

                      return Card(
                        margin: const EdgeInsets.all(8.0),
                        child: ListTile(
                          title: Text('ชื่อคนไข้: ${patient['name'] ?? 'ไม่ระบุ'}'),
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
    );
  }
}
