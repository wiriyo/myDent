import 'package:flutter/material.dart';
import '../models/treatment_master.dart';
import '../services/treatment_master_service.dart';
import '../widgets/treatment_form_master.dart';

class TreatmentListScreen extends StatefulWidget {
  const TreatmentListScreen({super.key});

  @override
  State<TreatmentListScreen> createState() => _TreatmentListScreenState();
}

class _TreatmentListScreenState extends State<TreatmentListScreen> {
  int _selectedIndex = 4;

  void _onItemTapped(int index) {
    setState(() => _selectedIndex = index);

    if (index == 0) {
      Navigator.pushReplacementNamed(context, '/calendar');
    } else if (index == 1) {
      Navigator.pushReplacementNamed(context, '/patients');
    } else if (index == 3) {
      Navigator.pushReplacementNamed(context, '/reports');
    } else if (index == 4) {
      Navigator.pushReplacementNamed(context, '/settings');
    }
  }

  void _showTreatmentForm({TreatmentMaster? treatment}) {
    showDialog(
      context: context,
      builder:
          (context) => AlertDialog(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            backgroundColor: const Color(0xFFF9F0FF),
            titlePadding: const EdgeInsets.only(top: 16, left: 20, right: 8),
            title: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  treatment == null ? 'เพิ่มหัตถการ' : 'แก้ไขหัตถการ',
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
                GestureDetector(
                  onTap: () => Navigator.of(context).pop(),
                  child: Image.asset(
                    'assets/icons/back.png',
                    width: 24,
                    color: Colors.purple,
                  ),
                ),
              ],
            ),
            content: TreatmentFormMaster(
              treatment: treatment,
              onSave: (newTreatment) {
                if (treatment == null) {
                  TreatmentMasterService.addTreatment(newTreatment);
                } else {
                  TreatmentMasterService.updateTreatment(newTreatment);
                }
                Navigator.of(context).pop();
              },
              onDelete:
                  treatment != null
                      ? () async {
                        final confirm = await showDialog<bool>(
                          context: context,
                          builder:
                              (context) => AlertDialog(
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(16),
                                ),
                                title: const Text('ยืนยันการลบ'),
                                content: Text(
                                  'ต้องการลบ "${treatment.name}" จริงหรือไม่คะ?',
                                ),
                                actions: [
                                  TextButton(
                                    onPressed:
                                        () => Navigator.of(context).pop(false),
                                    child: const Text('ยกเลิก'),
                                  ),
                                  ElevatedButton(
                                    onPressed:
                                        () => Navigator.of(context).pop(true),
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: Colors.redAccent,
                                    ),
                                    child: const Text(
                                      'ลบ',
                                      style: TextStyle(color: Colors.white),
                                    ),
                                  ),
                                ],
                              ),
                        );

                        if (confirm == true) {
                          await TreatmentMasterService.deleteTreatment(
                            treatment.treatmentId,
                          );
                          if (context.mounted) {
                            Navigator.of(context).pop(); // ปิดฟอร์ม
                          }
                        }
                      }
                      : null,
              onCancel: () => Navigator.of(context).pop(),
            ),
          ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFEFE0FF),
      appBar: AppBar(
        title: const Text('รายการหัตถการ'),
        backgroundColor: const Color(0xFFE0BBFF),
        elevation: 0,
      ),
      body: StreamBuilder<List<TreatmentMaster>>(
        stream: TreatmentMasterService.getAllTreatments(),
        builder: (context, snapshot) {
          if (!snapshot.hasData || snapshot.data!.isEmpty) {
            return const Center(child: Text('ยังไม่มีหัตถการในระบบ'));
          }

          final treatments = snapshot.data!;
          return ListView.builder(
            itemCount: treatments.length,
            itemBuilder: (context, index) {
              final treatment = treatments[index];
              return Card(
                color: Colors.white,
                elevation: 2,
                margin: const EdgeInsets.symmetric(vertical: 6, horizontal: 8),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
                child: ListTile(
                  contentPadding: const EdgeInsets.symmetric(
                    vertical: 8,
                    horizontal: 16,
                  ),
                  leading: Image.asset(
                    'assets/icons/treatment.png',
                    width: 32,
                    height: 32,
                  ),
                  title: Text(
                    treatment.name,
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      color: Colors.black87,
                    ),
                  ),
                  subtitle: Row(
                    children: [
                      Image.asset(
                        'assets/icons/clock.png',
                        width: 16,
                        height: 16,
                      ),
                      const SizedBox(width: 4),
                      Text('${treatment.duration} นาที'),
                      const SizedBox(width: 16),
                      Image.asset(
                        'assets/icons/money.png',
                        width: 16,
                        height: 16,
                      ),
                      const SizedBox(width: 4),
                      Text('${treatment.price.toStringAsFixed(0)} บาท'),
                    ],
                  ),
                  trailing: Image.asset(
                    'assets/icons/edit.png',
                    width: 24,
                    height: 24,
                  ),
                  onTap: () => _showTreatmentForm(treatment: treatment),
                ),
              );
            },
          );
        },
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _showTreatmentForm(),
        backgroundColor: Colors.purple,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
        child: const Icon(Icons.add, size: 30, color: Colors.white),
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerDocked,
      bottomNavigationBar: BottomAppBar(
        shape: const CircularNotchedRectangle(),
        notchMargin: 8,
        color: const Color(0xFFFBEAFF),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16.0),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              IconButton(
                icon: const Icon(Icons.calendar_today, size: 30),
                color:
                    _selectedIndex == 0
                        ? Colors.purple
                        : Colors.purple.shade200,
                onPressed: () => _onItemTapped(0),
              ),
              IconButton(
                icon: const Icon(Icons.people_alt, size: 30),
                color:
                    _selectedIndex == 1
                        ? Colors.purple
                        : Colors.purple.shade200,
                onPressed: () => _onItemTapped(1),
              ),
              const SizedBox(width: 40),
              IconButton(
                icon: const Icon(Icons.bar_chart, size: 30),
                color:
                    _selectedIndex == 3
                        ? Colors.purple
                        : Colors.purple.shade200,
                onPressed: () => _onItemTapped(3),
              ),
              IconButton(
                icon: const Icon(Icons.settings, size: 30),
                color:
                    _selectedIndex == 4
                        ? Colors.purple
                        : Colors.purple.shade200,
                onPressed: () => _onItemTapped(4),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
