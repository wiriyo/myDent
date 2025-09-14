import 'dart:io';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';

import '../auth/auth_provider.dart';
import '../services/clinic_settings_service.dart';
import '../styles/app_theme.dart';

class ClinicSettingsScreen extends StatefulWidget {
  const ClinicSettingsScreen({super.key});

  @override
  State<ClinicSettingsScreen> createState() => _ClinicSettingsScreenState();
}

class _ClinicSettingsScreenState extends State<ClinicSettingsScreen> {
  final _formKey = GlobalKey<FormState>();
  final _addressCtrl = TextEditingController();
  final _phoneCtrl = TextEditingController();
  final _lineCtrl = TextEditingController();
  bool _showLine = true;
  final _nameCtrl = TextEditingController();
  final _taxCtrl = TextEditingController();
  bool _showTax = false;

  String? _logoUrl;
  File? _logoFile;
  bool _loading = true;
  bool _saving = false;

  final _service = ClinicSettingsService();

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final clinicId = Provider.of<AppAuthProvider>(context, listen: false).verifiedClinicId;
    if (clinicId == null || clinicId.isEmpty) {
      setState(() => _loading = false);
      return;
    }
    final data = await _service.getClinicInfo(clinicId: clinicId);
    if (data != null) {
      _logoUrl = data['logoUrl'] as String?;
      _nameCtrl.text = (data['name'] ?? '') as String;
      _addressCtrl.text = (data['address'] ?? '') as String;
      _phoneCtrl.text = (data['phone'] ?? '') as String;
      _lineCtrl.text = (data['lineId'] ?? '') as String;
      _showLine = (data['showLineId'] ?? true) as bool;
      _taxCtrl.text = (data['taxId'] ?? '') as String;
      _showTax = (data['showTaxId'] ?? false) as bool;
    }
    setState(() => _loading = false);
  }

  Future<void> _pickLogo() async {
    final picker = ImagePicker();
    final x = await picker.pickImage(source: ImageSource.gallery, imageQuality: 85, maxWidth: 1024);
    if (x != null) {
      setState(() => _logoFile = File(x.path));
    }
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _saving = true);
    try {
      final clinicId = Provider.of<AppAuthProvider>(context, listen: false).verifiedClinicId;
      String? logoUrl = _logoUrl;
      if (_logoFile != null) {
        logoUrl = await _service.uploadLogo(_logoFile!, clinicId: clinicId);
      }
      await _service.saveClinicInfo(
        clinicId: clinicId,
        logoUrl: logoUrl,
        name: _nameCtrl.text.trim(),
        address: _addressCtrl.text.trim(),
        phone: _phoneCtrl.text.trim(),
        lineId: _lineCtrl.text.trim().isEmpty ? null : _lineCtrl.text.trim(),
        showLineId: _showLine,
        taxId: _taxCtrl.text.trim().isEmpty ? null : _taxCtrl.text.trim(),
        showTaxId: _showTax,
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('บันทึกข้อมูลคลินิกแล้ว')));
      Navigator.pop(context);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('เกิดข้อผิดพลาด: $e')));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _addressCtrl.dispose();
    _phoneCtrl.dispose();
    _lineCtrl.dispose();
    _taxCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('ข้อมูลคลินิก'), backgroundColor: AppTheme.primaryLight, elevation: 0),
      backgroundColor: AppTheme.background,
      body: _loading
          ? const Center(child: CircularProgressIndicator(color: AppTheme.primary))
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Center(
                      child: Stack(
                        clipBehavior: Clip.none,
                        children: [
                          InkWell(
                            onTap: _saving ? null : _pickLogo,
                            borderRadius: BorderRadius.circular(80),
                            child: Container(
                              width: 140,
                              height: 140,
                              decoration: BoxDecoration(
                                color: Colors.white,
                                shape: BoxShape.circle,
                                boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10, offset: const Offset(0, 4))],
                                image: _logoFile != null
                                    ? DecorationImage(image: FileImage(_logoFile!), fit: BoxFit.cover)
                                    : (_logoUrl != null && _logoUrl!.isNotEmpty)
                                        ? DecorationImage(image: NetworkImage(_logoUrl!), fit: BoxFit.cover)
                                        : null,
                              ),
                              child: (_logoFile == null && (_logoUrl == null || _logoUrl!.isEmpty))
                                  ? Column(
                                      mainAxisAlignment: MainAxisAlignment.center,
                                      children: const [
                                        Icon(Icons.image_outlined, color: AppTheme.textSecondary),
                                        SizedBox(height: 6),
                                        Text('โลโก้คลินิก', style: TextStyle(color: AppTheme.textSecondary)),
                                      ],
                                    )
                                  : null,
                            ),
                          ),
                          if (_logoFile != null || (_logoUrl != null && _logoUrl!.isNotEmpty))
                            Positioned(
                              top: -6,
                              right: -6,
                              child: Material(
                                color: Colors.transparent,
                                child: InkWell(
                                  onTap: _saving
                                      ? null
                                      : () async {
                                          if (_logoFile != null) {
                                            setState(() => _logoFile = null);
                                          } else if (_logoUrl != null && _logoUrl!.isNotEmpty) {
                                            final url = _logoUrl!;
                                            setState(() => _logoUrl = null);
                                            try {
                                              await _service.deleteLogo(logoUrl: url);
                                              if (mounted) {
                                                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('ลบโลโก้แล้ว')));
                                              }
                                            } catch (e) {
                                              if (mounted) {
                                                ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('ลบโลโก้ไม่สำเร็จ: $e')));
                                              }
                                            }
                                          }
                                        },
                                  borderRadius: BorderRadius.circular(12),
                                  child: Container(
                                    padding: const EdgeInsets.all(4),
                                    decoration: const BoxDecoration(color: Colors.redAccent, shape: BoxShape.circle),
                                    child: const Icon(Icons.close, color: Colors.white, size: 16),
                                  ),
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),
                    const Text('ชื่อคลินิก', style: TextStyle(fontWeight: FontWeight.bold)),
                    const SizedBox(height: 6),
                    TextFormField(
                      controller: _nameCtrl,
                      decoration: _inputDecoration('ระบุชื่อคลินิก'),
                      validator: (v) => (v == null || v.trim().isEmpty) ? 'กรุณากรอกชื่อคลินิก' : null,
                    ),
                    const SizedBox(height: 16),
                    const Text('ที่อยู่คลินิก', style: TextStyle(fontWeight: FontWeight.bold)),
                    const SizedBox(height: 6),
                    TextFormField(
                      controller: _addressCtrl,
                      maxLines: 3,
                      decoration: _inputDecoration('กรอกที่อยู่คลินิก'),
                      validator: (v) => (v == null || v.trim().isEmpty) ? 'กรุณากรอกที่อยู่' : null,
                    ),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        const Expanded(child: Text('เลขที่ผู้เสียภาษี', style: TextStyle(fontWeight: FontWeight.bold))),
                        Switch(value: _showTax, onChanged: (val) => setState(() => _showTax = val)),
                      ],
                    ),
                    const SizedBox(height: 6),
                    TextFormField(
                      controller: _taxCtrl,
                      keyboardType: TextInputType.number,
                      decoration: _inputDecoration('ระบุเลขที่ผู้เสียภาษี (ไม่บังคับ)'),
                    ),
                    const SizedBox(height: 16),
                    const Text('เบอร์โทร', style: TextStyle(fontWeight: FontWeight.bold)),
                    const SizedBox(height: 6),
                    TextFormField(
                      controller: _phoneCtrl,
                      keyboardType: TextInputType.phone,
                      decoration: _inputDecoration('เช่น 0812345678'),
                      validator: (v) => (v == null || v.trim().isEmpty) ? 'กรุณากรอกเบอร์โทร' : null,
                    ),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        const Expanded(child: Text('Line ID', style: TextStyle(fontWeight: FontWeight.bold))),
                        Switch(value: _showLine, onChanged: (val) => setState(() => _showLine = val)),
                      ],
                    ),
                    const SizedBox(height: 6),
                    TextFormField(
                      controller: _lineCtrl,
                      decoration: _inputDecoration('ระบุ Line ID (ไม่บังคับ)'),
                    ),
                    const SizedBox(height: 24),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        onPressed: _saving ? null : _save,
                        icon: _saving
                            ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                            : const Icon(Icons.save_outlined),
                        label: const Text('บันทึก'),
                        style: ElevatedButton.styleFrom(backgroundColor: AppTheme.primary, foregroundColor: Colors.white, padding: const EdgeInsets.symmetric(vertical: 14), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
                      ),
                    ),
                  ],
                ),
              ),
            ),
    );
  }

  InputDecoration _inputDecoration(String hint) {
    return InputDecoration(
      hintText: hint,
      filled: true,
      fillColor: Colors.white,
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
    );
  }
}
