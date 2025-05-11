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

  final _firestore = FirebaseFirestore.instance;

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
    // // 👇 ดึงค่าจาก Autocomplete controller มาใส่ใน controller หลัก
    // FocusManager.instance.primaryFocus?.unfocus(); // ปิดแป้นพิมพ์
    // await Future.delayed(
    //   const Duration(milliseconds: 50),
    // ); // รอ sync ค่าให้เสร็จ

    final name = _patientController.text.trim();

    if (name.isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('กรุณาใส่ชื่อคนไข้')));
      return;
    }

    if (_selectedPatientId == null) {
      // 👉 เพิ่มชื่อใหม่
      final newDoc = await _firestore.collection('patients').add({
        'name': name,
        'createdAt': DateTime.now(),
      });

      _selectedPatientId = newDoc.id;
    }

    // 🧾 ตอนนี้เรามี _selectedPatientId แล้วแน่นอน!
    if (_selectedPatientId != null) {
      print('✅ บันทึกนัดให้ $_selectedPatientId ($name)');
      if (context.mounted) Navigator.pop(context); // ปิด dialog อย่างปลอดภัย
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

                /// 🌟 ช่องกรอกชื่อคนไข้
                Autocomplete<Map<String, dynamic>>(
                  displayStringForOption: (option) => option['name'],
                  optionsBuilder: (textEditingValue) async {
                    if (textEditingValue.text.isEmpty) return [];
                    return await _searchPatients(textEditingValue.text);
                  },
                  onSelected: (option) {
                    setState(() {
                      _selectedPatientId = option['id'];
                      _patientController.text =
                          option['name']; // อัปเดต controller ของเราให้รู้ด้วย
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
                      controller: controller, // ✅ ต้องใช้ controller จากระบบ
                      focusNode: focusNode,
                      onEditingComplete: () {
                        _patientController.text =
                            controller
                                .text; // 🧁 sync กลับมาเก็บไว้ใช้ตอนบันทึก
                        _selectedPatientId = null; // รีเซ็ต ID
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
                    return Material(
                      borderRadius: BorderRadius.circular(12),
                      elevation: 4,
                      child: ListView.separated(
                        padding: const EdgeInsets.all(8),
                        shrinkWrap: true,
                        itemCount: options.length,
                        itemBuilder: (context, index) {
                          final option = options.elementAt(index);
                          return ListTile(
                            title: Text(option['name']),
                            onTap: () => onSelected(option),
                          );
                        },
                        separatorBuilder: (_, __) => const Divider(height: 1),
                      ),
                    );
                  },
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

          /// ปุ่มยกเลิก
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
