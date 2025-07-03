// 📁 lib/screens/patients_screen.dart

import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../services/patient_service.dart';
import '../styles/app_theme.dart';
import '../widgets/custom_bottom_nav_bar.dart'; // ✨ [FIX] 1. import Navbar ใหม่ของเราเข้ามาค่ะ
import 'appointment_add.dart';


class PatientsScreen extends StatefulWidget {
  const PatientsScreen({super.key});

  @override
  State<PatientsScreen> createState() => _PatientsScreenState();
}

class _PatientsScreenState extends State<PatientsScreen> {
  final TextEditingController _searchController = TextEditingController();
  final PatientService _patientService = PatientService();
  List<Map<String, dynamic>> _allPatients = [];
  List<Map<String, dynamic>> _searchResults = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _fetchAllPatients();
    _searchController.addListener(() {
      _filterPatients(_searchController.text);
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  // --- ✨ ระบบจัดการข้อมูล ✨ ---
  Future<void> _fetchAllPatients() async {
    setState(() { _isLoading = true; });
    try {
      final result = await _patientService.fetchPatientsOnce();
      setState(() {
        _allPatients = result.map((patient) {
          final map = patient.toMap();
          map['docId'] = patient.patientId;
          return map;
        }).toList();
        
        _allPatients.sort((a, b) => (a['name'] as String).compareTo(b['name'] as String));
        
        _searchResults = List.from(_allPatients);
        _isLoading = false;
      });
    } catch (e) {
      setState(() { _isLoading = false; });
      debugPrint("Error fetching patients: $e");
    }
  }

  void _filterPatients(String query) {
    if (query.isEmpty) {
      setState(() {
        _searchResults = List.from(_allPatients);
      });
      return;
    }
    final results = _allPatients.where((patient) {
      final name = '${patient['prefix'] ?? ''} ${patient['name'] ?? ''}'.toLowerCase();
      final phone = patient['telephone']?.toLowerCase() ?? '';
      return name.contains(query.toLowerCase()) || phone.contains(query.toLowerCase());
    }).toList();

    setState(() {
      _searchResults = results;
    });
  }
  
  // --- ✨ ส่วนประกอบของ UI ✨ ---
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.background, 
      appBar: AppBar(
        automaticallyImplyLeading: false,
        title: const Text('รายชื่อคนไข้'),
        backgroundColor: AppTheme.primaryLight, 
        elevation: 0,
      ),
      body: Column(
        children: [
          _buildSearchBar(),
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator(color: AppTheme.primary))
                : _allPatients.isEmpty
                    ? _buildEmptyState()
                    : _searchResults.isEmpty
                        ? _buildNoResultsState()
                        : ListView.builder(
                            padding: const EdgeInsets.fromLTRB(16, 0, 16, 80),
                            itemCount: _searchResults.length,
                            itemBuilder: (context, index) {
                              final data = _searchResults[index];
                              return _PatientCard(
                                data: data,
                                onCall: () => _makeCall(data['telephone']),
                                onEdit: () => _navigateToEdit(data),
                                onDelete: () => _confirmDelete(data['docId']),
                                onTap: () => _navigateToDetail(data),
                              );
                            },
                          ),
          ),
        ],
      ),
      floatingActionButton: _buildFloatingActionButton(),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerDocked,
      // ✨ [FIX] 2. เรียกใช้ CustomBottomNavBar ของเราตรงนี้เลยค่ะ
      bottomNavigationBar: const CustomBottomNavBar(selectedIndex: 1),
    );
  }

  Widget _buildSearchBar() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
      child: TextField(
        controller: _searchController,
        style: const TextStyle(fontFamily: AppTheme.fontFamily),
        decoration: InputDecoration(
          hintText: 'ค้นหาด้วยชื่อ หรือเบอร์โทร...',
          hintStyle: const TextStyle(fontFamily: AppTheme.fontFamily),
          prefixIcon: const Icon(Icons.search, color: Colors.grey),
          suffixIcon: _searchController.text.isNotEmpty
              ? IconButton(
                  icon: const Icon(Icons.clear, color: Colors.grey),
                  onPressed: () {
                    _searchController.clear();
                  },
                )
              : null,
          filled: true,
          fillColor: Colors.white,
          contentPadding: const EdgeInsets.symmetric(vertical: 10.0, horizontal: 20.0),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(30.0),
            borderSide: BorderSide.none,
          ),
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.sentiment_dissatisfied, size: 60, color: Colors.grey.shade400),
          const SizedBox(height: 16),
          const Text('ยังไม่มีข้อมูลคนไข้ในระบบ', style: TextStyle(fontSize: 16, color: AppTheme.textDisabled, fontFamily: AppTheme.fontFamily)),
          const SizedBox(height: 8),
          const Text('กดปุ่ม + เพื่อเพิ่มคนไข้ใหม่ได้เลยค่ะ', style: TextStyle(color: AppTheme.textDisabled, fontFamily: AppTheme.fontFamily)),
        ],
      ),
    );
  }

  Widget _buildNoResultsState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.search_off, size: 60, color: Colors.grey.shade400),
          const SizedBox(height: 16),
          const Text('ไม่พบข้อมูลคนไข้ที่ค้นหา', style: TextStyle(fontSize: 16, color: AppTheme.textDisabled, fontFamily: AppTheme.fontFamily)),
        ],
      ),
    );
  }

  // ✨ [FIX] 3. ลบ _buildBottomAppBar และฟังก์ชันที่เกี่ยวข้องออกไปค่ะ
  
  Widget _buildFloatingActionButton() {
    return FloatingActionButton(
      onPressed: _navigateToAdd,
      backgroundColor: AppTheme.primary,
      tooltip: 'เพิ่มคนไข้ใหม่',
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
      child: const Icon(Icons.add, color: Colors.white, size: 36),
    );
  }

  // --- ✨ ระบบนำทางและจัดการ Action ✨ ---
  void _navigateToAdd() async {
    final result = await Navigator.pushNamed(context, '/add_patient');
    if (result == true) {
      await _fetchAllPatients();
    }
  }

  void _navigateToEdit(Map<String, dynamic> data) async {
    if (data['docId'] != null && data['docId'] != '') {
      final result = await Navigator.pushNamed(
        context,
        '/add_patient',
        arguments: data,
      );
      if (result == true) {
        await _fetchAllPatients();
      }
    }
  }

  void _navigateToDetail(Map<String, dynamic> data) {
    Navigator.pushNamed(context, '/patient_detail', arguments: data);
  }

  void _makeCall(String? phone) async {
    if (phone == null || phone.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('ไม่มีเบอร์โทรศัพท์ค่ะ', style: TextStyle(fontFamily: AppTheme.fontFamily))));
      return;
    }
    final phoneNumber = phone.replaceAll('-', '');
    final uri = Uri.parse('tel:$phoneNumber');
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri);
    } else {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('ไม่สามารถโทรออกได้ค่ะ', style: TextStyle(fontFamily: AppTheme.fontFamily))));
    }
  }

  Future<void> _confirmDelete(String? docId) async {
    if (docId == null) return;

    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('ยืนยันการลบ', style: TextStyle(fontFamily: AppTheme.fontFamily)),
        content: const Text('คุณแน่ใจหรือไม่ว่าต้องการลบข้อมูลคนไข้รายนี้?', style: TextStyle(fontFamily: AppTheme.fontFamily)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('ยกเลิก', style: TextStyle(fontFamily: AppTheme.fontFamily))),
          TextButton(onPressed: () => Navigator.pop(context, true), child: const Text('ลบ', style: TextStyle(color: Colors.red, fontFamily: AppTheme.fontFamily))),
        ],
      ),
    );

    if (confirm == true) {
      await _patientService.deletePatient(docId);
      await _fetchAllPatients();
    }
  }
}


