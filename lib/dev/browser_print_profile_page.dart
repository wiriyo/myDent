import 'package:flutter/material.dart';

import '../features/printing/services/print_settings_service.dart';

class BrowserPrintProfilePage extends StatefulWidget {
  const BrowserPrintProfilePage({super.key});

  @override
  State<BrowserPrintProfilePage> createState() =>
      _BrowserPrintProfilePageState();
}

class _BrowserPrintProfilePageState extends State<BrowserPrintProfilePage> {
  final PrintSettingsService _service = PrintSettingsService();
  PrintSettings? _settings;
  bool _loading = true;
  bool _saving = false;

  static const List<int> _widthOptions = <int>[512, 576, 640];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final PrintSettings settings = await _service.load();
    if (!mounted) return;
    setState(() {
      _settings = settings;
      _loading = false;
    });
  }

  Future<void> _updateSettings({
    BrowserPrintMode? mode,
    int? width,
    bool? autoClose,
  }) async {
    if (_settings == null) {
      return;
    }
    final PrintSettings updated = _settings!.copyWith(
      browserMode: mode,
      browserPixelWidth: width,
      browserAutoClose: autoClose,
    );
    setState(() {
      _settings = updated;
      _saving = true;
    });
    try {
      await _service.save(updated);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('บันทึกการตั้งค่าพิมพ์ผ่านเบราว์เซอร์แล้ว')),
      );
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('บันทึกการตั้งค่าไม่สำเร็จ: $error')),
      );
    } finally {
      if (mounted) {
        setState(() => _saving = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    if (_loading) {
      return Scaffold(
        appBar: AppBar(title: const Text('โปรไฟล์พิมพ์ (Browser)')),
        body: const Center(child: CircularProgressIndicator()),
      );
    }
    final settings = _settings!;
    return Scaffold(
      appBar: AppBar(title: const Text('โปรไฟล์พิมพ์ (Browser)')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text(
            'ตั้งค่าการพิมพ์ผ่านเบราว์เซอร์สำหรับสลิปกระดาษ 80 มม.',
            style: theme.textTheme.titleMedium,
          ),
          const SizedBox(height: 12),
          const Text(
            'เลือกโหมดที่ต้องการใช้งานบนเบราว์เซอร์ สามารถสลับระหว่างการพิมพ์แบบรูปภาพ (PNG) '
            'และการเรนเดอร์ HTML ที่ตัวหนังสือคมชัดกว่าได้ตลอดเวลา.',
          ),
          const SizedBox(height: 16),
          Card(
            elevation: 0,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
              side: BorderSide(color: theme.colorScheme.outlineVariant),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                RadioListTile<BrowserPrintMode>(
                  value: BrowserPrintMode.png,
                  groupValue: settings.browserMode,
                  onChanged: _saving
                      ? null
                      : (mode) => _updateSettings(mode: mode),
                  title: const Text('โหมด PNG (ง่าย/เร็ว)'),
                  subtitle: const Text(
                    'เหมาะกับการเรนเดอร์จากหน้า Preview เดิม และรองรับโลโก้/ภาพประกอบได้ทันที',
                  ),
                ),
                RadioListTile<BrowserPrintMode>(
                  value: BrowserPrintMode.html,
                  groupValue: settings.browserMode,
                  onChanged: _saving
                      ? null
                      : (mode) => _updateSettings(mode: mode),
                  title: const Text('โหมด HTML (ตัวหนังสือคม)'),
                  subtitle: const Text(
                    'ใช้ HTML+CSS เพื่อให้ข้อความคมชัดกว่าเดิม เหมาะสำหรับใบเสร็จที่ต้องการความชัดสูง',
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),
          Text(
            'ความกว้างด็อตของเครื่องพิมพ์',
            style: theme.textTheme.titleMedium,
          ),
          const SizedBox(height: 8),
          DropdownButtonFormField<int>(
            value: settings.browserPixelWidth,
            decoration: const InputDecoration(
              border: OutlineInputBorder(),
              labelText: 'เลือกความกว้าง (พิกเซล)',
            ),
            items: _widthOptions
                .map(
                  (value) => DropdownMenuItem<int>(
                    value: value,
                    child: Text('$value px (80 มม.)'),
                  ),
                )
                .toList(),
            onChanged: _saving
                ? null
                : (value) {
                    if (value != null) {
                      _updateSettings(width: value);
                    }
                  },
          ),
          const SizedBox(height: 24),
          SwitchListTile.adaptive(
            value: settings.browserAutoClose,
            onChanged: _saving
                ? null
                : (value) => _updateSettings(autoClose: value),
            title: const Text('ปิดหน้าต่างพิมพ์อัตโนมัติหลังส่งพิมพ์'),
            subtitle: const Text(
              'เปิดไว้เพื่อให้หน้าต่างปิดเองหลังสั่งพิมพ์เสร็จ ช่วยลดความสับสนของสตาฟ',
            ),
          ),
          const SizedBox(height: 24),
          Text(
            'เคล็ดลับ: หากเครื่องพิมพ์ของคลินิกมีความละเอียด 203 dpi (ส่วนใหญ่) ให้เลือก 576 px. '
            'บางรุ่นอย่าง Epson TM-T88V ที่รองรับ 640 px สามารถเลือกได้ตามสเปกจริง.',
            style: theme.textTheme.bodySmall,
          ),
        ],
      ),
    );
  }
}
