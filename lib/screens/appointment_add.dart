// ----------------------------------------------------------------
// 📁 lib/screens/appointment_add.dart (UPGRADED)
// v3.3.0 - ✨ Implemented Dual-Wheel Custom Time Picker
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
  List<TreatmentMaster> _allTreatmentsMaster = [];

  Patient? _selectedPatient;
  
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
    _loadInitialData();

    _isEditing = widget.appointment != null;
    final initialAppointment = widget.appointment;

    _patientController = TextEditingController(text: initialAppointment?.patientName ?? '');
    
    if (initialAppointment != null) {
      _selectedPatient = Patient(
        patientId: initialAppointment.patientId,
        name: initialAppointment.patientName,
        prefix: '',
        hnNumber: initialAppointment.hnNumber,
        telephone: initialAppointment.patientPhone,
      );
    }

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

  Future<void> _loadInitialData() async {
    final patientsFuture = _patientService.fetchPatientsOnce();
    final treatmentsFuture = TreatmentMasterService.getAllTreatments().first;

    final results = await Future.wait([patientsFuture, treatmentsFuture]);

    if (mounted) {
      setState(() {
        _allPatients = results[0] as List<Patient>;
        _allTreatmentsMaster = results[1] as List<TreatmentMaster>;
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
      locale: const Locale('th', 'TH'),
      initialDate: _selectedDate,
      firstDate: DateTime(1900),
      lastDate: DateTime.now().add(const Duration(days: 365 * 5)),
      builder: (context, child) {
        return Localizations.override(
          context: context,
          locale: const Locale('th', 'TH'),
          child: Theme(
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
          ),
        );
      },
    );
    if (picked != null && picked != _selectedDate) {
      setState(() {
        _selectedDate = picked;
      });
    }
  }

  // ✨ [DUAL-WHEEL TIME PICKER] เปลี่ยนมาใช้วงล้อเลือกเวลาแบบคู่ค่ะ
  Future<void> _pickStartTime() async {
    final List<int> hours = List<int>.generate(24, (i) => i);
    final List<int> minutes = [0, 15, 30, 45];

    final initialTime = _startTime ?? const TimeOfDay(hour: 9, minute: 0);
    
    // หาค่าเริ่มต้นสำหรับวงล้อชั่วโมง
    int initialHourIndex = hours.indexOf(initialTime.hour);
    if(initialHourIndex == -1) initialHourIndex = 9;

    // หาค่าเริ่มต้นสำหรับวงล้อนาที (หาค่าที่ใกล้เคียงที่สุด)
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
                // วงล้อเลือกชั่วโมง
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
                // วงล้อเลือกนาที
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
    
    if (_selectedPatient == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('กรุณาเลือกคนไข้จากรายการค่ะ')));
      return;
    }

    final startTime = DateTime(_selectedDate.year, _selectedDate.month, _selectedDate.day, _startTime!.hour, _startTime!.minute);
    final endTime = DateTime(_selectedDate.year, _selectedDate.month, _selectedDate.day, _endTime!.hour, _endTime!.minute);

    final teethList = _teethController.text.split(',').map((e) => e.trim()).where((e) => e.isNotEmpty).toList();

    final appointment = AppointmentModel(
      appointmentId: widget.appointment?.appointmentId ?? '',
      userId: userId,
      patientId: _selectedPatient!.patientId,
      patientName: _selectedPatient!.name,
      hnNumber: _selectedPatient!.hnNumber,
      patientPhone: _selectedPatient!.telephone,
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
    return LayoutBuilder(
      builder: (context, constraints) {
        return Autocomplete<Patient>(
          displayStringForOption: (patient) => patient.name,
          initialValue: TextEditingValue(text: _patientController.text),
          optionsBuilder: (TextEditingValue textEditingValue) {
            if (textEditingValue.text.isEmpty) {
              setState(() {
                 _selectedPatient = null;
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
              _selectedPatient = patient;
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
                if (value == null || value.isEmpty || _selectedPatient == null) {
                  return 'กรุณาเลือกคนไข้จากรายการ';
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
                                      Text(option.name, style: const TextStyle(fontWeight: FontWeight.bold)),
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
                    validator: (value) => (value == null || value.isEmpty) ? 'กรุณาใส่หัตถการ' : null,
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
