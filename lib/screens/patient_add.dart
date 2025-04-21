import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';

class PatientAddScreen extends StatefulWidget {
  const PatientAddScreen({super.key});

  @override
  State<PatientAddScreen> createState() => _PatientAddScreenState();
}

class _PatientAddScreenState extends State<PatientAddScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _phoneController = TextEditingController();
  final _idCardController = TextEditingController();
  final _addressController = TextEditingController();
  final _allergyController = TextEditingController(text: 'ปฏิเสธ');
  final _diseaseController = TextEditingController(text: 'ปฏิเสธ');

  DateTime? _birthDate;
  int _calculatedAge = 0;
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
        _calculatedAge = now.year - picked.year - (now.month < picked.month || (now.month == picked.month && now.day < picked.day) ? 1 : 0);
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
      backgroundColor: const Color(0xFFFFF0FA),
      body: Padding(
        padding: const EdgeInsets.all(20.0),
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
                      validator: (value) => value!.isEmpty ? 'กรุณากรอกชื่อ' : null,
                    ),
                  ),
                  const SizedBox(width: 12),
                  DropdownButton<String>(
                    value: _selectedGender,
                    icon: Icon(
                      _selectedGender == 'หญิง' ? Icons.female : Icons.male,
                      color: _selectedGender == 'หญิง' ? Colors.pinkAccent : Colors.blueAccent,
                      size: 28,
                    ),
                    underline: Container(),
                    items: ['หญิง', 'ชาย'].map((String value) {
                      return DropdownMenuItem<String>(
                        value: value,
                        child: const SizedBox.shrink(),
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
                              formatted += '-' + text.substring(3, 6);
                              if (text.length > 6) {
                                formatted += '-' + text.substring(6, text.length.clamp(6, 10));
                              }
                            } else {
                              formatted += '-' + text.substring(3);
                            }
                          } else {
                            formatted = text;
                          }
                          return TextEditingValue(
                            text: formatted,
                            selection: TextSelection.collapsed(offset: formatted.length),
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
                    if (text.length >= 1) {
                      formatted += text.substring(0, 1);
                    }
                    if (text.length >= 2) {
                      formatted += '-' + text.substring(1, text.length.clamp(1, 5));
                    }
                    if (text.length >= 6) {
                      formatted += '-' + text.substring(5, text.length.clamp(5, 10));
                    }
                    if (text.length >= 11) {
                      formatted += '-' + text.substring(10, text.length.clamp(10, 12));
                    }
                    if (text.length >= 13) {
                      formatted += '-' + text.substring(12, text.length.clamp(12, 13));
                    }
                    return TextEditingValue(
                      text: formatted,
                      selection: TextSelection.collapsed(offset: formatted.length),
                    );
                  })
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
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                ),
              ),
              const SizedBox(height: 12),
              if (_calculatedAge > 0)
                Text("อายุ: $_calculatedAge ปี", style: const TextStyle(fontFamily: 'Poppins')),
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

                    final querySnapshot = await FirebaseFirestore.instance
                        .collection('patients')
                        .where('name', isEqualTo: enteredName)
                        .get();

                    if (querySnapshot.docs.isNotEmpty) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('ชื่อซ้ำ: มีคนไข้ชื่อนี้อยู่ในระบบแล้ว')),
                      );
                      return;
                    }

                    final patientData = {
                      'name': enteredName,
                      'phone': _phoneController.text,
                      'idCard': _idCardController.text,
                      'gender': _selectedGender,
                      'birthDate': _birthDate != null ? DateFormat('yyyy-MM-dd').format(_birthDate!) : null,
                      'age': _calculatedAge,
                      'address': _addressController.text,
                      'allergy': _allergyController.text,
                      'disease': _diseaseController.text,
                      'createdAt': Timestamp.now(),
                    };

                    await FirebaseFirestore.instance.collection('patients').add(patientData).then((_) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('บันทึกข้อมูลเรียบร้อยแล้ว')),
                      );
                      Navigator.pop(context);
                    }).catchError((error) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text('เกิดข้อผิดพลาด: $error')),
                      );
                    });
                  }
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFBFA3FF),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(32),
                  ),
                  textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
                child: const Text("บันทึกข้อมูล"),
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
