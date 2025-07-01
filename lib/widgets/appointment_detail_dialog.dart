// 📁 lib/widgets/appointment_detail_dialog.dart (ฉบับนำหัตถการกลับมาแล้วค่ะ 💖)

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
  State<AppointmentDetailDialog> createState() =>
      _AppointmentDetailDialogState();
}

class _AppointmentDetailDialogState extends State<AppointmentDetailDialog> {
  final AppointmentService _appointmentService = AppointmentService();
  late String _currentStatus;
  late TextEditingController _reasonController;

  final List<String> statusOptions = [
    'รอยืนยัน',
    'ยืนยันแล้ว',
    'ติดต่อไม่ได้',
    'ไม่มาตามนัด',
    'ปฏิเสธนัด',
    'เลื่อนนัด',
  ];

  @override
  void initState() {
    super.initState();
    _currentStatus = widget.appointment['status'] ?? 'รอยืนยัน';

    _reasonController = TextEditingController(
      text: widget.appointment['postponedReason'] ?? '',
    );
  }

   @override
  void dispose() {
    // ✨ อย่าลืม dispose controller เพื่อคืนหน่วยความจำนะคะ ✨
    _reasonController.dispose();
    super.dispose();
  }

  // --- ฟังก์ชันสำหรับจัดการการทำงานของปุ่ม ---

