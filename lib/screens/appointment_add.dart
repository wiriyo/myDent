import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

class AppointmentAddDialog extends StatefulWidget {
  final Map<String, dynamic>? appointmentData; // ✅ เพิ่มตรงนี้
  final DateTime? initialDate;
  final DateTime? initialStartTime; // ✅ เพิ่มตัวแปรนี้

  const AppointmentAddDialog({
    super.key,
    this.appointmentData,
    this.initialDate,
    this.initialStartTime, // ✅ เพิ่มตัวแปรนี้
  }); // ✅ อัปเดต constructor

  @override
  State<AppointmentAddDialog> createState() => _AppointmentAddDialogState();
}

class _AppointmentAddDialogState extends State<AppointmentAddDialog> {
  final TextEditingController _patientController = TextEditingController();
  String? _selectedPatientId;

  final TextEditingController _treatmentController = TextEditingController();
  int? _defaultDuration;
  int? _defaultPrice;

  final TextEditingController _durationController = TextEditingController();

  TimeOfDay? _startTime;
  TimeOfDay? _endTime;
  final _firestore = FirebaseFirestore.instance;

  DateTime? _selectedDate = DateTime.now();

  DateTime? _selectedStartTime;
  final TextEditingController _startTimeController = TextEditingController();

  String getFormattedDate(DateTime date) {
    final months = [
      '',
      'ม.ค.',
      'ก.พ.',
      'มี.ค.',
      'เม.ย.',
      'พ.ค.',
      'มิ.ย.',
      'ก.ค.',
      'ส.ค.',
      'ก.ย.',
      'ต.ค.',
      'พ.ย.',
      'ธ.ค.',
    ];
    return '${date.day} ${months[date.month]} ${date.year + 543}';
  }

  final List<String> statusOptions = [
    'รอยืนยัน',
    'ยืนยันแล้ว',
    'ติดต่อไม่ได้',
    'ไม่มาตามนัด',
    'ปฏิเสธนัด',
  ];

  bool _durationManuallyEdited = false;

  String _status = 'รอยืนยัน'; // ค่าสถานะเริ่มต้น

  @override
  void initState() {
    super.initState();

    final data = widget.appointmentData;
    _selectedDate = widget.initialDate ?? DateTime.now();

    _durationController.addListener(() {
      _updateEndTimeIfPossible();
      _durationManuallyEdited = true;
    });

    if (data != null) {
      _selectedPatientId = data['patientId'];
      _patientController.text = data['patientName'] ?? '';
      _treatmentController.text = data['treatment'] ?? '';
      _durationController.text = (data['duration'] ?? '').toString();
      //_updateEndTime();
      _status = data['status'] ?? 'รอยืนยัน';

      final Timestamp? startTimestamp = data['startTime'];
      final Timestamp? endTimestamp = data['endTime'];
      final Timestamp? dateTimestamp = data['date'];

      if (startTimestamp != null) {
        final dt = startTimestamp.toDate();
        _startTime = TimeOfDay(hour: dt.hour, minute: dt.minute);
      }

      if (endTimestamp != null) {
        final dt = endTimestamp.toDate();
        _endTime = TimeOfDay(hour: dt.hour, minute: dt.minute);
      }

      if (dateTimestamp != null) {
        _selectedDate = dateTimestamp.toDate();
      }

      // 🔁 ทำงานทุกครั้ง ไม่ต้องรอ text ว่าง
      _fetchPatientNameIfNeeded();
      _fetchTreatmentDetailsIfNeeded();
    } else {
      // ✅ เพิ่มตรงนี้: ถ้าไม่มี data แต่อาจมี initialStartTime ส่งมา
      final initialTime = widget.initialStartTime;

      if (initialTime != null) {
        _startTime = TimeOfDay(
          hour: initialTime.hour,
          minute: initialTime.minute,
        );

        // 🪄 เพิ่มความน่ารัก: set _selectedDate จาก initialStartTime ด้วย
        _selectedDate = initialTime;
        _calculateEndTime();
      }
    }
  }

  void _calculateEndTime() {
    if (_startTime != null && _durationController.text.isNotEmpty) {
      final durationMinutes = int.tryParse(_durationController.text);
      if (durationMinutes != null) {
        final start = DateTime(0, 0, 0, _startTime!.hour, _startTime!.minute);
        final end = start.add(Duration(minutes: durationMinutes));
        setState(() {
          _endTime = TimeOfDay(hour: end.hour, minute: end.minute);
        });
      }
    }
  }

