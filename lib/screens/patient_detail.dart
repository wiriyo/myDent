// v1.9.11 - 🎨 ไม่ย้อมสีไอคอน notes และ x_ray
// v1.9.10 - 🎨 เพิ่ม HN ที่การ์ดข้อมูลคนไข้
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:io';

import '../models/patient.dart';
import '../models/treatment.dart';
import '../services/patient_service.dart';
import '../services/treatment_service.dart';
import '../services/medical_image_service.dart';
import '../providers/treatment_provider.dart';

import '../widgets/custom_bottom_nav_bar.dart';
import '../widgets/treatment_form.dart';
import '../screens/medical_image_gallery.dart';
import '../screens/medical_image_viewer.dart';
import '../styles/app_theme.dart';

class PatientDetailScreen extends StatefulWidget {
  const PatientDetailScreen({super.key});

  @override
  State<PatientDetailScreen> createState() => _PatientDetailScreenState();
}

/// ฟังก์ชันสำหรับเปิดหน้าดูรูปภาพแบบเต็มจอ
void openImageViewer({
  required BuildContext context,
  required List<Map<String, dynamic>> images,
  required int startIndex,
  required String patientId,
}) {
  Navigator.push(
    context,
    MaterialPageRoute(
      builder: (_) => MedicalImageViewer(
        images: images,
        initialIndex: startIndex,
        patientId: patientId,
      ),
    ),
  );
}

