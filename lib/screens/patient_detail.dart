import 'package:flutter/material.dart';
import '../services/treatment_service.dart';
import '../services/patient_service.dart';
import '../models/treatment.dart';
import 'treatment_add.dart';
import 'package:url_launcher/url_launcher.dart';

class PatientDetailScreen extends StatefulWidget {
  const PatientDetailScreen({super.key});

  @override
  State<PatientDetailScreen> createState() => _PatientDetailScreenState();
}

class _PatientDetailScreenState extends State<PatientDetailScreen>
    with WidgetsBindingObserver {
  Map<String, dynamic> patient = {};
  String patientId = '';

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed && patientId.isNotEmpty) {
      _reloadPatientData(patientId);
    }
  }

  Future<void> _reloadPatientData(String docId) async {
    final fetchedPatient = await PatientService().getPatientById(docId);
    if (fetchedPatient != null) {
      setState(() {
        patient = fetchedPatient.toMap();
        patient['docId'] = fetchedPatient.patientId;
      });
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final args =
        ModalRoute.of(context)?.settings.arguments as Map<String, dynamic>?;
    if (args != null) {
      patient = args;
      patientId = patient['docId'] ?? '';
      if (patientId.isNotEmpty) {
        _reloadPatientData(patientId);
      }
    }
  }

  @override
  void didUpdateWidget(covariant PatientDetailScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (patientId.isNotEmpty) {
      _reloadPatientData(patientId);
    }
  }

  Widget _buildRatingStars(int rating) {
    return Row(
      children: List.generate(5, (index) {
        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 2.0),
          child: Image.asset(
            index < rating
                ? 'assets/icons/tooth_good.png'
                : 'assets/icons/tooth_broke.png',
            width: 20,
            height: 20,
          ),
        );
      }),
    );
  }

  @override
  Widget build(BuildContext context) {
    final String name = patient['name'] ?? 'ไม่พบชื่อ';
    final String gender = patient['gender'] ?? 'หญิง';
    final int age = patient['age'] ?? 0;
    final String phone = patient['telephone'] ?? '-';
    final int rating = (patient['rating'] is int) ? patient['rating'] : 3;

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
        automaticallyImplyLeading: false,
        title: const Text('รายละเอียดคนไข้'),
        backgroundColor: const Color(0xFFE0BBFF),
        elevation: 0,
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(16.0),
          children: [
            GestureDetector(
              onTap: () async {
                final updated = await Navigator.pushNamed(
                  context,
                  '/add_patient',
                  arguments: patient,
                );
                if (updated == true && patientId.isNotEmpty) {
                  await Future.delayed(const Duration(milliseconds: 300));
                  await _reloadPatientData(patientId);
                }
              },
              child: Container(
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
                          child: _buildRatingStars(rating),
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
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('เบอร์โทร: $phone'),
                              const SizedBox(height: 4),
                              Text('ที่อยู่: ${patient['address'] ?? '-'}'),
                            ],
                          ),
                        ),
                        ElevatedButton.icon(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.greenAccent.shade100,
                            foregroundColor: Colors.black,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(20),
                            ),
                          ),
                          onPressed: () async {
                            final uri = Uri.parse('tel:$phone');
                            if (await canLaunchUrl(uri)) {
                              await launchUrl(uri);
                            }
                          },
                          icon: Image.asset(
                            'assets/icons/phone.png',
                            width: 20,
                            height: 20,
                          ),
                          label: const Text('โทร'),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 24),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'ประวัติการรักษา',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: Colors.purple,
                  ),
                ),
                StreamBuilder<List<Treatment>>(
                  stream: TreatmentService().getTreatments(patientId),
                  builder: (context, snapshot) {
                    if (!snapshot.hasData || snapshot.data!.isEmpty) {
                      return const Text(
                        '🧾 0 บาท',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: Colors.purple,
                        ),
                      );
                    }
                    final total = snapshot.data!
                        .map((e) => e.price)
                        .fold(0.0, (a, b) => a + b);
                    return Text(
                      '🧾 ${total.toStringAsFixed(0)} บาท',
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: Colors.purple,
                      ),
                    );
                  },
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
                    return GestureDetector(
                      onTap: () {
                        showTreatmentDialog(
                          context,
                          patientId: patientId,
                          treatment: treatment.toMap(),
                        );
                      },
                      child: Card(
                        margin: const EdgeInsets.only(bottom: 12),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                        elevation: 2,
                        color: Colors.white,
                        child: Padding(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 16.0,
                            vertical: 12.0,
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Row(
                                children: [
                                  Image.asset(
                                    'assets/icons/report.png',
                                    width: 24,
                                  ),
                                  const SizedBox(width: 8),
                                  Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(treatment.procedure),
                                      Row(
                                        children: [
                                          Image.asset(
                                            'assets/icons/tooth.png',
                                            width: 16,
                                          ),
                                          const SizedBox(width: 4),
                                          Text(treatment.toothNumber),
                                        ],
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.end,
                                children: [
                                  Row(
                                    children: [
                                      Image.asset(
                                        'assets/icons/money.png',
                                        width: 16,
                                      ),
                                      const SizedBox(width: 4),
                                      Text(
                                        '${treatment.price.toStringAsFixed(0)} บาท',
                                      ),
                                    ],
                                  ),
                                  Row(
                                    children: [
                                      Image.asset(
                                        'assets/icons/calendar.png',
                                        width: 16,
                                      ),
                                      const SizedBox(width: 4),
                                      Text(
                                        '${treatment.date.day}/${treatment.date.month}/${treatment.date.year}',
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ],
                          ),
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
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          final id = patient['id'] ?? 'P-0001';
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
