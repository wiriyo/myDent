import 'package:flutter/material.dart';
import '../models/treatment_master.dart';

class TreatmentFormMaster extends StatefulWidget {
  final TreatmentMaster? treatment;
  final void Function(TreatmentMaster) onSave;
  final void Function()? onDelete;
  final VoidCallback onCancel;

  const TreatmentFormMaster({
    super.key,
    this.treatment,
    required this.onSave,
    this.onDelete,
    required this.onCancel,
  });

  @override
  State<TreatmentFormMaster> createState() => _TreatmentFormMasterState();
}

class _TreatmentFormMasterState extends State<TreatmentFormMaster> {
  late TextEditingController nameController;
  late TextEditingController durationController;
  late TextEditingController priceController;

  @override
  void initState() {
    super.initState();
    nameController = TextEditingController(text: widget.treatment?.name ?? '');
    durationController =
        TextEditingController(text: widget.treatment?.duration.toString() ?? '');
    priceController =
        TextEditingController(text: widget.treatment?.price.toString() ?? '');
  }

  @override
  void dispose() {
    nameController.dispose();
    durationController.dispose();
    priceController.dispose();
    super.dispose();
  }

  

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        const SizedBox(height: 8),
        TextFormField(
          controller: nameController,
          decoration: InputDecoration(
            prefixIcon: Padding(
              padding: const EdgeInsets.all(8.0),
              child: Image.asset('assets/icons/report.png', width: 24),
            ),
            hintText: 'ชื่อหัตถการ',
            filled: true,
            fillColor: Colors.white,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: TextFormField(
                controller: durationController,
                keyboardType: TextInputType.number,
                decoration: InputDecoration(
                  prefixIcon: Padding(
                    padding: const EdgeInsets.all(8.0),
                    child: Image.asset('assets/icons/clock.png', width: 24),
                  ),
                  hintText: 'ระยะเวลา (นาที)',
                  filled: true,
                  fillColor: Colors.white,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: TextFormField(
                controller: priceController,
                keyboardType: TextInputType.number,
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
              ),
            ),
          ],
        ),
        const SizedBox(height: 24),
        Row(
          children: [
            Expanded(
              child: ElevatedButton(
                onPressed: () {
                  final treatment = TreatmentMaster(
                    treatmentId: widget.treatment?.treatmentId ?? '',
                    name: nameController.text.trim(),
                    duration: int.tryParse(durationController.text) ?? 30,
                    price: double.tryParse(priceController.text) ?? 0.0,
                  );
                  widget.onSave(treatment);
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
                    Image.asset('assets/icons/save.png', width: 24),
                    const SizedBox(width: 8),
                    const Text('บันทึก'),
                  ],
                ),
              ),
            ),
            if (widget.treatment != null) ...[
              const SizedBox(width: 12),
              Expanded(
                child: ElevatedButton(
                  onPressed: widget.onDelete,
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
                      Image.asset('assets/icons/delete.png', width: 24),
                      const SizedBox(width: 8),
                      const Text('ลบ'),
                    ],
                  ),
                ),
              ),
            ],
          ],
        ),
      ],
    );
  }
}
