import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/treatment.dart';
import '../services/treatment_service.dart';
import '../models/treatment_master.dart';
import '../services/treatment_master_service.dart';

class TreatmentForm extends StatefulWidget {
  final String patientId;
  final Map<String, dynamic>? treatment;

  const TreatmentForm({super.key, required this.patientId, this.treatment});

  @override
  State<TreatmentForm> createState() => _TreatmentFormState();
}

class _TreatmentFormState extends State<TreatmentForm> {
  final _formKey = GlobalKey<FormState>();
  final TextEditingController _procedureController = TextEditingController();
  final TextEditingController _toothNumberController = TextEditingController();
  final TextEditingController _priceController = TextEditingController();
  DateTime? _selectedDate;
  final TreatmentService _treatmentService = TreatmentService();

  String? treatmentId;

  @override
  void initState() {
    super.initState();
    print('👩‍⚕️ patientId: ${widget.patientId}');
    if (widget.treatment != null) {
      treatmentId = widget.treatment!['id'];
      _procedureController.text = widget.treatment!['procedure'];
      _toothNumberController.text = widget.treatment!['toothNumber'];
      _priceController.text = widget.treatment!['price'].toString();
      _selectedDate = (widget.treatment!['date'] as Timestamp?)?.toDate();
    }
  }

