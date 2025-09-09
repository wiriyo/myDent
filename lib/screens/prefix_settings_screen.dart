import 'package:flutter/material.dart';
import '../services/prefix_service.dart';
import '../models/prefix.dart';
import '../config/clinic_context.dart';

class PrefixSettingsScreen extends StatefulWidget {
  const PrefixSettingsScreen({super.key});

  @override
  State<PrefixSettingsScreen> createState() => _PrefixSettingsScreenState();
}

class _PrefixSettingsScreenState extends State<PrefixSettingsScreen> {
  final _controller = TextEditingController();
  bool _submitting = false;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _addPrefix() async {
    final name = _controller.text.trim();
    if (name.isEmpty) return;
    setState(() => _submitting = true);
    try {
      await PrefixService.addPrefix(name);
      _controller.clear();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('เพิ่มคำนำหน้านามไม่สำเร็จ: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  Future<void> _editPrefix(Prefix prefix) async {
    final controller = TextEditingController(text: prefix.name);
    final result = await showDialog<String>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('แก้ไขคำนำหน้านาม'),
        content: TextField(
          controller: controller,
          decoration: const InputDecoration(hintText: 'เช่น นาย, นาง, น.ส.'),
          autofocus: true,
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('ยกเลิก')),
          ElevatedButton(onPressed: () => Navigator.pop(context, controller.text.trim()), child: const Text('บันทึก')),
        ],
      ),
    );
    if (result == null) return;
    final newName = result.trim();
    if (newName.isEmpty || newName == prefix.name) return;
    try {
      await PrefixService.updatePrefix(prefix.id, newName);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('แก้ไขไม่สำเร็จ: $e')),
        );
      }
    }
  }

  Future<void> _deletePrefix(Prefix prefix) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('ลบคำนำหน้านาม'),
        content: Text('ต้องการลบ "${prefix.name}" ใช่ไหม'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('ยกเลิก')),
          ElevatedButton(onPressed: () => Navigator.pop(context, true), child: const Text('ลบ')),
        ],
      ),
    );
    if (confirm != true) return;
    try {
      await PrefixService.deletePrefix(prefix.id);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('ลบไม่สำเร็จ: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final clinicId = ClinicContext.activeClinicId;
    final hasClinic = clinicId != null && clinicId.isNotEmpty;

    return Scaffold(
      appBar: AppBar(title: const Text('ตั้งค่าคำนำหน้านาม')),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            if (!hasClinic)
              const Padding(
                padding: EdgeInsets.only(bottom: 12.0),
                child: Text('ไม่พบรหัสคลินิก กรุณาเข้าสู่ระบบ/เลือกคลินิกใหม่', style: TextStyle(color: Colors.red)),
              ),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _controller,
                    decoration: const InputDecoration(hintText: 'เพิ่มคำนำหน้านาม เช่น นาย, นาง, น.ส.')
                  ),
                ),
                const SizedBox(width: 12),
                ElevatedButton(
                  onPressed: _submitting || !hasClinic ? null : _addPrefix,
                  child: _submitting ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2)) : const Text('เพิ่ม'),
                )
              ],
            ),
            const SizedBox(height: 16),
            Expanded(
              child: StreamBuilder<List<Prefix>>(
                stream: PrefixService.getAllPrefixes().map((list) => list..sort((a, b) => a.name.compareTo(b.name))),
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Center(child: CircularProgressIndicator());
                  }
                  if (snapshot.hasError) {
                    return Center(child: Text('เกิดข้อผิดพลาด: ${snapshot.error}'));
                  }
                  final items = snapshot.data ?? [];
                  if (items.isEmpty) {
                    return const Center(child: Text('ยังไม่มีคำนำหน้านาม'));
                  }
                  return ListView.separated(
                    itemCount: items.length,
                    separatorBuilder: (_, __) => const Divider(height: 1),
                    itemBuilder: (context, index) {
                      final p = items[index];
                      return ListTile(
                        title: Text(p.name),
                        onTap: () => _editPrefix(p),
                        trailing: IconButton(
                          icon: const Icon(Icons.delete_outline),
                          onPressed: () => _deletePrefix(p),
                        ),
                      );
                    },
                  );
                },
              ),
            )
          ],
        ),
      ),
    );
  }
}

