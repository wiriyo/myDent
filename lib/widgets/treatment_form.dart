// v1.5.1 - 🎨 อัปเดต UI ปุ่มเพิ่มรูปภาพ และซ่อนแกลเลอรีเมื่อไม่มีรูป
// v1.5.0 - 📝 เพิ่มช่องสำหรับบันทึกการรักษา (Treatment Notes)
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';
import '../providers/treatment_provider.dart';
import '../models/treatment_master.dart';
import '../models/treatment.dart';
import '../services/treatment_master_service.dart';
import '../styles/app_theme.dart';

class TreatmentForm extends StatefulWidget {
  final String patientId;
  final Treatment? treatment;
  final String? patientName;
  final String? initialProcedure;
  final DateTime? initialDate;
  final String? initialToothNumber;
  final double? initialPrice;

  const TreatmentForm({
    super.key,
    required this.patientId,
    this.treatment,
    this.patientName,
    this.initialProcedure,
    this.initialDate,
    this.initialToothNumber,
    this.initialPrice,
  });

  @override
  State<TreatmentForm> createState() => _TreatmentFormState();
}

class _TreatmentFormState extends State<TreatmentForm> {
  final _formKey = GlobalKey<FormState>();
  final TextEditingController _procedureController = TextEditingController();
  final TextEditingController _toothNumberController = TextEditingController();
  final TextEditingController _priceController = TextEditingController();
  final TextEditingController _notesController = TextEditingController();
  DateTime? _selectedDate;
  String? _selectedTreatmentMasterId;

  final List<File> _newImages = [];
  List<String> _existingImageUrls = [];
  bool get _isEditing => widget.treatment != null;

  @override
  void initState() {
    super.initState();
    if (_isEditing) {
      final t = widget.treatment!;
      _selectedTreatmentMasterId = t.treatmentMasterId;
      _procedureController.text = t.procedure;
      _toothNumberController.text = t.toothNumber;
      _priceController.text = t.price.toStringAsFixed(0);
      _selectedDate = t.date;
      _existingImageUrls = List.from(t.imageUrls);
      _notesController.text = t.notes ?? '';
    } else {
      _procedureController.text = widget.initialProcedure ?? '';
      _toothNumberController.text = widget.initialToothNumber ?? '';
      if (widget.initialPrice != null) {
        _priceController.text = widget.initialPrice!.toStringAsFixed(0);
      }
      _selectedDate = widget.initialDate;
    }
  }