  Future<void> _selectDate(BuildContext context) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate ?? DateTime.now(),
      firstDate: DateTime(2000),
      lastDate: DateTime(2101),
    );
    if (picked != null && picked != _selectedDate) {
      setState(() {
        _selectedDate = picked;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Form(
      key: _formKey,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'การรักษา',
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: Colors.purple,
                ),
              ),
              GestureDetector(
                onTap: () => Navigator.pop(context),
                child: Image.asset(
                  'assets/icons/back.png',
                  width: 24,
                  height: 24,
                  color: Colors.purple,
                ),
              ),
            ],
          ),
          Align(
            alignment: Alignment.centerRight,
            child: ElevatedButton.icon(
              onPressed: () => _selectDate(context),
              icon: Image.asset('assets/icons/calendar.png', width: 24),
              label: Text(
                _selectedDate != null
                    ? '${_selectedDate!.day}/${_selectedDate!.month}/${_selectedDate!.year}'
                    : 'เลือกวันที่',
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.purple.shade100,
                foregroundColor: Colors.black,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(20),
                ),
              ),
            ),
          ),

          const SizedBox(height: 12),
          StreamBuilder<List<TreatmentMaster>>(
            stream: TreatmentMasterService.getAllTreatments(),
            builder: (context, snapshot) {
              if (!snapshot.hasData) {
                return const CircularProgressIndicator(); // หรือ Container() ถ้าอยากซ่อน
              }

              final masterList = snapshot.data!;

              return Autocomplete<TreatmentMaster>(
                optionsBuilder: (TextEditingValue textEditingValue) {
                  if (textEditingValue.text.isEmpty) {
                    return const Iterable<TreatmentMaster>.empty();
                  }
                  return masterList.where((option) {
                    return option.name.toLowerCase().contains(
                      textEditingValue.text.toLowerCase(),
                    );
                  });
                },
                displayStringForOption: (option) => option.name,
                fieldViewBuilder: (
                  BuildContext context,
                  TextEditingController controller,
                  FocusNode focusNode,
                  VoidCallback onFieldSubmitted,
                ) {
                  controller.text = _procedureController.text; // 🩷 สำคัญสุด!

                  controller.addListener(() {
                    _procedureController.text = controller.text;
                  });

                  return TextFormField(
                    controller: controller,
                    focusNode: focusNode,
                    decoration: InputDecoration(
                      prefixIcon: Padding(
                        padding: const EdgeInsets.all(8.0),
                        child: Image.asset(
                          'assets/icons/report.png',
                          width: 24,
                        ),
                      ),
                      hintText: 'หัตถการ',
                      filled: true,
                      fillColor: Colors.white,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    validator:
                        (value) =>
                            value == null || value.isEmpty
                                ? 'กรุณากรอกหัตถการ'
                                : null,
                  );
                },

                // ✅ เพิ่มตัวนี้ให้น่ารัก~
                optionsViewBuilder: (context, onSelected, options) {
                  return Align(
                    alignment: Alignment.topLeft,
                    child: Material(
                      borderRadius: BorderRadius.circular(12),
                      elevation: 4,
                      color: const Color(0xFFFFF5FC),
                      child: ConstrainedBox(
                        constraints: BoxConstraints(
                          // ✅ แสดงได้สูงสุดไม่เกิน 5 รายการพอดี
                          maxHeight: options.length * 50.0,
                        ),
                        child: ListView.builder(
                          padding: const EdgeInsets.all(8),
                          shrinkWrap: true, // ✅ ให้ความสูงพอดีรายการ
                          itemCount: options.length,
                          itemBuilder: (context, index) {
                            final treatment = options.elementAt(index);
                            return InkWell(
                              onTap: () => onSelected(treatment),
                              borderRadius: BorderRadius.circular(12),
                              child: Padding(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 12,
                                  vertical: 10,
                                ),
                                child: Row(
                                  children: [
                                    Image.asset(
                                      'assets/icons/treatment.png',
                                      width: 20,
                                      height: 20,
                                      //color: Colors.purple,
                                    ),
                                    const SizedBox(width: 8),
                                    Text(
                                      treatment.name,
                                      style: const TextStyle(
                                        fontSize: 16,
                                        color: Colors.black87,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            );
                          },
                        ),
                      ),
                    ),
                  );
                },

                onSelected: (TreatmentMaster selected) {
                  setState(() {
                    _procedureController.text = selected.name;
                    _priceController.text = selected.price.toStringAsFixed(0);
                  });
                },
              );
            },
          ),

          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: TextFormField(
                  controller: _toothNumberController,
                  decoration: InputDecoration(
                    prefixIcon: Padding(
                      padding: const EdgeInsets.all(8.0),
                      child: Image.asset('assets/icons/tooth.png', width: 24),
                    ),
                    hintText: 'ซี่ฟัน',
                    filled: true,
                    fillColor: Colors.white,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  keyboardType: TextInputType.number,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: TextFormField(
                  controller: _priceController,
                  decoration: InputDecoration(
                    prefixIcon: Padding(
                      padding: const EdgeInsets.all(8.0),
                      child: Image.asset('assets/icons/money.png', width: 24),
                    ),
                    hintText: 'ราคา',
                    filled: true,
                    fillColor: Colors.white,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  keyboardType: TextInputType.number,
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),
          Row(
            children: [
              Expanded(
                child: ElevatedButton(
                  onPressed: () async {
                    if (_formKey.currentState!.validate()) {
                      final name = _procedureController.text.trim();
                      final price =
                          double.tryParse(_priceController.text) ?? 0.0;

                      // 🟣 1. บันทึกชื่อใหม่เข้า treatment_master ถ้ายังไม่มี
                      await TreatmentMasterService.addIfNotExist(name, price);

                      final treatment = Treatment(
                        id: treatmentId ?? '',
                        patientId: widget.patientId,
                        procedure: name,
                        toothNumber: _toothNumberController.text,
                        price: price,
                        date: _selectedDate ?? DateTime.now(),
                      );

                      if (treatmentId == null) {
                        print('📩 เรียกใช้ addTreatment แล้ว');
                        await _treatmentService.addTreatment(treatment);
                      } else {
                        await _treatmentService.updateTreatment(treatment);
                      }

                      if (context.mounted) Navigator.pop(context);
                    }
                  },

                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.orangeAccent.shade100,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(30),
                    ),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Image.asset(
                        'assets/icons/save.png',
                        width: 24,
                        height: 24,
                      ),
                      const SizedBox(width: 8),
                      const Text('บันทึก'),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 12),
              if (treatmentId != null)
                //if (true)
                Expanded(
                  child: ElevatedButton(
                    onPressed: () async {
                      await _treatmentService.deleteTreatment(
                        widget.patientId,
                        treatmentId!,
                      );
                      if (context.mounted) Navigator.pop(context);
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.redAccent.shade100,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(30),
                      ),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Image.asset(
                          'assets/icons/delete.png',
                          width: 24,
                          height: 24,
                        ),
                        const SizedBox(width: 8),
                        const Text('ลบ'),
                      ],
                    ),
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }
}