class _PatientDetailScreenState extends State<PatientDetailScreen>
    with WidgetsBindingObserver {
  final PatientService _patientService = PatientService();
  final MedicalImageService _medicalImageService = MedicalImageService();
  Patient? patient;
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
      _reloadPatientData();
    }
  }

  Future<void> _reloadPatientData() async {
    final fetchedPatient = await _patientService.getPatientById(patientId);
    if (mounted && fetchedPatient != null) {
      setState(() {
        patient = fetchedPatient;
      });
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (patient == null) {
      final args = ModalRoute.of(context)?.settings.arguments;
      Patient? initialPatient;
      if (args is Patient) {
        initialPatient = args;
      } else if (args is Map<String, dynamic>) {
        initialPatient = Patient.fromMap(args);
      }
      if (initialPatient != null) {
        setState(() {
          patient = initialPatient;
          patientId = initialPatient!.patientId;
        });
        if (patientId.isNotEmpty) {
          _reloadPatientData();
        }
      }
    }
  }

  Future<void> _pickAndUploadImage(ImageSource source) async {
    final picker = ImagePicker();
    final pickedFile = await picker.pickImage(
      source: source,
      imageQuality: 80,
      maxWidth: 1080,
    );

    if (pickedFile != null && mounted) {
      try {
        final downloadUrl = await _medicalImageService.uploadImageAndGetUrl(
          file: File(pickedFile.path),
          patientId: patientId,
        );

        await FirebaseFirestore.instance
            .collection('patients')
            .doc(patientId)
            .collection('medical_images')
            .add({
          'url': downloadUrl,
          'createdAt': Timestamp.now(),
        });

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('อัปโหลดรูปภาพสำเร็จแล้วค่ะ! 💜')),
        );
      } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('เกิดข้อผิดพลาดในการอัปโหลด: $e')),
        );
      }
    }
  }

  void _showImageSourcePicker() {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (bottomSheetContext) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Wrap(
              runSpacing: 10,
              children: [
                ListTile(
                  leading: const Icon(Icons.photo_library_rounded, color: Colors.teal),
                  title: const Text("เลือกจากคลังภาพ"),
                  onTap: () async {
                    Navigator.pop(bottomSheetContext);
                    await _pickAndUploadImage(ImageSource.gallery);
                  },
                ),
                ListTile(
                  leading: const Icon(Icons.camera_alt_rounded, color: Colors.deepOrange),
                  title: const Text("ถ่ายรูปด้วยกล้อง"),
                  onTap: () async {
                    Navigator.pop(bottomSheetContext);
                    await _pickAndUploadImage(ImageSource.camera);
                  },
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildRatingStars(double rating) {
    final int fullStars = rating.floor();
    final bool hasHalfStar = (rating - fullStars) >= 0.5;

    return Row(
      children: List.generate(5, (index) {
        Widget toothIcon;
        if (index < fullStars) {
          toothIcon = Image.asset('assets/icons/tooth_good.png', width: 20, height: 20);
        } else if (index == fullStars && hasHalfStar) {
          toothIcon = Image.asset('assets/icons/tooth_good.png', width: 20, height: 20, color: AppTheme.ratingInflamedTooth);
        } else {
          toothIcon = Image.asset('assets/icons/tooth_broke.png', width: 20, height: 20);
        }
        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 2.0),
          child: toothIcon,
        );
      }),
    );
  }
  
  Widget _getGenderIcon(String gender, {double size = 20}) {
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

  Widget _buildDetailRow({required String iconPath, required Widget child}) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Image.asset(iconPath, width: 22, height: 22),
        const SizedBox(width: 12),
        Expanded(child: child),
      ],
    );
  }

  int _calculateAge(DateTime? birthDate) {
    if (birthDate == null) return 0;
    final today = DateTime.now();
    int age = today.year - birthDate.year;
    if (today.month < birthDate.month ||
        (today.month == birthDate.month && today.day < birthDate.day)) {
      age--;
    }
    return age > 0 ? age : 0;
  }

  @override
  Widget build(BuildContext context) {
    if (patient == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('รายละเอียดคนไข้')),
        body: const Center(child: CircularProgressIndicator()),
      );
    }
    
    final String prefix = patient!.prefix;
    final String name = patient!.name;
    final String hnNumber = patient!.hnNumber ?? 'N/A';
    final String gender = patient!.gender;
    final int age = _calculateAge(patient!.birthDate);
    final String phone = patient!.telephone ?? '-';
    final double rating = patient!.rating;

    final cardColor;
    if (rating >= 4.5) {
      cardColor = AppTheme.rating5Star;
    } else if (rating >= 3.5) {
      cardColor = AppTheme.rating4Star;
    } else {
      cardColor = AppTheme.rating3StarAndBelow;
    }

    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(
        automaticallyImplyLeading: false,
        title: const Text('รายละเอียดคนไข้'),
        backgroundColor: AppTheme.primaryLight,
        elevation: 0,
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(16.0),
          children: [
            GestureDetector(
              onTap: () async {
                final result = await Navigator.pushNamed(
                  context,
                  '/add_patient',
                  arguments: patient,
                );
                if (result == true) {
                  _reloadPatientData();
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
                      color: AppTheme.primaryLight.withOpacity(0.6),
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
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        Row(
                          children: [
                            Image.asset(AppTheme.iconPathHn, width: 22, height: 22),
                            const SizedBox(width: 8),
                            Text(hnNumber, style: const TextStyle(fontSize: 16)),
                          ],
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.8),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: AppTheme.primaryLight),
                          ),
                          child: _buildRatingStars(rating),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    _buildDetailRow(
                      iconPath: AppTheme.iconPathUser,
                      child: Text(
                        '$prefix $name',
                        style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: AppTheme.primary),
                      ),
                    ),
                    const SizedBox(height: 12),
                    _buildDetailRow(
                      iconPath: AppTheme.iconPathAge,
                      child: Row(
                        children: [
                          Text('อายุ $age ปี', style: const TextStyle(fontSize: 16)),
                          const SizedBox(width: 8),
                          _getGenderIcon(gender, size: 22),
                        ],
                      ),
                    ),
                    const SizedBox(height: 8),
                    _buildDetailRow(
                      iconPath: AppTheme.iconPathPhone,
                      child: Row(
                        children: [
                          Expanded(child: Text('เบอร์โทร: $phone', style: const TextStyle(fontSize: 16))),
                          if (phone != '-')
                            SizedBox(
                              height: 40,
                              width: 40,
                              child: Material(
                                color: AppTheme.buttonCallBg,
                                shape: const CircleBorder(),
                                clipBehavior: Clip.antiAlias,
                                child: IconButton(
                                  padding: EdgeInsets.zero,
                                  tooltip: 'โทรหา $name',
                                  icon: Image.asset('assets/icons/phone.png', width: 22, height: 22),
                                  onPressed: () async {
                                    final uri = Uri.parse('tel:$phone');
                                    if (await canLaunchUrl(uri)) {
                                      await launchUrl(uri);
                                    }
                                  },
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 8),
                    _buildDetailRow(
                      iconPath: AppTheme.iconPathAddress,
                      child: Text('ที่อยู่: ${patient!.address ?? '-'}', style: const TextStyle(fontSize: 16)),
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 24),
            
            Column(
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    const Text(
                      'แกลเลอรีรูปภาพ',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: AppTheme.primary,
                      ),
                    ),
                    Container(
                      decoration: BoxDecoration(
                        color: AppTheme.buttonEditBg,
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                            color: Colors.grey.withOpacity(0.3),
                            spreadRadius: 1,
                            blurRadius: 3,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: IconButton(
                        icon: Image.asset('assets/icons/x_ray.png', width: 28, height: 28),
                        tooltip: 'เพิ่มรูปภาพในแกลเลอรี',
                        onPressed: _showImageSourcePicker,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                if (patientId.isNotEmpty)
                  MedicalImageGallery(
                    imageStream: _medicalImageService.getMedicalImages(patientId),
                    patientId: patientId,
                    onImageTap: openImageViewer,
                  ),
              ],
            ),

            const SizedBox(height: 24),

            if (patientId.isNotEmpty)
              StreamBuilder<List<Treatment>>(
                stream: TreatmentService().getTreatments(patientId),
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Center(child: CircularProgressIndicator());
                  }

                  final treatments = snapshot.data ?? [];
                  final double totalCost = treatments.fold(0.0, (sum, item) => sum + item.price);

                  return Column(
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          const Text('ประวัติการรักษา', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: AppTheme.primary)),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                            decoration: BoxDecoration(
                              color: AppTheme.primary.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: Row(
                              children: [
                                Image.asset(AppTheme.iconPathMoney, width: 20, height: 20),
                                const SizedBox(width: 8),
                                Text(
                                  '${totalCost.toStringAsFixed(0)} บาท',
                                  style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppTheme.primary),
                                ),
                              ],
                            ),
                          )
                        ],
                      ),
                      const SizedBox(height: 16),
                      
                      if (treatments.isEmpty)
                        const Padding(padding: EdgeInsets.all(16.0), child: Text('ยังไม่มีประวัติการรักษา'))
                      else
                        ListView.builder(
                          shrinkWrap: true,
                          physics: const NeverScrollableScrollPhysics(),
                          itemCount: treatments.length,
                          itemBuilder: (context, index) {
                            final treatment = treatments[index];
                            return GestureDetector(
                              onTap: () async {
                                final result = await showDialog<bool>(
                                  context: context,
                                  barrierDismissible: false,
                                  builder: (BuildContext context) {
                                    return ChangeNotifierProvider(
                                      create: (_) => TreatmentProvider(),
                                      child: Dialog(
                                        insetPadding: const EdgeInsets.all(16),
                                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                                        backgroundColor: const Color(0xFFFBEAFF),
                                        child: SingleChildScrollView(
                                          padding: const EdgeInsets.all(16.0),
                                          child: TreatmentForm(
                                            patientId: patientId,
                                            treatment: treatment,
                                          ),
                                        ),
                                      ),
                                    );
                                  },
                                );
                                if (result == true) {
                                  _reloadPatientData();
                                }
                              },
                              child: Card(
                                margin: const EdgeInsets.only(bottom: 12),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                                elevation: 2,
                                color: Colors.white,
                                child: Padding(
                                  padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0),
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Row(
                                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Expanded(
                                            child: Column(
                                              crossAxisAlignment: CrossAxisAlignment.start,
                                              children: [
                                                Row(
                                                  children: [
                                                    Image.asset(AppTheme.iconPathTreatment, width: 16, height: 16),
                                                    const SizedBox(width: 8),
                                                    Expanded(child: Text(treatment.procedure, style: const TextStyle(fontWeight: FontWeight.bold))),
                                                  ],
                                                ),
                                                const SizedBox(height: 4),
                                                if (treatment.toothNumber.isNotEmpty)
                                                  Row(
                                                    children: [
                                                      Image.asset(AppTheme.iconPathTooth, width: 16, height: 16),
                                                      const SizedBox(width: 8),
                                                      Text(treatment.toothNumber),
                                                    ],
                                                  ),
                                              ],
                                            ),
                                          ),
                                          const SizedBox(width: 16),
                                          Column(
                                            crossAxisAlignment: CrossAxisAlignment.end,
                                            children: [
                                              Row(
                                                children: [
                                                  Image.asset(AppTheme.iconPathMoney, width: 16, height: 16),
                                                  const SizedBox(width: 4),
                                                  Text('${treatment.price.toStringAsFixed(0)} บาท'),
                                                ],
                                              ),
                                              const SizedBox(height: 4),
                                              Row(
                                                children: [
                                                  Image.asset(AppTheme.iconPathCalendar, width: 16, height: 16),
                                                  const SizedBox(width: 4),
                                                  Text(DateFormat('dd/MM/yy').format(treatment.date)),
                                                ],
                                              ),
                                            ],
                                          ),
                                        ],
                                      ),
                                      if (treatment.notes != null && treatment.notes!.isNotEmpty) ...[
                                        const Divider(height: 20, thickness: 1),
                                        Row(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            // ✨ [UI-FIX v1.9.11] นำสีออกจากไอคอน
                                            Image.asset('assets/icons/notes.png', width: 16, height: 16),
                                            const SizedBox(width: 8),
                                            Expanded(
                                              child: Text(
                                                treatment.notes!,
                                                style: TextStyle(color: Colors.grey.shade800, fontStyle: FontStyle.italic),
                                              ),
                                            ),
                                          ],
                                        ),
                                      ],
                                      if (treatment.imageUrls.isNotEmpty) ...[
                                        const Divider(height: 20, thickness: 1),
                                        InkWell(
                                          onTap: () {
                                            final imageMaps = treatment.imageUrls.map((url) {
                                              return {'url': url, 'createdAt': Timestamp.now(), 'id': url};
                                            }).toList();
                                            openImageViewer(
                                              context: context,
                                              images: imageMaps,
                                              startIndex: 0,
                                              patientId: patientId,
                                            );
                                          },
                                          child: Row(
                                            children: [
                                              // ✨ [UI-FIX v1.9.11] นำสีออกจากไอคอน
                                              Image.asset('assets/icons/x_ray.png', width: 20, height: 20),
                                              const SizedBox(width: 8),
                                              Text(
                                                '${treatment.imageUrls.length} รูปภาพ',
                                                style: const TextStyle(color: AppTheme.primary, fontWeight: FontWeight.bold),
                                              ),
                                            ],
                                          ),
                                        ),
                                      ]
                                    ],
                                  ),
                                ),
                              ),
                            );
                          },
                        ),
                    ],
                  );
                },
              ),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          showDialog<bool>(
            context: context,
            barrierDismissible: false,
            builder: (BuildContext context) {
              return ChangeNotifierProvider(
                create: (_) => TreatmentProvider(),
                child: Dialog(
                  insetPadding: const EdgeInsets.all(16),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                  backgroundColor: const Color(0xFFFBEAFF),
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.all(16.0),
                    child: TreatmentForm(
                      patientId: patientId,
                    ),
                  ),
                ),
              );
            },
          ).then((result) {
            if (result == true) {
              _reloadPatientData();
            }
          });
        },
        backgroundColor: AppTheme.primary,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
        child: const Icon(Icons.add, color: Colors.white, size: 36),
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerDocked,
      bottomNavigationBar: const CustomBottomNavBar(selectedIndex: 1),
    );
  }
}
