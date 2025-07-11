// 💖 สวัสดีค่ะพี่ทะเล! ไลลาอัปเกรดหน้าแสดงรายชื่อคนไข้ให้แล้วนะคะ
// ตอนนี้การ์ดคนไข้ของเราสามารถแสดงผลคะแนนแบบ double และมีฟันสีชมพูได้แล้วค่ะ! 😊

import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../models/patient.dart';
import '../services/patient_service.dart';
import '../styles/app_theme.dart';
import '../widgets/custom_bottom_nav_bar.dart';

class PatientsScreen extends StatefulWidget {
  const PatientsScreen({super.key});

  @override
  State<PatientsScreen> createState() => _PatientsScreenState();
}

class _PatientsScreenState extends State<PatientsScreen> {
  final TextEditingController _searchController = TextEditingController();
  final PatientService _patientService = PatientService();

  List<Patient> _allPatients = [];
  List<Patient> _searchResults = [];
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

  Future<void> _fetchAllPatients() async {
    setState(() {
      _isLoading = true;
    });
    try {
      final result = await _patientService.fetchPatientsOnce();
      setState(() {
        _allPatients = result;
        _allPatients.sort((a, b) => a.name.compareTo(b.name));
        _searchResults = List.from(_allPatients);
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _isLoading = false;
      });
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
      final name = '${patient.prefix} ${patient.name}'.toLowerCase();
      final phone = patient.telephone?.toLowerCase() ?? '';
      final hn = patient.hnNumber?.toLowerCase() ?? '';
      final queryLower = query.toLowerCase();

      return name.contains(queryLower) ||
          phone.contains(queryLower) ||
          hn.contains(queryLower);
    }).toList();

    setState(() {
      _searchResults = results;
    });
  }

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
                ? const Center(
                    child: CircularProgressIndicator(color: AppTheme.primary))
                : _allPatients.isEmpty
                    ? _buildEmptyState()
                    : _searchResults.isEmpty
                        ? _buildNoResultsState()
                        : ListView.builder(
                            padding:
                                const EdgeInsets.fromLTRB(16, 0, 16, 80),
                            itemCount: _searchResults.length,
                            itemBuilder: (context, index) {
                              final patient = _searchResults[index];
                              return _PatientCard(
                                patient: patient,
                                onCall: () => _makeCall(patient.telephone),
                                onEdit: () => _navigateToEdit(patient),
                                onDelete: () =>
                                    _confirmDelete(patient.patientId),
                                onTap: () => _navigateToDetail(patient),
                              );
                            },
                          ),
          ),
        ],
      ),
      floatingActionButton: _buildFloatingActionButton(),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerDocked,
      bottomNavigationBar: const CustomBottomNavBar(selectedIndex: 1),
    );
  }

  Widget _buildSearchBar() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
      child: TextField(
        controller: _searchController,
        style: const TextStyle(fontFamily: AppTheme.fontFamily),
        decoration: InputDecoration(
          hintText: 'ค้นหาด้วยชื่อ, เบอร์โทร, หรือ HN...',
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
          contentPadding:
              const EdgeInsets.symmetric(vertical: 10.0, horizontal: 20.0),
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
          Icon(Icons.sentiment_dissatisfied,
              size: 60, color: Colors.grey.shade400),
          const SizedBox(height: 16),
          const Text('ยังไม่มีข้อมูลคนไข้ในระบบ',
              style: TextStyle(
                  fontSize: 16,
                  color: AppTheme.textDisabled,
                  fontFamily: AppTheme.fontFamily)),
          const SizedBox(height: 8),
          const Text('กดปุ่ม + เพื่อเพิ่มคนไข้ใหม่ได้เลยค่ะ',
              style: TextStyle(
                  color: AppTheme.textDisabled,
                  fontFamily: AppTheme.fontFamily)),
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
          const Text('ไม่พบข้อมูลคนไข้ที่ค้นหา',
              style: TextStyle(
                  fontSize: 16,
                  color: AppTheme.textDisabled,
                  fontFamily: AppTheme.fontFamily)),
        ],
      ),
    );
  }

  Widget _buildFloatingActionButton() {
    return FloatingActionButton(
      onPressed: _navigateToAdd,
      backgroundColor: AppTheme.primary,
      tooltip: 'เพิ่มคนไข้ใหม่',
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
      child: const Icon(Icons.add, color: Colors.white, size: 36),
    );
  }

  void _navigateToAdd() async {
    final result = await Navigator.pushNamed(context, '/add_patient');
    if (result == true) {
      await _fetchAllPatients();
    }
  }

  void _navigateToEdit(Patient patient) async {
    final result = await Navigator.pushNamed(
      context,
      '/add_patient',
      arguments: patient,
    );
    if (result == true) {
      await _fetchAllPatients();
    }
  }

  void _navigateToDetail(Patient patient) {
    Navigator.pushNamed(context, '/patient_detail', arguments: patient);
  }

  void _makeCall(String? phone) async {
    if (phone == null || phone.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('ไม่มีเบอร์โทรศัพท์ค่ะ',
              style: TextStyle(fontFamily: AppTheme.fontFamily))));
      return;
    }
    final phoneNumber = phone.replaceAll('-', '');
    final uri = Uri.parse('tel:$phoneNumber');
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri);
    } else {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('ไม่สามารถโทรออกได้ค่ะ',
              style: TextStyle(fontFamily: AppTheme.fontFamily))));
    }
  }

  Future<void> _confirmDelete(String? docId) async {
    if (docId == null) return;

    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('ยืนยันการลบ',
            style: TextStyle(fontFamily: AppTheme.fontFamily)),
        content: const Text('คุณแน่ใจหรือไม่ว่าต้องการลบข้อมูลคนไข้รายนี้?',
            style: TextStyle(fontFamily: AppTheme.fontFamily)),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('ยกเลิก',
                  style: TextStyle(fontFamily: AppTheme.fontFamily))),
          TextButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('ลบ',
                  style: TextStyle(
                      color: Colors.red, fontFamily: AppTheme.fontFamily))),
        ],
      ),
    );

    if (confirm == true) {
      await _patientService.deletePatient(docId);
      await _fetchAllPatients();
    }
  }
}

