// 💖 สวัสดีค่ะพี่ทะเล! ไลลาอัปเกรดหน้านี้ให้รองรับ rating แบบ double แล้วนะคะ
// เราจะจัดการแปลงข้อมูลระหว่าง double (สำหรับบันทึก) กับ int (สำหรับแสดงผลใน Dropdown) กันในนี้นะคะ 😊

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../models/patient.dart';
import '../models/prefix.dart';
import '../providers/patient_provider.dart';
import '../auth/auth_provider.dart';
import '../services/prefix_service.dart';
import '../styles/app_theme.dart';
import '../widgets/custom_bottom_nav_bar.dart';
import '../widgets/custom_date_picker.dart';

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

  // ✨ เรายังคงใช้ int สำหรับควบคุม Dropdown เหมือนเดิมนะคะ จะได้ง่ายค่ะ
  int _selectedRating = 5;
  DateTime? _birthDate;
  int _calculatedAge = 0;
  bool _isEditing = false;
  String _selectedGender = 'ไม่ระบุ';

  Patient? _editingPatient;
  bool _isDataInitialized = false;

  @override
  void initState() {
    super.initState();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_isDataInitialized) {
      Patient? initialPatient = widget.patient;

      if (initialPatient == null) {
        final args = ModalRoute.of(context)?.settings.arguments;
        if (args is Patient) {
          initialPatient = args;
        }
      }

      if (initialPatient != null) {
        _isEditing = true;
        _editingPatient = initialPatient;
        _populateFields(initialPatient);
      } else {
        _prefixController.clear();
        _selectedGender = 'ไม่ระบุ';
        _allergyController.text = 'ปฏิเสธ';
        _diseaseController.text = 'ปฏิเสธ';
      }

      _isDataInitialized = true;
    }
  }

  void _populateFields(Patient patient) {
    _nameController.text = patient.name;
    _prefixController.text = patient.prefix;
    _phoneController.text = _ThaiPhoneInputFormatter.format(
      patient.telephone ?? '',
    );
    _idCardController.text = _ThaiIdCardInputFormatter.format(
      patient.idCard ?? '',
    );
    _hnController.text = patient.hnNumber ?? '';
    _addressController.text = patient.address ?? '';
    _allergyController.text = patient.allergy ?? 'ปฏิเสธ';
    _diseaseController.text = patient.medicalHistory ?? 'ปฏิเสธ';
    final gender = patient.gender.trim();
    _selectedGender = gender.isEmpty ? 'ไม่ระบุ' : gender;
    // ✨ [FIXED] แปลงค่า double จาก patient.rating มาเป็น int โดยการปัดเศษค่ะ
    _selectedRating = patient.rating.round();
    if (patient.birthDate != null) {
      _birthDate = patient.birthDate;
      _calculateAgeFromBirthdate(patient.birthDate!);
    }
  }

  void _calculateAgeFromBirthdate(DateTime birthDate) {
    final now = DateTime.now();
    _calculatedAge =
        now.year -
        birthDate.year -
        ((now.month < birthDate.month ||
                (now.month == birthDate.month && now.day < birthDate.day))
            ? 1
            : 0);
  }

  void _selectDate() async {
    final now = DateTime.now();
    final picked = await showBuddhistDatePicker(
      context: context,
      initialDate: _birthDate ?? DateTime(now.year - 20, now.month, now.day),
      firstDate: DateTime(now.year - 120),
      lastDate: now,
    );

    if (picked != null) {
      setState(() {
        _birthDate = picked;
        _calculateAgeFromBirthdate(picked);
      });
    }
  }

  void _updateGenderFromPrefix(String prefix) {
    String newGender;
    switch (prefix) {
      case 'นาย':
      case 'ด.ช.':
        newGender = 'ชาย';
        break;
      case 'นาง':
      case 'น.ส.':
      case 'ด.ญ.':
        newGender = 'หญิง';
        break;
      default:
        newGender = 'ไม่ระบุ';
        break;
    }
    if (newGender != _selectedGender) {
      setState(() {
        _selectedGender = newGender;
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
          'คะแนนความร่วมมือ',
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
              List.generate(6, (index) => index).reversed.map((rating) {
                // .reversed() to show 5 stars first
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

  Widget _getGenderIcon(String gender, {double size = 36}) {
    String iconPath;
    switch (gender) {
      case 'หญิง':
        iconPath = 'assets/icons/female.png';
        break;
      case 'ชาย':
        iconPath = 'assets/icons/male.png';
        break;
      default:
        iconPath = 'assets/icons/gender.png';
        break;
    }
    return Image.asset(iconPath, width: size, height: size);
  }

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (_) {
        final clinicId =
            Provider.of<AppAuthProvider>(
              context,
              listen: false,
            ).verifiedClinicId;
        return PatientProvider(clinicId: clinicId);
      },
      child: Scaffold(
        appBar: AppBar(
          automaticallyImplyLeading: false,
          title: Text(_isEditing ? "แก้ไขข้อมูลคนไข้" : "เพิ่มข้อมูลคนไข้"),
          backgroundColor: AppTheme.primaryLight,
          elevation: 0,
        ),
        backgroundColor: AppTheme.background,
        body: Consumer<PatientProvider>(
          builder: (context, provider, child) {
            return AbsorbPointer(
              absorbing: provider.isLoading,
              child: Form(
                key: _formKey,
                child: ListView(
                  padding: const EdgeInsets.fromLTRB(20.0, 20.0, 20.0, 24.0),
                  children: [
                    // ... (The rest of the form fields remain the same) ...
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          flex: 2,
                          child: StreamBuilder<List<Prefix>>(
                            stream: PrefixService.getAllPrefixes(),
                            builder: (context, snapshot) {
                              if (!snapshot.hasData) {
                                return const SizedBox.shrink();
                              }
                              final prefixList = snapshot.data!;
                              return Autocomplete<String>(
                                initialValue: TextEditingValue(
                                  text: _prefixController.text,
                                ),
                                optionsBuilder: (
                                  TextEditingValue textEditingValue,
                                ) {
                                  if (textEditingValue.text == '') {
                                    return prefixList.map((e) => e.name);
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
                                  _updateGenderFromPrefix(selected);
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
                                    onChanged: (value) {
                                      _prefixController.text = value;
                                      _updateGenderFromPrefix(value);
                                    },
                                    textAlign: TextAlign.center,
                                    decoration: InputDecoration(
                                      labelText: 'คำนำหน้า',
                                      filled: true,
                                      fillColor: Colors.white,
                                      contentPadding:
                                          const EdgeInsets.symmetric(
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
                                optionsViewBuilder: (
                                  context,
                                  onSelected,
                                  options,
                                ) {
                                  return Align(
                                    alignment: Alignment.topLeft,
                                    child: Material(
                                      elevation: 4,
                                      borderRadius: BorderRadius.circular(12),
                                      color: Colors.white,
                                      child: ConstrainedBox(
                                        constraints: const BoxConstraints(
                                          maxWidth: 120,
                                          maxHeight: 200,
                                        ),
                                        child: ListView.builder(
                                          padding: EdgeInsets.zero,
                                          itemCount: options.length,
                                          itemBuilder: (context, index) {
                                            final option = options.elementAt(
                                              index,
                                            );
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
                          flex: 5,
                          child: _buildTextField(
                            'ชื่อ - นามสกุล',
                            _nameController,
                            validator:
                                (value) =>
                                    value!.isEmpty ? 'กรุณากรอกชื่อ' : null,
                          ),
                        ),
                        const SizedBox(width: 12),
                        DropdownButton<String>(
                          icon: const SizedBox.shrink(),
                          value: _selectedGender,
                          underline: Container(),
                          selectedItemBuilder: (BuildContext context) {
                            return ['ไม่ระบุ', 'ชาย', 'หญิง'].map((
                              String value,
                            ) {
                              return Align(
                                alignment: Alignment.center,
                                child: _getGenderIcon(value, size: 36),
                              );
                            }).toList();
                          },
                          items:
                              ['ไม่ระบุ', 'ชาย', 'หญิง'].map((String value) {
                                return DropdownMenuItem<String>(
                                  value: value,
                                  child: _getGenderIcon(value, size: 28),
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
                      inputFormatters: const [
                        _ThaiPhoneInputFormatter(),
                      ],
                    ),
                    const SizedBox(height: 12),
                    _buildTextField(
                      'เลขบัตรประจำตัวประชาชน',
                      _idCardController,
                      keyboardType: TextInputType.number,
                      inputFormatters: const [
                        _ThaiIdCardInputFormatter(),
                      ],
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
                                ? DateFormat('d MMMM yyyy', 'th_TH').format(
                                  DateTime(
                                    _birthDate!.year + 543,
                                    _birthDate!.month,
                                    _birthDate!.day,
                                  ),
                                )
                                : 'เลือกวันเกิด',
                            style: const TextStyle(fontSize: 16),
                          ),
                          style: TextButton.styleFrom(
                            backgroundColor: AppTheme.bottomNav,
                            foregroundColor: AppTheme.primary,
                            padding: const EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 12,
                            ),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(16),
                              side: const BorderSide(
                                color: AppTheme.primaryLight,
                              ),
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
                              color: AppTheme.primary.withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(20),
                              border: Border.all(color: AppTheme.primaryLight),
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
                                    color: AppTheme.primary,
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
                    const SizedBox(height: 24),
                    _buildActionButtons(provider),
                  ],
                ),
              ),
            );
          },
        ),
        bottomNavigationBar: const CustomBottomNavBar(selectedIndex: 1),
      ),
    );
  }

  Widget _buildActionButtons(PatientProvider provider) {
    return Row(
      children: [
        if (_isEditing) ...[
          Expanded(
            child: ElevatedButton(
              onPressed:
                  provider.isLoading
                      ? null
                      : () async {
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
                                    onPressed:
                                        () => Navigator.pop(context, false),
                                    child: const Text('ยกเลิก'),
                                  ),
                                  TextButton(
                                    onPressed:
                                        () => Navigator.pop(context, true),
                                    child: const Text('ลบ'),
                                  ),
                                ],
                              ),
                        );

                        if (confirm != true) return;

                        final navigator = Navigator.of(context);

                        if (_editingPatient != null &&
                            _editingPatient!.patientId.isNotEmpty) {
                          if (!mounted) return;
                          final success = await provider.deletePatient(
                            _editingPatient!.patientId,
                          );

                          if (success) {
                            _showSnackBar('ลบข้อมูลสำเร็จแล้วค่ะ!');
                            navigator.pushNamedAndRemoveUntil(
                              '/patients',
                              (Route<dynamic> route) => false,
                            );
                          } else {
                            _showSnackBar(
                              provider.error ?? 'เกิดข้อผิดพลาดที่ไม่รู้จัก',
                              isError: true,
                            );
                          }
                        } else {
                          _showSnackBar(
                            'เกิดข้อผิดพลาด: ไม่พบ ID ของคนไข้ที่จะลบ',
                            isError: true,
                          );
                        }
                      },
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.redAccent.shade100,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(30),
                ),
              ),
              child:
                  provider.isLoading
                      ? const SizedBox.shrink()
                      : Image.asset(
                        'assets/icons/delete.png',
                        width: 24,
                        height: 24,
                      ),
            ),
          ),
          const SizedBox(width: 12),
        ],
        Expanded(
          child: ElevatedButton(
            onPressed:
                provider.isLoading
                    ? null
                    : () async {
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
                                    onPressed:
                                        () => Navigator.pop(context, false),
                                    child: const Text('ยกเลิก'),
                                  ),
                                  TextButton(
                                    onPressed:
                                        () => Navigator.pop(context, true),
                                    child: const Text('บันทึก'),
                                  ),
                                ],
                              ),
                        );

                        if (confirm != true) return;

                        if (_isEditing &&
                            (_editingPatient?.patientId ?? '').isEmpty) {
                          _showSnackBar(
                            'เกิดข้อผิดพลาด: ไม่พบ ID ของคนไข้',
                            isError: true,
                          );
                          return;
                        }

                        // ✨ [FIXED] แปลงค่า int จาก _selectedRating กลับไปเป็น double ตอนบันทึกค่ะ
                        final patient = Patient(
                          patientId:
                              _isEditing ? _editingPatient!.patientId : '',
                          prefix: _prefixController.text.trim(),
                          name: _nameController.text.trim(),
                          hnNumber: _hnController.text.trim(),
                          telephone:
                              _phoneController.text.replaceAll('-', '').trim(),
                          address: _addressController.text.trim(),
                          idCard:
                              _idCardController.text.replaceAll('-', '').trim(),
                          birthDate: _birthDate,
                          medicalHistory: _diseaseController.text.trim(),
                          allergy: _allergyController.text.trim(),
                          gender: _selectedGender,
                          age: _calculatedAge,
                          rating:
                              _selectedRating
                                  .toDouble(), // แปลงกลับเป็น double ตรงนี้ค่ะ
                        );

                        final navigator = Navigator.of(context);
                        if (!mounted) return;
                        final success = await provider.savePatient(
                          patient,
                          _isEditing,
                        );

                        if (success) {
                          _showSnackBar('บันทึกข้อมูลสำเร็จแล้วค่ะ!');
                          navigator.pop(true);
                        } else {
                          _showSnackBar(
                            provider.error ?? 'เกิดข้อผิดพลาดที่ไม่รู้จัก',
                            isError: true,
                          );
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
            child:
                provider.isLoading
                    ? const SizedBox(
                      width: 24,
                      height: 24,
                      child: CircularProgressIndicator(color: Colors.black54),
                    )
                    : Image.asset(
                      'assets/icons/save.png',
                      width: 24,
                      height: 24,
                    ),
          ),
        ),
      ],
    );
  }

  Widget _buildTextField(
    String label,
    TextEditingController controller, {
    TextInputType? keyboardType,
    List<TextInputFormatter>? inputFormatters,
    String? Function(String?)? validator,
    bool readOnly = false,
    String? hintText,
  }) {
    return TextFormField(
      controller: controller,
      keyboardType: keyboardType,
      inputFormatters: inputFormatters,
      validator: validator,
      readOnly: readOnly,
      style: TextStyle(
        fontFamily: 'Poppins',
        color: readOnly ? Colors.grey.shade700 : Colors.black,
      ),
      decoration: InputDecoration(
        labelText: label,
        hintText: hintText,
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
        fillColor: readOnly ? Colors.grey.shade200 : Colors.white,
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

class _PatternInputFormatter extends TextInputFormatter {
  const _PatternInputFormatter(this.blocks);

  final List<int> blocks;

  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    final digitsOnly = newValue.text.replaceAll(RegExp(r'\D'), '');
    final formatted = formatDigits(digitsOnly, blocks);
    return TextEditingValue(
      text: formatted,
      selection: TextSelection.collapsed(offset: formatted.length),
    );
  }

  static String formatDigits(String input, List<int> blocks) {
    final digits = input.replaceAll(RegExp(r'\D'), '');
    final maxLength = blocks.fold<int>(0, (sum, item) => sum + item);
    final limited =
        digits.length > maxLength ? digits.substring(0, maxLength) : digits;
    final buffer = StringBuffer();
    var index = 0;
    for (final block in blocks) {
      if (index >= limited.length) break;
      final end =
          (index + block) > limited.length ? limited.length : (index + block);
      if (buffer.isNotEmpty) buffer.write('-');
      buffer.write(limited.substring(index, end));
      index = end;
    }
    return buffer.toString();
  }
}

class _ThaiPhoneInputFormatter extends _PatternInputFormatter {
  const _ThaiPhoneInputFormatter() : super(_blocks);

  static const List<int> _blocks = [3, 3, 5];

  static String format(String input) =>
      _PatternInputFormatter.formatDigits(input, _blocks);
}

class _ThaiIdCardInputFormatter extends _PatternInputFormatter {
  const _ThaiIdCardInputFormatter() : super(_blocks);

  static const List<int> _blocks = [1, 4, 5, 2, 1];

  static String format(String input) =>
      _PatternInputFormatter.formatDigits(input, _blocks);
}
