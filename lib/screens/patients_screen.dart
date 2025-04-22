import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';
import '../screens/patient_add.dart';

class PatientsScreen extends StatefulWidget {
  const PatientsScreen({super.key});

  @override
  State<PatientsScreen> createState() => _PatientsScreenState();
}

class _PatientsScreenState extends State<PatientsScreen> {
  final TextEditingController _searchController = TextEditingController();
  List<Map<String, dynamic>> _searchResults = [];
  bool _showSuggestions = false;

  Future<void> _performSearch(String query) async {
    final result = await FirebaseFirestore.instance
        .collection('patients')
        .where('keywords', arrayContains: query.toLowerCase())
        .get();

    setState(() {
      _searchResults = result.docs.map((doc) {
        final data = doc.data();
        return {
          ...data,
          'docId': doc.id,
        };
      }).toList();
      _showSuggestions = true;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFEFE0FF),
      appBar: AppBar(
        title: const Text('รายชื่อคนไข้'),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(60),
          child: Padding(
            padding: const EdgeInsets.all(12.0),
            child: Column(
              children: [
                TextField(
                  controller: _searchController,
                  decoration: InputDecoration(
                    hintText: 'ค้นหาชื่อหรือเบอร์โทร...',
                    filled: true,
                    fillColor: Colors.white,
                    prefixIcon: const Icon(Icons.search),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(20),
                      borderSide: BorderSide.none,
                    ),
                  ),
                  onChanged: (value) {
                    if (value.isNotEmpty) {
                      _performSearch(value.trim());
                    } else {
                      setState(() {
                        _searchResults = [];
                        _showSuggestions = false;
                      });
                    }
                  },
                ),
              ],
            ),
          ),
        ),
        backgroundColor: const Color(0xFFE0BBFF),
        elevation: 0,
      ),
      body: _showSuggestions
          ? ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: _searchResults.length,
              itemBuilder: (context, index) {
                final data = _searchResults[index];
                return _buildCard(context, data, docId: data['docId']);
              },
            )
          : StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance
                  .collection('patients')
                  .orderBy('createdAt', descending: true)
                  .snapshots(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }

                final patients = snapshot.data?.docs ?? [];

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
                          BoxShadow(color: Colors.green.shade100, blurRadius: 4, offset: const Offset(2, 2))
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
                          BoxShadow(color: Colors.orange.shade100, blurRadius: 4, offset: const Offset(2, 2))
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
                          BoxShadow(color: Colors.red.shade100, blurRadius: 4, offset: const Offset(2, 2))
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
                      style: TextStyle(
                        fontSize: 18,
                        color: rating >= 5
                            ? Colors.purple
                            : rating >= 4
                                ? Colors.orange
                                : Colors.redAccent,
                      ),
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