  void _makePhoneCall() async {
    final String? telephone = widget.patient['telephone']?.toString();
    if (telephone != null && telephone.isNotEmpty) {
      final Uri phoneUri = Uri.parse('tel:$telephone');
      if (await canLaunchUrl(phoneUri)) {
        await launchUrl(phoneUri);
      } else {
        if (mounted) {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(const SnackBar(content: Text('ไม่สามารถโทรออกได้')));
        }
      }
    } else {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('ไม่มีเบอร์โทรศัพท์สำหรับคนไข้คนนี้')),
        );
      }
    }
  }

  void _editAppointment() {
    Navigator.pop(context);
    showDialog(
      context: context,
      builder:
          (_) => AppointmentAddDialog(
        appointmentData: {
          'appointmentId': widget.appointmentId,
          ...widget.appointment,
        },
      ),
    ).then((_) => widget.onDataChanged());
  }

  void _deleteAppointment() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder:
          (context) => AlertDialog(
        title: const Text('ยืนยันการลบ'),
        content: const Text('คุณต้องการลบนัดหมายนี้ใช่หรือไม่?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('ยกเลิก'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('ลบ', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );

    if (confirm == true) {
      try {
        await _appointmentService.deleteAppointment(widget.appointmentId);
        if (mounted) {
          Navigator.pop(context);
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('ลบนัดหมายเรียบร้อยแล้ว')),
          );
          widget.onDataChanged();
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(SnackBar(content: Text('เกิดข้อผิดพลาดในการลบ: $e')));
        }
      }
    }
  }

  void _saveChanges() async {
    try {
      final reason = _currentStatus == 'เลื่อนนัด' ? _reasonController.text : null;
      await _appointmentService.updateAppointmentDetails(
        appointmentId: widget.appointmentId,
        status: _currentStatus,
        postponedReason: reason,
      );
      if (mounted) {
        Navigator.pop(context); // ✨ เพิ่มบรรทัดนี้เพื่อปิดหน้าต่างค่ะ ✨
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('บันทึกการเปลี่ยนแปลงเรียบร้อยแล้ว'),
            duration: Duration(seconds: 2),
          ),
        );
        widget.onDataChanged();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('เกิดข้อผิดพลาดในการบันทึก: $e')),
        );
      }
    }
  }
  
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
    if (today.month < birthDateTime.month ||
        (today.month == birthDateTime.month && today.day < birthDateTime.day)) {
      age--;
    }
    return age > 0 ? age : 0;
  }
  
  Widget _buildRatingStars(int rating) {
    return Row(
      children: List.generate(5, (index) {
        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 2.0),
          child: Image.asset(
            index < rating
                ? 'assets/icons/tooth_good.png'
                : 'assets/icons/tooth_broke.png',
            width: 20,
            height: 20,
          ),
        );
      }),
    );
  }

  @override
  Widget build(BuildContext context) {
    final String patientName =
        widget.patient['name']?.toString() ?? 'ไม่มีชื่อ';
    final int rating = (widget.patient['rating'] as num?)?.toInt() ?? 0;
    final int age = _calculateAge(widget.patient['birthDate']);
    final String telephone = widget.patient['telephone']?.toString() ?? '-';
    final String treatment = widget.appointment['treatment']?.toString() ?? '-';
    final DateTime startTime =
        (widget.appointment['startTime'] as Timestamp).toDate();
    final DateTime endTime =
        (widget.appointment['endTime'] as Timestamp).toDate();
    final String gender = widget.patient['gender'] ?? '';

    Color dialogColor;
    if (rating >= 5) {
      dialogColor = const Color(0xFFE0F7E9);
    } else if (rating >= 4) {
      dialogColor = const Color(0xFFFFF8E1);
    } else {
      dialogColor = const Color(0xFFFFEBEE);
    }

    return AlertDialog(
      backgroundColor: dialogColor,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      // กำหนด padding ให้สวยงาม
      titlePadding: const EdgeInsets.fromLTRB(24, 24, 24, 0),
      contentPadding: const EdgeInsets.fromLTRB(24, 12, 24, 12),
      actionsPadding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
      
      // --- ✨ ส่วนหัวเรื่อง (Title): เหลือแค่ Rating อย่างเดียวค่ะ ✨ ---
      title: Row(
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          if (rating > 0)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(color: Colors.white.withOpacity(0.8), borderRadius: BorderRadius.circular(12), border: Border.all(color: Colors.purple.shade100)),
              child: _buildRatingStars(rating),
            ),
        ],
      ),

        // --- ส่วนเนื้อหา (Content) ---
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Divider(),
            const SizedBox(height: 16),

            // ✨ ย้ายชื่อคนไข้มาอยู่ตรงนี้แทนค่ะ! ✨
            Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Image.asset('assets/icons/user.png', width: 24, height: 24, color: const Color(0xFF6A4DBA)),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    patientName,
                    style: const TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF6A4DBA),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),

            // (ส่วนที่เหลือเหมือนเดิมทั้งหมดค่ะ)
            Row(children: [Text('อายุ: $age ปี', style: const TextStyle(fontSize: 16)), const SizedBox(width: 8), if (gender.isNotEmpty) Icon(gender == 'ชาย' ? Icons.male : Icons.female, color: gender == 'ชาย' ? Colors.blue.shade300 : Colors.pink.shade200, size: 20)]),
            const SizedBox(height: 4),
            Row(children: [Text('โทร: $telephone', style: const TextStyle(fontSize: 16)), const Spacer(), if (telephone.isNotEmpty && telephone != '-') SizedBox(height: 38, width: 38, child: Material(color: Colors.green.shade100, shape: const CircleBorder(), clipBehavior: Clip.antiAlias, child: IconButton(padding: EdgeInsets.zero, icon: Image.asset('assets/icons/phone.png', width: 20), onPressed: _makePhoneCall, tooltip: 'โทรหาคนไข้')))]),
            const SizedBox(height: 16),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Image.asset('assets/icons/treatment.png', width: 40, height: 40),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(treatment, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w600)),
                      const SizedBox(height: 4),
                      Text('เวลา: ${DateFormat.Hm().format(startTime)} - ${DateFormat.Hm().format(endTime)}', style: TextStyle(fontSize: 16, color: Colors.grey.shade700)),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            DropdownButtonFormField<String>(
              value: _currentStatus,
              items: statusOptions.map((status) => DropdownMenuItem(value: status, child: Text(status))).toList(),
              onChanged: (value) { setState(() { _currentStatus = value ?? _currentStatus; }); },
              decoration: InputDecoration(labelText: 'สถานะ', filled: true, fillColor: Colors.white, border: OutlineInputBorder(borderRadius: BorderRadius.circular(12))),
            ),
            if (_currentStatus == 'เลื่อนนัด')
              Padding(
                padding: const EdgeInsets.only(top: 16.0),
                child: TextField(
                  controller: _reasonController,
                  decoration: InputDecoration(labelText: 'เหตุผลการเลื่อนนัด', filled: true, fillColor: Colors.white, border: OutlineInputBorder(borderRadius: BorderRadius.circular(12))),
                  maxLines: 2,
                ),
              ),
          ],
        ),
      ),

      // --- ส่วนปุ่มควบคุม (Actions) ---
      actions: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Row(
              children: [
                _buildIconActionButton(iconPath: 'assets/icons/save.png', backgroundColor: Colors.green.shade300, tooltip: 'บันทึกการเปลี่ยนแปลง', onPressed: _saveChanges),
                const SizedBox(width: 12),
                _buildIconActionButton(iconPath: 'assets/icons/edit.png', backgroundColor: Colors.orange.shade300, tooltip: 'แก้ไขนัดหมาย', onPressed: _editAppointment),
              ],
            ),
            _buildIconActionButton(iconPath: 'assets/icons/delete.png', backgroundColor: Colors.red.shade300, tooltip: 'ลบนัดหมาย', onPressed: _deleteAppointment),
          ],
        ),
      ],
    );
  }

  Widget _buildIconActionButton({
    required String iconPath,
    required Color backgroundColor,
    required String tooltip,
    required VoidCallback onPressed,
  }) {
    return SizedBox(
      height: 48, // เพิ่มความสูงเล็กน้อย
      width: 64,  // ✨ เพิ่มความกว้างให้ปุ่มดูสมดุลค่ะ ✨
      child: Material(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(14), // เพิ่มขอบมนให้ดูนุ่มนวลขึ้น
        clipBehavior: Clip.antiAlias,
        child: IconButton(
          tooltip: tooltip,
          icon: Image.asset(iconPath, width: 26, height: 26, color: Colors.white), // ปรับขนาดไอคอนให้ใหญ่ขึ้นนิดนึง
          onPressed: onPressed,
        ),
      ),
    );
  }
}