  Future<void> _fetchPatientName(String patientId) async {
    final doc =
        await FirebaseFirestore.instance
            .collection('patients')
            .doc(patientId)
            .get();

    if (doc.exists) {
      final patientData = doc.data();
      if (patientData != null) {
        setState(() {
          _patientController.text = patientData['name'] ?? '';
        });
      }
    }
  }

  Future<void> _fetchPatientNameIfNeeded() async {
    if (_selectedPatientId != null) {
      final doc =
          await _firestore.collection('patients').doc(_selectedPatientId).get();
      if (doc.exists) {
        final data = doc.data();
        if (data != null && data['name'] != null) {
          setState(() {
            _patientController.text = data['name'];
          });
        }
      }
    }
  }

  Future<void> _fetchTreatmentDetailsIfNeeded() async {
    final treatmentName = _treatmentController.text.trim();
    if (treatmentName.isEmpty) return;

    final snapshot =
        await _firestore
            .collection('treatment_master')
            .where('name', isEqualTo: treatmentName)
            .limit(1)
            .get();

    if (snapshot.docs.isNotEmpty) {
      final data = snapshot.docs.first.data();
      final duration = (data['duration'] as num?)?.toInt();
      final price = (data['price'] as num?)?.toInt();

      setState(() {
        if (duration != null && !_durationManuallyEdited) {
          _durationController.text = duration.toString();
          _defaultDuration = duration;
        }
        if (price != null) {
          _defaultPrice = price;
        }
      });
    }
  }

  Future<void> _pickStartTime() async {
    final picked = await showTimePicker(
      context: context,
      initialTime: _startTime ?? TimeOfDay.now(),
    );

    if (picked != null) {
      setState(() {
        _startTime = picked;
        _updateEndTime(); // คำนวณเวลาสิ้นสุดใหม่
      });
    }
  }

