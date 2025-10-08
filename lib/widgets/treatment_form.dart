// ----------------------------------------------------------------
// 📁 lib/widgets/treatment_form.dart (v2.4 - 💖 Laila's New Flow Fix!)
// ----------------------------------------------------------------
import 'package:flutter/material.dart';
import 'dart:io';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';

import '../providers/treatment_provider.dart';
import '../models/treatment_master.dart';
import '../models/treatment.dart';
import '../models/patient.dart';
import '../services/treatment_master_service.dart';
import '../services/patient_service.dart';
import '../services/tooth_history_service.dart';
import '../styles/app_theme.dart';

import '../features/printing/render/receipt_mapper.dart'
    show ReceiptLineInput, buildReceiptModel;
import '../features/printing/render/preview_pages.dart' as pv;
import '../features/printing/domain/receipt_model.dart' as receipt;
import '../features/printing/services/receipt_number_service.dart';

class _SaveDecision {
  final bool confirmed;
  final bool shouldSchedule;

  const _SaveDecision({required this.confirmed, required this.shouldSchedule});
}

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
  final ToothHistoryService _toothHistoryService = ToothHistoryService();
  List<String> _teethHistory = [];
  final FocusNode _toothFieldFocusNode = FocusNode();
  final _formKey = GlobalKey<FormState>();
  final TextEditingController _procedureController = TextEditingController();
  final TextEditingController _toothNumberController = TextEditingController();
  final TextEditingController _priceController = TextEditingController();
  final TextEditingController _notesController = TextEditingController();
  DateTime? _selectedDate;
  String? _selectedTreatmentMasterId;
  String? _receiptNumber;
  DateTime? _receiptIssuedAt;

  final List<File> _newImages = [];
  List<String> _existingImageUrls = [];
  bool get _isEditing => widget.treatment != null;
  bool _isSaveButtonLocked = false;

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
      _receiptNumber = t.receiptNumber;
      _receiptIssuedAt = t.receiptIssuedAt;
    } else {
      _procedureController.text = widget.initialProcedure ?? '';
      _selectedDate = widget.initialDate;
      _toothNumberController.text = widget.initialToothNumber ?? '';
      _priceController.text =
          widget.initialPrice != null
              ? widget.initialPrice!.toStringAsFixed(0)
              : '';
    }
    _loadToothHistory();
  }

  @override
  void dispose() {
    _procedureController.dispose();
    _toothNumberController.dispose();
    _priceController.dispose();
    _notesController.dispose();
    _toothFieldFocusNode.dispose();
    super.dispose();
  }

  void _loadToothHistory() {
    _toothHistoryService.loadHistory().then((history) {
      if (!mounted) {
        _teethHistory = history;
        return;
      }
      setState(() {
        _teethHistory = history;
      });
    });
  }

  Iterable<String> _buildToothNumberOptions(TextEditingValue editingValue) {
    if (_teethHistory.isEmpty) {
      return const Iterable<String>.empty();
    }
    final rawText = editingValue.text;
    final rawSegments = rawText.split(',');
    final trimmedSegments =
        rawSegments.map((segment) => segment.trim()).toList();
    final String query =
        trimmedSegments.isNotEmpty ? trimmedSegments.last : rawText.trim();
    final lowerQuery = query.toLowerCase();
    final used =
        trimmedSegments
            .where((segment) => segment.isNotEmpty)
            .map((segment) => segment.toLowerCase())
            .toSet();
    used.remove(lowerQuery);
    if (query.isEmpty) {
      return _teethHistory.where(
        (option) => !used.contains(option.toLowerCase()),
      );
    }
    return _teethHistory.where((option) {
      final normalized = option.toLowerCase();
      if (used.contains(normalized)) return false;
      return normalized.contains(lowerQuery);
    });
  }

  void _handleToothNumberSelection(String selection) {
    final rawSegments = _toothNumberController.text.split(',');
    if (rawSegments.isEmpty) {
      rawSegments.add(selection);
    } else {
      rawSegments[rawSegments.length - 1] = selection;
    }
    final deduped = <String>[];
    final seen = <String>{};
    for (final segment in rawSegments) {
      final trimmed = segment.trim();
      if (trimmed.isEmpty) continue;
      final normalized = trimmed.toLowerCase();
      if (seen.add(normalized)) {
        deduped.add(trimmed);
      }
    }
    final updatedText = deduped.join(', ');
    _toothNumberController.value = TextEditingValue(
      text: updatedText,
      selection: TextSelection.fromPosition(
        TextPosition(offset: updatedText.length),
      ),
    );
  }

  Future<String> _nextBillNo() async {
    try {
      return await ReceiptNumberService.next();
    } catch (e) {
      debugPrint('❌ _nextBillNo error: $e');
      final now = DateTime.now();
      final beYY = (now.year + 543) % 100;
      final yy = beYY.toString().padLeft(2, '0');
      return '$yy-000';
    }
  }

  Future<String> _resolvePatientName() async {
    final fromWidget = (widget.patientName ?? '').trim();
    if (fromWidget.isNotEmpty) return fromWidget;
    try {
      final svc = PatientService();
      final name = await svc.getPatientNameById(widget.patientId);
      if (name != null && name.trim().isNotEmpty) return name.trim();
    } catch (_) {}
    return '';
  }

  Future<Patient?> _getPatientForScheduling() async {
    try {
      return await PatientService().getPatientById(widget.patientId);
    } catch (e) {
      debugPrint("Error fetching patient for scheduling: $e");
      return null;
    }
  }

  Future<receipt.ReceiptModel> _buildReceiptFromForm() async {
    await _ensureReceiptInfo();
    final patientName = await _resolvePatientName();
    final proc = _procedureController.text.trim();
    final tooth = _toothNumberController.text.trim();
    final price =
        double.tryParse(_priceController.text.replaceAll(',', '')) ?? 0.0;
    final lineName = tooth.isEmpty ? proc : '$proc (#$tooth)';
    final billNo = _receiptNumber ?? '';
    final issuedAt = _receiptIssuedAt ?? DateTime.now();
    const clinicName = 'คลินิกทันตกรรมหมอกุสุมาภรณ์';
    const clinicAddress = '304 ม.1 ต.หนองพอก\nอ.หนองพอก จ.ร้อยเอ็ด';
    const clinicPhone = '094-5639334';
    return buildReceiptModel(
      clinicName: clinicName,
      clinicAddress: clinicAddress,
      clinicPhone: clinicPhone,
      billNo: billNo,
      issuedAt: issuedAt,
      patientName: patientName,
      items: [ReceiptLineInput(name: lineName, qty: 1, price: price)],
      subTotal: price,
      discount: 0,
      vat: 0,
      grandTotal: price,
    );
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
                  leading: const Icon(
                    Icons.photo_library_rounded,
                    color: Colors.teal,
                  ),
                  title: const Text('เลือกจากคลังภาพ'),
                  onTap: () async {
                    Navigator.pop(bottomSheetContext);
                    await _pickAndSetImage(ImageSource.gallery);
                  },
                ),
                ListTile(
                  leading: const Icon(
                    Icons.camera_alt_rounded,
                    color: Colors.deepOrange,
                  ),
                  title: const Text('ถ่ายรูปด้วยกล้อง'),
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

  Future<void> _ensureReceiptInfo() async {
    if (_receiptNumber != null && _receiptIssuedAt != null) {
      return;
    }
    final billNo = await _nextBillNo();
    final now = DateTime.now();
    if (!mounted) {
      _receiptNumber = billNo;
      _receiptIssuedAt = now;
      return;
    }
    setState(() {
      _receiptNumber = billNo;
      _receiptIssuedAt = now;
    });
  }

  void _showErrorSnackBar(String message, {bool isError = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message, style: const TextStyle(color: Colors.white)),
        backgroundColor: isError ? Colors.redAccent : Colors.redAccent,
      ),
    );
  }

  Future<_SaveDecision?> _showSaveConfirmationDialog() async {
    return showDialog<_SaveDecision>(
      context: context,
      barrierDismissible: false,
      builder: (context) {
        bool? selection = _isEditing ? false : null;

        return StatefulBuilder(
          builder: (context, setState) {
            final textTheme = Theme.of(context).textTheme;
            final bool disableConfirm = !_isEditing && selection == null;

            Widget buildOption({
              required bool value,
              required IconData icon,
              required String title,
              required String subtitle,
            }) {
              final bool isSelected = selection == value;
              return InkWell(
                onTap: () => setState(() => selection = value),
                borderRadius: BorderRadius.circular(16),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  curve: Curves.easeInOut,
                  margin: const EdgeInsets.only(bottom: 12),
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color:
                        isSelected
                            ? AppTheme.primary.withValues(alpha: 0.12)
                            : Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color:
                          isSelected
                              ? AppTheme.primary
                              : AppTheme.primary.withValues(alpha: 0.2),
                      width: 1.5,
                    ),
                    boxShadow:
                        isSelected
                            ? [
                              BoxShadow(
                                color: AppTheme.primary.withValues(alpha: 0.18),
                                offset: const Offset(0, 6),
                                blurRadius: 14,
                              ),
                            ]
                            : null,
                  ),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: AppTheme.primary.withValues(alpha: 0.15),
                          shape: BoxShape.circle,
                        ),
                        child: Icon(icon, color: AppTheme.primary),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              title,
                              style: textTheme.titleMedium?.copyWith(
                                color: AppTheme.textPrimary,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              subtitle,
                              style: textTheme.bodySmall?.copyWith(
                                color: AppTheme.textSecondary,
                              ),
                            ),
                          ],
                        ),
                      ),
                      Radio<bool>(
                        value: value,
                        groupValue: selection,
                        onChanged: (val) => setState(() => selection = val),
                        activeColor: AppTheme.primary,
                      ),
                    ],
                  ),
                ),
              );
            }

            return AlertDialog(
              backgroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(24),
              ),
              titlePadding: EdgeInsets.zero,
              contentPadding: const EdgeInsets.fromLTRB(24, 16, 24, 0),
              actionsPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
              title: Container(
                padding: const EdgeInsets.fromLTRB(24, 24, 24, 16),
                decoration: const BoxDecoration(
                  color: AppTheme.primaryLight,
                  borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
                ),
                child: Row(
                  children: [
                    CircleAvatar(
                      radius: 22,
                      backgroundColor: AppTheme.primary,
                      child: const Icon(
                        Icons.content_paste_rounded,
                        color: Colors.white,
                        size: 28,
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            'ยืนยันการบันทึก',
                            style: textTheme.titleLarge?.copyWith(
                              fontWeight: FontWeight.w800,
                              color: AppTheme.textPrimary,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'ตรวจสอบข้อมูลอีกครั้งก่อนดำเนินการนะคะ',
                            style: textTheme.bodyMedium?.copyWith(
                              color: AppTheme.textSecondary,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'ระบบจะบันทึกข้อมูลการรักษาให้ทันทีหลังจากกดยืนยันค่ะ',
                    style: textTheme.bodyMedium?.copyWith(
                      color: AppTheme.textSecondary,
                    ),
                  ),
                  if (!_isEditing) ...[
                    const SizedBox(height: 20),
                    Text(
                      'เลือกขั้นตอนถัดไป',
                      style: textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w700,
                        color: AppTheme.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 12),
                    buildOption(
                      value: true,
                      icon: Icons.event_available_rounded,
                      title: 'นัดหมายครั้งต่อไป',
                      subtitle: 'พาไปที่หน้าปฏิทินเพื่อสร้างนัดใหม่ต่อได้เลย',
                    ),
                    buildOption(
                      value: false,
                      icon: Icons.insert_drive_file_rounded,
                      title: 'ไม่มีนัดหมาย',
                      subtitle: 'กลับไปดูใบเสร็จและสรุปรายการรักษาที่บันทึกไว้',
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '* เลือกได้เพียง 1 ตัวเลือกก่อนกดยืนยัน',
                      style: textTheme.bodySmall?.copyWith(
                        color: AppTheme.textDisabled,
                      ),
                    ),
                  ],
                ],
              ),
              actions: [
                TextButton(
                  onPressed:
                      () => Navigator.of(context).pop(
                        const _SaveDecision(
                          confirmed: false,
                          shouldSchedule: false,
                        ),
                      ),
                  style: TextButton.styleFrom(
                    foregroundColor: AppTheme.textSecondary,
                    textStyle: const TextStyle(fontWeight: FontWeight.w600),
                  ),
                  child: const Text('ยกเลิก'),
                ),
                TextButton(
                  onPressed:
                      disableConfirm
                          ? null
                          : () => Navigator.of(context).pop(
                            _SaveDecision(
                              confirmed: true,
                              shouldSchedule: selection ?? false,
                            ),
                          ),
                  style: TextButton.styleFrom(
                    foregroundColor: AppTheme.primary,
                    disabledForegroundColor: AppTheme.textDisabled,
                    textStyle: const TextStyle(fontWeight: FontWeight.w700),
                  ),
                  child: const Text('ยืนยัน'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  void _handleSave() async {
    if (_isSaveButtonLocked) return;

    setState(() => _isSaveButtonLocked = true);

    final formState = _formKey.currentState;
    if (formState == null || !formState.validate()) {
      if (mounted) setState(() => _isSaveButtonLocked = false);
      return;
    }

    final decision = await _showSaveConfirmationDialog();

    if (!mounted) return;

    if (decision?.confirmed != true) {
      setState(() => _isSaveButtonLocked = false);
      return;
    }

    final bool shouldScheduleAfterSave =
        !_isEditing && decision!.shouldSchedule;

    final provider = context.read<TreatmentProvider>();

    await _ensureReceiptInfo();
    if (_receiptNumber == null || _receiptIssuedAt == null) {
      if (mounted) {
        _showErrorSnackBar('ไม่สามารถสร้างเลขที่ใบเสร็จได้', isError: true);
        setState(() => _isSaveButtonLocked = false);
      }
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
      receiptNumber: _receiptNumber,
      receiptIssuedAt: _receiptIssuedAt,
    );

    final success = await provider.saveTreatment(
      patientId: widget.patientId,
      treatment: treatmentData,
      isEditing: _isEditing,
      images: _newImages,
    );
    debugPrint("💖 Laila Debug: Treatment saved successfully: $success");

    if (!mounted) return;

    if (success) {
      final newEntries =
          _toothNumberController.text
              .split(',')
              .map((value) => value.trim())
              .where((value) => value.isNotEmpty)
              .toList();
      if (newEntries.isNotEmpty) {
        await _toothHistoryService.addEntries(newEntries);
        _loadToothHistory();
      }

      if (!mounted) return;

      if (_isEditing) {
        debugPrint(
          "💖 Laila Debug: Editing treatment. Showing receipt preview.",
        );
        final receipt = await _buildReceiptFromForm();
        if (!mounted) return;
        await Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) => pv.ReceiptPreviewPage(receipt: receipt),
          ),
        );

        if (!mounted) return;
        Navigator.of(context).pop(true);
        return;
      }

      debugPrint(
        "💖 Laila Debug: Should schedule after save: $shouldScheduleAfterSave",
      );

      if (!mounted) return;

      if (shouldScheduleAfterSave) {
        final patientForScheduling = await _getPatientForScheduling();
        if (patientForScheduling == null) {
          if (mounted) {
            _showErrorSnackBar(
              'ไม่สามารถดึงข้อมูลคนไข้เพื่อนัดหมายได้',
              isError: true,
            );
            setState(() => _isSaveButtonLocked = false);
          }
          return;
        }

        final receipt = await _buildReceiptFromForm();
        if (!mounted) return;
        debugPrint(
          "💖 Laila Debug: Replacing current route with CalendarScreen.",
        );

        // 💖✨ THE NEW FLOW FIX v2.4: ใช้ pushReplacementNamed เพื่อ "สลับหน้า"
        // วิธีนี้จะปิดหน้าฟอร์มปัจจุบันทิ้ง แล้วเอาหน้าปฏิทินเข้ามาแทนที่
        // ทำให้ Flow การทำงานถูกต้องและไม่เกิดข้อผิดพลาดค่ะ
        Navigator.of(context).pushReplacementNamed(
          '/calendar',
          arguments: {
            'initialPatient': patientForScheduling,
            'receiptDraft': receipt,
          },
        );
        return;
      }

      debugPrint("💖 Laila Debug: No scheduling needed. Showing receipt only.");
      final receipt = await _buildReceiptFromForm();
      if (!mounted) return;
      await Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => pv.ReceiptPreviewPage(receipt: receipt),
        ),
      );

      debugPrint(
        "💖 Laila Debug: Receipt preview finished. Closing TreatmentForm.",
      );
      if (!mounted) return;
      Navigator.of(context).pop(true);
      return;
    } else {
      _showErrorSnackBar(provider.error ?? 'มีบางอย่างผิดพลาดค่ะ', isError: true);
      setState(() => _isSaveButtonLocked = false);
    }
  }

  void _handleDeleteExistingImage(String imageUrl) async {
    final provider = context.read<TreatmentProvider>();

    final confirm = await showDialog<bool>(
      context: context,
      builder:
          (context) => AlertDialog(
            title: const Text('ยืนยันการลบ'),
            content: const Text('คุณต้องการลบรูปภาพนี้ออกจากระบบใช่หรือไม่?'),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text('ยกเลิก'),
              ),
              TextButton(
                onPressed: () => Navigator.pop(context, true),
                child: const Text('ลบ', style: TextStyle(color: Colors.red)),
              ),
            ],
          ),
    );

    if (confirm != true) return;

    final success = await provider.deleteTreatmentImage(
      patientId: widget.patientId,
      treatmentId: widget.treatment!.id,
      imageUrl: imageUrl,
    );

    if (!context.mounted) return;

    if (success) {
      setState(() {
        _existingImageUrls.remove(imageUrl);
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('ลบรูปภาพสำเร็จแล้วค่ะ'),
          backgroundColor: Colors.green,
        ),
      );
    } else {
      _showErrorSnackBar(provider.error ?? 'มีบางอย่างผิดพลาดค่ะ', isError: true);
    }
    _loadToothHistory();
  }

  @override
  Widget build(BuildContext context) {
    final treatmentProvider = context.watch<TreatmentProvider>();
    final isSaving = treatmentProvider.isLoading;

    return Form(
      key: _formKey,
      child: AbsorbPointer(
        absorbing: isSaving || _isSaveButtonLocked,
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
                    return masterList.where(
                      (option) => option.name.toLowerCase().contains(
                        textEditingValue.text.toLowerCase(),
                      ),
                    );
                  },
                  displayStringForOption: (option) => option.name,
                  fieldViewBuilder: (
                    context,
                    controller,
                    focusNode,
                    onFieldSubmitted,
                  ) {
                    controller.text = _procedureController.text;
                    controller.addListener(
                      () => _procedureController.text = controller.text,
                    );
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
                  optionsViewBuilder: (context, onSelected, options) {
                    return Align(
                      alignment: Alignment.topLeft,
                      child: Material(
                        borderRadius: BorderRadius.circular(12),
                        elevation: 4,
                        color: const Color(0xFFFFF5FC),
                        child: ConstrainedBox(
                          constraints: BoxConstraints(
                            maxHeight:
                                options.length * 50.0 > 200
                                    ? 200
                                    : options.length * 50.0,
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
                  child: LayoutBuilder(
                    builder: (context, constraints) {
                      return RawAutocomplete<String>(
                        focusNode: _toothFieldFocusNode,
                        textEditingController: _toothNumberController,
                        optionsBuilder: _buildToothNumberOptions,
                        displayStringForOption: (option) => option,
                        onSelected:
                            (selection) =>
                                _handleToothNumberSelection(selection),
                        fieldViewBuilder: (
                          context,
                          controller,
                          focusNode,
                          onFieldSubmitted,
                        ) {
                          return TextFormField(
                            controller: controller,
                            focusNode: focusNode,
                            keyboardType: TextInputType.text,
                            textCapitalization: TextCapitalization.characters,
                            decoration: InputDecoration(
                              prefixIcon: Padding(
                                padding: const EdgeInsets.all(8.0),
                                child: Image.asset(
                                  'assets/icons/tooth.png',
                                  width: 24,
                                ),
                              ),
                              hintText: 'ซี่ฟัน',
                              filled: true,
                              fillColor: Colors.white,
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                            onFieldSubmitted: (_) => onFieldSubmitted(),
                          );
                        },
                        optionsViewBuilder: (context, onSelected, options) {
                          final optionList = options.toList();
                          if (optionList.isEmpty) {
                            return const SizedBox.shrink();
                          }
                          final maxVisible =
                              optionList.length > 6 ? 6 : optionList.length;
                          final maxHeight =
                              maxVisible <= 0
                                  ? 0.0
                                  : (maxVisible * 48.0) + 16.0;
                          return Align(
                            alignment: Alignment.topLeft,
                            child: Material(
                              elevation: 4.0,
                              color: const Color(0xFFFCF5FF),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                                side: BorderSide(
                                  color: AppTheme.primary.withValues(alpha: 0.25),
                                ),
                              ),
                              child: SizedBox(
                                width: constraints.maxWidth,
                                child: ConstrainedBox(
                                  constraints: BoxConstraints(
                                    maxHeight: maxHeight,
                                  ),
                                  child: ListView.builder(
                                    shrinkWrap: true,
                                    padding: const EdgeInsets.symmetric(
                                      vertical: 8.0,
                                    ),
                                    itemCount: optionList.length,
                                    itemBuilder: (context, index) {
                                      final option = optionList[index];
                                      return InkWell(
                                        onTap: () => onSelected(option),
                                        borderRadius: BorderRadius.circular(8),
                                        child: Padding(
                                          padding: const EdgeInsets.symmetric(
                                            horizontal: 16,
                                            vertical: 8,
                                          ),
                                          child: Row(
                                            children: [
                                              Image.asset(
                                                'assets/icons/tooth.png',
                                                width: 24,
                                                height: 24,
                                              ),
                                              const SizedBox(width: 16),
                                              Expanded(child: Text(option)),
                                            ],
                                          ),
                                        ),
                                      );
                                    },
                                  ),
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
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              maxLines: 3,
            ),
            const SizedBox(height: 16),
            _buildImageSection(),
            const SizedBox(height: 24),
            Row(
              children: [
                Expanded(
                  child: ElevatedButton(
                    onPressed:
                        treatmentProvider.isLoading || _isSaveButtonLocked
                            ? null
                            : _handleSave,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.orangeAccent.shade100,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(30),
                      ),
                    ),
                    child:
                        treatmentProvider.isLoading
                            ? const SizedBox(
                              width: 24,
                              height: 24,
                              child: CircularProgressIndicator(
                                color: Colors.black54,
                              ),
                            )
                            : Row(
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
                if (_isEditing) ...[
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () async {
                        final success = await treatmentProvider.deleteTreatment(
                          widget.patientId,
                          widget.treatment!.id,
                        );
                        if (success && context.mounted) {
                          Navigator.pop(context, true);
                        } else if (!success && context.mounted) {
                          _showErrorSnackBar(
                            treatmentProvider.error ?? 'มีบางอย่างผิดพลาดค่ะ',
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
                          treatmentProvider.isLoading
                              ? const SizedBox.shrink()
                              : Row(
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
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildImageSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            const Text(
              'รูปภาพประกอบ',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
            ),
            Container(
              decoration: BoxDecoration(
                color: AppTheme.buttonEditBg,
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: Colors.grey.withValues(alpha: 0.3),
                    spreadRadius: 1,
                    blurRadius: 3,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: IconButton(
                icon: Image.asset(
                  'assets/icons/x_ray.png',
                  width: 28,
                  height: 28,
                ),
                tooltip: 'เพิ่มรูปภาพ',
                onPressed: () => _showImageSourcePicker(context),
              ),
            ),
          ],
        ),
        if (_existingImageUrls.isNotEmpty || _newImages.isNotEmpty) ...[
          const SizedBox(height: 8),
          SizedBox(
            height: 100,
            child: GridView.builder(
              scrollDirection: Axis.horizontal,
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 1,
                mainAxisSpacing: 8,
                crossAxisSpacing: 8,
              ),
              itemCount: _existingImageUrls.length + _newImages.length,
              itemBuilder: (context, index) {
                if (index < _existingImageUrls.length) {
                  final imageUrl = _existingImageUrls[index];
                  return _buildImageThumbnail(
                    imageProvider: NetworkImage(imageUrl),
                    onRemove:
                        _isEditing
                            ? () => _handleDeleteExistingImage(imageUrl)
                            : null,
                  );
                } else {
                  final imageIndex = index - _existingImageUrls.length;
                  final imageFile = _newImages[imageIndex];
                  return _buildImageThumbnail(
                    imageProvider: FileImage(imageFile),
                    onRemove:
                        () => setState(() => _newImages.removeAt(imageIndex)),
                  );
                }
              },
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildImageThumbnail({
    required ImageProvider imageProvider,
    required VoidCallback? onRemove,
  }) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(12.0),
      child: Stack(
        children: [
          Image(
            image: imageProvider,
            width: 100,
            height: 100,
            fit: BoxFit.cover,
            errorBuilder:
                (context, error, stackTrace) => Container(
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
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.6),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.close, color: Colors.white, size: 18),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
