// ----- ‼️ FILE: lib/widgets/treatment_form.dart -----
// เวอร์ชัน 1.3: ✨ ขัดเงาขั้นสุดท้าย!
// เปลี่ยนมาใช้ Treatment model แทน Map เพื่อความปลอดภัยสูงสุด

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/treatment_provider.dart';
import '../models/treatment_master.dart';
import '../models/treatment.dart'; // ✨ [CHANGED v1.3] import Treatment model
import '../services/treatment_master_service.dart';

class TreatmentForm extends StatefulWidget {
  final String patientId;
  // ✨ [CHANGED v1.3] เปลี่ยนจาก Map ที่ไม่ปลอดภัย มาเป็น Treatment model ที่แข็งแรง!
  final Treatment? treatment;

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

  String? _selectedTreatmentMasterId;

  @override
  void initState() {
    super.initState();
    // ✨ [CHANGED v1.3] การตั้งค่าเริ่มต้นตอนนี้สะอาดและปลอดภัยขึ้นมาก
    // เราดึงข้อมูลจาก object โดยตรง ไม่ต้องพิมพ์ key ที่เป็น String เองแล้ว
    if (widget.treatment != null) {
      final t = widget.treatment!;
      _selectedTreatmentMasterId = t.treatmentMasterId;
      _procedureController.text = t.procedure;
      _toothNumberController.text = t.toothNumber;
      _priceController.text = t.price.toString();
      _selectedDate = t.date;
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

  void _showErrorSnackBar(BuildContext context, String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message, style: const TextStyle(color: Colors.white)),
        backgroundColor: Colors.redAccent,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<TreatmentProvider>(
      builder: (context, provider, child) {
        return Form(
          key: _formKey,
          child: AbsorbPointer(
            absorbing: provider.isLoading,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // ... (ส่วน UI ด้านบนเหมือนเดิม ไม่ได้แก้ไข) ...
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
                      return const CircularProgressIndicator();
                    }
                    final masterList = snapshot.data!;
                    return Autocomplete<TreatmentMaster>(
                      optionsBuilder: (TextEditingValue textEditingValue) {
                        if (textEditingValue.text.isEmpty) {
                          if (_selectedTreatmentMasterId != null) {
                            setState(() => _selectedTreatmentMasterId = null);
                          }
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
                        controller.text = _procedureController.text;
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
                          validator: (value) =>
                              value == null || value.isEmpty
                                  ? 'กรุณากรอกหัตถการ'
                                  : null,
                        );
                      },
                      optionsViewBuilder: (context, onSelected, options) {
                        return Align(
                          alignment: Alignment.topLeft,
                          child: Material(
                            borderRadius: BorderRadius.circular(12),
                            elevation: 4,
                            color: const Color(0xFFFFF5FC),
                            child: ConstrainedBox(
                              constraints: BoxConstraints(
                                maxHeight: options.length * 50.0,
                              ),
                              child: ListView.builder(
                                padding: const EdgeInsets.all(8),
                                shrinkWrap: true,
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
                          _selectedTreatmentMasterId = selected.treatmentId;
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
                            final success = await provider.saveOrUpdateTreatment(
                              patientId: widget.patientId,
                              // ✨ [CHANGED v1.3] ส่ง ID จาก object โดยตรง
                              treatmentId: widget.treatment?.id,
                              selectedTreatmentMasterId: _selectedTreatmentMasterId,
                              procedure: _procedureController.text.trim(),
                              toothNumber: _toothNumberController.text,
                              price: double.tryParse(_priceController.text) ?? 0.0,
                              date: _selectedDate ?? DateTime.now(),
                            );

                            if (success && context.mounted) {
                              Navigator.pop(context);
                            } else if (!success && context.mounted) {
                              _showErrorSnackBar(context, provider.error ?? 'มีบางอย่างผิดพลาดค่ะ');
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
                        child: provider.isLoading
                            ? const SizedBox(
                                width: 24,
                                height: 24,
                                child: CircularProgressIndicator(color: Colors.black54),
                              )
                            : Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Image.asset('assets/icons/save.png', width: 24, height: 24),
                                  const SizedBox(width: 8),
                                  const Text('บันทึก'),
                                ],
                              ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    // ✨ [CHANGED v1.3] เช็คจาก object โดยตรง
                    if (widget.treatment != null)
                      Expanded(
                        child: ElevatedButton(
                          onPressed: () async {
                            final success = await provider.deleteTreatment(widget.patientId, widget.treatment!.id);
                            if (success && context.mounted) {
                              Navigator.pop(context);
                            } else if (!success && context.mounted) {
                              _showErrorSnackBar(context, provider.error ?? 'มีบางอย่างผิดพลาดค่ะ');
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
                              ? const SizedBox.shrink()
                              : Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Image.asset('assets/icons/delete.png', width: 24, height: 24),
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
          ),
        );
      },
    );
  }
}