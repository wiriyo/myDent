import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../auth/auth_provider.dart';
import '../services/clinic_settings_service.dart';
import '../styles/app_theme.dart';
import '../services/logo_cache_service.dart';
import '../config/clinic_defaults.dart';
import '../config/feature_flags.dart';
import '../utils/upload_image_payload.dart';
import '../widgets/adaptive_network_image.dart';
import '../core/widgets/responsive_shell.dart';

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
  bool _welcomeScreenEnabled = FeatureFlags.showInAppSplash;

  String? _logoUrl;
  UploadImagePayload? _logoImage;
  bool _loading = true;
  bool _saving = false;

  final _service = ClinicSettingsService();

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final clinicId =
        Provider.of<AppAuthProvider>(context, listen: false).verifiedClinicId;
    if (clinicId == null || clinicId.isEmpty) {
      setState(() => _loading = false);
      return;
    }
    final data = await _service.getClinicInfo(clinicId: clinicId);
    if (data != null) {
      _logoUrl = data['logoUrl'] as String?;
      final loadedName = (data['name'] ?? '') as String;
      _nameCtrl.text =
          loadedName.isEmpty ? ClinicDefaults.defaultClinicName : loadedName;
      _addressCtrl.text = (data['address'] ?? '') as String;
      _phoneCtrl.text = _PhoneDashFormatter.format(
        (data['phone'] ?? '') as String,
      );
      _lineCtrl.text = (data['lineId'] ?? '') as String;
      _showLine = (data['showLineId'] ?? true) as bool;
      _taxCtrl.text = (data['taxId'] ?? '') as String;
      _showTax = (data['showTaxId'] ?? false) as bool;
      _welcomeScreenEnabled =
          (data['welcomeScreenEnabled'] ?? FeatureFlags.showInAppSplash)
              as bool;
      try {
        final prefs = await SharedPreferences.getInstance();
        await prefs.setBool(
          'mydent.welcomeScreenEnabled',
          _welcomeScreenEnabled,
        );
      } catch (_) {}
    }
    setState(() => _loading = false);
  }

  Future<void> _pickLogo() async {
    final picker = ImagePicker();
    final x = await picker.pickImage(
      source: ImageSource.gallery,
      imageQuality: 85,
      maxWidth: 1024,
    );
    final payload = await UploadImagePayload.fromXFile(x);
    if (payload != null) {
      setState(() => _logoImage = payload);
    }
  }

  Widget _buildLogoPreview() {
    if (_logoImage != null) {
      return Image.memory(
        _logoImage!.bytes,
        fit: BoxFit.cover,
        errorBuilder:
            (context, error, stackTrace) => Container(
              color: Colors.grey.shade200,
              alignment: Alignment.center,
              child: const Icon(
                Icons.broken_image,
                size: 40,
                color: Colors.grey,
              ),
            ),
      );
    }

    if (_logoUrl != null && _logoUrl!.isNotEmpty) {
      return AdaptiveNetworkImage(
        url: _logoUrl!,
        fit: BoxFit.cover,
        placeholder: Container(
          color: Colors.purple.shade50,
          alignment: Alignment.center,
          child: const CircularProgressIndicator(strokeWidth: 2),
        ),
        error: Container(
          color: Colors.grey.shade200,
          alignment: Alignment.center,
          child: const Icon(Icons.broken_image, size: 40, color: Colors.grey),
        ),
      );
    }

    return Image.asset(ClinicDefaults.defaultLogoAsset, fit: BoxFit.cover);
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _saving = true);
    try {
      final clinicId =
          Provider.of<AppAuthProvider>(context, listen: false).verifiedClinicId;
      String? logoUrl = _logoUrl;
      if (_logoImage != null) {
        logoUrl = await _service.uploadLogo(_logoImage!, clinicId: clinicId);
        try {
          await LogoCacheService.save(_logoImage!.bytes);
        } catch (_) {}
      }
      final nameVal = _nameCtrl.text.trim();
      final addressVal = _addressCtrl.text.trim();
      final phoneVal = _PhoneDashFormatter.format(_phoneCtrl.text);
      final lineVal = _lineCtrl.text.trim();
      final taxVal = _taxCtrl.text.trim();

      await _service.saveClinicInfo(
        clinicId: clinicId,
        logoUrl: logoUrl,
        name: nameVal.isEmpty ? null : nameVal,
        address: addressVal.isEmpty ? null : addressVal,
        phone: phoneVal.isEmpty ? null : phoneVal,
        lineId: lineVal.isEmpty ? null : lineVal,
        showLineId: _showLine,
        taxId: taxVal.isEmpty ? null : taxVal,
        showTaxId: _showTax,
        welcomeScreenEnabled: _welcomeScreenEnabled,
      );
      try {
        final prefs = await SharedPreferences.getInstance();
        await prefs.setBool(
          'mydent.welcomeScreenEnabled',
          _welcomeScreenEnabled,
        );
      } catch (_) {}
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('บันทึกข้อมูลคลินิกแล้ว')));
      Navigator.pop(context);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('เกิดข้อผิดพลาด: $e')));
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
      appBar: AppBar(
        title: const Text('ข้อมูลคลินิก'),
        backgroundColor: AppTheme.primaryLight,
        elevation: 0,
      ),
      backgroundColor: AppTheme.background,
      body:
          _loading
              ? const Center(
                child: CircularProgressIndicator(color: AppTheme.primary),
              )
              : SingleChildScrollView(
                padding: const EdgeInsets.all(16),
                child: Form(
                  key: _formKey,
                  child: ResponsiveShell(
                    maxWidth: 560,
                    // responsive for web
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                      Align(
                        alignment: Alignment.centerRight,
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Text(
                              'Welcome Screen',
                              style: TextStyle(fontWeight: FontWeight.bold),
                            ),
                            Switch(
                              value: _welcomeScreenEnabled,
                              onChanged:
                                  (val) => setState(
                                    () => _welcomeScreenEnabled = val,
                                  ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 8),
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
                                  boxShadow: [
                                    BoxShadow(
                                      color: Colors.black.withValues(
                                        alpha: 0.05,
                                      ),
                                      blurRadius: 10,
                                      offset: const Offset(0, 4),
                                    ),
                                  ],
                                ),
                                child: ClipOval(child: _buildLogoPreview()),
                              ),
                            ),
                            if (_logoImage != null ||
                                (_logoUrl != null && _logoUrl!.isNotEmpty))
                              Positioned(
                                top: -6,
                                right: -6,
                                child: Material(
                                  color: Colors.transparent,
                                  child: InkWell(
                                    onTap:
                                        _saving
                                            ? null
                                            : () async {
                                              final messenger =
                                                  ScaffoldMessenger.of(context);
                                              if (_logoImage != null) {
                                                setState(
                                                  () => _logoImage = null,
                                                );
                                              } else if (_logoUrl != null &&
                                                  _logoUrl!.isNotEmpty) {
                                                final url = _logoUrl!;
                                                setState(() => _logoUrl = null);
                                                try {
                                                  await _service.deleteLogo(
                                                    logoUrl: url,
                                                  );
                                                  await LogoCacheService.clear();
                                                  if (!mounted) return;
                                                  messenger.showSnackBar(
                                                    const SnackBar(
                                                      content: Text(
                                                        'ลบโลโก้แล้ว',
                                                      ),
                                                    ),
                                                  );
                                                } catch (e) {
                                                  if (!mounted) return;
                                                  messenger.showSnackBar(
                                                    SnackBar(
                                                      content: Text(
                                                        'ลบโลโก้ไม่สำเร็จ: $e',
                                                      ),
                                                    ),
                                                  );
                                                }
                                              }
                                            },
                                    borderRadius: BorderRadius.circular(12),
                                    child: Container(
                                      padding: const EdgeInsets.all(4),
                                      decoration: const BoxDecoration(
                                        color: Colors.redAccent,
                                        shape: BoxShape.circle,
                                      ),
                                      child: const Icon(
                                        Icons.close,
                                        color: Colors.white,
                                        size: 16,
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 16),
                      const Text(
                        'ชื่อคลินิก',
                        style: TextStyle(fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 6),
                      TextFormField(
                        controller: _nameCtrl,
                        keyboardType: TextInputType.multiline,
                        textInputAction: TextInputAction.newline,
                        minLines: 1,
                        maxLines: 3,
                        decoration: _inputDecoration('ระบุชื่อคลินิก'),
                        // อนุญาตให้ว่างได้ (ระบบจะแสดงค่า default เมื่ออ่านเพื่อใช้งาน)
                      ),
                      const SizedBox(height: 16),
                      const Text(
                        'ที่อยู่คลินิก',
                        style: TextStyle(fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 6),
                      TextFormField(
                        controller: _addressCtrl,
                        maxLines: 3,
                        decoration: _inputDecoration('กรอกที่อยู่คลินิก'),
                        validator: (_) => null,
                      ),
                      const SizedBox(height: 16),
                      Row(
                        children: [
                          const Expanded(
                            child: Text(
                              'เลขที่ผู้เสียภาษี',
                              style: TextStyle(fontWeight: FontWeight.bold),
                            ),
                          ),
                          Switch(
                            value: _showTax,
                            onChanged: (val) => setState(() => _showTax = val),
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      TextFormField(
                        controller: _taxCtrl,
                        keyboardType: TextInputType.number,
                        decoration: _inputDecoration(
                          'ระบุเลขที่ผู้เสียภาษี (ไม่บังคับ)',
                        ),
                      ),
                      const SizedBox(height: 16),
                      const Text(
                        'เบอร์โทร',
                        style: TextStyle(fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 6),
                      TextFormField(
                        controller: _phoneCtrl,
                        keyboardType: TextInputType.phone,
                        inputFormatters: [_PhoneDashFormatter()],
                        decoration: _inputDecoration('เช่น 0812345678'),
                        validator: (_) => null,
                      ),
                      const SizedBox(height: 16),
                      Row(
                        children: [
                          const Expanded(
                            child: Text(
                              'Line ID',
                              style: TextStyle(fontWeight: FontWeight.bold),
                            ),
                          ),
                          Switch(
                            value: _showLine,
                            onChanged: (val) => setState(() => _showLine = val),
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      TextFormField(
                        controller: _lineCtrl,
                        decoration: _inputDecoration(
                          'ระบุ Line ID (ไม่บังคับ)',
                        ),
                      ),
                      const SizedBox(height: 24),
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton.icon(
                          onPressed: _saving ? null : _save,
                          icon:
                              _saving
                                  ? const SizedBox(
                                    width: 16,
                                    height: 16,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      color: Colors.white,
                                    ),
                                  )
                                  : const Icon(Icons.save_outlined),
                          label: const Text('บันทึก'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppTheme.primary,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
    ));
  }

  InputDecoration _inputDecoration(String hint) {
    return InputDecoration(
      hintText: hint,
      filled: true,
      fillColor: Colors.white,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide.none,
      ),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
    );
  }
}

class _PhoneDashFormatter extends TextInputFormatter {
  static String format(String input) {
    final digits = input.replaceAll(RegExp(r'[^0-9]'), '');
    final buffer = StringBuffer();
    for (var i = 0; i < digits.length && i < 10; i++) {
      if (i == 3 || i == 6) {
        buffer.write('-');
      }
      buffer.write(digits[i]);
    }
    return buffer.toString();
  }

  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    final formatted = format(newValue.text);
    final int digitsBeforeCursor =
        newValue.selection.end <= 0
            ? 0
            : newValue.text
                .substring(0, newValue.selection.end)
                .replaceAll(RegExp(r'[^0-9]'), '')
                .length;

    int cursorPosition = 0;
    int digitCount = 0;
    while (cursorPosition < formatted.length &&
        digitCount < digitsBeforeCursor) {
      if (formatted[cursorPosition] != '-') {
        digitCount++;
      }
      cursorPosition++;
    }

    return TextEditingValue(
      text: formatted,
      selection: TextSelection.collapsed(offset: cursorPosition),
    );
  }
}
