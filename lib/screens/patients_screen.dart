import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

class PatientsScreen extends StatefulWidget {
  const PatientsScreen({super.key});

  @override
  State<PatientsScreen> createState() => _PatientsScreenState();
}

class _PatientsScreenState extends State<PatientsScreen> {
  final TextEditingController _searchController = TextEditingController();
  List<Map<String, dynamic>> _searchResults = [];
  List<Map<String, dynamic>> _allPatients = [];
  bool _isSearchExpanded = false;

  @override
  void initState() {
    super.initState();
    _fetchAllPatients();
  }

  Future<void> _fetchAllPatients() async {
    final result = await FirebaseFirestore.instance.collection('patients').get();
    setState(() {
      _allPatients = result.docs.map((doc) {
        final data = doc.data();
        return {...data, 'docId': doc.id};
      }).toList();
      _searchResults = List.from(_allPatients);
    });
  }

  void _filterPatients(String query) {
    final results = _allPatients.where((patient) {
      final name = patient['name']?.toLowerCase() ?? '';
      final phone = patient['phone']?.toLowerCase() ?? '';
      return name.contains(query.toLowerCase()) || phone.contains(query.toLowerCase());
    }).toList();

    setState(() {
      _searchResults = results;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFEFE0FF),
      appBar: AppBar(
        title: const Text('Patient'),
        backgroundColor: const Color(0xFFE0BBFF),
        elevation: 0,
      ),
      body: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: _searchResults.length,
        itemBuilder: (context, index) {
          final data = _searchResults[index];
          return GestureDetector(
            onTap: () {
              Navigator.pushNamed(
                context,
                '/patient_detail',
                arguments: data,
              );
            },
            child: _buildCard(context, data, docId: data['docId']),
          );
        },
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () async {
          final result = await Navigator.pushNamed(context, '/add_patient');
          if (result == true) {
            await _fetchAllPatients();
          }
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
                color: Colors.purple.shade200,
                onPressed: () {
                  Navigator.pushNamed(context, '/calendar');
                },
              ),
              IconButton(
                icon: const Icon(Icons.people_alt, size: 30),
                color: Colors.purple,
                onPressed: () {
                  Navigator.pushNamed(context, '/patients');
                },
              ),
              const SizedBox(width: 40),
              IconButton(
                icon: const Icon(Icons.bar_chart, size: 30),
                color: Colors.purple.shade200,
                onPressed: () {
                  Navigator.pushNamed(context, '/reports');
                },
              ),
              IconButton(
                icon: const Icon(Icons.settings, size: 30),
                color: Colors.purple.shade200,
                onPressed: () {
                  Navigator.pushNamed(context, '/settings');
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildCard(BuildContext context, Map<String, dynamic> data, {String? docId}) {
    final name = data['name'] ?? '-';
    final phone = data['phone'] ?? '-';
    final rating = data['rating'] ?? 5;
    final gender = data['gender'] ?? 'หญิง';
    final age = data['age']?.toString() ?? '-';

    Color cardColor;
    if (rating >= 5) {
      cardColor = const Color(0xFFD0F8CE);
    } else if (rating >= 4) {
      cardColor = const Color(0xFFFFF9C4);
    } else {
      cardColor = const Color(0xFFFFCDD2);
    }

    return Card(
      elevation: 4,
      color: cardColor,
      margin: const EdgeInsets.symmetric(vertical: 6),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Row(
          children: [
            Icon(
              gender == 'ชาย' ? Icons.male : Icons.female,
              color: gender == 'ชาย' ? Colors.blue : Colors.pink,
              size: 36,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(name, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
                  const SizedBox(height: 4),
                  Text('เบอร์: $phone'),
                  Text('อายุ: $age ปี'),
                ],
              ),
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Row(
                  children: List.generate(
                    rating,
                    (index) => Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 1),
                      child: Image.asset('assets/icons/tooth_good.png', width: 18, height: 18),
                    ),
                  ),
                ),
                Row(
                  children: [
                    _buildRoundedButton(
                      onPressed: () async {
                        final phoneNumber = phone.replaceAll('-', '');
                        final uri = Uri.parse('tel:$phoneNumber');
                        if (await canLaunchUrl(uri)) {
                          await launchUrl(uri);
                        }
                      },
                      icon: Image.asset('assets/icons/phone.png', width: 24),
                      color: Colors.greenAccent.shade100,
                    ),
                    const SizedBox(width: 4),
                    _buildRoundedButton(
                      onPressed: () async {
                        final result = await Navigator.pushNamed(
                          context,
                          '/add_patient',
                          arguments: data,
                        );
                        if (result == true) {
                          await _fetchAllPatients();
                        }
                      },
                      icon: const Icon(Icons.edit, color: Colors.black),
                      color: Colors.orangeAccent.shade100,
                    ),
                    const SizedBox(width: 4),
                    _buildRoundedButton(
                      onPressed: () async {
                        final confirm = await showDialog<bool>(
                          context: context,
                          builder: (context) => AlertDialog(
                            title: const Text('ยืนยันการลบ'),
                            content: const Text('คุณแน่ใจหรือไม่ว่าต้องการลบคนไข้รายนี้?'),
                            actions: [
                              TextButton(
                                onPressed: () => Navigator.pop(context, false),
                                child: const Text('ยกเลิก'),
                              ),
                              TextButton(
                                onPressed: () => Navigator.pop(context, true),
                                child: const Text('ลบ'),
                              ),
                            ],
                          ),
                        );

                        if (confirm == true) {
                          await FirebaseFirestore.instance
                              .collection('patients')
                              .doc(docId)
                              .delete();
                          await _fetchAllPatients();
                        }
                      },
                      icon: const Icon(Icons.delete, color: Colors.black),
                      color: Colors.redAccent.shade100,
                    ),
                  ],
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRoundedButton({required VoidCallback onPressed, required Widget icon, required Color color}) {
    return ElevatedButton(
      onPressed: onPressed,
      style: ElevatedButton.styleFrom(
        backgroundColor: color,
        padding: const EdgeInsets.all(8),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(30),
        ),
      ),
      child: icon,
    );
  }
}
