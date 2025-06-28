// 📁 lib/widgets/appointment_detail_dialog.dart (ฉบับสมบูรณ์ มีชีวิตชีวา! ✨)

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';

import '../services/appointment_service.dart';
import '../screens/appointment_add.dart';

class AppointmentDetailDialog extends StatefulWidget {
  final String appointmentId;
  final Map<String, dynamic> appointment;
  final Map<String, dynamic> patient;
  final VoidCallback onDataChanged;

  const AppointmentDetailDialog({
    super.key,
    required this.appointmentId,
    required this.appointment,
    required this.patient,
    required this.onDataChanged,
  });

  @override
  State<AppointmentDetailDialog> createState() => _AppointmentDetailDialogState();
}

class _AppointmentDetailDialogState extends State<AppointmentDetailDialog> {
  final AppointmentService _appointmentService = AppointmentService();
  late String _currentStatus;
  
  final List<String> statusOptions = [
    'รอยืนยัน',
    'ยืนยันแล้ว',
    'ติดต่อไม่ได้',
    'ไม่มาตามนัด',
    'ปฏิเสธนัด',
  ];

  @override
  void initState() {
    super.initState();
    _currentStatus = widget.appointment['status'] ?? 'รอยืนยัน';
  }

  // --- ฟังก์ชันสำหรับจัดการการทำงานของปุ่ม ---

  void _makePhoneCall() async {
    final String? telephone = widget.patient['telephone']?.toString();
    if (telephone != null && telephone.isNotEmpty) {
      final Uri phoneUri = Uri.parse('tel:$telephone');
      if (await canLaunchUrl(phoneUri)) {
        await launchUrl(phoneUri);
      } else {
         if(mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('ไม่สามารถโทรออกได้')));
      }
    } else {
        if(mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('ไม่มีเบอร์โทรศัพท์สำหรับคนไข้คนนี้')));
    }
  }

  void _editAppointment() {
    Navigator.pop(context); 
    showDialog(
      context: context,
      builder: (_) => AppointmentAddDialog(
        appointmentData: {'appointmentId': widget.appointmentId, ...widget.appointment},
      ),
    ).then((_) => widget.onDataChanged());
  }

  void _deleteAppointment() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('ยืนยันการลบ'),
        content: const Text('คุณต้องการลบนัดหมายนี้ใช่หรือไม่?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('ยกเลิก')),
          TextButton(onPressed: () => Navigator.pop(context, true), child: const Text('ลบ', style: TextStyle(color: Colors.red))),
        ],
      ),
    );

    if (confirm == true) {
      try {
        await _appointmentService.deleteAppointment(widget.appointmentId);
        if(mounted) {
          Navigator.pop(context); 
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('ลบนัดหมายเรียบร้อยแล้ว')));
          widget.onDataChanged();
        }
      } catch (e) {
        if(mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('เกิดข้อผิดพลาดในการลบ: $e')));
      }
    }
  }

  void _updateStatus(String newStatus) async {
    setState(() { _currentStatus = newStatus; });
    try {
      await _appointmentService.updateAppointmentStatus(widget.appointmentId, newStatus);
       if(mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('อัปเดตสถานะเป็น "$newStatus"'), duration: const Duration(seconds: 2)));
       widget.onDataChanged();
    } catch (e) {
      if(mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('เกิดข้อผิดพลาดในการอัปเดตสถานะ: $e')));
    }
  }

  // ✨ FIX: แก้ไขฟังก์ชันคำนวณอายุให้รับข้อมูลได้ถูกต้อง ✨
  int _calculateAge(dynamic birthDate) {
    if (birthDate == null) return 0;
    
    DateTime? birthDateTime;
    if (birthDate is Timestamp) {
      birthDateTime = birthDate.toDate();
    } else if (birthDate is String) {
      birthDateTime = DateTime.tryParse(birthDate);
    }

    if (birthDateTime == null) return 0;

    final today = DateTime.now();
    int age = today.year - birthDateTime.year;
    if (today.month < birthDateTime.month || (today.month == birthDateTime.month && today.day < birthDateTime.day)) {
      age--;
    }
    return age > 0 ? age : 0;
  }
  
  Widget _buildRatingStars(int rating) {
     return Row(
      mainAxisSize: MainAxisSize.min,
      children: List.generate(5, (index) {
        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 1.0),
          child: Icon(
            index < rating ? Icons.star_rounded : Icons.star_border_rounded,
            color: Colors.amber,
            size: 20,
          ),
        );
      }),
    );
  }

  @override
  Widget build(BuildContext context) {
    // ✨ FIX: แก้ไขการดึงข้อมูลทั้งหมดให้ปลอดภัยและถูกต้องตามที่ DEBUG CONSOLE บอก ✨
    final String patientName = widget.patient['name']?.toString() ?? 'ไม่มีชื่อ';
    final int rating = (widget.patient['rating'] as num?)?.toInt() ?? 0;
    final int age = _calculateAge(widget.patient['birthDate']);
    final String telephone = widget.patient['telephone']?.toString() ?? '-';
    final String treatment = widget.appointment['treatment']?.toString() ?? '-';
    final DateTime startTime = (widget.appointment['startTime'] as Timestamp).toDate();
    final DateTime endTime = (widget.appointment['endTime'] as Timestamp).toDate();

    return Dialog(
      backgroundColor: const Color(0xFFFDF8FF),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(child: Text(patientName, style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Color(0xFF6A4DBA)))),
                if (rating > 0) _buildRatingStars(rating),
              ],
            ),
            const SizedBox(height: 8),
            const Divider(),
            const SizedBox(height: 16),

            Text('อายุ: $age ปี', style: const TextStyle(fontSize: 16)),
            const SizedBox(height: 4),
            Text('โทร: $telephone', style: const TextStyle(fontSize: 16)),
            const SizedBox(height: 16),

            Text(treatment, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w600)),
            const SizedBox(height: 4),
            Text(
              'เวลา: ${DateFormat.Hm().format(startTime)} - ${DateFormat.Hm().format(endTime)}',
              style: TextStyle(fontSize: 16, color: Colors.grey.shade700),
            ),
            const SizedBox(height: 16),

            DropdownButtonFormField<String>(
              value: _currentStatus,
              items: statusOptions.map((status) => DropdownMenuItem(value: status, child: Text(status))).toList(),
              onChanged: (value) {
                if(value != null && value != _currentStatus) {
                  _updateStatus(value);
                }
              },
              decoration: InputDecoration(
                labelText: 'สถานะ',
                filled: true,
                fillColor: Colors.white,
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
              ),
            ),
            const SizedBox(height: 24),

            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                _buildActionButton(icon: Icons.delete_forever, label: 'ลบ', color: Colors.red.shade300, onPressed: _deleteAppointment),
                Row(
                  children: [
                    _buildActionButton(icon: Icons.phone, label: 'โทร', color: Colors.green.shade400, onPressed: _makePhoneCall),
                    const SizedBox(width: 8),
                    _buildActionButton(icon: Icons.edit, label: 'แก้ไข', color: Colors.orange.shade400, onPressed: _editAppointment),
                  ],
                )
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildActionButton({ required IconData icon, required String label, required Color color, required VoidCallback onPressed }) {
    return ElevatedButton.icon(
      onPressed: onPressed,
      icon: Icon(icon, size: 18),
      label: Text(label),
      style: ElevatedButton.styleFrom(
        foregroundColor: Colors.white,
        backgroundColor: color,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      ),
    );
  }
}