import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class PatientDetailScreen extends StatefulWidget {
  const PatientDetailScreen({super.key});

  @override
  State<PatientDetailScreen> createState() => _PatientDetailScreenState();
}

class _PatientDetailScreenState extends State<PatientDetailScreen> {
  final _formKey = GlobalKey<FormState>();
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _phoneController = TextEditingController();
  final TextEditingController _idCardController = TextEditingController();
  final TextEditingController _addressController = TextEditingController();
  final TextEditingController _allergyController = TextEditingController();
  final TextEditingController _diseaseController = TextEditingController();
  String? _selectedGender = 'หญิง';

  DateTime? _birthDate;
  int? _calculatedAge;

  void _pickBirthDate() async {
    final pickedDate = await showDatePicker(
      context: context,
      initialDate: DateTime(2000, 1, 1),
      firstDate: DateTime(1900),
      lastDate: DateTime.now(),
      locale: const Locale("th", "TH"),
    );

    if (pickedDate != null) {
      setState(() {
        _birthDate = pickedDate;
        _calculatedAge = DateTime.now().year - pickedDate.year;
        if (DateTime.now().month < pickedDate.month ||
            (DateTime.now().month == pickedDate.month && DateTime.now().day < pickedDate.day)) {
          _calculatedAge = _calculatedAge! - 1;
        }
      });
    }
  }

