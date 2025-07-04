// v1.1.2 - Final
// 📁 lib/screens/appointment_add.dart

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import '../models/appointment_model.dart'; 
import '../services/appointment_service.dart'; 
import '../styles/app_theme.dart';

class AppointmentAddDialog extends StatefulWidget {
  final AppointmentModel? appointment; 
  final DateTime? initialDate;
  final DateTime? initialStartTime;

  const AppointmentAddDialog({
    super.key,
    this.appointment,
    this.initialDate,
    this.initialStartTime,
  });

  @override
  State<AppointmentAddDialog> createState() => _AppointmentAddDialogState();
}

class _AppointmentAddDialogState extends State<AppointmentAddDialog> {
  final _formKey = GlobalKey<FormState>();
  final _appointmentService = AppointmentService();

  String? _selectedPatientId;
  late TextEditingController _patientController;
  late TextEditingController _treatmentController;
  late TextEditingController _durationController;
  late TextEditingController _notesController;
  late TextEditingController _teethController;
  
  late DateTime _selectedDate;
  TimeOfDay? _startTime;
  TimeOfDay? _endTime;
  String _status = 'รอยืนยัน';

  final List<String> statusOptions = [
    'รอยืนยัน',
    'ยืนยันแล้ว',
    'ติดต่อไม่ได้',
    'ไม่มาตามนัด',
    'ปฏิเสธนัด',
  ];

  bool _isEditing = false;

  @override
  void initState() {
    super.initState();
    _isEditing = widget.appointment != null;

    final initialAppointment = widget.appointment;

    _patientController = TextEditingController(text: initialAppointment?.patientName ?? '');
    _selectedPatientId = initialAppointment?.patientId;
    
    _treatmentController = TextEditingController(text: initialAppointment?.treatment ?? '');
    _durationController = TextEditingController(text: initialAppointment?.duration.toString() ?? '30');
    _notesController = TextEditingController(text: initialAppointment?.notes ?? '');
    _teethController = TextEditingController(text: initialAppointment?.teeth?.join(', ') ?? ''); 
    
    _status = initialAppointment?.status ?? 'รอยืนยัน';
    _selectedDate = initialAppointment?.startTime ?? widget.initialDate ?? DateTime.now();
    _startTime = initialAppointment != null 
        ? TimeOfDay.fromDateTime(initialAppointment.startTime)
        : widget.initialStartTime != null 
            ? TimeOfDay.fromDateTime(widget.initialStartTime!) 
            : const TimeOfDay(hour: 9, minute: 0);

    _calculateEndTime();
    _durationController.addListener(_calculateEndTime);
  }

  @override
  void dispose() {
    _patientController.dispose();
    _treatmentController.dispose();
    _durationController.dispose();
    _notesController.dispose();
    _teethController.dispose();
    super.dispose();
  }

  void _calculateEndTime() {
    if (_startTime != null && _durationController.text.isNotEmpty) {
      final durationMinutes = int.tryParse(_durationController.text);
      if (durationMinutes != null) {
        final start = DateTime(0, 0, 0, _startTime!.hour, _startTime!.minute);
        final end = start.add(Duration(minutes: durationMinutes));
        if (mounted) {
          setState(() {
            _endTime = TimeOfDay(hour: end.hour, minute: end.minute);
          });
        }
      }
    }
  }

  Future<void> _pickStartTime() async {
    final picked = await showTimePicker(
      context: context,
      initialTime: _startTime ?? TimeOfDay.now(),
    );
    if (picked != null && mounted) {
      setState(() {
        _startTime = picked;
        _calculateEndTime();
      });
    }
  }