// --- ✨ การ์ดคนไข้ดีไซน์ใหม่ by ไลลา ✨ ---
class _PatientCard extends StatelessWidget {
  final Map<String, dynamic> data;
  final VoidCallback onCall;
  final VoidCallback onEdit;
  final VoidCallback onDelete;
  final VoidCallback onTap;

  const _PatientCard({
    required this.data,
    required this.onCall,
    required this.onEdit,
    required this.onDelete,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final prefix = data['prefix'] ?? '';
    final name = data['name'] ?? '-';
    final phone = data['telephone'] ?? '-';
    final rating = (data['rating'] as num?)?.toInt() ?? 0;
    final gender = data['gender'] ?? 'ไม่ระบุ';
    final age = data['age']?.toString() ?? '-';
    final medicalHistory = data['medicalHistory'] as String?;
    final allergy = data['allergy'] as String?;
    
    final cardColor = switch (rating) {
      >= 5 => AppTheme.rating5Star,
      4    => AppTheme.rating4Star,
      _    => AppTheme.rating3StarAndBelow,
    };

    return Card(
      elevation: 0,
      color: cardColor,
      margin: const EdgeInsets.symmetric(vertical: 6),
      clipBehavior: Clip.antiAlias,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(24),
        side: BorderSide(color: Colors.grey.shade200)
      ),
      child: Stack(
        children: [
          // --- ส่วนข้อมูลหลัก ---
          InkWell(
            onTap: onTap,
            borderRadius: BorderRadius.circular(24),
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const SizedBox(height: 25), 
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      const SizedBox(width: 40),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                             _buildInfoRow(iconAsset: 'assets/icons/user.png', text: '$prefix $name', isTitle: true),
                             const SizedBox(height: 4),
                             Row(
                               children: [
                                 Expanded(child: _buildInfoRow(iconAsset: 'assets/icons/phone.png', text: phone)),
                                 if (medicalHistory != null && medicalHistory.isNotEmpty) ...[
                                   const SizedBox(width: 16),
                                   Expanded(child: _buildInfoRow(iconAsset: 'assets/icons/medical_report.png', text: medicalHistory)),
                                 ],
                               ],
                             ),
                             const SizedBox(height: 2),
                             Row(
                               children: [
                                 Expanded(child: _buildInfoRow(iconAsset: 'assets/icons/age.png', text: '$age ปี')),
                                 if (allergy != null && allergy.isNotEmpty) ...[
                                   const SizedBox(width: 16),
                                   Expanded(child: _buildInfoRow(iconAsset: 'assets/icons/no_drugs.png', text: allergy)),
                                 ],
                               ],
                             ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  // --- ส่วนล่าง: ปุ่ม Action ---
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      _buildActionButton(onPressed: onCall, iconAsset: 'assets/icons/phone.png', text: 'โทร', backgroundColor: AppTheme.buttonCallBg, foregroundColor: AppTheme.buttonCallFg),
                      const SizedBox(width: 8),
                      _buildActionButton(onPressed: onEdit, iconAsset: 'assets/icons/edit.png', text: 'แก้ไข', backgroundColor: AppTheme.buttonEditBg, foregroundColor: AppTheme.buttonEditFg),
                      const SizedBox(width: 8),
                      _buildActionButton(onPressed: onDelete, iconAsset: 'assets/icons/delete.png', text: 'ลบ', backgroundColor: AppTheme.buttonDeleteBg, foregroundColor: AppTheme.buttonDeleteFg),
                    ],
                  ),
                ],
              ),
            ),
          ),
          
