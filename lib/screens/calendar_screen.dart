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
  DateTime currentDate = DateTime.now();
  DateTime selectedDate = DateTime.now();

  void _changeMonth(int offset) {
    setState(() {
      currentDate = DateTime(currentDate.year, currentDate.month + offset);
    });
  }

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
                    setState(() {});
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
      appBar: AppBar(
        elevation: 0,
        backgroundColor: Colors.white,
        centerTitle: true,
        title: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          mainAxisSize: MainAxisSize.min,
          children: [
            IconButton(
              icon: Icon(Icons.chevron_left, color: Colors.grey.shade600),
              onPressed: () => _changeMonth(-1),
            ),
            const SizedBox(width: 8),
            Text(
              DateFormat('MMM').format(currentDate),
              style: const TextStyle(color: Colors.black, fontWeight: FontWeight.bold, fontSize: 18),
            ),
            const SizedBox(width: 8),
            IconButton(
              icon: Icon(Icons.chevron_right, color: Colors.grey.shade600),
              onPressed: () => _changeMonth(1),
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
          if (viewMode == 'Month')
            buildCalendarGrid()
          else
            buildWeekView(),
          buildAppointmentsList(),
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

  Widget buildWeekView() {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final weekStart = selectedDate.subtract(Duration(days: selectedDate.weekday - 1));

    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: List.generate(7, (index) {
          final day = weekStart.add(Duration(days: index));
          final isSelected = selectedDate.day == day.day && selectedDate.month == day.month && selectedDate.year == day.year;
          return Expanded(
            child: GestureDetector(
              onTap: () => setState(() => selectedDate = day),
              child: Column(
                children: [
                  Text(DateFormat('E').format(day), style: const TextStyle(fontWeight: FontWeight.bold)),
                  const SizedBox(height: 4),
                  CircleAvatar(
                    backgroundColor: isSelected ? Colors.pinkAccent : Colors.grey.shade300,
                    radius: 16,
                    child: Text('${day.day}', style: const TextStyle(color: Colors.white)),
                  ),
                ],
              ),
            ),
          );
        }),
      ),
    );
  }

  Widget buildCalendarGrid() {
    final firstDayOfMonth = DateTime(currentDate.year, currentDate.month, 1);
    final daysInMonth = DateTime(currentDate.year, currentDate.month + 1, 0).day; // จำนวนวันในเดือน
    // Debug: ตรวจสอบจำนวนวันในเดือน
    print('daysInMonth: $daysInMonth');
    // ปรับ firstWeekday ให้เริ่มจากวันจันทร์ (0) ถึงวันอาทิตย์ (6)
    final firstWeekday = (firstDayOfMonth.weekday + 6) % 7; // วันแรกของเดือน

    // กำหนดให้มี 6 แถวเสมอ (6 สัปดาห์ x 7 วัน = 42 ช่อง)
    const totalGridCount = 42;

    return SizedBox(
      height: 400, // เพิ่มความสูงให้เพียงพอสำหรับ 6 แถว
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: List.generate(7, (index) {
                final weekday = DateFormat.E().format(DateTime(2023, 1, index + 2));
                return Expanded(
                  child: Center(
                    child: Text(
                      weekday,
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                  ),
                );
              }),
            ),
            const SizedBox(height: 8),
            Expanded(
              child: GridView.builder(
                shrinkWrap: true, // เพิ่มเพื่อให้ GridView ปรับขนาดตามเนื้อหา
                physics: const NeverScrollableScrollPhysics(),
                itemCount: totalGridCount,
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 7,
                  childAspectRatio: 1,
                  crossAxisSpacing: 8,
                  mainAxisSpacing: 8,
                  mainAxisExtent: 50, // ความสูงของแต่ละช่อง
                ),
                itemBuilder: (context, index) {
                  // คำนวณวันที่สำหรับช่องปัจจุบัน
                  final dayNum = index - firstWeekday + 1;
                  // แสดงเฉพาะวันที่ที่อยู่ในเดือนนี้ (1 ถึง daysInMonth)
                  final isValidDay = dayNum >= 1 && dayNum <= daysInMonth;
                  final date = DateTime(currentDate.year, currentDate.month, isValidDay ? dayNum : 1);
                  final isSelected = isValidDay &&
                      selectedDate.day == dayNum &&
                      selectedDate.month == currentDate.month;

                  // Debug: ดูว่า dayNum คำนวณถูกต้องหรือไม่
                  if (index >= firstWeekday && dayNum <= daysInMonth) {
                    print('index: $index, dayNum: $dayNum, isValidDay: $isValidDay');
                  }

                  return GestureDetector(
                    onTap: () => isValidDay ? setState(() => selectedDate = date) : null,
                    child: Container(
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(8),
                        color: isValidDay && isSelected ? Colors.pinkAccent : Colors.transparent,
                      ),
                      child: Center(
                        child: Text(
                          isValidDay ? '$dayNum' : '',
                          style: TextStyle(
                            color: isValidDay && isSelected ? Colors.white : Colors.black,
                          ),
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
          ],
        ),
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

        final appointments = snapshot.data!
            .where((appt) => DateFormat('yyyy-MM-dd').format(DateTime.parse(appt['startTime'])) == DateFormat('yyyy-MM-dd').format(selectedDate))
            .toList();

        if (appointments.isEmpty) {
          return const Center(child: Text('ไม่มีนัดหมายในวันนี้'));
        }

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