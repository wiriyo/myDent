import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../models/patient.dart';
import '../models/prefix.dart';
import '../services/prefix_service.dart';

class PatientAddScreen extends StatefulWidget {
  const PatientAddScreen({super.key});

  @override
  State<PatientAddScreen> createState() => _PatientAddScreenState();
}

class _PatientAddScreenState extends State<PatientAddScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _prefixController = TextEditingController(
    text: 'น.ส.',
  ); // 💜 เพิ่ม controller

  final _phoneController = TextEditingController();
  final _idCardController = TextEditingController();
  final _addressController = TextEditingController();
  final _allergyController = TextEditingController(text: 'ปฏิเสธ');
  final _diseaseController = TextEditingController(text: 'ปฏิเสธ');
  int _selectedRating = 5;

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
        _calculatedAge =
            now.year -
            picked.year -
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
    _prefixController.dispose();

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
      print('isEditing = $_isEditing, docId = $_docId');
      _isEditing = true;
      _docId = args['docId'] ?? args['id'];
      _nameController.text = args['name'] ?? '';
      _prefixController.text =
          (args['prefix'] as String?)?.trim().isNotEmpty == true
              ? args['prefix']
              : 'น.ส.';
      _phoneController.text = args['phone'] ?? '';
      _idCardController.text = args['idCard'] ?? '';
      _selectedGender = args['gender'] ?? 'หญิง';
      _addressController.text = args['address'] ?? '';
      _allergyController.text = args['allergy'] ?? 'ปฏิเสธ';
      _diseaseController.text = args['disease'] ?? 'ปฏิเสธ';
      _selectedRating = args['rating'] ?? 5;
      if (args['birthDate'] != null) {
        _birthDate = DateTime.tryParse(args['birthDate']);
        if (_birthDate != null) {
          final now = DateTime.now();
          _calculatedAge =
              now.year -
              _birthDate!.year -
              (now.month < _birthDate!.month ||
                      (now.month == _birthDate!.month &&
                          now.day < _birthDate!.day)
                  ? 1
                  : 0);
        }
      }
    }
  }

  Widget _buildRatingDropdown() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'ระดับความพึงพอใจ',
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 8),
        DropdownButtonFormField<int>(
          value: _selectedRating,
          decoration: InputDecoration(
            filled: true,
            fillColor: Colors.white,
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(16)),
          ),
          items:
              List.generate(6, (index) => index).map((rating) {
                return DropdownMenuItem(
                  value: rating,
                  child: Row(
                    children: List.generate(5, (i) {
                      return Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 2.0),
                        child: Image.asset(
                          i < rating
                              ? 'assets/icons/tooth_good.png'
                              : 'assets/icons/tooth_broke.png',
                          width: 20,
                          height: 20,
                        ),
                      );
                    }),
                  ),
                );
              }).toList(),
          onChanged: (value) {
            if (value != null) {
              setState(() {
                _selectedRating = value;
              });
            }
          },
        ),
      ],
    );
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
        padding: const EdgeInsets.only(top: 20.0, left: 20.0, right: 20.0),
        child: Form(
          key: _formKey,
          child: ListView(
            children: [
              Row(
                children: [
                  const Spacer(),
                  GestureDetector(
                    onTap: () => Navigator.pop(context),
                    child: Padding(
                      padding: const EdgeInsets.only(top: 8.0, right: 4),
                      child: Image.asset(
                        'assets/icons/back.png',
                        width: 32,
                        color: Colors.purple,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              Row(
                children: [
                  SizedBox(
                    width: 60,
                    child: StreamBuilder<List<Prefix>>(
                      stream: PrefixService.getAllPrefixes(),
                      builder: (context, snapshot) {
                        if (!snapshot.hasData) return const SizedBox.shrink();
                        final prefixList = snapshot.data!;
                        return Autocomplete<String>(
                          optionsBuilder: (TextEditingValue textEditingValue) {
                            if (textEditingValue.text == '') {
                              return const Iterable<String>.empty();
                            }
                            return prefixList
                                .map((e) => e.name)
                                .where(
                                  (name) => name.toLowerCase().contains(
                                    textEditingValue.text.toLowerCase(),
                                  ),
                                );
                          },
                          onSelected: (String selected) {
                            _prefixController.text = selected;
                          },
                          fieldViewBuilder: (
                            BuildContext context,
                            TextEditingController textEditingController,
                            FocusNode focusNode,
                            VoidCallback onFieldSubmitted,
                          ) {
                            return TextFormField(
                              controller: _prefixController, // ใช้ตัวหลักตรง ๆ
                              focusNode: focusNode,
                              decoration: InputDecoration(
                                //hintText: 'คำนำหน้า',
                                filled: true,
                                fillColor: Colors.white,
                                contentPadding: const EdgeInsets.symmetric(
                                  vertical: 12,
                                  horizontal: 12,
                                ),
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                focusedBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(12),
                                  borderSide: const BorderSide(
                                    color: Color(0xFFBFA3FF),
                                    width: 2,
                                  ),
                                ),
                              ),
                            );
                          },
                          optionsViewBuilder: (context, onSelected, options) {
                            return Align(
                              alignment: Alignment.topLeft,
                              child: Material(
                                elevation: 4,
                                borderRadius: BorderRadius.circular(12),
                                color: Colors.white,
                                child: ConstrainedBox(
                                  constraints: const BoxConstraints(
                                    maxWidth: 25, // 💜 ลดความกว้าง
                                    maxHeight: 150, // แสดงได้พอประมาณ
                                  ),
                                  child: ListView.builder(
                                    padding: EdgeInsets.zero,
                                    itemCount: options.length,
                                    itemBuilder: (context, index) {
                                      final option = options.elementAt(index);
                                      return ListTile(
                                        title: Text(
                                          option,
                                          style: const TextStyle(
                                            fontFamily: 'Poppins',
                                          ),
                                        ),
                                        onTap: () => onSelected(option),
                                      );
                                    },
                                  ),
                                ),
                              ),
                            );
                          },
                        );
                      },
                    ),
                  ),

                  const SizedBox(width: 12),
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
                    icon: const SizedBox.shrink(),
                    value: _selectedGender,
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
                            size: 36,
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
              _buildTextField(
                'เบอร์โทรศัพท์',
                _phoneController,
                keyboardType: TextInputType.phone,
              ),
              const SizedBox(height: 12),
              _buildTextField(
                'เลขบัตรประจำตัวประชาชน',
                _idCardController,
                keyboardType: TextInputType.number,
              ),
              const SizedBox(height: 12),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  TextButton.icon(
                    onPressed: _selectDate,
                    icon: Image.asset(
                      'assets/icons/cake.png',
                      width: 24,
                      height: 24,
                    ),
                    label: Text(
                      _birthDate != null
                          ? '${_birthDate!.day}/${_birthDate!.month}/${_birthDate!.year}'
                          : 'เลือกวันเกิด',
                      style: const TextStyle(fontSize: 16),
                    ),
                    style: TextButton.styleFrom(
                      backgroundColor: const Color(0xFFFBEAFF),
                      foregroundColor: Colors.purple,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 12,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                        side: const BorderSide(color: Colors.purpleAccent),
                      ),
                    ),
                  ),
                  if (_calculatedAge > 0)
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 8,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.purple.shade50,
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: Colors.purple.shade200),
                      ),
                      child: Row(
                        children: [
                          Image.asset(
                            'assets/icons/age.png',
                            width: 20,
                            height: 20,
                          ),
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
              const SizedBox(height: 16),
              _buildRatingDropdown(),
              //const SizedBox(height: 16)
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
                      builder:
                          (context) => AlertDialog(
                            title: const Text('ยืนยันการบันทึก'),
                            content: const Text(
                              'คุณต้องการบันทึกข้อมูลนี้หรือไม่?',
                            ),
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
                      await PrefixService.addIfNotExist(
                        _prefixController.text.trim(),
                      );

                      final patient = Patient(
                        patientId: _docId ?? '',
                        prefix: _prefixController.text.trim(),
                        name: _nameController.text.trim(),
                        telephone: _phoneController.text.trim(),
                        address: _addressController.text.trim(),
                        idCard: _idCardController.text.trim(),
                        birthDate: _birthDate,
                        medicalHistory: _diseaseController.text.trim(),
                        allergy: _allergyController.text.trim(),
                        gender: _selectedGender,
                        age: _calculatedAge,
                        rating: _selectedRating,
                      );

                      final patientData = patient.toMap();
                      patientData['updatedAt'] = FieldValue.serverTimestamp();

                      if (_isEditing && _docId != null && _docId!.isNotEmpty) {
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
            if (_isEditing && _docId != null && _docId!.isNotEmpty)
              const SizedBox(width: 12),
            if (_isEditing && _docId != null && _docId!.isNotEmpty)
              Expanded(
                child: ElevatedButton(
                  onPressed: () async {
                    final confirm = await showDialog<bool>(
                      context: context,
                      builder:
                          (context) => AlertDialog(
                            title: const Text('ยืนยันการลบ'),
                            content: const Text(
                              'คุณแน่ใจหรือไม่ว่าต้องการลบข้อมูลนี้?',
                            ),
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
