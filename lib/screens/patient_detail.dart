import 'package:flutter/material.dart';
import '../services/treatment_service.dart';
import '../models/treatment.dart';
import 'treatment_add.dart';

// class PatientDetailScreen extends StatelessWidget {
//   const PatientDetailScreen({super.key});
class PatientDetailScreen extends StatefulWidget {
  const PatientDetailScreen({super.key});

  @override
  State<PatientDetailScreen> createState() => _PatientDetailScreenState();
}

class _PatientDetailScreenState extends State<PatientDetailScreen> {
  late Map<String, dynamic> patient;
  late String patientId;
  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final args =
        ModalRoute.of(context)?.settings.arguments as Map<String, dynamic>?;
    patient =
        args ??
        {
          'docId': 'P-0001',
          'name': 'ไม่พบชื่อ',
          'gender': 'หญิง',
          'age': 0,
          'phone': '-',
          'rating': 3,
        };
    patientId = patient['docId'];
    print('🧾 patientId ที่รับมา: $patientId');
  }

  @override
  Widget build(BuildContext context) {
    //final patient =
        // ModalRoute.of(context)?.settings.arguments as Map<String, dynamic> ??
        // {
        //   'id': 'P-0001',
        //   'name': 'กานต์รวี หอมหวาน',
        //   'gender': 'หญิง',
        //   'age': 25,
        //   'phone': '091-234-5678',
        //   'rating': 5,
        // };
    //final String id = patient?['id'] ?? 'P-0001';
    final String name = patient?['name'] ?? 'กานต์รวี หอมหวาน';
    final String gender = patient?['gender'] ?? 'หญิง';
    final int age = patient?['age'] ?? 25;
    final String phone = patient?['phone'] ?? '091-234-5678';
    final int rating = patient?['rating'] ?? 5;

    Color cardColor;
    if (rating >= 5) {
      cardColor = const Color(0xFFE0F7E9);
    } else if (rating >= 4) {
      cardColor = const Color(0xFFFFF8E1);
    } else {
      cardColor = const Color(0xFFFFEBEE);
    }

    return Scaffold(
      backgroundColor: const Color(0xFFEFE0FF),
      appBar: AppBar(
        title: const Text('รายละเอียดคนไข้'),
        backgroundColor: const Color(0xFFE0BBFF),
        elevation: 0,
      ),
      body: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: cardColor,
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.purple.shade100,
                      blurRadius: 6,
                      offset: const Offset(0, 3),
                    ),
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          name,
                          style: const TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.bold,
                            color: Colors.purple,
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 6,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.8),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: Colors.purple.shade200),
                          ),
                          child: Text(
                            '🦷' * rating,
                            style: const TextStyle(fontSize: 20),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Icon(
                          gender == 'ชาย' ? Icons.male : Icons.female,
                          color: gender == 'ชาย' ? Colors.blue : Colors.pink,
                          size: 20,
                        ),
                        const SizedBox(width: 6),
                        Text('อายุ $age ปี'),
                      ],
                    ),
                    const SizedBox(height: 8),
                    const Text('เลขบัตร: 1234567890123'),
                    const SizedBox(height: 4),
                    Text('เบอร์โทร: $phone'),
                    const SizedBox(height: 4),
                    const Text('ที่อยู่: 123/4 ถ.สุขใจ เขตบางน่ารัก กรุงเทพฯ'),
                    const SizedBox(height: 12),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        ElevatedButton.icon(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.greenAccent.shade100,
                            foregroundColor: Colors.black,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(20),
                            ),
                          ),
                          onPressed: () {},
                          icon: const Icon(Icons.call),
                          label: const Text('โทร'),
                        ),
                        const SizedBox(width: 8),
                        ElevatedButton.icon(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.orangeAccent.shade100,
                            foregroundColor: Colors.black,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(20),
                            ),
                          ),
                          onPressed: () {},
                          icon: const Icon(Icons.edit),
                          label: const Text('แก้ไข'),
                        ),
                        const SizedBox(width: 8),
                        ElevatedButton.icon(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.redAccent.shade100,
                            foregroundColor: Colors.black,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(20),
                            ),
                          ),
                          onPressed: () {
                            showDialog(
                              context: context,
                              builder: (BuildContext context) {
                                return AlertDialog(
                                  title: const Text('ยืนยันการลบ'),
                                  content: const Text(
                                    'คุณแน่ใจหรือไม่ว่าต้องการลบข้อมูลนี้?',
                                  ),
                                  actions: [
                                    TextButton(
                                      child: const Text('ยกเลิก'),
                                      onPressed: () {
                                        Navigator.of(context).pop();
                                      },
                                    ),
                                    TextButton(
                                      child: const Text('ลบ'),
                                      onPressed: () {
                                        Navigator.of(context).pop();
                                      },
                                    ),
                                  ],
                                );
                              },
                            );
                          },
                          icon: const Icon(Icons.delete),
                          label: const Text('ลบ'),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: const [
                  Text(
                    'ประวัติการรักษา',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: Colors.purple,
                    ),
                  ),
                  Text(
                    '🧾 2,400 บาท',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: Colors.purple,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              StreamBuilder<List<Treatment>>(
                stream: TreatmentService().getTreatments(patientId),
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Center(child: CircularProgressIndicator());
                  }
                  if (!snapshot.hasData || snapshot.data!.isEmpty) {
                    return const Padding(
                      padding: EdgeInsets.all(16.0),
                      child: Text('ยังไม่มีประวัติการรักษา'),
                    );
                  }

                  final treatments = snapshot.data!;
                  return ListView.builder(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: treatments.length,
                    itemBuilder: (context, index) {
                      final treatment = treatments[index];
                      return Card(
                        margin: const EdgeInsets.only(bottom: 12),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                        elevation: 2,
                        color: Colors.white,
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text('🛠️ ${treatment.procedure}'),
                                  Text('🦷 ${treatment.toothNumber}'),
                                ],
                              ),
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.end,
                                children: [
                                  Text('💰 ${treatment.price.toStringAsFixed(0)} บาท'),
                                  Text('📅 ${treatment.date.day}/${treatment.date.month}/${treatment.date.year}'),
                                ],
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  );
                },
              ),
            ],
          ),
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          final id = patient['id'] ?? 'P-0001'; // fallback ถ้า id หาย
          showTreatmentDialog(context, patientId: patient['docId']);
        },

        backgroundColor: Colors.purple,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
        child: const Icon(Icons.add, color: Colors.white, size: 36),
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
                    ModalRoute.of(context)?.settings.name == '/calendar'
                        ? Colors.purple
                        : Colors.purple.shade200,
                onPressed: () {
                  if (ModalRoute.of(context)?.settings.name != '/calendar') {
                    Navigator.pushNamed(context, '/calendar');
                  }
                },
              ),
              IconButton(
                icon: const Icon(Icons.people_alt, size: 30),
                color:
                    ModalRoute.of(context)?.settings.name == '/patients'
                        ? Colors.purple
                        : Colors.purple.shade200,
                onPressed: () {
                  if (ModalRoute.of(context)?.settings.name != '/patients') {
                    Navigator.pushNamed(context, '/patients');
                  }
                },
              ),
              const SizedBox(width: 40),
              IconButton(
                icon: const Icon(Icons.bar_chart, size: 30),
                color:
                    ModalRoute.of(context)?.settings.name == '/reports'
                        ? Colors.purple
                        : Colors.purple.shade200,
                onPressed: () {
                  if (ModalRoute.of(context)?.settings.name != '/reports') {
                    Navigator.pushNamed(context, '/reports');
                  }
                },
              ),
              IconButton(
                icon: const Icon(Icons.settings, size: 30),
                color:
                    ModalRoute.of(context)?.settings.name == '/settings'
                        ? Colors.purple
                        : Colors.purple.shade200,
                onPressed: () {
                  if (ModalRoute.of(context)?.settings.name != '/settings') {
                    Navigator.pushNamed(context, '/settings');
                  }
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}