  @override
  void dispose() {
    _procedureController.dispose();
    _toothNumberController.dispose();
    _priceController.dispose();
    _notesController.dispose();
    super.dispose();
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

  Future<void> _pickAndSetImage(ImageSource source) async {
    final picker = ImagePicker();
    final pickedFile = await picker.pickImage(
      source: source,
      imageQuality: 80,
      maxWidth: 1080,
    );
    if (pickedFile != null) {
      setState(() {
        _newImages.add(File(pickedFile.path));
      });
    }
  }

  void _showImageSourcePicker(BuildContext context) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (bottomSheetContext) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Wrap(
              runSpacing: 10,
              children: [
                ListTile(
                  leading: const Icon(Icons.photo_library_rounded, color: Colors.teal),
                  title: const Text("เลือกจากคลังภาพ"),
                  onTap: () async {
                    Navigator.pop(bottomSheetContext);
                    await _pickAndSetImage(ImageSource.gallery);
                  },
                ),
                ListTile(
                  leading: const Icon(Icons.camera_alt_rounded, color: Colors.deepOrange),
                  title: const Text("ถ่ายรูปด้วยกล้อง"),
                  onTap: () async {
                    Navigator.pop(bottomSheetContext);
                    await _pickAndSetImage(ImageSource.camera);
                  },
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  void _showErrorSnackBar(BuildContext context, String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message, style: const TextStyle(color: Colors.white)),
        backgroundColor: Colors.redAccent,
      ),
    );
  }

  void _handleSave(TreatmentProvider provider) async {
    if (!_formKey.currentState!.validate()) {
      return;
    }
    final treatmentData = Treatment(
      id: widget.treatment?.id ?? '',
      patientId: widget.patientId,
      treatmentMasterId: _selectedTreatmentMasterId ?? '',
      procedure: _procedureController.text.trim(),
      toothNumber: _toothNumberController.text.trim(),
      price: double.tryParse(_priceController.text) ?? 0.0,
      date: _selectedDate ?? DateTime.now(),
      imageUrls: _existingImageUrls,
      notes: _notesController.text.trim(),
    );

    final success = await provider.saveTreatment(
      patientId: widget.patientId,
      treatment: treatmentData,
      isEditing: _isEditing,
      images: _newImages,
    );

    if (success && context.mounted) {
      Navigator.pop(context, true);
    } else if (!success && context.mounted) {
      _showErrorSnackBar(context, provider.error ?? 'มีบางอย่างผิดพลาดค่ะ');
    }
  }

  void _handleDeleteExistingImage(TreatmentProvider provider, String imageUrl) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('ยืนยันการลบ'),
        content: const Text('คุณต้องการลบรูปภาพนี้ออกจากระบบใช่หรือไม่?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('ยกเลิก')),
          TextButton(onPressed: () => Navigator.pop(context, true), child: const Text('ลบ', style: TextStyle(color: Colors.red))),
        ],
      ),
    );

    if (confirm != true) return;

    final success = await provider.deleteTreatmentImage(
      patientId: widget.patientId,
      treatmentId: widget.treatment!.id,
      imageUrl: imageUrl,
    );

    if (success && context.mounted) {
      setState(() {
        _existingImageUrls.remove(imageUrl);
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('ลบรูปภาพสำเร็จแล้วค่ะ'), backgroundColor: Colors.green),
      );
    } else if (!success && context.mounted) {
      _showErrorSnackBar(context, provider.error ?? 'มีบางอย่างผิดพลาดค่ะ');
    }
  }


  @override
  Widget build(BuildContext context) {
    final treatmentProvider = context.watch<TreatmentProvider>();

    return Form(
      key: _formKey,
      child: AbsorbPointer(
        absorbing: treatmentProvider.isLoading,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('การรักษา', style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Colors.purple)),
                GestureDetector(
                  onTap: () => Navigator.pop(context),
                  child: Image.asset('assets/icons/back.png', width: 24, height: 24, color: Colors.purple),
                ),
              ],
            ),
            if (widget.patientName != null && widget.patientName!.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 8.0),
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    widget.patientName!,
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w500,
                      color: Colors.black87,
                    ),
                  ),
                ),
              ),
            Align(
              alignment: Alignment.centerRight,
              child: ElevatedButton.icon(
                onPressed: () => _selectDate(context),
                icon: Image.asset('assets/icons/calendar.png', width: 24),
                label: Text(_selectedDate != null ? '${_selectedDate!.day}/${_selectedDate!.month}/${_selectedDate!.year}' : 'เลือกวันที่'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.purple.shade100,
                  foregroundColor: Colors.black,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                ),
              ),
            ),
            const SizedBox(height: 12),
            StreamBuilder<List<TreatmentMaster>>(
              stream: TreatmentMasterService.getAllTreatments(),
              builder: (context, snapshot) {
                if (!snapshot.hasData) return const CircularProgressIndicator();
                final masterList = snapshot.data!;
                return Autocomplete<TreatmentMaster>(
                  optionsBuilder: (TextEditingValue textEditingValue) {
                    if (textEditingValue.text.isEmpty) {
                      if (_selectedTreatmentMasterId != null) {
                        setState(() => _selectedTreatmentMasterId = null);
                      }
                      return const Iterable<TreatmentMaster>.empty();
                    }
                    return masterList.where((option) => option.name.toLowerCase().contains(textEditingValue.text.toLowerCase()));
                  },
                  displayStringForOption: (option) => option.name,
                  fieldViewBuilder: (context, controller, focusNode, onFieldSubmitted) {
                    controller.text = _procedureController.text;
                    controller.addListener(() => _procedureController.text = controller.text);
                    return TextFormField(
                      controller: controller,
                      focusNode: focusNode,
                      decoration: InputDecoration(
                        prefixIcon: Padding(padding: const EdgeInsets.all(8.0), child: Image.asset('assets/icons/report.png', width: 24)),
                        hintText: 'หัตถการ',
                        filled: true,
                        fillColor: Colors.white,
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      validator: (value) => value == null || value.isEmpty ? 'กรุณากรอกหัตถการ' : null,
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
                          constraints: BoxConstraints(maxHeight: options.length * 50.0 > 200 ? 200 : options.length * 50.0),
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
                                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                                  child: Row(
                                    children: [
                                      Image.asset('assets/icons/treatment.png', width: 20, height: 20),
                                      const SizedBox(width: 8),
                                      Text(treatment.name, style: const TextStyle(fontSize: 16, color: Colors.black87)),
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
                      prefixIcon: Padding(padding: const EdgeInsets.all(8.0), child: Image.asset('assets/icons/tooth.png', width: 24)),
                      hintText: 'ซี่ฟัน',
                      filled: true,
                      fillColor: Colors.white,
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    keyboardType: TextInputType.number,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: TextFormField(
                    controller: _priceController,
                    decoration: InputDecoration(
                      prefixIcon: Padding(padding: const EdgeInsets.all(8.0), child: Image.asset('assets/icons/money.png', width: 24)),
                      hintText: 'ราคา',
                      filled: true,
                      fillColor: Colors.white,
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    keyboardType: TextInputType.number,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _notesController,
              decoration: InputDecoration(
                prefixIcon: Padding(
                  padding: const EdgeInsets.all(8.0),
                  child: Image.asset('assets/icons/notes.png', width: 24),
                ),
                hintText: 'บันทึกการรักษา (ถ้ามี)',
                filled: true,
                fillColor: Colors.white,
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
              ),
              maxLines: 3,
            ),
            const SizedBox(height: 16),
            _buildImageSection(treatmentProvider),
            const SizedBox(height: 24),
            Row(
              children: [
                Expanded(
                  child: ElevatedButton(
                    onPressed: () => _handleSave(treatmentProvider),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.orangeAccent.shade100,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
                    ),
                    child: treatmentProvider.isLoading
                        ? const SizedBox(width: 24, height: 24, child: CircularProgressIndicator(color: Colors.black54))
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
                if (_isEditing) ...[
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () async {
                        final success = await treatmentProvider.deleteTreatment(widget.patientId, widget.treatment!.id);
                        if (success && context.mounted) {
                          Navigator.pop(context, true);
                        } else if (!success && context.mounted) {
                          _showErrorSnackBar(context, treatmentProvider.error ?? 'มีบางอย่างผิดพลาดค่ะ');
                        }
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.redAccent.shade100,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
                      ),
                      child: treatmentProvider.isLoading
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
                ]
              ],
            ),
          ],
        ),
      ),
    );
  }

  // ✨ [UI-FIX v1.5.1] อัปเดต UI ปุ่มและซ่อนแกลเลอรีเมื่อไม่มีรูป
  Widget _buildImageSection(TreatmentProvider provider) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            const Text("รูปภาพประกอบ", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
            Container(
              decoration: BoxDecoration(
                color: AppTheme.buttonEditBg,
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: Colors.grey.withOpacity(0.3),
                    spreadRadius: 1,
                    blurRadius: 3,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: IconButton(
                icon: Image.asset('assets/icons/x_ray.png', width: 28, height: 28),
                tooltip: 'เพิ่มรูปภาพ',
                onPressed: () => _showImageSourcePicker(context),
              ),
            ),
          ],
        ),
        // ✨ ถ้ามีรูปภาพอย่างน้อย 1 รูป (ทั้งรูปเก่าและรูปใหม่) ถึงจะแสดงส่วนนี้
        if (_existingImageUrls.isNotEmpty || _newImages.isNotEmpty) ...[
          const SizedBox(height: 8),
          SizedBox(
            height: 100,
            child: GridView.builder(
              scrollDirection: Axis.horizontal,
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: 1, mainAxisSpacing: 8, crossAxisSpacing: 8),
              itemCount: _existingImageUrls.length + _newImages.length,
              itemBuilder: (context, index) {
                if (index < _existingImageUrls.length) {
                  final imageUrl = _existingImageUrls[index];
                  return _buildImageThumbnail(
                    imageProvider: NetworkImage(imageUrl),
                    onRemove: _isEditing
                        ? () => _handleDeleteExistingImage(provider, imageUrl)
                        : null,
                  );
                } else {
                  final imageIndex = index - _existingImageUrls.length;
                  final imageFile = _newImages[imageIndex];
                  return _buildImageThumbnail(
                    imageProvider: FileImage(imageFile),
                    onRemove: () => setState(() => _newImages.removeAt(imageIndex)),
                  );
                }
              },
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildImageThumbnail({required ImageProvider imageProvider, required VoidCallback? onRemove}) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(12.0),
      child: Stack(
        children: [
          Image(
            image: imageProvider,
            width: 100,
            height: 100,
            fit: BoxFit.cover,
            errorBuilder: (context, error, stackTrace) => Container(
              width: 100,
              height: 100,
              color: Colors.grey.shade300,
              child: const Icon(Icons.broken_image, color: Colors.white),
            ),
          ),
          if (onRemove != null)
            Positioned(
              top: 4,
              right: 4,
              child: GestureDetector(
                onTap: onRemove,
                child: Container(
                  decoration: BoxDecoration(color: Colors.black.withOpacity(0.6), shape: BoxShape.circle),
                  child: const Icon(Icons.close, color: Colors.white, size: 18),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
