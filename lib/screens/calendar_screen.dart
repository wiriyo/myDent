import 'package:flutter/material.dart';
import 'package:mydent_app/services/appointment_service.dart';
import 'package:intl/intl.dart';

class CalendarScreen extends StatefulWidget {
  @override
  _CalendarScreenState createState() => _CalendarScreenState();
}

class _CalendarScreenState extends State<CalendarScreen> {
  String viewMode = 'Month';
  final _nameController = TextEditingController();
  final _typeController = TextEditingController();
  final _datetimeController = TextEditingController();
  final _durationController = TextEditingController();

  void _openAppointmentForm() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) => Padding(
        padding: EdgeInsets.only(
          bottom: MediaQuery.of(context).viewInsets.bottom,
          left: 16,
          right: 16,
          top: 24,
        ),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('เพิ่มนัดหมาย', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
              const SizedBox(height: 16),
              TextField(
                controller: _nameController,
                decoration: InputDecoration(labelText: 'ชื่อคนไข้'),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: _typeController,
                decoration: InputDecoration(labelText: 'ประเภทการรักษา'),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: _datetimeController,
                decoration: InputDecoration(labelText: 'วันเวลา (เช่น 2025-04-22 10:00)'),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: _durationController,
                decoration: InputDecoration(labelText: 'ระยะเวลา (นาที)'),
                keyboardType: TextInputType.number,
              ),
              const SizedBox(height: 16),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.pinkAccent,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                onPressed: () async {
                  try {
                    final name = _nameController.text.trim();
                    final type = _typeController.text.trim();
                    final dateTime = DateFormat("yyyy-MM-dd HH:mm").parse(_datetimeController.text.trim());
                    final duration = Duration(minutes: int.parse(_durationController.text.trim()));

                    await AppointmentService.addAppointment(
                      patientName: name,
                      type: type,
                      startTime: dateTime,
                      duration: duration,
                    );

                    Navigator.pop(context);
                    _nameController.clear();
                    _typeController.clear();
                    _datetimeController.clear();
                    _durationController.clear();
                  } catch (e) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('เกิดข้อผิดพลาด: ${e.toString()}')),
                    );
                  }
                },
                child: const Text('บันทึกนัดหมาย'),
              ),
              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8F6FC),
      appBar: AppBar(leading: Container(),elevation: 0,
        backgroundColor: Colors.white,
        title: Row(
           children: [
            Expanded(
              child: Align(
                alignment: Alignment.centerLeft,
                child: Text('<<<', style: TextStyle(color: Colors.grey.shade600, fontSize: 16)),
              ),
            ),
            Expanded(
              child: Align(
                alignment: Alignment.center,
                child: Text('Apr', style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold, fontSize: 18)),
              ),
            ),
            Expanded(
              child: Align(
                alignment: Alignment.centerRight,
                child: Text('>>>', style: TextStyle(color: Colors.grey.shade600, fontSize: 16)),
              ),
            ),
          ],
        ),
        ),
      
      
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                ChoiceChip(
                  label: const Text('Week'),
                  selected: viewMode == 'Week',
                  onSelected: (_) {
                    setState(() => viewMode = 'Week');
                  },
                ),
                const SizedBox(width: 8),
                ChoiceChip(
                  label: const Text('Month'),
                  selected: viewMode == 'Month',
                  onSelected: (_) {
                    setState(() => viewMode = 'Month');
                  },
                ),
              ],
            ),
          ),
          viewMode == 'Month' ? buildCalendarGrid() : buildWeekView(),
          Expanded(child: buildAppointmentsList()),
        ],
      ),
      bottomNavigationBar: BottomNavigationBar(
        backgroundColor: Colors.white,
        selectedItemColor: Colors.purple,
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.calendar_today), label: 'Calendar'),
          BottomNavigationBarItem(icon: Icon(Icons.person), label: 'Patients'),
          BottomNavigationBarItem(icon: Icon(Icons.settings), label: 'Settings'),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _openAppointmentForm,
        child: const Icon(Icons.add),
        backgroundColor: Colors.pinkAccent,
      ),
    );
  }

  Widget buildCalendarGrid() {
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: GridView.builder(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 7,
          childAspectRatio: 1,
          crossAxisSpacing: 8,
          mainAxisSpacing: 8,
        ),
        itemCount: 35,
        itemBuilder: (context, index) {
          return Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(8),
              color: index == 9 ? Colors.pinkAccent : Colors.transparent,
            ),
            child: Center(
              child: Text(
                '${index + 1}',
                style: TextStyle(
                  color: index == 9 ? Colors.white : Colors.black,
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget buildWeekView() {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final weekStart = today.subtract(Duration(days: today.weekday - 1));

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: List.generate(7, (index) {
          final day = weekStart.add(Duration(days: index));
          final isToday = day.day == now.day && day.month == now.month && day.year == now.year;
          return Expanded(
            child: Container(
              margin: const EdgeInsets.symmetric(horizontal: 4),
              decoration: BoxDecoration(
                color: isToday ? Colors.pinkAccent : Colors.transparent,
                borderRadius: BorderRadius.circular(8),
              ),
              padding: const EdgeInsets.symmetric(vertical: 12),
              child: Column(
                children: [
                  Text(
                    DateFormat('E').format(day),
                    style: TextStyle(
                      color: isToday ? Colors.white : Colors.black54,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '${day.day}',
                    style: TextStyle(
                      color: isToday ? Colors.white : Colors.black,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),
          );
        }),
      ),
    );
  }

  Widget buildAppointmentsList() {
    return StreamBuilder<List<Map<String, dynamic>>>(
      stream: AppointmentService.getAppointmentsForCurrentUser(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        if (!snapshot.hasData || snapshot.data!.isEmpty) {
          return const Center(child: Text('ไม่มีนัดหมาย'));
        }
        final appointments = snapshot.data!;
        return ListView.builder(
          padding: const EdgeInsets.all(16.0),
          itemCount: appointments.length,
          itemBuilder: (context, index) {
            final appt = appointments[index];
            return Padding(
              padding: const EdgeInsets.only(bottom: 12.0),
              child: Container(
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: const [
                    BoxShadow(color: Colors.black12, blurRadius: 8, offset: Offset(0, 2)),
                  ],
                ),
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              appt['patientName'] ?? '',
                              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                            decoration: BoxDecoration(
                              color: Colors.amber.shade100,
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Text(
                              appt['status'] ?? 'Pending',
                              style: const TextStyle(color: Colors.black),
                            ),
                          )
                        ],
                      ),
                      const SizedBox(height: 8),
                      Text(appt['type'] ?? '', style: const TextStyle(color: Colors.purple)),
                      const SizedBox(height: 4),
                      Text('${appt['startTime']?.substring(11, 16)} - ${appt['endTime']?.substring(11, 16)}'),
                    ],
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }
}
