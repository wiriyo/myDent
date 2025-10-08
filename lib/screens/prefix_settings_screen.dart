import 'package:flutter/material.dart';
import '../services/prefix_service.dart';
import '../models/prefix.dart';
import '../widgets/custom_bottom_nav_bar.dart'; // Import the custom bottom nav bar
import '../styles/app_theme.dart';

class PrefixSettingsScreen extends StatefulWidget {
  const PrefixSettingsScreen({super.key});

  @override
  State<PrefixSettingsScreen> createState() => _PrefixSettingsScreenState();
}

class _PrefixSettingsScreenState extends State<PrefixSettingsScreen> {
  
  @override
  void initState() {
    super.initState();
  }

  // Dialog for adding a new prefix
  Future<void> _showAddPrefixDialog() async {
    final controller = TextEditingController();
    final formKey = GlobalKey<FormState>();

    final result = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('เพิ่มคำนำหน้าใหม่'),
        content: Form(
          key: formKey,
          child: TextFormField(
            controller: controller,
            autofocus: true,
            decoration: const InputDecoration(
              labelText: 'ชื่อคำนำหน้า',
              border: OutlineInputBorder(),
              hintText: 'เช่น นาย, นาง, นางสาว',
            ),
            validator: (value) {
              if (value == null || value.trim().isEmpty) {
                return 'กรุณาใส่ชื่อคำนำหน้า';
              }
              return null;
            },
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('ยกเลิก'),
          ),
          ElevatedButton(
            onPressed: () {
              if (formKey.currentState!.validate()) {
                Navigator.of(context).pop(controller.text.trim());
              }
            },
            child: const Text('เพิ่ม'),
          ),
        ],
      ),
    );

    if (result != null && result.isNotEmpty) {
      try {
        await PrefixService.addPrefix(result);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('เพิ่มคำนำหน้าสำเร็จ'),
              backgroundColor: Colors.green,
            ),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('เกิดข้อผิดพลาด: $e'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    }
  }

  // Dialog for editing a prefix
  Future<void> _editPrefix(Prefix prefix) async {
    final controller = TextEditingController(text: prefix.name);
    final formKey = GlobalKey<FormState>();

    final result = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('แก้ไขคำนำหน้า'),
        content: Form(
          key: formKey,
          child: TextFormField(
            controller: controller,
            autofocus: true,
            decoration: const InputDecoration(
              labelText: 'ชื่อคำนำหน้า',
              border: OutlineInputBorder(),
            ),
            validator: (value) {
              if (value == null || value.trim().isEmpty) {
                return 'กรุณาใส่ชื่อคำนำหน้า';
              }
              return null;
            },
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('ยกเลิก'),
          ),
          ElevatedButton(
            onPressed: () {
               if (formKey.currentState!.validate()) {
                Navigator.of(context).pop(controller.text.trim());
              }
            },
            child: const Text('บันทึก'),
          ),
        ],
      ),
    );

    if (result != null) {
      final newName = result;
      if (newName.isEmpty || newName == prefix.name) return;

      try {
        await PrefixService.updatePrefix(prefix.id, newName);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('แก้ไขสำเร็จ'),
              backgroundColor: Colors.green,
            ),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('เกิดข้อผิดพลาด: $e'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    }
  }

  // Dialog for deleting a prefix
  Future<void> _deletePrefix(Prefix prefix) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('ยืนยันการลบ'),
        content: Text('ต้องการลบ "${prefix.name}" ใช่ไหม? การกระทำนี้ไม่สามารถย้อนกลับได้'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('ยกเลิก'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
            ),
            child: const Text('ลบ'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      try {
        await PrefixService.deletePrefix(prefix.id);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('ลบสำเร็จ'),
              backgroundColor: Colors.orange,
              ),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('เกิดข้อผิดพลาด: $e'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('จัดการคำนำหน้า'),
        backgroundColor: theme.appBarTheme.backgroundColor,
      ),
      body: StreamBuilder<List<Prefix>>(
        stream: PrefixService.getAllPrefixes().map(
          (snapshot) {
            // Sort the prefixes by name alphabetically
            snapshot.sort((a, b) => a.name.compareTo(b.name));
            return snapshot;
          },
        ),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return Center(child: Text('เกิดข้อผิดพลาด: ${snapshot.error}'));
          }
          if (!snapshot.hasData || snapshot.data!.isEmpty) {
            return const Center(child: Text('แตะปุ่ม + เพื่อเพิ่มคำนำหน้าใหม่'));
          }

          final prefixes = snapshot.data!;
          return ListView.builder(
            padding: const EdgeInsets.all(8.0),
            itemCount: prefixes.length,
            itemBuilder: (context, index) {
              final p = prefixes[index];
              return Card(
                margin: const EdgeInsets.symmetric(vertical: 4.0, horizontal: 8.0),
                elevation: 2.0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12.0),
                ),
                child: ListTile(
                  title: Text(p.name, style: theme.textTheme.titleMedium),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      IconButton(
                        icon: Icon(Icons.edit, color: theme.colorScheme.primary),
                        onPressed: () => _editPrefix(p),
                        tooltip: 'แก้ไข',
                      ),
                      IconButton(
                        icon: Icon(Icons.delete, color: theme.colorScheme.error),
                        onPressed: () => _deletePrefix(p),
                        tooltip: 'ลบ',
                      ),
                    ],
                  ),
                ),
              );
            },
          );
        },
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _showAddPrefixDialog,
        backgroundColor: AppTheme.primary,
        tooltip: 'เพิ่มคำนำหน้า',
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
        child: const Icon(Icons.add, color: Colors.white, size: 36),
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerDocked,
      bottomNavigationBar: const CustomBottomNavBar(selectedIndex: 3),
    );
  }
}
