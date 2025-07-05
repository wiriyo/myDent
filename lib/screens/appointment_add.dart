// v1.2.9 - Final UI & Syntax Fix
// 📁 lib/screens/appointment_add.dart

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/appointment_model.dart';
import '../models/patient.dart';
import '../services/appointment_service.dart';
import '../services/patient_service.dart';
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
  final AppointmentService _appointmentService = AppointmentService();
  final PatientService _patientService = PatientService();

  List<Patient> _allPatients = [];

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

  bool _isEditing = false;

  @override
  void initState() {
    super.initState();
    _loadAllPatients();

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

  Future<void> _loadAllPatients() async {
    final patients = await _patientService.fetchPatientsOnce();
    if (mounted) {
      setState(() {
        _allPatients = patients;
      });
    }
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

  Future<void> _pickDate() async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime.now().subtract(const Duration(days: 365)),
      lastDate: DateTime.now().add(const Duration(days: 365 * 2)),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: const ColorScheme.light(
              primary: AppTheme.primary,
              onPrimary: Colors.white,
              onSurface: AppTheme.textPrimary,
            ),
            textButtonTheme: TextButtonThemeData(
              style: TextButton.styleFrom(
                foregroundColor: AppTheme.primary,
              ),
            ),
          ),
          child: child!,
        );
      },
    );
    if (picked != null && picked != _selectedDate) {
      setState(() {
        _selectedDate = picked;
      });
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

      if (mounted) {
        Navigator.of(context).pop(true);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('บันทึกนัดหมายเรียบร้อยแล้วค่ะ! ✨', style: TextStyle(fontFamily: AppTheme.fontFamily))),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('เกิดข้อผิดพลาด: ${e.toString()}', style: TextStyle(fontFamily: AppTheme.fontFamily))),
        );
      }
    }
  }

  InputDecoration _buildInputDecoration(String label, {Widget? prefixIcon}) {
    return InputDecoration(
      prefixIcon: prefixIcon != null ? Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12.0),
        child: prefixIcon,
      ) : null,
      labelText: label,
      filled: true,
      fillColor: Colors.white.withOpacity(0.7),
      contentPadding: const EdgeInsets.symmetric(vertical: 16.0, horizontal: 16.0),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: BorderSide(color: AppTheme.primary.withOpacity(0.3)),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: BorderSide(color: AppTheme.primary.withOpacity(0.5), width: 1.5),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: const BorderSide(color: AppTheme.primary, width: 2.0),
      ),
    );
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
                _buildPatientAutocompleteField(),
                const SizedBox(height: 16),
                _buildTreatmentAndTeethFields(),
                const SizedBox(height: 16),
                _buildDateField(),
                const SizedBox(height: 16),
                _buildTimeAndDurationFields(),
                const SizedBox(height: 16),
                _buildNotesField(),
                const SizedBox(height: 24),
                _buildActionButtons(),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildPatientAutocompleteField() {
    return Autocomplete<Patient>(
      displayStringForOption: (patient) => patient.name,
      initialValue: TextEditingValue(text: _patientController.text),
      optionsBuilder: (TextEditingValue textEditingValue) {
        _patientController.text = textEditingValue.text;
        if (textEditingValue.text.isEmpty) {
          setState(() {
             _selectedPatientId = null;
          });
          return const Iterable<Patient>.empty();
        }
        return _allPatients.where((patient) {
          final patientName = patient.name.toLowerCase();
          final hnNumber = patient.hnNumber?.toLowerCase() ?? '';
          final query = textEditingValue.text.toLowerCase();
          return patientName.contains(query) || hnNumber.contains(query);
        });
      },
      onSelected: (patient) {
        setState(() {
          _selectedPatientId = patient.patientId;
          _patientController.text = patient.name;
        });
      },
      fieldViewBuilder: (context, textEditingController, focusNode, onFieldSubmitted) {
        return TextFormField(
          controller: textEditingController,
          focusNode: focusNode,
          decoration: _buildInputDecoration(
            'ชื่อคนไข้',
            prefixIcon: Image.asset('assets/icons/user.png', width: 24, height: 24),
          ),
          validator: (value) {
            if (value == null || value.isEmpty) {
              return 'กรุณาใส่ชื่อคนไข้';
            }
            return null;
          },
        );
      },
      optionsViewBuilder: (context, onSelected, options) {
        return Align(
          alignment: Alignment.topLeft,
          child: Material(
            elevation: 4.0,
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxHeight: 250),
              child: ListView.builder(
                padding: EdgeInsets.zero,
                itemCount: options.length,
                itemBuilder: (BuildContext context, int index) {
                  final option = options.elementAt(index);
                  return InkWell(
                    onTap: () => onSelected(option),
                    child: ListTile(
                      title: Text(option.name),
                      subtitle: Text('HN: ${option.hnNumber ?? 'N/A'}'),
                    ),
                  );
                },
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildTreatmentAndTeethFields() {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: TextFormField(
            controller: _treatmentController,
            decoration: _buildInputDecoration(
              'หัตถการ',
              prefixIcon: Image.asset('assets/icons/treatment.png', width: 24, height: 24),
            ),
            validator: (value) => (value == null || value.isEmpty) ? 'กรุณาใส่หัตถการ' : null,
          ),
        ),
        const SizedBox(width: 12),
        SizedBox(
          width: 120,
          child: TextFormField(
            controller: _teethController,
            decoration: _buildInputDecoration(
              'ซี่ฟัน',
              prefixIcon: const Text('#', style: TextStyle(fontSize: 24, color: AppTheme.textSecondary)),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildDateField() {
    return InkWell(
      onTap: _pickDate,
      child: InputDecorator(
        decoration: _buildInputDecoration(
          'วันที่',
          prefixIcon: Image.asset('assets/icons/calendar.png', width: 24, height: 24),
        ),
        child: Text(
          // ✨ The Fix! แก้ไขรูปแบบวันที่ให้ถูกต้องค่ะ
          DateFormat('dd MMMM yyyy', 'th_TH').format(_selectedDate),
          style: const TextStyle(fontSize: 16),
        ),
      ),
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
              decoration: _buildInputDecoration(
                'เวลาเริ่ม',
                prefixIcon: Image.asset('assets/icons/clock.png', width: 24, height: 24),
              ),
              child: Text(
                _startTime?.format(context) ?? 'เลือกเวลา',
                style: const TextStyle(fontSize: 16),
              ),
            ),
          ),
        ),
        const SizedBox(width: 12),
        SizedBox(
          width: 120,
          child: TextFormField(
            controller: _durationController,
            decoration: _buildInputDecoration('ระยะเวลา (นาที)'),
            keyboardType: TextInputType.number,
            textAlign: TextAlign.center,
            validator: (value) {
              if (value == null || value.isEmpty) return 'ใส่เวลา';
              if (int.tryParse(value) == null) return 'ตัวเลข';
              return null;
            },
          ),
        ),
      ],
    );
  }

  Widget _buildNotesField() {
    return TextFormField(
      controller: _notesController,
      decoration: _buildInputDecoration('หมายเหตุ (ถ้ามี)'),
      maxLines: 2,
    );
  }

  Widget _buildActionButtons() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        SizedBox(
          height: 54, 
          width: 96,
          child: Material(
            color: AppTheme.buttonCallBg,
            borderRadius: BorderRadius.circular(21),
            clipBehavior: Clip.antiAlias,
            elevation: 4,
            shadowColor: AppTheme.primary.withOpacity(0.3),
            child: InkWell(
              onTap: _saveAppointment,
              child: Tooltip(
                message: _isEditing ? 'บันทึกการแก้ไข' : 'เพิ่มนัดหมาย',
                child: Padding(
                  padding: const EdgeInsets.all(12.0),
                  child: Image.asset(
                    'assets/icons/save.png',
                  ),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}
