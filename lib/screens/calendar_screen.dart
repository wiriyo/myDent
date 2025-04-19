// lib/screens/calendar_screen.dart
import 'package:flutter/material.dart';
import 'package:table_calendar/table_calendar.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../services/appointment_service.dart';
import '../models/appointment.dart';
import '../models/patient.dart';

class CalendarScreen extends StatefulWidget {
  const CalendarScreen({super.key});

  @override
  State<CalendarScreen> createState() => _CalendarScreenState();
}

class _CalendarScreenState extends State<CalendarScreen> {
  CalendarFormat _calendarFormat = CalendarFormat.month;
  DateTime _focusedDay = DateTime.now();
  DateTime? _selectedDay;
  final AppointmentService _appointmentService = AppointmentService();
  Map<DateTime, List<Appointment>> _events = {};
  List<Map<Appointment, Patient>> _selectedAppointmentsWithPatients = [];

  @override
  void initState() {
    super.initState();
    _selectedDay = _focusedDay;
    _fetchAppointments();
  }

  void _fetchAppointments() {
    FirebaseFirestore.instance.collection('appointments').snapshots().listen((snapshot) {
      final appointments = snapshot.docs
          .map((doc) => Appointment.fromMap(doc.data() as Map<String, dynamic>))
          .toList();
      setState(() {
        _events = {};
        for (var appointment in appointments) {
          final date = DateTime(
              appointment.date.year, appointment.date.month, appointment.date.day);
          if (_events[date] == null) _events[date] = [];
          _events[date]!.add(appointment);
        }
      });
    });
  }

  void _fetchAppointmentsForSelectedDay(DateTime selectedDay) async {
    List<Appointment> appointments =
        await _appointmentService.getAppointmentsByDate(selectedDay).first;
    List<Map<Appointment, Patient>> appointmentsWithPatients = [];
    for (var appointment in appointments) {
      Patient patient = await _appointmentService.getPatientById(appointment.patientId);
      appointmentsWithPatients.add({appointment: patient});
    }
    setState(() {
      _selectedAppointmentsWithPatients = appointmentsWithPatients;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Row(
          children: [
            Image.asset('assets/images/tooth_logo.png', width: 40),
            SizedBox(width: 10),
            Text('MyDent Calendar'),
          ],
        ),
      ),
      body: Column(
        children: [
          TableCalendar(
            firstDay: DateTime.utc(2020, 1, 1),
            lastDay: DateTime.utc(2030, 12, 31),
            focusedDay: _focusedDay,
            calendarFormat: _calendarFormat,
            selectedDayPredicate: (day) {
              return isSameDay(_selectedDay, day);
            },
            onDaySelected: (selectedDay, focusedDay) {
              setState(() {
                _selectedDay = selectedDay;
                _focusedDay = focusedDay;
              });
              _fetchAppointmentsForSelectedDay(selectedDay);
            },
            onFormatChanged: (format) {
              setState(() {
                _calendarFormat = format;
              });
            },
            eventLoader: (day) {
              return _events[DateTime(day.year, day.month, day.day)] ?? [];
            },
            calendarStyle: CalendarStyle(
              // ลบสีที่กำหนดเอง ใช้สีเริ่มต้นของ TableCalendar
              todayDecoration: BoxDecoration(
                color: Theme.of(context).primaryColorLight, // สีน้ำเงินอ่อน (สีเริ่มต้นของ Theme)
                shape: BoxShape.circle,
              ),
              selectedDecoration: BoxDecoration(
                color: Theme.of(context).primaryColor, // สีน้ำเงิน (สีเริ่มต้นของ Theme)
                shape: BoxShape.circle,
              ),
              markerDecoration: BoxDecoration(
                color: Theme.of(context).colorScheme.secondary, // สีรองของ Theme
                shape: BoxShape.circle,
              ),
            ),
          ),
          Expanded(
            child: ListView.builder(
              itemCount: _selectedAppointmentsWithPatients.length,
              itemBuilder: (context, index) {
                final entry = _selectedAppointmentsWithPatients[index];
                final appointment = entry.keys.first;
                final patient = entry.values.first;
                return Card(
                  // ลบสีที่กำหนดเอง ใช้สีเริ่มต้นของ Card (สีขาว)
                  margin: EdgeInsets.symmetric(vertical: 5, horizontal: 10),
                  child: ListTile(
                    title: Text(
                      patient.name,
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                    subtitle: Text(
                      'Time: ${appointment.time} | Treatment: ${appointment.treatment}\nTel: ${patient.telephone}',
                    ),
                    trailing: Text(appointment.status),
                    onTap: () {
                      // ไปหน้า Patient Detail
                    },
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