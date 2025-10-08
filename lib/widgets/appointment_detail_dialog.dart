// ----------------------------------------------------------------
// 📁 lib/widgets/appointment_detail_dialog.dart (v2.0 - 💖 Laila's UI-Safe Fix!)
// ----------------------------------------------------------------
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
import '../features/printing/domain/appointment_slip_model.dart';
import '../features/printing/render/appointment_slip_preview_page.dart';
import '../features/printing/render/receipt_mapper.dart';
import 'package:provider/provider.dart';
import '../auth/auth_provider.dart';
import '../utils/thai_number_formatter.dart';

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
  AppointmentService? _appointmentService;
  final PatientService _patientService = PatientService();
  late String _currentStatus;
  late TextEditingController _reasonController;
  bool _isSaving = false;
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

    // ✅ เตรียม AppointmentService ด้วย clinicId จาก Provider
    final authProvider = Provider.of<AppAuthProvider>(context, listen: false);
    final clinicId = authProvider.verifiedClinicId;
    if (clinicId != null && clinicId.isNotEmpty) {
      _appointmentService = AppointmentService(clinicId: clinicId);
    } else {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('ไม่พบรหัสคลินิก กรุณาเข้าสู่ระบบใหม่'),
            ),
          );
        }
      });
    }
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

  void _openPatientDetail() {
    final navigator = Navigator.of(context, rootNavigator: true);
    navigator.pop();
    navigator.pushNamed('/patient_detail', arguments: widget.patient);
  }

  void _makePhoneCall() async {
    final String? telephone = widget.patient.telephone;
    if (telephone != null && telephone.isNotEmpty && telephone != '-') {
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

  AppointmentSlipModel _buildSlipFromState() {
    final patientName = widget.patient.name;
    final String hn = '';
    final DateTime startAt = widget.appointment.startTime;
    final String note =
        _reasonController.text.trim().isEmpty
            ? widget
                .appointment
                .treatment // ถ้าไม่มีโน้ต ให้ใช้ชื่อ treatment แทน
            : _reasonController.text.trim();

    return buildAppointmentSlip(
      clinicName: 'คลินิกทันตกรรม\nหมอกุสุมาภรณ์',
      clinicAddress: '304 ม.1 ต.หนองพอก\nอ.หนองพอก จ.ร้อยเอ็ด',
      clinicPhone: '094-5639334',
      patientName: patientName,
      hn: hn,
      startAt: startAt,
      note: note,
    );
  }

  void _editAppointment() {
    Navigator.pop(context);
    showDialog(
      context: context,
      builder: (_) => AppointmentAddDialog(appointment: widget.appointment),
    ).then((value) {
      if (value == true || value is Map) {
        widget.onDataChanged();
      }
    });
  }

  void _deleteAppointment() async {
    if (_appointmentService == null) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('ไม่พบรหัสคลินิก ไม่สามารถลบนัดหมายได้'),
          ),
        );
      }
      return;
    }
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
        await _appointmentService!.deleteAppointment(
          widget.appointment.appointmentId,
        );
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
    if (_appointmentService == null) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('ไม่พบรหัสคลินิก ไม่สามารถบันทึกได้')),
        );
      }
      return;
    }
    if (_isSaving) {
      return;
    }
    setState(() {
      _isSaving = true;
    });
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
        notes:
            _reasonController.text.trim().isEmpty
                ? null
                : _reasonController.text.trim(),
      );

      await _appointmentService!.updateAppointment(updatedAppointment);

      final currentRating = widget.patient.rating;
      final newRating = RatingService.calculateNewRating(
        currentRating: currentRating,
        appointmentStatus: _currentStatus,
      );

      if (newRating != currentRating) {
        await _patientService.updatePatientRating(
          widget.patient.patientId,
          newRating,
        );
      }

      double? initialPrice;
      if (_currentStatus == 'เสร็จสิ้น') {
        final master = await TreatmentMasterService.getTreatmentByName(
          widget.appointment.treatment,
        );
        initialPrice = master?.price;
      }

      if (!mounted) return;
      final navigator = Navigator.of(context);
      final messenger = ScaffoldMessenger.of(context);
      final bool shouldShowSlip = _currentStatus == 'รอยืนยัน';

      navigator.pop();
      if (shouldShowSlip) {
        final slip = _buildSlipFromState();
        await navigator.push(
          MaterialPageRoute(
            // 💖 FIX: แก้ไขแค่จุดนี้จุดเดียวเลยค่ะ บอกน้องให้ใช้ข้อมูลจริง โดยไม่กระทบ UI เดิมเลยค่ะ
            builder:
                (_) => AppointmentSlipPreviewPage(
                  slip: slip,
                  useSampleData: false,
                ),
          ),
        );
        if (!mounted) return;
      }

      if (_currentStatus == 'เสร็จสิ้น') {
        if (!mounted) return;
        showTreatmentDialog(
          context,
          patientId: widget.patient.patientId,
          patientName: widget.patient.name,
          initialProcedure: widget.appointment.treatment,
          initialDate: widget.appointment.startTime,
          initialToothNumber: widget.appointment.teeth?.join(', '),
          initialPrice: initialPrice,
        );
      }

      messenger.showSnackBar(
        const SnackBar(
          content: Text('บันทึกการเปลี่ยนแปลงเรียบร้อยแล้ว'),
          duration: Duration(seconds: 2),
        ),
      );
      widget.onDataChanged();
    } catch (e) {
      if (!mounted) return;
      final messengerCatch = ScaffoldMessenger.of(context);
      messengerCatch.showSnackBar(
        SnackBar(content: Text('เกิดข้อผิดพลาดในการบันทึก: $e')),
      );
      setState(() {
        _isSaving = false;
      });
      return;
    }

    if (!mounted) return;
    setState(() {
      _isSaving = false;
    });
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
    final String rawTelephone = widget.patient.telephone ?? '';
    final String formattedTelephone =
        ThaiNumberFormatter.formatPhoneNumber(rawTelephone);
    final String displayTelephone =
        formattedTelephone.isEmpty ? '-' : formattedTelephone;
    final String gender = widget.patient.gender;
    final String medicalHistory = widget.patient.medicalHistory ?? 'ไม่มี';
    final String allergy = widget.patient.allergy ?? 'ไม่มี';
    final String treatment = widget.appointment.treatment;
    final DateTime startTime = widget.appointment.startTime;
    final DateTime endTime = widget.appointment.endTime;
    final List<dynamic> teethList = widget.appointment.teeth ?? [];
    final String teethString = teethList.join(', ');
    final String fullTreatmentText =
        '$treatment ${teethString.isNotEmpty ? '(#$teethString)' : ''}';

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
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.8),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.purple.shade100),
              ),
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
            GestureDetector(
              onTap: _openPatientDetail,
              behavior: HitTestBehavior.opaque,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
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
                            fontFamily: AppTheme.fontFamily,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Text(
                        'อายุ: $age ปี',
                        style: const TextStyle(
                          fontSize: 16,
                          fontFamily: AppTheme.fontFamily,
                        ),
                      ),
                      const SizedBox(width: 8),
                      if (gender.isNotEmpty) _getGenderIcon(gender, size: 20),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Text(
                        'โทร: $displayTelephone',
                        style: const TextStyle(
                          fontSize: 16,
                          fontFamily: AppTheme.fontFamily,
                        ),
                      ),
                      const Spacer(),
                      if (rawTelephone.isNotEmpty)
                        SizedBox(
                          height: 38,
                          width: 38,
                          child: Material(
                            color: AppTheme.buttonCallBg,
                            shape: const CircleBorder(),
                            clipBehavior: Clip.antiAlias,
                            child: IconButton(
                              padding: EdgeInsets.zero,
                              icon: Image.asset(
                                AppTheme.iconPathCall,
                                width: 20,
                              ),
                              onPressed: _makePhoneCall,
                              tooltip: 'โทรออก',
                            ),
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  _buildInfoRow(text: 'ประวัติการรักษา: $medicalHistory'),
                  const SizedBox(height: 4),
                  _buildInfoRow(text: 'แพ้ยา/แพ้อื่น ๆ: $allergy'),
                ],
              ),
            ),
            const SizedBox(height: 16),
            const SizedBox(height: 16),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Image.asset(
                  'assets/icons/treatment.png',
                  width: 40,
                  height: 40,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        fullTreatmentText,
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w600,
                          fontFamily: AppTheme.fontFamily,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'วันที่: ${DateFormat('dd MMMM yyyy', 'th_TH').format(startTime)}',
                        style: TextStyle(
                          fontSize: 16,
                          color: Colors.grey.shade700,
                          fontFamily: AppTheme.fontFamily,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'เวลา: ${DateFormat.Hm('th_TH').format(startTime)} - ${DateFormat.Hm('th_TH').format(endTime)}',
                        style: TextStyle(
                          fontSize: 16,
                          color: Colors.grey.shade700,
                          fontFamily: AppTheme.fontFamily,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            DropdownButtonFormField<String>(
              value: _currentStatus,
              items:
                  statusOptions
                      .map(
                        (status) => DropdownMenuItem(
                          value: status,
                          child: Text(status),
                        ),
                      )
                      .toList(),
              onChanged: (value) {
                setState(() {
                  _currentStatus = value ?? _currentStatus;
                });
              },
              borderRadius: BorderRadius.circular(16.0),
              decoration: InputDecoration(
                labelText: 'สถานะ',
                filled: true,
                fillColor: Colors.white,
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 16.0,
                  vertical: 12.0,
                ),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(16.0),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(16.0),
                  borderSide: BorderSide(color: Colors.grey.shade400),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(16.0),
                  borderSide: const BorderSide(
                    color: AppTheme.primary,
                    width: 2.0,
                  ),
                ),
              ),
            ),
            if (_currentStatus == 'เลื่อนนัด' ||
                _reasonController.text.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 16.0),
                child: TextField(
                  controller: _reasonController,
                  decoration: InputDecoration(
                    labelText: 'บันทึก / เหตุผลการเลื่อนนัด',
                    filled: true,
                    fillColor: Colors.white.withValues(alpha: 0.8),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(16.0),
                    ),
                  ),
                  maxLines: 2,
                ),
              ),
          ],
        ),
      ),
      actions: [
        Row(
          mainAxisAlignment: MainAxisAlignment.end,
          children: [
            _buildIconActionButton(
              iconPath: 'assets/icons/save.png',
              backgroundColor: AppTheme.buttonCallBg,
              tooltip: 'บันทึกการเปลี่ยนแปลง',
              onPressed: _saveChanges,
              isEnabled: !_isSaving,
            ),
            const SizedBox(width: 8),
            _buildIconActionButton(
              iconPath: 'assets/icons/edit.png',
              backgroundColor: AppTheme.buttonEditBg,
              tooltip: 'แก้ไขนัดหมาย',
              onPressed: _editAppointment,
            ),
            const SizedBox(width: 8),
            _buildIconActionButton(
              iconPath: 'assets/icons/delete.png',
              backgroundColor: AppTheme.buttonDeleteBg,
              tooltip: 'ลบนัดหมาย',
              onPressed: _deleteAppointment,
            ),
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
        Expanded(
          child: Text(
            text,
            style: TextStyle(
              fontSize: 14,
              fontFamily: AppTheme.fontFamily,
              color: Colors.grey.shade800,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildIconActionButton({
    required String iconPath,
    required Color backgroundColor,
    required String tooltip,
    required VoidCallback onPressed,
    bool isEnabled = true,
  }) {
    return SizedBox(
      height: 48,
      width: 56,
      child: Material(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(14),
        clipBehavior: Clip.antiAlias,
        child: IconButton(
          tooltip: tooltip,
          icon: Image.asset(iconPath, width: 26, height: 26),
          onPressed: isEnabled ? onPressed : null,
        ),
      ),
    );
  }
}
