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
  List<Map<String, dynamic>> _allPatients = [];
  bool _isSearchExpanded = false;

  @override
  void initState() {
    super.initState();
    _fetchAllPatients();
  }

  Future<void> _fetchAllPatients() async {
    final result =
        await FirebaseFirestore.instance.collection('patients').get();
    setState(() {
      _allPatients =
          result.docs.map((doc) {
            final data = doc.data();
            return {...data, 'docId': doc.id};
          }).toList();
      _searchResults = List.from(_allPatients);
    });
  }

  void _filterPatients(String query) {
    final results =
        _allPatients.where((patient) {
          final name = patient['name']?.toLowerCase() ?? '';
          final phone = patient['phone']?.toLowerCase() ?? '';
          return name.contains(query.toLowerCase()) ||
              phone.contains(query.toLowerCase());
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
        actions: [
          AnimatedContainer(
            duration: const Duration(milliseconds: 300),
            width:
                _isSearchExpanded
                    ? MediaQuery.of(context).size.width * 0.7
                    : 50,
            child: Row(
              children: [
                if (_isSearchExpanded)
                  Expanded(
                    child: TextField(
                      controller: _searchController,
                      decoration: InputDecoration(
                        hintText: 'ค้นหา...',
                        filled: true,
                        fillColor: Colors.white,
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 12,
                        ),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(20),
                          borderSide: BorderSide.none,
                        ),
                      ),
                      onChanged: (value) => _filterPatients(value),
                    ),
                  ),
                IconButton(
                  icon: const Icon(Icons.search, color: Colors.white),
                  onPressed: () {
                    setState(() {
                      _isSearchExpanded = !_isSearchExpanded;
                      if (!_isSearchExpanded) {
                        _searchController.clear();
                        _searchResults = List.from(_allPatients);
                      }
                    });
                  },
                ),
              ],
            ),
          ),
        ],
        backgroundColor: const Color(0xFFE0BBFF),
        elevation: 0,
      ),
      body: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: _searchResults.length,
        itemBuilder: (context, index) {
          final data = _searchResults[index];
          return _buildCard(context, data, docId: data['docId']);
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
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
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

  Widget _buildCard(
    BuildContext context,
    Map<String, dynamic> data, {
    String? docId,
  }) {
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
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: ListTile(
        leading: Icon(
          data['gender'] == 'ชาย' ? Icons.male : Icons.female,
          color:
              data['gender'] == 'ชาย' ? Colors.blueAccent : Colors.pinkAccent,
          size: 36,
        ),
        title: Text(name, style: const TextStyle(fontWeight: FontWeight.bold)),
        subtitle: Text('เบอร์: $phone'),
        trailing: Wrap(
          spacing: 6,
          children: [
            IconButton(
              icon: const Icon(Icons.phone, color: Colors.green),
              onPressed: () async {
                final uri = Uri.parse('tel:$phone');
                if (await canLaunchUrl(uri)) {
                  await launchUrl(uri);
                }
              },
            ),
            IconButton(
              icon: const Icon(Icons.edit, color: Colors.orange),
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => PatientAddScreen(existingName: name),
                  ),
                );
              },
            ),
            IconButton(
              icon: const Icon(Icons.delete, color: Colors.redAccent),
              onPressed:
                  docId != null
                      ? () async {
                        await FirebaseFirestore.instance
                            .collection('patients')
                            .doc(docId)
                            .delete();
                      }
                      : null,
            ),
          ],
        ),
        onTap: () {
          Navigator.pushNamed(
            context,
            '/patient_detail',
            arguments: data,
          );
        },
      ),
    );
  }
}
