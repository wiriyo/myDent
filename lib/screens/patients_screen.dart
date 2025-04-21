import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class PatientsScreen extends StatelessWidget {
  const PatientsScreen({super.key});

  Stream<QuerySnapshot> _getPatientsStream() {
    return FirebaseFirestore.instance.collection('patients').snapshots();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Patients")),
      body: StreamBuilder<QuerySnapshot>(
        stream: _getPatientsStream(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
            return const Center(child: Text("ไม่มีข้อมูลคนไข้"));
          }

          final patients = snapshot.data!.docs;

          return ListView.builder(
            itemCount: patients.length,
            itemBuilder: (context, index) {
              final data = patients[index].data() as Map<String, dynamic>;
              final name = data['name'] ?? 'ไม่ระบุ';
              final gender = data['gender'] ?? '-';
              final phone = data['phone'] ?? '-';

              return Card(
                margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                color: Colors.pink.shade50,
                child: ListTile(
                  title: Text(name, style: const TextStyle(fontWeight: FontWeight.bold)),
                  subtitle: Text("เพศ: $gender\nโทร: $phone"),
                ),
              );
            },
          );
        },
      ),
    );
  }
}