class _PatientCard extends StatelessWidget {
  final Patient patient;
  final VoidCallback onCall;
  final VoidCallback onEdit;
  final VoidCallback onDelete;
  final VoidCallback onTap;

  const _PatientCard({
    required this.patient,
    required this.onCall,
    required this.onEdit,
    required this.onDelete,
    required this.onTap,
  });

  Widget _getGenderIcon(String gender, {double size = 16}) {
    String iconPath;
    switch (gender) {
      case 'หญิง':
        iconPath = AppTheme.iconPathFemale;
        break;
      case 'ชาย':
        iconPath = AppTheme.iconPathMale;
        break;
      default:
        iconPath = AppTheme.iconPathGender;
        break;
    }
    return Image.asset(iconPath, width: size, height: size);
  }

  // ✨ [UPGRADED] เพิ่มผู้ช่วยสำหรับแสดงดาวที่รองรับฟันสีชมพูค่ะ!
  Widget _buildRatingStars(double rating) {
    final int fullStars = rating.floor();
    final bool hasHalfStar = (rating - fullStars) >= 0.5;

    return Row(
      children: List.generate(5, (index) {
        Widget toothIcon;
        if (index < fullStars) {
          // 🦷 ฟันดี
          toothIcon = Image.asset(
            'assets/icons/tooth_good.png',
            width: 24,
            height: 24,
          );
        } else if (index == fullStars && hasHalfStar) {
          // 💖 ฟันอักเสบ (สีชมพู)
          toothIcon = Image.asset(
            'assets/icons/tooth_good.png',
            width: 24,
            height: 24,
            color: AppTheme.ratingInflamedTooth,
          );
        } else {
          // 🦷 ฟันผุ
          toothIcon = Image.asset(
            'assets/icons/tooth_broke.png',
            width: 24,
            height: 24,
          );
        }
        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 1.5),
          child: toothIcon,
        );
      }),
    );
  }

  @override
  Widget build(BuildContext context) {
    final prefix = patient.prefix;
    final name = patient.name;
    final phone = patient.telephone ?? '-';
    final rating = patient.rating; // ✨ เป็น double แล้ว
    final gender = patient.gender;
    final age = patient.age?.toString() ?? '-';
    final medicalHistory =
        (patient.medicalHistory != null && patient.medicalHistory!.isNotEmpty)
            ? patient.medicalHistory
            : '-';
    final allergy = (patient.allergy != null && patient.allergy!.isNotEmpty)
        ? patient.allergy
        : '-';

    // ✨ [FIXED] เปลี่ยนมาใช้ if-else ที่รองรับ double ค่ะ
    final cardColor;
    if (rating >= 4.5) {
      cardColor = AppTheme.rating5Star;
    } else if (rating >= 3.5) {
      cardColor = AppTheme.rating4Star;
    } else {
      cardColor = AppTheme.rating3StarAndBelow;
    }

    final borderColor;
    if (rating >= 4.5) {
      borderColor = AppTheme.rating5StarBorder;
    } else if (rating >= 3.5) {
      borderColor = AppTheme.rating4StarBorder;
    } else {
      borderColor = AppTheme.rating3StarAndBelowBorder;
    }

    return Card(
      elevation: 0,
      color: cardColor,
      margin: const EdgeInsets.symmetric(vertical: 6),
      clipBehavior: Clip.antiAlias,
      shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(24),
          side: BorderSide(color: borderColor, width: 1.5)),
      child: Stack(
        children: [
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
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            _buildInfoRow(
                                iconAsset: 'assets/icons/user.png',
                                text: '$prefix $name',
                                isTitle: true),
                            const SizedBox(height: 4),
                            Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Expanded(
                                    child: _buildInfoRow(
                                        iconAsset: 'assets/icons/phone.png',
                                        text: phone)),
                                const SizedBox(width: 16),
                                Expanded(
                                    child: _buildInfoRow(
                                        iconAsset:
                                            'assets/icons/medical_report.png',
                                        text: medicalHistory!)),
                              ],
                            ),
                            const SizedBox(height: 2),
                            Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Expanded(
                                  child: _buildInfoRow(
                                      iconAsset: 'assets/icons/age.png',
                                      text: '$age ปี',
                                      trailing: Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          const SizedBox(width: 8),
                                          _getGenderIcon(gender),
                                        ],
                                      )),
                                ),
                                const SizedBox(width: 16),
                                Expanded(
                                    child: _buildInfoRow(
                                        iconAsset: 'assets/icons/no_drugs.png',
                                        text: allergy!)),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      _buildActionButton(
                          onPressed: onCall,
                          iconAsset: 'assets/icons/phone.png',
                          text: 'โทร',
                          backgroundColor: AppTheme.buttonCallBg,
                          foregroundColor: AppTheme.buttonCallFg),
                      const SizedBox(width: 8),
                      _buildActionButton(
                          onPressed: onEdit,
                          iconAsset: 'assets/icons/edit.png',
                          text: 'แก้ไข',
                          backgroundColor: AppTheme.buttonEditBg,
                          foregroundColor: AppTheme.buttonEditFg),
                      const SizedBox(width: 8),
                      _buildActionButton(
                          onPressed: onDelete,
                          iconAsset: 'assets/icons/delete.png',
                          text: 'ลบ',
                          backgroundColor: AppTheme.buttonDeleteBg,
                          foregroundColor: AppTheme.buttonDeleteFg),
                    ],
                  ),
                ],
              ),
            ),
          ),
          Positioned(
            top: 10,
            left: 16,
            child: _buildInfoRow(
              iconAsset: 'assets/icons/hn_id.png',
              text: patient.hnNumber ?? 'N/A',
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
                  border:
                      Border.all(color: Colors.grey.shade200.withOpacity(0.5))),
              // ✨ [UPGRADED] เปลี่ยนมาเรียกใช้ _buildRatingStars ที่เราสร้างขึ้นมาใหม่ค่ะ!
              child: _buildRatingStars(rating),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoRow(
      {String? iconAsset,
      IconData? icon,
      required String text,
      bool isTitle = false,
      Widget? trailing}) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        if (iconAsset != null)
          Padding(
            padding: const EdgeInsets.only(top: 2.0),
            child: Image.asset(iconAsset,
                width: isTitle ? 18 : 16, height: isTitle ? 18 : 16),
          )
        else if (icon != null)
          Padding(
            padding: const EdgeInsets.only(top: 2.0),
            child: Icon(icon, size: 16, color: AppTheme.textSecondary),
          ),
        const SizedBox(width: 8),
        Flexible(
          child: Text(
            text,
            style: isTitle
                ? const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 18,
                    fontFamily: AppTheme.fontFamily,
                    color: AppTheme.textPrimary)
                : const TextStyle(
                    color: AppTheme.textSecondary,
                    fontSize: 16,
                    fontFamily: AppTheme.fontFamily),
            overflow: TextOverflow.ellipsis,
            maxLines: 1,
          ),
        ),
        if (trailing != null) trailing,
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
          textStyle: const TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 14,
              fontFamily: AppTheme.fontFamily)),
    );
  }
}