  Future<TimeOfDay?> showCustomTimePicker(
    BuildContext context,
    TimeOfDay? initialTime,
  ) async {
    int selectedHour = initialTime?.hour ?? TimeOfDay.now().hour;
    int selectedMinute =
        (initialTime?.minute ?? TimeOfDay.now().minute) ~/ 15 * 15;

    return showModalBottomSheet<TimeOfDay>(
      context: context,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) {
        return Container(
          padding: const EdgeInsets.all(16),
          decoration: const BoxDecoration(
            color: Color(0xFFFBEAFF),
            borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                'เลือกเวลาเริ่ม',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF6A4DBA),
                ),
              ),
              const SizedBox(height: 16),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  DropdownButton<int>(
                    value: selectedHour,
                    onChanged:
                        (value) => value != null ? selectedHour = value : null,
                    items:
                        List.generate(24, (index) => index)
                            .map(
                              (hour) => DropdownMenuItem(
                                value: hour,
                                child: Text('$hour น.'),
                              ),
                            )
                            .toList(),
                  ),
                  const SizedBox(width: 20),
                  DropdownButton<int>(
                    value: selectedMinute,
                    onChanged:
                        (value) =>
                            value != null ? selectedMinute = value : null,
                    items:
                        [0, 15, 30, 45]
                            .map(
                              (min) => DropdownMenuItem(
                                value: min,
                                child: Text(
                                  '${min.toString().padLeft(2, '0')} นาที',
                                ),
                              ),
                            )
                            .toList(),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: () {
                  Navigator.pop(
                    context,
                    TimeOfDay(hour: selectedHour, minute: selectedMinute),
                  );
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.orangeAccent.shade100,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                ),
                child: const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                  child: Text(
                    'ตกลง',
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  void _updateEndTimeIfPossible() {
    if (_startTime != null && _durationController.text.isNotEmpty) {
      final durationMinutes = int.tryParse(_durationController.text);
      if (durationMinutes != null) {
        final startDateTime = DateTime(
          _selectedDate!.year,
          _selectedDate!.month,
          _selectedDate!.day,
          _startTime!.hour,
          _startTime!.minute,
        );
        final endDateTime = startDateTime.add(
          Duration(minutes: durationMinutes),
        );
        _endTime = TimeOfDay(
          hour: endDateTime.hour,
          minute: endDateTime.minute,
        );
        setState(() {}); // อัปเดต UI
      }
    }
  }

  void _updateEndTime() {
    if (_startTime != null && _durationController.text.isNotEmpty) {
      final duration = int.tryParse(_durationController.text);
      if (duration != null) {
        final endMinutes =
            _startTime!.hour * 60 + _startTime!.minute + duration;
        setState(() {
          _endTime = TimeOfDay(hour: endMinutes ~/ 60, minute: endMinutes % 60);
        });
      }
    }
  }

  Future<void> _checkOrAddTreatmentMaster() async {
    final name = _treatmentController.text.trim();
    await Future.delayed(const Duration(milliseconds: 50));

    final durationText = _durationController.text.trim();
    int? duration = int.tryParse(durationText);
    if (duration == null || duration <= 0) duration = 30;

    final snapshot =
        await _firestore
            .collection('treatment_master')
            .where('name', isEqualTo: name)
            .get();

    if (snapshot.docs.isEmpty) {
      await _firestore.collection('treatment_master').add({
        'name': name,
        'duration': duration,
        'price': 500,
        'createdAt': DateTime.now(),
      });
      print('🟢 เพิ่มหัตถการใหม่: $name ($duration นาที)');
    } else {
      final data = snapshot.docs.first.data();
      _defaultDuration = (data['duration'] as num).toInt();
      _defaultPrice = (data['price'] as num).toInt();
      //_durationController.text = _defaultDuration.toString();
      if (!_durationManuallyEdited) {
        _durationController.text = _defaultDuration.toString();
      }
    }
  }

  Future<List<Map<String, dynamic>>> _searchPatients(String query) async {
    final snapshot =
        await _firestore
            .collection('patients')
            .where('name', isGreaterThanOrEqualTo: query)
            .where('name', isLessThanOrEqualTo: '$query\uf8ff')
            .get();

    return snapshot.docs.map((doc) {
      final data = doc.data();
      return {'id': doc.id, 'name': data['name']};
    }).toList();
  }

  Future<void> _addNewPatient(String name) async {
    final newDoc = await _firestore.collection('patients').add({
      'name': name,
      'createdAt': DateTime.now(),
    });
    setState(() {
      _selectedPatientId = newDoc.id;
      _patientController.text = name;
    });
  }

  Future<void> _saveAppointment() async {
    final name = _patientController.text.trim();
    final treatment = _treatmentController.text.trim();
    final duration = int.tryParse(_durationController.text.trim()) ?? 30;

    if (name.isEmpty ||
        treatment.isEmpty ||
        _selectedDate == null ||
        _startTime == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('กรุณากรอกข้อมูลให้ครบถ้วน')),
      );
      return;
    }

    await _checkOrAddTreatmentMaster();

    if (_selectedPatientId == null) {
      final newDoc = await _firestore.collection('patients').add({
        'name': name,
        'createdAt': DateTime.now(),
      });
      _selectedPatientId = newDoc.id;
    }

    final startDateTime = DateTime(
      _selectedDate!.year,
      _selectedDate!.month,
      _selectedDate!.day,
      _startTime!.hour,
      _startTime!.minute,
    );

    final endDateTime =
        _endTime != null
            ? DateTime(
              _selectedDate!.year,
              _selectedDate!.month,
              _selectedDate!.day,
              _endTime!.hour,
              _endTime!.minute,
            )
            : null;

    final appointmentData = {
      'patientId': _selectedPatientId,
      'patientName': name,
      'treatment': treatment,
      'duration': duration,
      'status': _status,
      'date': Timestamp.fromDate(_selectedDate!),
      'startTime': Timestamp.fromDate(startDateTime),
      'endTime': endDateTime != null ? Timestamp.fromDate(endDateTime) : null,
      'updatedAt': FieldValue.serverTimestamp(),
    };

    final existingId = widget.appointmentData?['appointmentId'];

    if (existingId != null && existingId.toString().isNotEmpty) {
      // 🎯 อัปเดตนัดเดิม
      await _firestore
          .collection('appointments')
          .doc(existingId)
          .update(appointmentData);
    } else {
      // 🆕 สร้างนัดใหม่
      final docRef = await _firestore.collection('appointments').add({
        ...appointmentData,
        'createdAt': FieldValue.serverTimestamp(),
      });
      await docRef.update({'appointmentId': docRef.id});
    }

    if (context.mounted) {
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('บันทึกนัดหมายเรียบร้อยแล้ว')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: const Color(0xFFFBEAFF),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: Stack(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 24, 20, 20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text(
                  'เพิ่มนัดหมายใหม่',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF6A4DBA),
                  ),
                ),
                const SizedBox(height: 16),

                Autocomplete<Map<String, dynamic>>(
                  displayStringForOption: (option) => option['name'],
                  optionsBuilder: (textEditingValue) async {
                    if (textEditingValue.text.isEmpty) return [];
                    return await _searchPatients(textEditingValue.text);
                  },
                  onSelected: (option) {
                    setState(() {
                      _selectedPatientId = option['id'];
                      _patientController.text = option['name'];
                    });
                  },
                  fieldViewBuilder: (
                    context,
                    controller,
                    focusNode,
                    onEditingComplete,
                  ) {
                    controller.text =
                        _patientController.text; // 💜 sync ค่าให้ controller

                    return TextField(
                      controller: controller,
                      focusNode: focusNode,
                      onEditingComplete: () {
                        _patientController.text = controller.text;
                        _selectedPatientId = null;
                        onEditingComplete();
                      },
                      decoration: InputDecoration(
                        labelText: 'ชื่อคนไข้',
                        filled: true,
                        fillColor: Colors.white,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                    );
                  },

                  optionsViewBuilder: (context, onSelected, options) {
                    final maxVisibleItems = 4;
                    final itemHeight = 50.0;
                    return Align(
                      alignment: Alignment.topLeft,
                      child: Material(
                        elevation: 4,
                        borderRadius: BorderRadius.circular(12),
                        child: ConstrainedBox(
                          constraints: BoxConstraints(
                            maxHeight:
                                itemHeight *
                                options.length.clamp(1, maxVisibleItems),
                            minWidth: MediaQuery.of(context).size.width * 0.75,
                          ),
                          child: ListView.separated(
                            padding: const EdgeInsets.symmetric(vertical: 8),
                            shrinkWrap: true,
                            itemCount: options.length,
                            itemBuilder: (context, index) {
                              final option = options.elementAt(index);
                              return ListTile(
                                title: Text(option['name']),
                                onTap: () => onSelected(option),
                                dense: true,
                                visualDensity: const VisualDensity(
                                  horizontal: 0,
                                  vertical: -2,
                                ),
                              );
                            },
                            separatorBuilder:
                                (_, __) => const Divider(height: 1),
                          ),
                        ),
                      ),
                    );
                  },
                ),

                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      flex: 4,
                      child: Autocomplete<Map<String, dynamic>>(
                        displayStringForOption: (option) => option['name'],
                        optionsBuilder: (textEditingValue) async {
                          if (textEditingValue.text.isEmpty) return [];
                          final snapshot =
                              await _firestore
                                  .collection('treatment_master')
                                  .where(
                                    'name',
                                    isGreaterThanOrEqualTo:
                                        textEditingValue.text,
                                  )
                                  .where(
                                    'name',
                                    isLessThanOrEqualTo:
                                        '${textEditingValue.text}\uf8ff',
                                  )
                                  .get();
                          return snapshot.docs.map((doc) {
                            final data = doc.data();
                            return {
                              'id': doc.id,
                              'name': data['name'],
                              'duration': data['duration'],
                              'price': data['price'],
                            };
                          }).toList();
                        },
                        onSelected: (option) {
                          setState(() {
                            _treatmentController.text = option['name'];
                            _defaultDuration =
                                (option['duration'] as num?)?.toInt();
                            _defaultPrice = (option['price'] as num?)?.toInt();

                            if (!_durationManuallyEdited &&
                                _defaultDuration != null) {
                              _durationController.text =
                                  _defaultDuration.toString();
                            }
                          });
                        },

                        fieldViewBuilder: (
                          context,
                          controller,
                          focusNode,
                          onEditingComplete,
                        ) {
                          controller.text =
                              _treatmentController
                                  .text; // 💜 sync ค่าให้ controller

                          return TextField(
                            controller: controller,
                            focusNode: focusNode,
                            onEditingComplete: onEditingComplete,
                            decoration: InputDecoration(
                              labelText: 'หัตถการ',
                              filled: true,
                              fillColor: Colors.white,
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                          );
                        },

                        optionsViewBuilder: (context, onSelected, options) {
                          final maxVisibleItems = 4;
                          final itemHeight = 48.0;
                          return Align(
                            alignment: Alignment.topLeft,
                            child: Material(
                              elevation: 4,
                              borderRadius: BorderRadius.circular(12),
                              child: ConstrainedBox(
                                constraints: BoxConstraints(
                                  maxHeight:
                                      itemHeight *
                                      options.length.clamp(1, maxVisibleItems),
                                ),
                                child: ListView.builder(
                                  padding: const EdgeInsets.symmetric(
                                    vertical: 4,
                                  ),
                                  shrinkWrap: true,
                                  itemCount: options.length,
                                  itemBuilder: (context, index) {
                                    final option = options.elementAt(index);
                                    return ListTile(
                                      dense: true,
                                      visualDensity: const VisualDensity(
                                        vertical: -2,
                                      ),
                                      title: Text(option['name']),
                                      onTap: () => onSelected(option),
                                    );
                                  },
                                ),
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      flex: 1,
                      child: TextField(
                        controller: _durationController,
                        keyboardType: TextInputType.number,
                        onChanged: (value) {
                          _updateEndTime();
                          _durationManuallyEdited = true;
                        },
                        decoration: InputDecoration(
                          labelText: 'นาที',
                          filled: true,
                          fillColor: Colors.white,
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      child: DropdownButtonFormField<String>(
                        value: _status,
                        items:
                            statusOptions.map((status) {
                              return DropdownMenuItem(
                                value: status,
                                child: Text(
                                  status,
                                  style: const TextStyle(fontSize: 14),
                                ),
                              );
                            }).toList(),
                        onChanged:
                            (value) =>
                                setState(() => _status = value ?? _status),
                        decoration: InputDecoration(
                          labelText: 'สถานะ',
                          filled: true,
                          fillColor: Colors.white,
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.purple.shade100,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        onPressed: () async {
                          final picked = await showDatePicker(
                            context: context,
                            initialDate: _selectedDate ?? DateTime.now(),
                            firstDate: DateTime(2020),
                            lastDate: DateTime(2035),
                            locale: const Locale('th', 'TH'),
                          );
                          if (picked != null) {
                            setState(() => _selectedDate = picked);
                          }
                        },
                        child: Text(
                          _selectedDate != null
                              ? getFormattedDate(_selectedDate!)
                              : 'เลือกวันที่',
                          style: const TextStyle(color: Colors.black87),
                        ),
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 16),
                Row(
                  children: [
                    const Text(
                      'เวลาเริ่ม:',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(width: 12),
                    ElevatedButton(
                      onPressed: _pickStartTime,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.purple.shade100,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: Text(
                        _startTime != null
                            ? _startTime!.format(context)
                            : 'เลือกเวลา',
                        style: const TextStyle(color: Colors.black87),
                      ),
                    ),

                    const SizedBox(width: 20),

                    /// ✨ เพิ่ม Flexible ตรงนี้เพื่อให้สิ้นสุดไม่ล้น
                    if (_endTime != null)
                      Flexible(
                        child: Text(
                          'สิ้นสุด: ${_endTime!.format(context)}',
                          style: const TextStyle(color: Colors.grey),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                  ],
                ),

                const SizedBox(height: 24),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    if (widget.appointmentData != null)
                      ElevatedButton.icon(
                        onPressed: () async {
                          final confirm = await showDialog<bool>(
                            context: context,
                            builder:
                                (context) => AlertDialog(
                                  title: const Text('ยืนยันการลบ'),
                                  content: const Text(
                                    'คุณต้องการลบนัดหมายนี้ใช่หรือไม่?',
                                  ),
                                  actions: [
                                    TextButton(
                                      onPressed:
                                          () => Navigator.pop(context, false),
                                      child: const Text('ยกเลิก'),
                                    ),
                                    TextButton(
                                      onPressed:
                                          () => Navigator.pop(context, true),
                                      child: const Text(
                                        'ลบ',
                                        style: TextStyle(color: Colors.red),
                                      ),
                                    ),
                                  ],
                                ),
                          );

                          if (confirm == true &&
                              widget.appointmentData!['id'] != null) {
                            await FirebaseFirestore.instance
                                .collection('appointments')
                                .doc(widget.appointmentData!['id'])
                                .delete();

                            if (context.mounted) {
                              Navigator.pop(context);
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text('ลบนัดหมายเรียบร้อยแล้ว'),
                                ),
                              );
                            }
                          }
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.redAccent.shade100,
                          padding: const EdgeInsets.symmetric(
                            horizontal: 20,
                            vertical: 12,
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                          ),
                        ),
                        icon: Image.asset(
                          'assets/icons/delete.png',
                          width: 24,
                          height: 24,
                        ),
                        label: const Text(
                          'ลบ',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    const SizedBox(width: 12),
                    ElevatedButton.icon(
                      onPressed: () {
                        FocusScope.of(context).unfocus();
                        _saveAppointment();
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.orangeAccent.shade100,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 24,
                          vertical: 12,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                      ),
                      icon: Image.asset(
                        'assets/icons/save.png',
                        width: 24,
                        height: 24,
                      ),
                      label: const Text(
                        'บันทึก',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