  Widget _buildTextField(String label, TextEditingController controller, {TextInputType? keyboardType}) {
    Icon? icon;
    if (label.contains('ชื่อ')) {
      icon = const Icon(Icons.person);
    } else if (label.contains('โทร')) {
      icon = const Icon(Icons.phone);
    } else if (label.contains('บัตร')) {
      icon = const Icon(Icons.badge);
    } else if (label.contains('ที่อยู่')) {
      icon = const Icon(Icons.home);
    } else if (label.contains('แพ้ยา')) {
      icon = const Icon(Icons.warning_amber);
    } else if (label.contains('โรค')) {
      icon = const Icon(Icons.healing);
    }

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: TextFormField(
        controller: controller,
        keyboardType: keyboardType,
        style: const TextStyle(fontFamily: 'Poppins'),
        decoration: InputDecoration(
          labelText: label,
          labelStyle: const TextStyle(color: Color(0xFF6A4DBA), fontWeight: FontWeight.bold),
          filled: true,
          fillColor: Colors.white,
          prefixIcon: icon != null ? Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: icon,
          ) : null,
          contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(16),
            borderSide: const BorderSide(color: Color(0xFF6A4DBA)),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(16),
            borderSide: const BorderSide(color: Color(0xFFBFA3FF), width: 2),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: const Color(0xFFD9B8FF),
        title: const Text("เพิ่มข้อมูลคนไข้"),
      ),
      backgroundColor: const Color(0xFFEFE0FF),
      body: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Form(
          key: _formKey,
          child: ListView(
            children: [
              Image.asset('assets/images/tooth_logo.png', height: 100),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(child: _buildTextField('ชื่อ - นามสกุล', _nameController)),
                  const SizedBox(width: 12),
                  SizedBox(
                    width: 80,
                    child: DropdownButtonFormField<String>(
                      decoration: InputDecoration(
                        filled: true,
                        fillColor: Colors.white,
                        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(16),
                          borderSide: const BorderSide(color: Color(0xFF6A4DBA)),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(16),
                          borderSide: const BorderSide(color: Color(0xFFBFA3FF), width: 2),
                        ),
                      ),
                      value: _selectedGender,
                      items: const [
                        DropdownMenuItem(
                          value: 'ชาย',
                          child: Icon(Icons.male, color: Color(0xFF6A4DBA), size: 32),
                        ),
                        DropdownMenuItem(
                          value: 'หญิง',
                          child: Icon(Icons.female, color: Color(0xFFEC407A), size: 32),
                        ),
                      ],
                      onChanged: (value) {
                        setState(() {
                          _selectedGender = value;
                        });
                      },
                    ),
                  ),
                ],
              ),
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 8),
                child: Row(
                  children: [
                    Expanded(
                      child: TextFormField(
                        controller: _phoneController,
                        keyboardType: TextInputType.phone,
                        style: const TextStyle(fontFamily: 'Poppins'),
                        decoration: InputDecoration(
                          labelText: 'เบอร์โทรศัพท์',
                          labelStyle: const TextStyle(color: Color(0xFF6A4DBA), fontWeight: FontWeight.bold),
                          filled: true,
                          fillColor: Colors.white,
                          prefixIcon: const Padding(
                            padding: EdgeInsets.symmetric(horizontal: 12),
                            child: Icon(Icons.phone),
                          ),
                          contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(16),
                            borderSide: const BorderSide(color: Color(0xFF6A4DBA)),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(16),
                            borderSide: const BorderSide(color: Color(0xFFBFA3FF), width: 2),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
Container(
  decoration: BoxDecoration(
    gradient: const LinearGradient(
      colors: [Color(0xFF81C784), Color(0xFF66BB6A)],
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
    ),
    borderRadius: BorderRadius.circular(16),
    boxShadow: [
      BoxShadow(
        color: Colors.green.withOpacity(0.3),
        blurRadius: 8,
        offset: const Offset(0, 3),
      ),
    ],
  ),
  child: IconButton(
    icon: const Icon(Icons.phone_rounded, color: Colors.white, size: 28),
    tooltip: 'โทรหาคนไข้',
    onPressed: () {
      final phone = _phoneController.text.trim();
      if (phone.isNotEmpty) {
        final uri = Uri.parse('tel:$phone');
        launchUrl(uri);
      }
    },
  ),
)
                  ],
                ),
              ),
              _buildTextField('เลขบัตรประจำตัวประชาชน', _idCardController),
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                decoration: BoxDecoration(
                  color: Colors.white,
                  border: Border.all(color: const Color(0xFF6A4DBA)),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Center(
                  child: TextButton.icon(
                    onPressed: _pickBirthDate,
                    icon: const Icon(Icons.cake, color: Color(0xFF6A4DBA)),
                    label: Text(
                      _birthDate != null
                          ? DateFormat('dd/MM/yyyy').format(_birthDate!)
                          : "เลือกวันเกิด",
                      style: const TextStyle(
                        fontFamily: 'Poppins',
                        color: Color(0xFF6A4DBA),
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
              ),
              if (_calculatedAge != null)
                Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Text("อายุ: $_calculatedAge ปี", style: const TextStyle(fontFamily: 'Poppins')),
                ),
              _buildTextField('ที่อยู่', _addressController),
              _buildTextField('ประวัติการแพ้ยา', _allergyController),
              _buildTextField('โรคประจำตัว', _diseaseController),
              const SizedBox(height: 24),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFBFA3FF),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(32),
                  ),
                  textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
                onPressed: () {
                  if (_formKey.currentState!.validate()) {
                    final patientData = {
                      'name': _nameController.text.trim(),
                      'phone': _phoneController.text.trim(),
                      'idCard': _idCardController.text.trim(),
                      'birthDate': _birthDate != null ? _birthDate!.toIso8601String() : null,
                      'age': _calculatedAge,
                      'address': _addressController.text.trim(),
                      'allergy': _allergyController.text.trim(),
                      'disease': _diseaseController.text.trim(),
                      'gender': _selectedGender,
                      'createdAt': Timestamp.now(),
                    };

                    FirebaseFirestore.instance.collection('patients').add(patientData).then((_) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('บันทึกข้อมูลเรียบร้อยแล้ว')),
                      );
                      Navigator.pop(context);
                    }).catchError((error) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text('เกิดข้อผิดพลาด: \$error')),
                      );
                    });
                  }
                },
                child: const Text("บันทึกข้อมูล"),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
