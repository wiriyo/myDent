// v1.0.3 - Final Fix
// 📁 lib/screens/appointments_screen.dart

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';

import '../auth/login_screen.dart';
import '../models/appointment_model.dart'; // ✨ 1. เราจะใช้ Model โดยตรงค่ะ
import '../models/working_hours_model.dart';
import '../services/appointment_service.dart';
import '../services/working_hours_service.dart';
import 'package:provider/provider.dart';
import '../auth/auth_provider.dart';

class AppointmentsScreen extends StatefulWidget {
  const AppointmentsScreen({super.key});

  @override
  State<AppointmentsScreen> createState() => _AppointmentsScreenState();
}

class _AppointmentsScreenState extends State<AppointmentsScreen> {
  late Future<DayWorkingHours?> _todayWorkingHoursFuture;
  final WorkingHoursService _workingHoursService = WorkingHoursService();
  AppointmentService? _appointmentService; // ✨ จะสร้างภายหลังด้วย clinicId

  @override
  void initState() {
    super.initState();
    _todayWorkingHoursFuture = _loadTodayWorkingHours();
    // ✅ สร้าง AppointmentService พร้อม clinicId จาก Provider
    // ใช้ listen:false เพราะเราไม่ต้องการ rebuild จาก provider ตรงนี้
    final authProvider = Provider.of<AppAuthProvider>(context, listen: false);
    final clinicId = authProvider.verifiedClinicId;
    if (clinicId != null && clinicId.isNotEmpty) {
      _appointmentService = AppointmentService(clinicId: clinicId);
    }
  }

  Future<void> _resetLogin(BuildContext context) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('skipLogin');
    await FirebaseAuth.instance.signOut();
    if (!mounted) return;
    Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute(builder: (_) => const LoginScreen()),
      (route) => false,
    );
  }

  String _getThaiDayName(int weekday) {
    switch (weekday) {
      case DateTime.monday: return 'จันทร์';
      case DateTime.tuesday: return 'อังคาร';
      case DateTime.wednesday: return 'พุธ';
      case DateTime.thursday: return 'พฤหัสบดี';
      case DateTime.friday: return 'ศุกร์';
      case DateTime.saturday: return 'เสาร์';
      case DateTime.sunday: return 'อาทิตย์';
      default: return '';
    }
  }

  Future<DayWorkingHours?> _loadTodayWorkingHours() async {
    try {
      final allHours = await _workingHoursService.loadWorkingHours();
      final todayWeekday = DateTime.now().weekday;
      final todayThaiName = _getThaiDayName(todayWeekday);
      
      return allHours.firstWhere((day) => day.dayName == todayThaiName,
          orElse: () => throw Exception('Working hours for today not found'));
    } catch (e) {
      debugPrint("Could not load today's working hours: $e");
      return null;
    }
  }

  Widget _buildWorkingHoursCard(DayWorkingHours day) {
    final String dayText = 'เวลาทำการวันนี้ (${day.dayName})';
    String timeText;
    final bool isClosed = day.isClosed || day.timeSlots.isEmpty;

    if (isClosed) {
      timeText = 'คลินิกปิดทำการ';
    } else {
      timeText = day.timeSlots.map((slot) {
        return '${slot.openTime.format(context)} - ${slot.closeTime.format(context)}';
      }).join(' และ ');
    }

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16.0),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      color: isClosed ? Colors.red.shade50 : Colors.green.shade50,
      elevation: 2,
      child: ListTile(
        leading: Icon(Icons.access_time_filled,
            color: isClosed ? Colors.red.shade400 : Colors.green.shade700, size: 30),
        title: Text(dayText, style: const TextStyle(fontWeight: FontWeight.bold)),
        subtitle: Text(timeText, style: TextStyle(color: isClosed ? Colors.red.shade700 : Colors.green.shade800, fontSize: 14)),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Appointments'),
        backgroundColor: const Color(0xFFD9B8FF),
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: 'Reset Login Mode',
            onPressed: () => _resetLogin(context),
          ),
        ],
      ),
      backgroundColor: const Color(0xFFEFE0FF),
      body: Column(
        children: [
          const SizedBox(height: 8),
          FutureBuilder<DayWorkingHours?>(
            future: _todayWorkingHoursFuture,
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator.adaptive());
              }
              if (snapshot.hasError || !snapshot.hasData || snapshot.data == null) {
                return const Card(
                    margin: EdgeInsets.symmetric(horizontal: 16.0),
                    child: ListTile(leading: Icon(Icons.error_outline, color: Colors.orange), title: Text('ไม่สามารถโหลดเวลาทำการได้')));
              }
              return _buildWorkingHoursCard(snapshot.data!);
            },
          ),
          const SizedBox(height: 16),
          const Text(
            'รายการนัดหมายวันนี้',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 16),
          Expanded(
            // ✨ 2. เปลี่ยน StreamBuilder ให้รับ List<AppointmentModel> ค่ะ
            child: StreamBuilder<List<AppointmentModel>>(
              // ✨ 3. เรียกใช้ฟังก์ชันที่ถูกต้อง และส่งวันที่ของวันนี้เข้าไปค่ะ
              stream: _appointmentService?.getAppointmentsStreamByDate(DateTime.now()),
              builder: (context, snapshot) {
                if (_appointmentService == null) {
                  return const Center(child: Text('ไม่พบรหัสคลินิก กรุณาเข้าสู่ระบบใหม่'));
                }
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }
                if (snapshot.hasError) {
                  return Center(child: Text('เกิดข้อผิดพลาด: ${snapshot.error}'));
                }
                if (!snapshot.hasData || snapshot.data!.isEmpty) {
                  return const Center(child: Text('ไม่มีนัดหมายสำหรับวันนี้ค่ะ'));
                }

                // ✨ 4. ข้อมูลที่ได้เป็น List<AppointmentModel> ที่กรองและเรียงมาแล้วค่ะ
                final todayAppointments = snapshot.data!;
                
                return ListView.builder(
                  padding: const EdgeInsets.all(16.0),
                  itemCount: todayAppointments.length,
                  itemBuilder: (context, index) {
                    // ✨ 5. ตอนนี้ appt เป็น Object ของ AppointmentModel แล้วค่ะ
                    final appt = todayAppointments[index];

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
                                    // ✨ 6. เข้าถึงข้อมูลได้โดยตรงเลยค่ะ
                                    child: Text(
                                      appt.patientName,
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
                                      appt.status,
                                      style: const TextStyle(color: Colors.black),
                                    ),
                                  )
                                ],
                              ),
                              const SizedBox(height: 8),
                              Text(appt.treatment, style: const TextStyle(color: Colors.purple)),
                              const SizedBox(height: 4),
                              Text(
                                '${DateFormat('dd/MM/yyyy').format(appt.startTime)} ${DateFormat.Hm().format(appt.startTime)} - ${DateFormat.Hm().format(appt.endTime)}',
                              ),
                            ],
                          ),
                        ),
                      ),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
