import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';
import '../screens/patient_add.dart';

class PatientsScreen extends StatelessWidget {
  const PatientsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFEFE0FF),
      appBar: AppBar(
        title: const Text('รายชื่อคนไข้'),
        backgroundColor: const Color(0xFFE0BBFF),
        elevation: 0,
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('patients')
            .orderBy('createdAt', descending: true)
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          final patients = snapshot.data?.docs ?? [];

          if (patients.isEmpty) {
            final mock = [
              {'name': 'คุณมะลิ', 'phone': '0844444444', 'gender': 'หญิง', 'age': 29, 'rating': 5},
              {'name': 'คุณสมชาย', 'phone': '0833333333', 'gender': 'ชาย', 'age': 42, 'rating': 4},
              {'name': 'คุณขวัญใจ', 'phone': '0822222222', 'gender': 'หญิง', 'age': 31, 'rating': 3},
              {'name': 'คุณต้นกล้า', 'phone': '0811111111', 'gender': 'ชาย', 'age': 27, 'rating': 2},
              {'name': 'คุณฟ้าใส', 'phone': '0812345678', 'gender': 'หญิง', 'age': 25, 'rating': 5},
              {'name': 'คุณเมฆา', 'phone': '0899999999', 'gender': 'ชาย', 'age': 30, 'rating': 4},
              {'name': 'คุณสายรุ้ง', 'phone': '0888888888', 'gender': 'หญิง', 'age': 28, 'rating': 3},
              {'name': 'คุณแสงดาว', 'phone': '0877777777', 'gender': 'หญิง', 'age': 26, 'rating': 2},
              {'name': 'คุณประกายทอง', 'phone': '0866666666', 'gender': 'ชาย', 'age': 32, 'rating': 1},
              {'name': 'คุณสายลม', 'phone': '0855555555', 'gender': 'ชาย', 'age': 35, 'rating': 4},
            ];

            return ListView(
              padding: const EdgeInsets.all(16),
              children: mock.map((data) => _buildCard(context, data)).toList(),
            );
          }

          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: patients.length,
            itemBuilder: (context, index) {
              final data = patients[index].data() as Map<String, dynamic>;
              return _buildCard(context, data, docId: patients[index].id);
            },
          );
        },
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (context) => const PatientAddScreen()),
          );
        },
        backgroundColor: Colors.purple,
        child: const Icon(Icons.add, color: Colors.white, size: 36),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(30),
        ),
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
                color: Colors.purple,
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
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.start,
          children: [
                        Padding(
              padding: const EdgeInsets.only(left: 0),
              child: Icon(
                data['gender'] == 'ชาย' ? Icons.male : Icons.female,
                color: data['gender'] == 'ชาย' ? Colors.blueAccent : Colors.pinkAccent,
                size: 36,
              ),
            ),
            const SizedBox(width: 4),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    name,
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Text('เบอร์: $phone'),
                    ],
                  ),
                  if (data['age'] != null)
                    Text('อายุ: ${data['age']} ปี'),
                ],
              ),
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      margin: const EdgeInsets.only(right: 8),
                      decoration: BoxDecoration(
                        color: const Color(0xFFC8E6C9),
                        boxShadow: [
                          BoxShadow(color: Colors.green.shade100, blurRadius: 4, offset: Offset(2, 2))
                        ],
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: IconButton(
                        icon: const Icon(Icons.phone, color: Colors.green),
                        onPressed: () async {
                          final uri = Uri.parse('tel:$phone');
                          if (await canLaunchUrl(uri)) {
                            await launchUrl(uri);
                          }
                        },
                      ),
                    ),
                    Container(
                      decoration: BoxDecoration(
                        color: const Color(0xFFFFE0B2),
                        boxShadow: [
                          BoxShadow(color: Colors.orange.shade100, blurRadius: 4, offset: Offset(2, 2))
                        ],
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: IconButton(
                        icon: const Icon(Icons.edit, color: Colors.deepOrange),
                        onPressed: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => PatientAddScreen(
                                existingName: name,
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                    Container(
                      margin: const EdgeInsets.only(left: 8),
                      decoration: BoxDecoration(
                        color: const Color(0xFFEF9A9A),
                        boxShadow: [
                          BoxShadow(color: Colors.red.shade100, blurRadius: 4, offset: Offset(2, 2))
                        ],
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: IconButton(
                        icon: const Icon(Icons.delete, color: Colors.redAccent),
                        onPressed: docId != null
                            ? () async {
                                await FirebaseFirestore.instance
                                    .collection('patients')
                                    .doc(docId)
                                    .delete();
                              }
                            : null,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: List.generate(
                    5,
                    (i) => Text(
                      i < rating ? '🦷' : '⬜',
                      style: TextStyle(fontSize: 18, color: rating >= 5 ? Colors.purple : rating >= 4 ? Colors.orange : Colors.redAccent),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
