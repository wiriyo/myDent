import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

class AppointmentAddDialog extends StatefulWidget {
  const AppointmentAddDialog({super.key});

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

  String getFormattedDate(DateTime date) {
  final months = [
    '', 'ม.ค.', 'ก.พ.', 'มี.ค.', 'เม.ย.', 'พ.ค.', 'มิ.ย.',
    'ก.ค.', 'ส.ค.', 'ก.ย.', 'ต.ค.', 'พ.ย.', 'ธ.ค.'
  ];
  return '${date.day} ${months[date.month]} ${date.year + 543}';
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
                                  min.toString().padLeft(2, '0') + ' นาที',
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
      _durationController.text = _defaultDuration.toString();
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
    await _checkOrAddTreatmentMaster();

    if (name.isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('กรุณาใส่ชื่อคนไข้')));
      return;
    }

    if (_selectedPatientId == null) {
      final newDoc = await _firestore.collection('patients').add({
        'name': name,
        'createdAt': DateTime.now(),
      });
      _selectedPatientId = newDoc.id;
    }

    if (_selectedPatientId != null) {
      print('✅ บันทึกนัดให้ $_selectedPatientId ($name)');
      if (context.mounted) Navigator.pop(context);
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
                    controller.addListener(() {
                      _patientController.text = controller.text;
                    });
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
                                (option['duration'] as num).toInt();
                            _defaultPrice = (option['price'] as num).toInt();
                            _durationController.text =
                                _defaultDuration.toString();
                          });
                        },
                        fieldViewBuilder: (
                          context,
                          controller,
                          focusNode,
                          onEditingComplete,
                        ) {
                          controller.addListener(() {
                            _treatmentController.text = controller.text;
                          });
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
                        onChanged: (value) => _updateEndTime(),
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

                /// 📆 ช่องเลือกวันที่
                Row(
                  children: [
                    const Text(
                      'วันที่:',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(width: 12),
                    ElevatedButton(
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
                          setState(() {
                            _selectedDate = picked;
                          });
                        }
                      },
                      child: Text(
                        _selectedDate != null
                            ? getFormattedDate(_selectedDate!)
                            : 'เลือกวันที่',
                        style: const TextStyle(color: Colors.black87),
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
                ElevatedButton.icon(
                  onPressed: () {
                    FocusScope.of(context).unfocus();
                    _saveAppointment();
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.orangeAccent.shade100,
                    padding: const EdgeInsets.symmetric(
                      vertical: 12,
                      horizontal: 24,
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
          ),

          Positioned(
            top: 4,
            right: 4,
            child: IconButton(
              icon: Image.asset('assets/icons/back.png', width: 28, height: 28),
              onPressed: () => Navigator.pop(context),
              tooltip: 'ยกเลิก',
            ),
          ),
        ],
      ),
    );
  }
}