          Positioned(
            top: 8,
            left: 12,
            child: Icon(
              gender == 'ชาย' ? Icons.male : Icons.female,
              color: gender == 'ชาย' ? AppTheme.iconMale : AppTheme.iconFemale,
              size: 40,
            ),
          ),

          Positioned(
            top: 8,
            right: 8,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.8),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.grey.shade200.withOpacity(0.5))
              ),
              child: Row(
                children: List.generate(5, (index) => Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 1.5),
                  child: Image.asset(
                    index < rating ? 'assets/icons/tooth_good.png' : 'assets/icons/tooth_broke.png',
                    width: 24, height: 24,
                  ),
                )),
              ),
            ),
          ),
        ],
      ),
    );
  }
  
  Widget _buildInfoRow({String? iconAsset, IconData? icon, required String text, bool isTitle = false}) {
    return Row(
      children: [
        if (iconAsset != null)
          Image.asset(iconAsset, width: isTitle ? 18 : 16, height: isTitle ? 18 : 16)
        else if (icon != null)
          Icon(icon, size: 16, color: AppTheme.textSecondary),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            text,
            style: isTitle 
              ? const TextStyle(fontWeight: FontWeight.bold, fontSize: 18, fontFamily: AppTheme.fontFamily, color: AppTheme.textPrimary)
              : const TextStyle(color: AppTheme.textSecondary, fontSize: 16, fontFamily: AppTheme.fontFamily),
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }

  Widget _buildActionButton({
    required VoidCallback onPressed, 
    required String iconAsset, 
    required String text,
    required Color backgroundColor,
    required Color foregroundColor,
  }) {
    return ElevatedButton.icon(
      onPressed: onPressed,
      icon: Image.asset(iconAsset, width: 18, height: 18),
      label: Text(text),
      style: ElevatedButton.styleFrom(
        backgroundColor: backgroundColor,
        foregroundColor: foregroundColor,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
        ),
        elevation: 1,
        textStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14, fontFamily: AppTheme.fontFamily)
      ),
    );
  }
}
