// ----------------------------------------------------------------
// 📁 lib/screens/appointment_add.dart (v1.8 - 💖 Laila's Treatment Info Upgrade!)
// ----------------------------------------------------------------
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/appointment_model.dart';
import '../models/patient.dart';
import '../models/treatment_master.dart';
import '../services/appointment_service.dart';
import '../services/patient_service.dart';
import '../services/treatment_master_service.dart';
import '../styles/app_theme.dart';
import '../widgets/custom_date_picker.dart';
import 'package:provider/provider.dart';
import '../auth/auth_provider.dart';

class AppointmentAddDialog extends StatefulWidget {
  final AppointmentModel? appointment;
  final DateTime? initialDate;
  final DateTime? initialStartTime;
  final Patient? initialPatient;
  // 💖✨ START: TREATMENT INFO UPGRADE v1.8 ✨💖
  // เพิ่ม "ช่องรับโพย" สำหรับข้อมูลการรักษาเริ่มต้นค่ะ
  final String? initialTreatment;
  final String? initialTeeth;
  // 💖✨ END: TREATMENT INFO UPGRADE v1.8 ✨💖

  const AppointmentAddDialog({
    super.key,
    this.appointment,
    this.initialDate,
    this.initialStartTime,
    this.initialPatient,
    this.initialTreatment, // เพิ่มใน constructor
    this.initialTeeth,     // เพิ่มใน constructor
  });

  @override
  State<AppointmentAddDialog> createState() => _AppointmentAddDialogState();
}

class _AppointmentAddDialogState extends State<AppointmentAddDialog> {
  final _formKey = GlobalKey<FormState>();
  AppointmentService? _appointmentService;
  final PatientService _patientService = PatientService();
  List<Patient> _allPatients = [];
  List<TreatmentMaster> _allTreatmentsMaster = [];
  Patient? _selectedPatient;

  late TextEditingController _patientController;
  TextEditingController? _patientFieldController;
  late TextEditingController _treatmentController;
  late TextEditingController _durationController;
  late TextEditingController _notesController;
  late TextEditingController _teethController;
  late DateTime _selectedDate;
  TimeOfDay? _startTime;
  TimeOfDay? _endTime;
  String _status = 'รอยืนยัน';
  bool _isEditing = false;
  bool _isChainedAppointment = false;

  @override
  void initState() {
    super.initState();
    _loadInitialData();
    _isEditing = widget.appointment != null;
    _isChainedAppointment = widget.initialPatient != null;
    final initialAppointment = widget.appointment;
    String initialPatientName = '';
    if (_isChainedAppointment) {
      _selectedPatient = widget.initialPatient;
      initialPatientName = '${widget.initialPatient!.prefix}${widget.initialPatient!.name}';
    } else if (_isEditing) {
      _patientService.getPatientById(initialAppointment!.patientId).then((patient) {
        if (patient != null && mounted) {
          setState(() {
            _selectedPatient = patient;
          });
        }
      });
      initialPatientName = initialAppointment.patientName;
    }
    
    _patientController = TextEditingController(text: initialPatientName);
    // 💖✨ START: TREATMENT INFO UPGRADE v1.8 ✨💖
    // ใช้ข้อมูลจาก "โพย" ที่ได้รับมาเพื่อกรอกข้อมูลเริ่มต้นค่ะ
    _treatmentController = TextEditingController(text: initialAppointment?.treatment ?? widget.initialTreatment ?? '');
    _teethController = TextEditingController(text: initialAppointment?.teeth?.join(', ') ?? widget.initialTeeth ?? '');
    // 💖✨ END: TREATMENT INFO UPGRADE v1.8 ✨💖
    _durationController = TextEditingController(text: initialAppointment?.duration.toString() ?? '30');
    _notesController = TextEditingController(text: initialAppointment?.notes ?? '');
    _status = initialAppointment?.status ?? 'รอยืนยัน';
    _selectedDate = initialAppointment?.startTime ?? widget.initialDate ?? DateTime.now();
    
    _startTime = initialAppointment != null
        ? TimeOfDay.fromDateTime(initialAppointment.startTime)
        : widget.initialStartTime != null
            ? TimeOfDay.fromDateTime(widget.initialStartTime!)
            : const TimeOfDay(hour: 9, minute: 0);
    _calculateEndTime();
    _durationController.addListener(_calculateEndTime);

    // ✅ สร้าง AppointmentService พร้อม clinicId จาก Provider
    final authProvider = Provider.of<AppAuthProvider>(context, listen: false);
    final clinicId = authProvider.verifiedClinicId;
    if (clinicId != null && clinicId.isNotEmpty) {
      _appointmentService = AppointmentService(clinicId: clinicId);
    }
  }

