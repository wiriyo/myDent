import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';

class PatientAddScreen extends StatefulWidget {
  final String? existingName;
  const PatientAddScreen({super.key, this.existingName});

  @override
  State<PatientAddScreen> createState() => _PatientAddScreenState(existingName);
}

class _PatientAddScreenState extends State<PatientAddScreen> {
  final String? existingName;
  _PatientAddScreenState(this.existingName);
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _phoneController = TextEditingController();
  final _idCardController = TextEditingController();
  final _addressController = TextEditingController();
  final _allergyController = TextEditingController(text: 'ปฏิเสธ');
  final _diseaseController = TextEditingController(text: 'ปฏิเสธ');

  DateTime? _birthDate;
  int _calculatedAge = 0;
  bool _isEditing = false;
  String _selectedGender = 'หญิง';

  void _selectDate() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: DateTime(now.year - 20),
      firstDate: DateTime(1900),
      lastDate: now,
    );
    if (picked != null) {
      setState(() {
        _birthDate = picked;
        _calculatedAge =
            now.year - picked.year -
            (now.month < picked.month ||
                    (now.month == picked.month && now.day < picked.day)
                ? 1
                : 0);
      });
    }
  }

  @override
  void initState() {
    super.initState();
    if (existingName != null) {
      _isEditing = true;
      FirebaseFirestore.instance
          .collection('patients')
          .where('name', isEqualTo: existingName)
          .get()
          .then((snapshot) {
        if (snapshot.docs.isNotEmpty) {
          final data = snapshot.docs.first.data();
          setState(() {
            _nameController.text = data['name'] ?? '';
            _phoneController.text = data['phone'] ?? '';
            _idCardController.text = data['idCard'] ?? '';
            _selectedGender = data['gender'] ?? 'หญิง';
            _addressController.text = data['address'] ?? '';
            _allergyController.text = data['allergy'] ?? '';
            _diseaseController.text = data['disease'] ?? '';
            if (data['birthDate'] != null) {
              _birthDate = DateTime.tryParse(data['birthDate']);
              if (_birthDate != null) {
                final now = DateTime.now();
                _calculatedAge = now.year - _birthDate!.year - (now.month < _birthDate!.month || (now.month == _birthDate!.month && now.day < _birthDate!.day) ? 1 : 0);
              }
            }
          });
        }
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("เพิ่มข้อมูลคนไข้"),
        backgroundColor: const Color(0xFFE0BBFF),
        elevation: 0,
      ),
      backgroundColor: const Color(0xFFEFE0FF),
      body: Padding(
        padding: const EdgeInsets.only(top: 80.0, left: 20.0, right: 20.0),
        
        child: Form(
          key: _formKey,
          child: ListView(
            children: [
              Row(
                children: [
                  Expanded(
                    flex: 4,
                    child: _buildTextField(
                      'ชื่อ - นามสกุล',
                      _nameController,
                      validator:
                          (value) => value!.isEmpty ? 'กรุณากรอกชื่อ' : null,
                    ),
                  ),
                  const SizedBox(width: 12),
                  DropdownButton<String>(
                    value: _selectedGender,
                    icon: const Icon(Icons.arrow_drop_down),
                    underline: Container(),
                    selectedItemBuilder: (BuildContext context) {
                      return ['หญิง', 'ชาย'].map((String value) {
                        return Align(
                          alignment: Alignment.center,
                          child: Icon(
                            value == 'หญิง' ? Icons.female : Icons.male,
                            color:
                                value == 'หญิง'
                                    ? Colors.pinkAccent
                                    : Colors.blueAccent,
                            size: 28,
                          ),
                        );
                      }).toList();
                    },
                    items:
                        ['หญิง', 'ชาย'].map((String value) {
                          return DropdownMenuItem<String>(
                            value: value,
                            child: Icon(
                              value == 'หญิง' ? Icons.female : Icons.male,
                              color:
                                  value == 'หญิง'
                                      ? Colors.pinkAccent
                                      : Colors.blueAccent,
                              size: 28,
                            ),
                          );
                        }).toList(),
                    onChanged: (String? newValue) {
                      setState(() {
                        _selectedGender = newValue!;
                      });
                    },
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    flex: 5,
                    child: _buildTextField(
                      'เบอร์โทรศัพท์',
                      _phoneController,
                      keyboardType: TextInputType.phone,
                      inputFormatters: [
                        FilteringTextInputFormatter.digitsOnly,
                        TextInputFormatter.withFunction((oldValue, newValue) {
                          final text = newValue.text.replaceAll('-', '');
                          String formatted = '';
                          if (text.length >= 3) {
                            formatted += text.substring(0, 3);
                            if (text.length >= 6) {
                              formatted += '-${text.substring(3, 6)}';
                              if (text.length > 6) {
                                formatted +=
                                    '-${text.substring(6, text.length.clamp(6, 10))}';
                              }
                            } else {
                              formatted += '-${text.substring(3)}';
                            }
                          } else {
                            formatted = text;
                          }
                          return TextEditingValue(
                            text: formatted,
                            selection: TextSelection.collapsed(
                              offset: formatted.length,
                            ),
                          );
                        }),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  CircleAvatar(
                    radius: 20,
                    backgroundColor: Colors.green,
                    child: IconButton(
                      icon: const Icon(Icons.phone, color: Colors.white),
                      onPressed: () async {
                        final phone = _phoneController.text.replaceAll('-', '');
                        final uri = Uri.parse('tel:$phone');
                        if (await canLaunchUrl(uri)) {
                          await launchUrl(uri);
                        }
                      },
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              _buildTextField(
                'เลขบัตรประจำตัวประชาชน',
                _idCardController,
                keyboardType: TextInputType.number,
                inputFormatters: [
                  FilteringTextInputFormatter.digitsOnly,
                  TextInputFormatter.withFunction((oldValue, newValue) {
                    final text = newValue.text.replaceAll('-', '');
                    String formatted = '';
                    if (text.isNotEmpty) {
                      formatted += text.substring(0, 1);
                    }
                    if (text.length >= 2) {
                      formatted +=
                          '-${text.substring(1, text.length.clamp(1, 5))}';
                    }
                    if (text.length >= 6) {
                      formatted +=
                          '-${text.substring(5, text.length.clamp(5, 10))}';
                    }
                    if (text.length >= 11) {
                      formatted +=
                          '-${text.substring(10, text.length.clamp(10, 12))}';
                    }
                    if (text.length >= 13) {
                      formatted +=
                          '-${text.substring(12, text.length.clamp(12, 13))}';
                    }
                    return TextEditingValue(
                      text: formatted,
                      selection: TextSelection.collapsed(
                        offset: formatted.length,
                      ),
                    );
                  }),
                ],
              ),
              const SizedBox(height: 12),
              ElevatedButton.icon(
                onPressed: _selectDate,
                icon: const Icon(Icons.cake_outlined),
                label: const Text('เลือกวันเกิด'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFFBEAFF),
                  foregroundColor: Colors.purple,
                  side: const BorderSide(color: Colors.purpleAccent),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              if (_calculatedAge > 0)
                Text(
                  "อายุ: $_calculatedAge ปี",
                  style: const TextStyle(fontFamily: 'Poppins'),
                ),
              const SizedBox(height: 12),
              _buildTextField('ที่อยู่', _addressController),
              const SizedBox(height: 12),
              _buildTextField('ประวัติการแพ้ยา', _allergyController),
              const SizedBox(height: 12),
              _buildTextField('โรคประจำตัว', _diseaseController),
              const SizedBox(height: 24),
              ElevatedButton(
                onPressed: () async {
                  if (_formKey.currentState!.validate()) {
                    final enteredName = _nameController.text.trim();

                    final name = _nameController.text.trim();
                    final phone = _phoneController.text.trim().replaceAll('-', '');

                    List<String> generateKeywords(String input) {
                      input = input.toLowerCase();
                      List<String> keywords = [];
                      for (int i = 1; i <= input.length; i++) {
                        keywords.add(input.substring(0, i));
                      }
                      return keywords;
                    }

                    final patientData = {
                      'name': enteredName,
                      'phone': phone,
                      'idCard': _idCardController.text.trim(),
                      'gender': _selectedGender,
                      'birthDate': _birthDate?.toIso8601String(),
                      'age': _calculatedAge,
                      'address': _addressController.text.trim(),
                      'allergy': _allergyController.text.trim(),
                      'disease': _diseaseController.text.trim(),
                      'createdAt': FieldValue.serverTimestamp(),
                      'keywords': [
                        ...generateKeywords(name),
                        ...generateKeywords(phone),
                      ],
                    };

                    if (_isEditing) {
                      final snapshot = await FirebaseFirestore.instance
                          .collection('patients')
                          .where('name', isEqualTo: existingName)
                          .get();

                      if (snapshot.docs.isNotEmpty) {
                        await FirebaseFirestore.instance
                            .collection('patients')
                            .doc(snapshot.docs.first.id)
                            .update(patientData);
                      }
                    } else {
                      await FirebaseFirestore.instance
                          .collection('patients')
                          .add(patientData);
                    }

                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('บันทึกข้อมูลเรียบร้อยแล้ว'),
                      ),
                    );
                    Navigator.pop(context);
                  }
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFBFA3FF),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(32),
                  ),
                  textStyle: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                child: const Text("บันทึกข้อมูล"),
              ),
            ],
          ),
        ),
      ),
      bottomNavigationBar: BottomAppBar(
        shape: const CircularNotchedRectangle(),
        notchMargin: 8,
        color: const Color(0xFFFBEAFF),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16.0),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              IconButton(
                icon: const Icon(Icons.calendar_today, size: 30),
                color: Colors.purple,
                onPressed: () {
                  Navigator.pushNamed(context, '/patients');
                },
              ),
              IconButton(
                icon: const Icon(Icons.people_alt, size: 30),
                color: Colors.purple,
                onPressed: () {
                  Navigator.pushNamed(context, '/patients');
                },
              ),
              const SizedBox(width: 40),
              IconButton(
                icon: const Icon(Icons.bar_chart, size: 30),
                color: Colors.purple.shade200,
                onPressed: () {
                  Navigator.pushNamed(context, '/reports');
                },
              ),
              IconButton(
                icon: const Icon(Icons.settings, size: 30),
                color: Colors.purple.shade200,
                onPressed: () {
                  Navigator.pushNamed(context, '/settings');
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTextField(
    String label,
    TextEditingController controller, {
    TextInputType? keyboardType,
    List<TextInputFormatter>? inputFormatters,
    String? Function(String?)? validator,
  }) {
    return TextFormField(
      controller: controller,
      keyboardType: keyboardType,
      inputFormatters: inputFormatters,
      validator: validator,
      style: const TextStyle(fontFamily: 'Poppins'),
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: Icon(
          label.contains('ชื่อ')
              ? Icons.person
              : label.contains('โทร')
              ? Icons.phone
              : label.contains('บัตร')
              ? Icons.badge
              : label.contains('เกิด')
              ? Icons.cake
              : label.contains('แพ้')
              ? Icons.medication
              : label.contains('โรค')
              ? Icons.local_hospital
              : label.contains('ที่อยู่')
              ? Icons.home
              : Icons.note_alt,
          color: Colors.deepPurpleAccent,
        ),
        filled: true,
        fillColor: Colors.white,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: Color(0xFF6A4DBA)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: Color(0xFFBFA3FF), width: 2),
        ),
      ),
    );
  }
}
