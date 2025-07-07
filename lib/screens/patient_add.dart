// ----------------------------------------------------------------
// 📁 lib/screens/patient_add.dart
// v1.2.0 - ✨ อัปเกรดให้เรียกใช้ "หัวหน้าเชฟ" (Provider)
// ----------------------------------------------------------------
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart'; // ✨ [NEW v1.2] import Provider
import '../models/patient.dart';
import '../models/prefix.dart';
import '../providers/patient_provider.dart'; // ✨ [NEW v1.2] import พ่อครัวของเรา
import '../services/prefix_service.dart';

class PatientAddScreen extends StatefulWidget {
  final Patient? patient;
  const PatientAddScreen({super.key, this.patient});

  @override
  State<PatientAddScreen> createState() => _PatientAddScreenState();
}

class _PatientAddScreenState extends State<PatientAddScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _prefixController = TextEditingController();
  final _phoneController = TextEditingController();
  final _idCardController = TextEditingController();
  final _addressController = TextEditingController();
  final _allergyController = TextEditingController();
  final _diseaseController = TextEditingController();
  final _hnController = TextEditingController();

  int _selectedRating = 5;
  DateTime? _birthDate;
  int _calculatedAge = 0;
  bool _isEditing = false;
  String _selectedGender = 'หญิง';

  // ✨ [REMOVED v1.2] ไม่ต้องสร้าง Service เองแล้ว เชฟจัดการให้
  // final PatientService _patientService = PatientService();

  @override
  void initState() {
    super.initState();
    if (widget.patient != null) {
      _isEditing = true;
      _populateFields(widget.patient!);
    } else {
      _prefixController.text = 'น.ส.';
      _allergyController.text = 'ปฏิเสธ';
      _diseaseController.text = 'ปฏิเสธ';
    }
  }

  void _populateFields(Patient patient) {
    _nameController.text = patient.name;
    _prefixController.text = patient.prefix;
    _phoneController.text = patient.telephone ?? '';
    _idCardController.text = patient.idCard ?? '';
    _hnController.text = patient.hnNumber ?? '';
    _addressController.text = patient.address ?? '';
    _allergyController.text = patient.allergy ?? 'ปฏิเสธ';
    _diseaseController.text = patient.medicalHistory ?? 'ปฏิเสธ';
    _selectedGender = patient.gender;
    _selectedRating = patient.rating;
    if (patient.birthDate != null) {
      _birthDate = patient.birthDate;
      _calculateAgeFromBirthdate(patient.birthDate!);
    }
  }

  void _calculateAgeFromBirthdate(DateTime birthDate) {
    final now = DateTime.now();
    _calculatedAge = now.year -
        birthDate.year -
        ((now.month < birthDate.month ||
                (now.month == birthDate.month && now.day < birthDate.day))
            ? 1
            : 0);
  }

  void _selectDate() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _birthDate ?? DateTime(now.year - 20),
      firstDate: DateTime(1900),
      lastDate: now,
    );
    if (picked != null) {
      setState(() {
        _birthDate = picked;
        _calculateAgeFromBirthdate(picked);
      });
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _prefixController.dispose();
    _phoneController.dispose();
    _idCardController.dispose();
    _hnController.dispose();
    _addressController.dispose();
    _allergyController.dispose();
    _diseaseController.dispose();
    super.dispose();
  }
  
  // ✨ [NEW v1.2] สร้างเมธอดสำหรับแสดงข้อความแจ้งเตือน
  void _showSnackBar(String message, {bool isError = false}) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(message),
          backgroundColor: isError ? Colors.redAccent : Colors.green,
        ),
      );
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
    // ✨ [NEW v1.2] ห่อด้วย ChangeNotifierProvider เพื่อให้ Widget ข้างในเรียกใช้เชฟได้
    return ChangeNotifierProvider(
      create: (_) => PatientProvider(),
      child: Scaffold(
        appBar: AppBar(
          title: Text(_isEditing ? "แก้ไขข้อมูลคนไข้" : "เพิ่มข้อมูลคนไข้"),
          backgroundColor: const Color(0xFFE0BBFF),
          elevation: 0,
        ),
        backgroundColor: const Color(0xFFEFE0FF),
        // ✨ [NEW v1.2] ใช้ Consumer เพื่อคอยฟังสถานะจากเชฟ
        body: Consumer<PatientProvider>(
          builder: (context, provider, child) {
            return AbsorbPointer(
              absorbing: provider.isLoading, // ถ้าเชฟกำลังทำงาน จะกดปุ่มอื่นไม่ได้
              child: Padding(
                padding: const EdgeInsets.only(top: 20.0, left: 20.0, right: 20.0),
                child: Form(
                  key: _formKey,
                  child: ListView(
                    children: [
                      // ... (UI ส่วนบนเหมือนเดิม) ...
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
                                  initialValue: TextEditingValue(text: _prefixController.text),
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
                                      controller: textEditingController,
                                      focusNode: focusNode,
                                      decoration: InputDecoration(
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
                                            maxWidth: 25,
                                            maxHeight: 150,
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
                      Row(
                        children: [
                          Expanded(
                            child: _buildTextField(
                              'เบอร์โทรศัพท์',
                              _phoneController,
                              keyboardType: TextInputType.phone,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: _buildTextField(
                              'HN',
                              _hnController,
                            ),
                          ),
                        ],
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
                    ],
                  ),
                ),
              ),
            );
          }
        ),
        bottomNavigationBar: Padding(
          padding: const EdgeInsets.all(16.0),
          // ✨ [NEW v1.2] ใช้ Consumer เพื่อเข้าถึง provider ตอนกดปุ่ม
          child: Consumer<PatientProvider>(
            builder: (context, provider, child) {
              return Row(
                children: [
                  Expanded(
                    child: ElevatedButton(
                      onPressed: provider.isLoading ? null : () async {
                        if (_formKey.currentState!.validate()) {
                          // ... (ส่วนของ Dialog ยืนยันเหมือนเดิม) ...
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

                          if (confirm != true) return;

                          final patient = Patient(
                            patientId: _isEditing ? widget.patient!.patientId : '',
                            prefix: _prefixController.text.trim(),
                            name: _nameController.text.trim(),
                            hnNumber: _hnController.text.trim(),
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

                          final success = await provider.savePatient(patient, _isEditing);

                          if (success) {
                            _showSnackBar('บันทึกข้อมูลสำเร็จแล้วค่ะ!');
                            Navigator.pop(context, true);
                          } else {
                            _showSnackBar(provider.error ?? 'เกิดข้อผิดพลาดที่ไม่รู้จัก', isError: true);
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
                      // ✨ [CHANGED v1.2] แสดง Loading Indicator บนปุ่ม
                      child: provider.isLoading 
                          ? const SizedBox(width: 24, height: 24, child: CircularProgressIndicator(color: Colors.black54))
                          : Image.asset('assets/icons/save.png', width: 24, height: 24),
                    ),
                  ),
                  if (_isEditing) ...[
                    const SizedBox(width: 12),
                    Expanded(
                      child: ElevatedButton(
                        onPressed: provider.isLoading ? null : () async {
                          // ... (ส่วนของ Dialog ยืนยันเหมือนเดิม) ...
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

                          if (confirm != true) return;

                          final success = await provider.deletePatient(widget.patient!.patientId);
                          
                          if (success) {
                             _showSnackBar('ลบข้อมูลสำเร็จแล้วค่ะ!');
                             Navigator.pop(context, true);
                          } else {
                             _showSnackBar(provider.error ?? 'เกิดข้อผิดพลาดที่ไม่รู้จัก', isError: true);
                          }
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.redAccent.shade100,
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(30),
                          ),
                        ),
                        child: provider.isLoading
                            ? const SizedBox.shrink() // ซ่อนไปเลยถ้ากำลังโหลดอย่างอื่น
                            : Image.asset('assets/icons/delete.png', width: 24, height: 24),
                      ),
                    ),
                  ],
                ],
              );
            }
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
        prefixIcon: Padding(
          padding: const EdgeInsets.all(10),
          child: Image.asset(
            label.contains('ชื่อ')
                ? 'assets/icons/user.png'
                : label.contains('โทร')
                ? 'assets/icons/phone.png'
                : label.contains('HN')
                ? 'assets/icons/hn_id.png'
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
