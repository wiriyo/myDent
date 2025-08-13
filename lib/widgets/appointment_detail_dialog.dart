// 💖 สวัสดีค่ะพี่ทะเล! ไลลาตกแต่ง Dropdown ของช่องสถานะให้โค้งมนสวยงามแล้วนะคะ 😊

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';
import '../models/patient.dart';
import '../services/appointment_service.dart';
import '../services/patient_service.dart';
import '../services/rating_service.dart';
import '../services/treatment_master_service.dart';
import '../screens/appointment_add.dart';
import '../screens/treatment_add.dart';
import '../models/appointment_model.dart';
import '../styles/app_theme.dart';

// dev mode
import 'package:flutter/foundation.dart' show kDebugMode; // ซ่อนปุ่มในโปรดักชัน
import '../features/printing/printing.dart';
import '../features/printing/render/receipt_mapper.dart';
import '../features/printing/render/preview_pages.dart' as pv;


class AppointmentDetailDialog extends StatefulWidget {
  final AppointmentModel appointment;
  final Patient patient;
  final VoidCallback onDataChanged;

  const AppointmentDetailDialog({
    super.key,
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
  final PatientService _patientService = PatientService();
  late String _currentStatus;
  late TextEditingController _reasonController;

  final List<String> statusOptions = const [
    'รอยืนยัน',
    'ยืนยันแล้ว',
    'เสร็จสิ้น',
    'ยกเลิก',
    'ติดต่อไม่ได้',
    'ไม่มาตามนัด',
    'ปฏิเสธนัด',
    'เลื่อนนัด',
  ];

  @override
  void initState() {
    super.initState();
    _currentStatus = widget.appointment.status;
    _reasonController = TextEditingController(
      text: widget.appointment.notes ?? '',
    );
  }

  @override
  void dispose() {
    _reasonController.dispose();
    super.dispose();
  }

  Color _getDialogColor(double rating) {
    if (rating >= 4.5) {
      return AppTheme.rating5Star;
    } else if (rating >= 3.5) {
      return AppTheme.rating4Star;
    } else {
      return AppTheme.rating3StarAndBelow;
    }
  }

  void _makePhoneCall() async {
    final String? telephone = widget.patient.telephone;
    if (telephone != null && telephone.isNotEmpty && telephone != '-') {
      final Uri phoneUri = Uri.parse('tel:$telephone');
      if (await canLaunchUrl(phoneUri)) {
        await launchUrl(phoneUri);
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('ไม่สามารถโทรออกได้')));
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

  // ========= NEW: ตัวช่วยสร้างใบนัดจากสถานะปัจจุบัน เพื่อพรีวิว =========
  AppointmentSlipModel _buildSlipFromState() {
    final patientName = widget.patient.name;
    final String hn = ''; // ยังไม่มี HN ในโมเดล patient ของโปรเจกต์นี้
    final DateTime startAt = widget.appointment.startTime;
    final String? note = _reasonController.text.trim().isEmpty
        ? null
        : _reasonController.text.trim();

    // TODO: เปลี่ยนเป็นข้อมูลจริงจาก Clinic settings เมื่อพร้อมต่อ state
    return buildAppointmentSlip(
      clinicName: 'MyDent คลินิก',
      clinicAddress: '123 ถนนสุขใจ เขตบางกะปิ กทม.',
      clinicPhone: '02-123-4567',
      patientName: patientName,
      hn: hn,
      startAt: startAt,
      note: note,
    );
  }
  // ======================================================================

  void _editAppointment() {
    Navigator.pop(context);
    showDialog(
      context: context,
      builder: (_) => AppointmentAddDialog(
        appointment: widget.appointment,
      ),
    ).then((value) {
      if (value == true) {
        widget.onDataChanged();
      }
    });
  }

  void _deleteAppointment() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
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
        await _appointmentService.deleteAppointment(widget.appointment.appointmentId);
        if (mounted) {
          Navigator.pop(context);
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('ลบนัดหมายเรียบร้อยแล้ว')),
          );
          widget.onDataChanged();
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('เกิดข้อผิดพลาดในการลบ: $e')));
        }
      }
    }
  }

  void _saveChanges() async {
    try {
      final updatedAppointment = AppointmentModel(
        appointmentId: widget.appointment.appointmentId,
        userId: widget.appointment.userId,
        patientId: widget.appointment.patientId,
        patientName: widget.appointment.patientName,
        treatment: widget.appointment.treatment,
        duration: widget.appointment.duration,
        startTime: widget.appointment.startTime,
        endTime: widget.appointment.endTime,
        teeth: widget.appointment.teeth,
        status: _currentStatus,
        notes: _reasonController.text.trim().isEmpty ? null : _reasonController.text.trim(),
      );
      await _appointmentService.updateAppointment(updatedAppointment);

      final currentRating = widget.patient.rating;
      final newRating = RatingService.calculateNewRating(
        currentRating: currentRating,
        appointmentStatus: _currentStatus,
      );

      if (newRating != currentRating) {
        await _patientService.updatePatientRating(widget.patient.patientId, newRating);
      }
      double? initialPrice;
      if (_currentStatus == 'เสร็จสิ้น') {
        final master =
            await TreatmentMasterService.getTreatmentByName(widget.appointment.treatment);
        initialPrice = master?.price;
      }

      if (mounted) {
        Navigator.pop(context);
        if (_currentStatus == 'เสร็จสิ้น') {
          showTreatmentDialog(
            context,
            patientId: widget.patient.patientId,
            patientName: widget.patient.name,
            initialProcedure: widget.appointment.treatment,
            initialDate: widget.appointment.startTime,
            initialToothNumber:
                widget.appointment.teeth?.join(', '),
            initialPrice: initialPrice,
          );
        }
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

  int _calculateAge(DateTime? birthDate) {
    if (birthDate == null) return 0;
    final today = DateTime.now();
    int age = today.year - birthDate.year;
    if (today.month < birthDate.month ||
        (today.month == birthDate.month && today.day < birthDate.day)) {
      age--;
    }
    return age > 0 ? age : 0;
  }

  Widget _buildRatingStars(double rating) {
    final int fullStars = rating.floor();
    final bool hasHalfStar = (rating - fullStars) >= 0.5;

    return Row(
      children: List.generate(5, (index) {
        Widget toothIcon;
        if (index < fullStars) {
          toothIcon = Image.asset(
            'assets/icons/tooth_good.png',
            width: 20,
            height: 20,
          );
        } else if (index == fullStars && hasHalfStar) {
          toothIcon = Image.asset(
            'assets/icons/tooth_good.png',
            width: 20,
            height: 20,
            color: AppTheme.ratingInflamedTooth,
          );
        } else {
          toothIcon = Image.asset(
            'assets/icons/tooth_broke.png',
            width: 20,
            height: 20,
          );
        }
        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 2.0),
          child: toothIcon,
        );
      }),
    );
  }

  Widget _getGenderIcon(String gender, {double size = 20}) {
    String iconPath;
    switch (gender) {
      case 'หญิง':
        iconPath = AppTheme.iconPathFemale;
        break;
      case 'ชาย':
        iconPath = AppTheme.iconPathMale;
        break;
      default:
        iconPath = AppTheme.iconPathGender;
        break;
    }
    return Image.asset(iconPath, width: size, height: size);
  }

  @override
  Widget build(BuildContext context) {
    final int age = _calculateAge(widget.patient.birthDate);
    final String patientName = widget.patient.name;
    final double rating = widget.patient.rating;
    final String telephone = widget.patient.telephone ?? '-';
    final String gender = widget.patient.gender;
    final String medicalHistory = widget.patient.medicalHistory ?? 'ไม่มี';
    final String allergy = widget.patient.allergy ?? 'ไม่มี';
    final String treatment = widget.appointment.treatment;
    final DateTime startTime = widget.appointment.startTime;
    final DateTime endTime = widget.appointment.endTime;
    final List<dynamic> teethList = widget.appointment.teeth ?? [];
    final String teethString = teethList.join(', ');
    final String fullTreatmentText = '$treatment ${teethString.isNotEmpty ? '(#$teethString)' : ''}';
    
    final dialogColor = _getDialogColor(rating);

    return AlertDialog(
      backgroundColor: dialogColor,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      titlePadding: const EdgeInsets.fromLTRB(24, 24, 24, 0),
      contentPadding: const EdgeInsets.fromLTRB(24, 12, 24, 12),
      actionsPadding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
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
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Divider(),
            const SizedBox(height: 16),
            Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Image.asset(AppTheme.iconPathUser, width: 24, height: 24),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    patientName,
                    style: const TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF6A4DBA),
                      fontFamily: AppTheme.fontFamily
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Row(children: [
              Text('อายุ: $age ปี', style: const TextStyle(fontSize: 16, fontFamily: AppTheme.fontFamily)),
              const SizedBox(width: 8),
              if (gender.isNotEmpty)
                _getGenderIcon(gender, size: 20)
            ]),
            const SizedBox(height: 4),
            Row(children: [
              Text('โทร: $telephone', style: const TextStyle(fontSize: 16, fontFamily: AppTheme.fontFamily)),
              const Spacer(),
              if (telephone.isNotEmpty && telephone != '-')
                SizedBox(
                  height: 38,
                  width: 38,
                  child: Material(
                    color: AppTheme.buttonCallBg,
                    shape: const CircleBorder(),
                    clipBehavior: Clip.antiAlias,
                    child: IconButton(
                      padding: EdgeInsets.zero,
                      icon: Image.asset(AppTheme.iconPathCall, width: 20),
                      onPressed: _makePhoneCall,
                      tooltip: 'โทรหาคนไข้'
                    )
                  )
                )
            ]),
            const SizedBox(height: 8),
            _buildInfoRow(text: 'โรคประจำตัว: $medicalHistory'),
            const SizedBox(height: 4),
            _buildInfoRow(text: 'แพ้ยา: $allergy'),
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
                      Text(fullTreatmentText, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w600, fontFamily: AppTheme.fontFamily)),
                      const SizedBox(height: 4),
                      Text(
                        'วันที่: ${DateFormat('dd MMMM yyyy', 'th_TH').format(startTime)}',
                        style: TextStyle(fontSize: 16, color: Colors.grey.shade700, fontFamily: AppTheme.fontFamily)
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'เวลา: ${DateFormat.Hm('th_TH').format(startTime)} - ${DateFormat.Hm('th_TH').format(endTime)}',
                        style: TextStyle(fontSize: 16, color: Colors.grey.shade700, fontFamily: AppTheme.fontFamily)
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            // ✨ [UI-FIX] ตกแต่ง Dropdown ของเราให้สวยงามโค้งมนค่ะ!
            DropdownButtonFormField<String>(
              value: _currentStatus,
              items: statusOptions.map((status) => DropdownMenuItem(value: status, child: Text(status))).toList(),
              onChanged: (value) { setState(() { _currentStatus = value ?? _currentStatus; }); },
              borderRadius: BorderRadius.circular(16.0), // ทำให้เมนูที่กางออกมามนสวย
              decoration: InputDecoration(
                labelText: 'สถานะ',
                filled: true,
                fillColor: Colors.white,
                contentPadding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(16.0),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(16.0),
                  borderSide: BorderSide(color: Colors.grey.shade400),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(16.0),
                  borderSide: const BorderSide(color: AppTheme.primary, width: 2.0),
                ),
              ),
            ),
            if (_currentStatus == 'เลื่อนนัด' || _reasonController.text.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 16.0),
                child: TextField(
                  controller: _reasonController,
                  decoration: InputDecoration(
                    labelText: 'บันทึก / เหตุผลการเลื่อนนัด',
                    filled: true,
                    fillColor: Colors.white.withOpacity(0.8),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(16.0))
                  ),
                  maxLines: 2,
                ),
              ),
          ],
        ),
      ),
      actions: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Row(
              children: [
                _buildIconActionButton(iconPath: 'assets/icons/save.png', backgroundColor: AppTheme.buttonCallBg, tooltip: 'บันทึกการเปลี่ยนแปลง', onPressed: _saveChanges),
                const SizedBox(width: 12),
                _buildIconActionButton(iconPath: 'assets/icons/edit.png', backgroundColor: AppTheme.buttonEditBg, tooltip: 'แก้ไขนัดหมาย', onPressed: _editAppointment),
                // ========= NEW: ปุ่มพรีวิวใบนัด (DEV เท่านั้น) =========
                if (kDebugMode) ...[
                  const SizedBox(width: 12),
                  TextButton.icon(
                    style: TextButton.styleFrom(
                      backgroundColor: Colors.white.withOpacity(0.95),
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                    ),
                    icon: const Icon(Icons.print, color: AppTheme.primary),
                    label: const Text('พรีวิวใบนัด', style: TextStyle(color: AppTheme.primary)),
                    onPressed: () async {
  final slip = _buildSlipFromState();
  await Navigator.of(context).push(
    MaterialPageRoute(
      builder: (_) => pv.AppointmentSlipPreviewPage(slip: slip),
    ),
  );
},

                  ),
                ],
                // ======================================================
              ],
            ),
            _buildIconActionButton(iconPath: 'assets/icons/delete.png', backgroundColor: AppTheme.buttonDeleteBg, tooltip: 'ลบนัดหมาย', onPressed: _deleteAppointment),
          ],
        ),
      ],
    );
  }

  Widget _buildInfoRow({String? icon, required String text}) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (icon != null) ...[
          Image.asset(icon, width: 16, height: 16, color: Colors.grey.shade700),
          const SizedBox(width: 8),
        ],
        Expanded(child: Text(text, style: TextStyle(fontSize: 14, fontFamily: AppTheme.fontFamily, color: Colors.grey.shade800))),
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
      height: 48,
      width: 64,
      child: Material(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(14),
        clipBehavior: Clip.antiAlias,
        child: IconButton(
          tooltip: tooltip,
          icon: Image.asset(iconPath, width: 26, height: 26),
          onPressed: onPressed,
        ),
      ),
    );
  }
}