  Future<void> _loadInitialData() async {
    // ใช้ clinicId เพื่อดึงรายชื่อคนไข้เฉพาะคลินิก
    final authProvider = Provider.of<AppAuthProvider>(context, listen: false);
    final clinicId = authProvider.verifiedClinicId;
    final patientsFuture = (clinicId != null && clinicId.isNotEmpty)
        ? PatientService(clinicId: clinicId).fetchPatientsOnce()
        : _patientService.fetchPatientsOnce();
    final treatmentsFuture = TreatmentMasterService.getAllTreatments().first;
    final results = await Future.wait([patientsFuture, treatmentsFuture]);
    if (mounted) {
      setState(() {
        _allPatients = results[0] as List<Patient>;
        _allTreatmentsMaster = results[1] as List<TreatmentMaster>;
      });
    }
  }

  String _normalizePatientName(String value) {
    return value.replaceAll(RegExp(r'\s+'), '').toLowerCase();
  }

  Patient? _findPatientByDisplayName(String displayName) {
    final normalizedInput = _normalizePatientName(displayName);
    final normalizedHnInput = displayName.replaceAll(RegExp(r'\s+'), '').toLowerCase();
    Patient? potentialNameOnlyMatch;
    bool hasMultipleNameOnlyMatches = false;
    for (final patient in _allPatients) {
      final candidate = _normalizePatientName('${patient.prefix}${patient.name}');
      if (candidate == normalizedInput) {
        return patient;
      }
      final hnNumber = patient.hnNumber;
      if (hnNumber != null && hnNumber.isNotEmpty) {
        final normalizedHn = hnNumber.replaceAll(RegExp(r'\s+'), '').toLowerCase();
        if (normalizedHn == normalizedHnInput) {
          return patient;
        }
      }
      final normalizedNameOnly = _normalizePatientName(patient.name);
      if (normalizedNameOnly == normalizedInput) {
        if (potentialNameOnlyMatch != null &&
            potentialNameOnlyMatch.patientId != patient.patientId) {
          hasMultipleNameOnlyMatches = true;
        } else {
          potentialNameOnlyMatch = patient;
        }
      }
    }
    if (potentialNameOnlyMatch != null && !hasMultipleNameOnlyMatches) {
      return potentialNameOnlyMatch;
    }
    return null;
  }

  void _syncPatientFieldControllers(Patient patient) {
    final displayName = '${patient.prefix}${patient.name}';
    _patientController.text = displayName;
    if (_patientFieldController != null && _patientFieldController!.text != displayName) {
      _patientFieldController!.text = displayName;
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
    final DateTime? picked = await showBuddhistDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime(DateTime.now().year - 100),
      lastDate: DateTime.now().add(const Duration(days: 365 * 5)),
    );
    
    if (picked != null && picked != _selectedDate) {
      setState(() {
        _selectedDate = picked;
      });
    }
  }

