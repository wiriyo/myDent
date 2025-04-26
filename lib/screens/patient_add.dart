import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

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
  bool _isEditing = false;
  String _selectedGender = 'หญิง';
  String? _docId;

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
        _calculatedAge = now.year - picked.year -
            (now.month < picked.month ||
                    (now.month == picked.month && now.day < picked.day)
                ? 1
                : 0);
      });
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _phoneController.dispose();
    _idCardController.dispose();
    _addressController.dispose();
    _allergyController.dispose();
    _diseaseController.dispose();
    super.dispose();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final args = ModalRoute.of(context)?.settings.arguments;
    if (args != null && args is Map<String, dynamic> && !_isEditing) {
      _isEditing = true;
      _docId = args['docId'] ?? args['id'];
      _nameController.text = args['name'] ?? '';
      _phoneController.text = args['phone'] ?? '';
      _idCardController.text = args['idCard'] ?? '';
      _selectedGender = args['gender'] ?? 'หญิง';
      _addressController.text = args['address'] ?? '';
      _allergyController.text = args['allergy'] ?? 'ปฏิเสธ';
      _diseaseController.text = args['disease'] ?? 'ปฏิเสธ';
      if (args['birthDate'] != null) {
        _birthDate = DateTime.tryParse(args['birthDate']);
        if (_birthDate != null) {
          final now = DateTime.now();
          _calculatedAge = now.year - _birthDate!.year -
              (now.month < _birthDate!.month ||
                      (now.month == _birthDate!.month && now.day < _birthDate!.day)
                  ? 1
                  : 0);
        }
      }
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
                    child: _buildTextField('ชื่อ - นามสกุล', _nameController,
                        validator: (value) =>
                            value!.isEmpty ? 'กรุณากรอกชื่อ' : null),
                  ),
                  const SizedBox(width: 12),
                  DropdownButton<String>(
                    icon: const SizedBox.shrink(),
                    value: _selectedGender,
                    underline: Container(),
                    selectedItemBuilder: (BuildContext context) {
                      return ['หญิง', 'ชาย'].map((String value) {
                        return Align(
                          alignment: Alignment.center,
                          child: Icon(
                            value == 'หญิง' ? Icons.female : Icons.male,
                            color: value == 'หญิง'
                                ? Colors.pinkAccent
                                : Colors.blueAccent,
                            size: 28,
                          ),
                        );
                      }).toList();
                    },
                    items: ['หญิง', 'ชาย'].map((String value) {
                      return DropdownMenuItem<String>(
                        value: value,
                        child: Icon(
                          value == 'หญิง' ? Icons.female : Icons.male,
                          color: value == 'หญิง'
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
              _buildTextField('เบอร์โทรศัพท์', _phoneController,
                  keyboardType: TextInputType.phone),
              const SizedBox(height: 12),
              _buildTextField('เลขบัตรประจำตัวประชาชน', _idCardController,
                  keyboardType: TextInputType.number),
              const SizedBox(height: 12),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  TextButton.icon(
                    onPressed: _selectDate,
                    icon: Image.asset('assets/icons/cake.png', width: 24, height: 24),
                    label: Text(
                      _birthDate != null
                          ? '${_birthDate!.day}/${_birthDate!.month}/${_birthDate!.year}'
                          : 'เลือกวันเกิด',
                      style: const TextStyle(fontSize: 16),
                    ),
                    style: TextButton.styleFrom(
                      backgroundColor: const Color(0xFFFBEAFF),
                      foregroundColor: Colors.purple,
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                        side: const BorderSide(color: Colors.purpleAccent),
                      ),
                    ),
                  ),
                  if (_calculatedAge > 0)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      decoration: BoxDecoration(
                        color: Colors.purple.shade50,
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: Colors.purple.shade200),
                      ),
                      child: Row(
                        children: [
                          Image.asset('assets/icons/age.png', width: 20, height: 20),
                          const SizedBox(width: 6),
                          Text(
                            '$_calculatedAge ปี',
                            style: const TextStyle(
                              fontFamily: 'Poppins',
                              fontWeight: FontWeight.bold,
                              color: Colors.deepPurple,
                            ),
                          ),
                        ],
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 12),
              _buildTextField('ที่อยู่', _addressController),
              const SizedBox(height: 12),
              _buildTextField('ประวัติการแพ้ยา', _allergyController),
              const SizedBox(height: 12),
              _buildTextField('โรคประจำตัว', _diseaseController),
            ],
          ),
        ),
      ),
      bottomNavigationBar: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Row(
          children: [
            Expanded(
              child: ElevatedButton(
                onPressed: () async {
                  if (_formKey.currentState!.validate()) {
                    final confirm = await showDialog<bool>(
                      context: context,
                      builder: (context) => AlertDialog(
                        title: const Text('ยืนยันการบันทึก'),
                        content: const Text('คุณต้องการบันทึกข้อมูลนี้หรือไม่?'),
                        actions: [
                          TextButton(
                            onPressed: () => Navigator.pop(context, false),
                            child: const Text('ยกเลิก'),
                          ),
                          TextButton(
                            onPressed: () => Navigator.pop(context, true),
                            child: const Text('บันทึก'),
                          ),
                        ],
                      ),
                    );

                    if (confirm == true) {
                      final patientData = {
                        'name': _nameController.text.trim(),
                        'phone': _phoneController.text.trim(),
                        'idCard': _idCardController.text.trim(),
                        'gender': _selectedGender,
                        'birthDate': _birthDate?.toIso8601String(),
                        'age': _calculatedAge,
                        'address': _addressController.text.trim(),
                        'allergy': _allergyController.text.trim(),
                        'disease': _diseaseController.text.trim(),
                        'updatedAt': FieldValue.serverTimestamp(),
                      };

                      if (_isEditing && _docId != null) {
                        await FirebaseFirestore.instance
                            .collection('patients')
                            .doc(_docId)
                            .update(patientData);
                      } else {
                        patientData['createdAt'] = FieldValue.serverTimestamp();
                        await FirebaseFirestore.instance
                            .collection('patients')
                            .add(patientData);
                      }

                      Navigator.pop(context, true);
                    }
                  }
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.orangeAccent.shade100,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(30),
                  ),
                ),
                child: Image.asset(
                  'assets/icons/save.png',
                  width: 24,
                  height: 24,
                ),
              ),
            ),
            const SizedBox(width: 12),
            if (_isEditing)
              Expanded(
                child: ElevatedButton(
                  onPressed: () async {
                    final confirm = await showDialog<bool>(
                      context: context,
                      builder: (context) => AlertDialog(
                        title: const Text('ยืนยันการลบ'),
                        content: const Text('คุณแน่ใจหรือไม่ว่าต้องการลบข้อมูลนี้?'),
                        actions: [
                          TextButton(
                            onPressed: () => Navigator.pop(context, false),
                            child: const Text('ยกเลิก'),
                          ),
                          TextButton(
                            onPressed: () => Navigator.pop(context, true),
                            child: const Text('ลบ'),
                          ),
                        ],
                      ),
                    );

                    if (confirm == true && _docId != null) {
                      await FirebaseFirestore.instance
                          .collection('patients')
                          .doc(_docId)
                          .delete();
                      Navigator.pop(context, true);
                    }
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.redAccent.shade100,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(30),
                    ),
                  ),
                  child: Image.asset(
                    'assets/icons/delete.png',
                    width: 24,
                    height: 24,
                  ),
                ),
              ),
          ],
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
        prefixIcon: Padding(
          padding: EdgeInsets.all(10),
          child: Image.asset(
            label.contains('ชื่อ')
                ? 'assets/icons/user.png'
                : label.contains('โทร')
                    ? 'assets/icons/phone.png'
                    : label.contains('บัตร')
                        ? 'assets/icons/id_card.png'
                        : label.contains('เกิด')
                            ? 'assets/icons/cake.png'
                            : label.contains('แพ้')
                                ? 'assets/icons/no_drugs.png'
                                : label.contains('โรค')
                                    ? 'assets/icons/medical_report.png'
                                    : label.contains('ที่อยู่')
                                        ? 'assets/icons/house.png'
                                        : 'assets/icons/user.png',
            width: 24,
            height: 24,
          ),
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