  Future<void> _saveAppointment() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    final userId = FirebaseAuth.instance.currentUser?.uid;
    if (userId == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('เกิดข้อผิดพลาด: ไม่พบข้อมูลผู้ใช้')));
      return;
    }
    
    if (_startTime == null || _endTime == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('เกิดข้อผิดพลาด: ไม่สามารถคำนวณเวลาสิ้นสุดได้')));
      return;
    }
    
    final startTime = DateTime(_selectedDate.year, _selectedDate.month, _selectedDate.day, _startTime!.hour, _startTime!.minute);
    final endTime = DateTime(_selectedDate.year, _selectedDate.month, _selectedDate.day, _endTime!.hour, _endTime!.minute);
    
    final teethList = _teethController.text.split(',').map((e) => e.trim()).where((e) => e.isNotEmpty).toList();

    final appointment = AppointmentModel(
      appointmentId: widget.appointment?.appointmentId,
      userId: userId,
      patientId: _selectedPatientId ?? 'N/A', 
      patientName: _patientController.text.trim(),
      treatment: _treatmentController.text.trim(),
      duration: int.tryParse(_durationController.text.trim()) ?? 30,
      status: _status,
      startTime: startTime,
      endTime: endTime,
      notes: _notesController.text.trim(),
      teeth: teethList,
    );

    try {
      if (_isEditing) {
        await _appointmentService.updateAppointment(appointment);
      } else {
        await _appointmentService.addAppointment(appointment);
      }
      
      if(mounted) {
        Navigator.of(context).pop(true);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('บันทึกนัดหมายเรียบร้อยแล้วค่ะ! ✨', style: TextStyle(fontFamily: AppTheme.fontFamily))),
        );
      }
    } catch (e) {
      if(mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('เกิดข้อผิดพลาด: ${e.toString()}', style: TextStyle(fontFamily: AppTheme.fontFamily))),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: AppTheme.background,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Form(
          key: _formKey,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  _isEditing ? 'แก้ไขนัดหมาย' : 'เพิ่มนัดหมายใหม่',
                  style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: AppTheme.primary),
                ),
                const SizedBox(height: 24),
                _buildPatientField(),
                const SizedBox(height: 16),
                _buildTreatmentField(),
                const SizedBox(height: 16),
                _buildTimeAndDurationFields(),
                const SizedBox(height: 16),
                _buildTeethField(),
                const SizedBox(height: 16),
                _buildNotesField(),
                const SizedBox(height: 16),
                _buildStatusField(),
                const SizedBox(height: 24),
                _buildActionButtons(),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildPatientField() {
    return TextFormField(
      controller: _patientController,
      decoration: const InputDecoration(labelText: 'ชื่อคนไข้'),
      validator: (value) => (value == null || value.isEmpty) ? 'กรุณาใส่ชื่อคนไข้' : null,
    );
  }

  Widget _buildTreatmentField() {
    return TextFormField(
      controller: _treatmentController,
      decoration: const InputDecoration(labelText: 'หัตถการ'),
      validator: (value) => (value == null || value.isEmpty) ? 'กรุณาใส่หัตถการ' : null,
    );
  }
  
  Widget _buildTimeAndDurationFields() {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: InkWell(
            onTap: _pickStartTime,
            child: InputDecorator(
              decoration: InputDecoration(
                labelText: 'เวลาเริ่ม',
                contentPadding: const EdgeInsets.symmetric(vertical: 15, horizontal: 12),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
              ),
              child: Text(
                _startTime?.format(context) ?? 'เลือกเวลา',
                style: const TextStyle(fontSize: 16),
              ),
            ),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: TextFormField(
            controller: _durationController,
            decoration: const InputDecoration(labelText: 'ระยะเวลา (นาที)'),
            keyboardType: TextInputType.number,
            validator: (value) {
              if (value == null || value.isEmpty) return 'ใส่เวลา';
              if (int.tryParse(value) == null) return 'ต้องเป็นตัวเลข';
              return null;
            },
          ),
        ),
      ],
    );
  }

  Widget _buildTeethField() {
    return TextFormField(
      controller: _teethController,
      decoration: const InputDecoration(
        labelText: 'ซี่ฟัน (ถ้ามี)',
        hintText: 'เช่น 18, 28, 46',
      ),
    );
  }

  Widget _buildNotesField() {
    return TextFormField(
      controller: _notesController,
      decoration: const InputDecoration(labelText: 'หมายเหตุ (ถ้ามี)'),
      maxLines: 2,
    );
  }

  Widget _buildStatusField() {
    return DropdownButtonFormField<String>(
      value: _status,
      items: statusOptions.map((status) => DropdownMenuItem(
        value: status,
        child: Text(status),
      )).toList(),
      onChanged: (value) => setState(() => _status = value ?? _status),
      decoration: const InputDecoration(labelText: 'สถานะ'),
    );
  }

  Widget _buildActionButtons() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.end,
      children: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('ยกเลิก'),
        ),
        const SizedBox(width: 8),
        ElevatedButton.icon(
          onPressed: _saveAppointment,
          icon: const Icon(Icons.save),
          label: const Text('บันทึก'),
          style: ElevatedButton.styleFrom(
            backgroundColor: AppTheme.buttonEditBg,
            foregroundColor: AppTheme.buttonEditFg,
          ),
        ),
      ],
    );
  }
}