  Future<void> _pickStartTime() async {
    final List<int> hours = List<int>.generate(24, (i) => i);
    final List<int> minutes = [0, 15, 30, 45];
    final initialTime = _startTime ?? const TimeOfDay(hour: 9, minute: 0);
    
    int initialHourIndex = hours.indexOf(initialTime.hour);
    if(initialHourIndex == -1) initialHourIndex = 9;
    int initialMinuteIndex = 0;
    int minDiff = 60;
    for(int i=0; i < minutes.length; i++){
      int diff = (minutes[i] - initialTime.minute).abs();
      if(diff < minDiff){
        minDiff = diff;
        initialMinuteIndex = i;
      }
    }

    final hourController = FixedExtentScrollController(initialItem: initialHourIndex);
    final minuteController = FixedExtentScrollController(initialItem: initialMinuteIndex);
    TimeOfDay? pickedTime;

    await showDialog<void>(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('เลือกเวลาเริ่ม', style: TextStyle(fontFamily: AppTheme.fontFamily)),
          content: SizedBox(
            height: 200,
            width: 200,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Expanded(
                  child: ListWheelScrollView.useDelegate(
                    controller: hourController,
                    itemExtent: 50,
                    perspective: 0.005,
                    diameterRatio: 1.2,
                    physics: const FixedExtentScrollPhysics(),
                    childDelegate: ListWheelChildBuilderDelegate(
                      childCount: hours.length,
                      builder: (context, index) {
                        return Center(
                          child: Text(
                            hours[index].toString().padLeft(2, '0'),
                            style: const TextStyle(fontSize: 24, fontFamily: AppTheme.fontFamily),
                          ),
                        );
                      },
                    ),
                  ),
                ),
                const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 8.0),
                  child: Text(':', style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
                ),
                Expanded(
                  child: ListWheelScrollView.useDelegate(
                    controller: minuteController,
                    itemExtent: 50,
                    perspective: 0.005,
                    diameterRatio: 1.2,
                    physics: const FixedExtentScrollPhysics(),
                    childDelegate: ListWheelChildBuilderDelegate(
                      childCount: minutes.length,
                      builder: (context, index) {
                        return Center(
                          child: Text(
                            minutes[index].toString().padLeft(2, '0'),
                            style: const TextStyle(fontSize: 24, fontFamily: AppTheme.fontFamily),
                          ),
                        );
                      },
                    ),
                  ),
                ),
              ],
            ),
          ),
          actions: <Widget>[
            TextButton(
              child: const Text('ยกเลิก'),
              onPressed: () => Navigator.of(context).pop(),
            ),
            TextButton(
              child: const Text('ตกลง'),
              onPressed: () {
                final selectedHour = hours[hourController.selectedItem];
                final selectedMinute = minutes[minuteController.selectedItem];
                pickedTime = TimeOfDay(hour: selectedHour, minute: selectedMinute);
                Navigator.of(context).pop();
              },
            ),
          ],
        );
      },
    );

    if (pickedTime != null && mounted) {
      setState(() {
        _startTime = pickedTime;
        _calculateEndTime();
      });
    }
  }

  Future<void> _saveAppointment() async {
    if (_appointmentService == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('ไม่พบรหัสคลินิก กรุณาเข้าสู่ระบบใหม่')),
      );
      return;
    }
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
    final clinicId = Provider.of<AppAuthProvider>(context, listen: false).verifiedClinicId;
    if (clinicId == null || clinicId.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('ไม่พบรหัสคลินิก กรุณาเข้าสู่ระบบใหม่')),
      );
      return;
    }

    final rawPatientName = (_patientFieldController?.text ?? _patientController.text).trim();
    if (rawPatientName.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('กรุณากรอกชื่อคนไข้')),
      );
      return;
    }
    final sanitizedPatientName = rawPatientName.replaceAll(RegExp(r'\s+'), ' ').trim();

    Patient? patient = _selectedPatient;
    bool createdNewPatient = false;
    String? createdPatientHn;
    if (patient == null) {
      patient = _findPatientByDisplayName(rawPatientName);
      if (patient != null) {
        if (mounted) {
          setState(() {
            _selectedPatient = patient;
          });
        } else {
          _selectedPatient = patient;
        }
        _syncPatientFieldControllers(patient);
      }
    }

    if (patient == null) {
      try {
        final patientService = PatientService(clinicId: clinicId);
        final newPatient = Patient(
          patientId: '',
          name: sanitizedPatientName,
          prefix: '',
          clinicId: clinicId,
          gender: 'ไม่ระบุ',
        );
        final createdPatient = await patientService.addPatient(newPatient);
        patient = createdPatient;
        createdNewPatient = true;
        createdPatientHn = createdPatient.hnNumber;
        if (mounted) {
          setState(() {
            _selectedPatient = createdPatient;
            if (!_allPatients.any((p) => p.patientId == createdPatient.patientId)) {
              final updatedPatients = [..._allPatients, createdPatient];
              updatedPatients.sort((a, b) => '${a.prefix}${a.name}'.toLowerCase().compareTo('${b.prefix}${b.name}'.toLowerCase()));
              _allPatients = updatedPatients;
            }
          });
        } else {
          _selectedPatient = createdPatient;
          if (!_allPatients.any((p) => p.patientId == createdPatient.patientId)) {
            final updatedPatients = [..._allPatients, createdPatient];
            updatedPatients.sort((a, b) => '${a.prefix}${a.name}'.toLowerCase().compareTo('${b.prefix}${b.name}'.toLowerCase()));
            _allPatients = updatedPatients;
          }
        }
        _syncPatientFieldControllers(createdPatient);
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                'เกิดข้อผิดพลาดในการสร้างข้อมูลคนไข้ใหม่: ${e.toString()}',
                style: const TextStyle(fontFamily: AppTheme.fontFamily),
              ),
            ),
          );
        }
        return;
      }
    }

    final confirmedPatient = patient;
    // The confirmedPatient is guaranteed to be non-null, so this check is unnecessary.

    final startTime = DateTime(_selectedDate.year, _selectedDate.month, _selectedDate.day, _startTime!.hour, _startTime!.minute);
    final endTime = DateTime(_selectedDate.year, _selectedDate.month, _selectedDate.day, _endTime!.hour, _endTime!.minute);
    final teethList = _teethController.text.split(',').map((e) => e.trim()).where((e) => e.isNotEmpty).toList();

    final appointment = AppointmentModel(
      appointmentId: widget.appointment?.appointmentId ?? '',
      userId: userId,
      patientId: confirmedPatient.patientId,
      patientName: confirmedPatient.name,
      clinicId: clinicId,
      hnNumber: confirmedPatient.hnNumber,
      patientPhone: confirmedPatient.telephone,
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
        await _appointmentService!.updateAppointment(appointment);
      } else {
        await _appointmentService!.addAppointment(appointment);
      }
      if (mounted) {
        Navigator.of(context).pop({
          'appointment': appointment,
          'patient': _selectedPatient!,
        });
        final buffer = StringBuffer('บันทึกนัดหมายเรียบร้อยแล้วค่ะ! ✨');
        if (createdNewPatient) {
          final hnInfo = (createdPatientHn != null && createdPatientHn!.isNotEmpty)
              ? ' (HN: ${createdPatientHn!})'
              : '';
          buffer.writeln();
          buffer.write('สร้างคนไข้ใหม่: ${appointment.patientName}$hnInfo');
        }
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              buffer.toString(),
              style: const TextStyle(fontFamily: AppTheme.fontFamily),
            ),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('เกิดข้อผิดพลาด: ${e.toString()}', style: const TextStyle(fontFamily: AppTheme.fontFamily))),
        );
      }
    }
  }

  InputDecoration _buildInputDecoration(String label,
      {Widget? prefixIcon, String? helperText}) {
    return InputDecoration(
      prefixIcon: prefixIcon != null ? Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12.0),
        child: prefixIcon,
      ) : null,
      labelText: label,
      helperText: helperText,
      helperStyle: const TextStyle(fontFamily: AppTheme.fontFamily, color: AppTheme.textSecondary),
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
                _isChainedAppointment
                    ? _buildLockedPatientField()
                    : _buildPatientAutocompleteField(),
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

  Widget _buildLockedPatientField() {
    return TextFormField(
      controller: _patientController,
      readOnly: true,
      decoration: _buildInputDecoration(
        'ชื่อคนไข้',
        prefixIcon: Image.asset('assets/icons/user.png', width: 24, height: 24),
      ),
    );
  }

  Widget _buildPatientAutocompleteField() {
    return LayoutBuilder(
      builder: (context, constraints) {
        return Autocomplete<Patient>(
          displayStringForOption: (patient) => '${patient.prefix}${patient.name}',
          initialValue: TextEditingValue(text: _patientController.text),
          optionsBuilder: (TextEditingValue textEditingValue) {
            if (textEditingValue.text.isEmpty) {
              setState(() {
                  _selectedPatient = null;
              });
              return const Iterable<Patient>.empty();
            }
            return _allPatients.where((patient) {
              final patientName = '${patient.prefix}${patient.name}'.toLowerCase();
              final hnNumber = patient.hnNumber?.toLowerCase() ?? '';
              final query = textEditingValue.text.toLowerCase();
              return patientName.contains(query) || hnNumber.contains(query);
            });
          },
          onSelected: (patient) {
            if (mounted) {
              setState(() {
                _selectedPatient = patient;
              });
            } else {
              _selectedPatient = patient;
            }
            _syncPatientFieldControllers(patient);
          },
          fieldViewBuilder: (context, textEditingController, focusNode, onFieldSubmitted) {
            if (_patientFieldController != textEditingController) {
              _patientFieldController = textEditingController;
              _patientFieldController!.addListener(() {
                final currentText = _patientFieldController!.text;
                if (_selectedPatient == null) return;
                final selectedDisplay = '${_selectedPatient!.prefix}${_selectedPatient!.name}';
                if (_normalizePatientName(currentText) !=
                    _normalizePatientName(selectedDisplay)) {
                  setState(() {
                    _selectedPatient = null;
                  });
                }
              });
            }
            return TextFormField(
              controller: textEditingController,
              focusNode: focusNode,
              decoration: _buildInputDecoration(
                'ค้นหาคนไข้ (ชื่อ หรือ HN)',
                prefixIcon: Image.asset('assets/icons/user.png', width: 24, height: 24),
                helperText: 'ถ้าไม่พบในรายชื่อ สามารถพิมพ์ชื่อใหม่ได้เลยค่ะ',
              ),
              validator: (value) {
                if (value == null || value.trim().isEmpty) {
                  return 'กรุณากรอกชื่อคนไข้';
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
                color: const Color(0xFFFCF5FF),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                  side: BorderSide(color: AppTheme.primary.withOpacity(0.3)),
                ),
                child: SizedBox(
                  width: constraints.maxWidth,
                  child: ConstrainedBox(
                    constraints: BoxConstraints(maxHeight: ((68.0 * options.length) + 24.0).clamp(0.0, 272.0 + 24.0)),
                    child: ListView.builder(
                      shrinkWrap: true,
                      padding: const EdgeInsets.fromLTRB(8.0, 8.0, 8.0, 16.0),
                      itemCount: options.length,
                      itemBuilder: (BuildContext context, int index) {
                        final option = options.elementAt(index);
                        return InkWell(
                          onTap: () => onSelected(option),
                          borderRadius: BorderRadius.circular(12),
                          child: Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                            child: Row(
                              children: [
                                Image.asset('assets/icons/user.png', width: 24, height: 24),
                                const SizedBox(width: 16),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text('${option.prefix}${option.name}', style: const TextStyle(fontWeight: FontWeight.bold)),
                                      Text('HN: ${option.hnNumber ?? 'N/A'}', style: const TextStyle(color: AppTheme.textSecondary)),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                ),
              ),
            );
          },
        );
      }
    );
  }

  Widget _buildTreatmentAndTeethFields() {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          flex: 6,
          child: LayoutBuilder(
            builder: (context, constraints) {
              return Autocomplete<TreatmentMaster>(
                displayStringForOption: (treatment) => treatment.name,
                initialValue: TextEditingValue(text: _treatmentController.text),
                optionsBuilder: (TextEditingValue textEditingValue) {
                  _treatmentController.text = textEditingValue.text;
                  if (textEditingValue.text.isEmpty) {
                    return const Iterable<TreatmentMaster>.empty();
                  }
                  return _allTreatmentsMaster.where((treatment) {
                    return treatment.name
                        .toLowerCase()
                        .contains(textEditingValue.text.toLowerCase());
                  });
                },
                onSelected: (treatment) {
                  setState(() {
                    _treatmentController.text = treatment.name;
                    _durationController.text = treatment.duration.toString();
                    _calculateEndTime();
                  });
                },
                fieldViewBuilder: (context, controller, focusNode, onFieldSubmitted) {
                  return TextFormField(
                    controller: controller,
                    focusNode: focusNode,
                    decoration: _buildInputDecoration(
                      'หัตถการ',
                      prefixIcon: Image.asset('assets/icons/report.png', width: 24, height: 24),
                    ),
                    validator: (value) => (value?.isEmpty ?? true) ? 'กรุณาใส่หัตถการ' : null,
                    
                  );
                },
                optionsViewBuilder: (context, onSelected, options) {
                  return Align(
                    alignment: Alignment.topLeft,
                    child: Material(
                      elevation: 4.0,
                      color: const Color(0xFFFCF5FF),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                        side: BorderSide(color: AppTheme.primary.withOpacity(0.3)),
                      ),
                      child: SizedBox(
                        width: constraints.maxWidth,
                        child: ConstrainedBox(
                          constraints: BoxConstraints(maxHeight: ((64.0 * options.length) + 24.0).clamp(0.0, 256.0 + 24.0)),
                          child: ListView.builder(
                            shrinkWrap: true,
                            padding: const EdgeInsets.fromLTRB(8.0, 8.0, 8.0, 16.0),
                            itemCount: options.length,
                            itemBuilder: (context, index) {
                              final option = options.elementAt(index);
                              return InkWell(
                                onTap: () => onSelected(option),
                                borderRadius: BorderRadius.circular(12),
                                child: Padding(
                                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                                  child: Row(
                                    children: [
                                      Image.asset('assets/icons/report.png', width: 24, height: 24),
                                      const SizedBox(width: 16),
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            Text(option.name, style: const TextStyle(fontWeight: FontWeight.bold)),
                                            Text('เวลา: ${option.duration} นาที', style: const TextStyle(color: AppTheme.textSecondary)),
                                          ],
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              );
                            },
                          ),
                        ),
                      ),
                    ),
                  );
                },
              );
            }
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          flex: 4,
          child: TextFormField(
            controller: _teethController,
            keyboardType: TextInputType.number,
            decoration: _buildInputDecoration(
              'ซี่ฟัน',
              prefixIcon: Image.asset('assets/icons/tooth.png', width: 24, height: 24),
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
          DateFormat('dd MMMM yy', 'th_TH').format(
            DateTime(_selectedDate.year + 543, _selectedDate.month, _selectedDate.day)
          ),
          style: const TextStyle(fontSize: 16),
        ),
      ),
    );
  }

  Widget _buildTimeAndDurationFields() {
    String formatTimeOfDay(TimeOfDay? tod) {
      if (tod == null) return 'เลือกเวลา';
      final now = DateTime.now();
      final dt = DateTime(now.year, now.month, now.day, tod.hour, tod.minute);
      return DateFormat('HH:mm').format(dt);
    }

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
                formatTimeOfDay(_startTime),
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
              final input = value?.trim() ?? '';
              if (input.isEmpty) return 'ใส่เวลา';
              if (int.tryParse(input) == null) return 'ตัวเลข';
              
              if (int.tryParse(input) == null) return 'ตัวเลข';
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
