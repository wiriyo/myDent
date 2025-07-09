// ----------------------------------------------------------------
// 📁 lib/screens/patient_detail.dart
// v1.8.0 - ✨ Added Spacing for Image Gallery
// ----------------------------------------------------------------
import 'dart:io';
import 'package:flutter/material.dart';
import '../models/patient.dart';
import '../services/treatment_service.dart';
import '../services/patient_service.dart';
import '../models/treatment.dart';
import 'treatment_add.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:image_picker/image_picker.dart';
import '../services/medical_image_service.dart';
import 'package:permission_handler/permission_handler.dart';
import '../main.dart';
import 'medical_image_viewer.dart';
import 'medical_image_gallery.dart';
import '../styles/app_theme.dart';
import '../widgets/custom_bottom_nav_bar.dart';

class PatientDetailScreen extends StatefulWidget {
  const PatientDetailScreen({super.key});

  @override
  State<PatientDetailScreen> createState() => _PatientDetailScreenState();
}

void openImageViewer({
  required BuildContext context,
  required List<Map<String, dynamic>> images,
  required int startIndex,
  required String patientId,
}) {
  Navigator.push(
    context,
    MaterialPageRoute(
      builder:
          (_) => MedicalImageViewer(
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
      _reloadPatientData(patientId);
    }
  }

  Future<void> _reloadPatientData(String docId) async {
    final fetchedPatient = await _patientService.getPatientById(docId);
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
          _reloadPatientData(patientId);
        }
      }
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

  Future<void> requestPermissions() async {
    if (await Permission.photos.request().isGranted ||
        await Permission.storage.request().isGranted ||
        await Permission.camera.request().isGranted) {
    } else {
    }
  }

  Future<File?> pickImage(ImageSource source) async {
    final picker = ImagePicker();
    final pickedFile = await picker.pickImage(
      source: source,
      imageQuality: 75,
      maxWidth: 1080,
    );

    if (pickedFile != null) {
      return File(pickedFile.path);
    } else {
      return null;
    }
  }

  void _showImageSourcePicker(BuildContext context) {
    final rootContext = scaffoldMessengerKey.currentContext;

    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return Padding(
          padding: const EdgeInsets.all(20.0),
          child: Wrap(
            runSpacing: 10,
            children: [
              ListTile(
                leading: const Icon(Icons.photo, color: Colors.teal),
                title: const Text("เลือกจากคลังภาพ"),
                onTap: () async {
                  Navigator.pop(context);
                  final image = await pickImage(ImageSource.gallery);
                  if (image != null) {
                    try {
                      await MedicalImageService().uploadMedicalImage(
                        file: image,
                        patientId: patientId,
                      );

                      if (!mounted || rootContext == null) return;
                      Future.delayed(const Duration(milliseconds: 100), () {
                        ScaffoldMessenger.of(rootContext).showSnackBar(
                          const SnackBar(content: Text('อัปโหลดสำเร็จแล้ว 💜')),
                        );
                      });
                    } catch (e) {
                      if (!mounted || rootContext == null) return;
                      ScaffoldMessenger.of(rootContext).showSnackBar(
                        SnackBar(content: Text("เกิดข้อผิดพลาด: $e")),
                      );
                    }
                  }
                },
              ),
              ListTile(
                leading: const Icon(Icons.camera_alt, color: Colors.deepOrange),
                title: const Text("ถ่ายรูปด้วยกล้อง"),
                onTap: () async {
                  Navigator.pop(context);
                  final image = await pickImage(ImageSource.camera);
                  if (image != null) {
                    try {
                      await MedicalImageService().uploadMedicalImage(
                        file: image,
                        patientId: patientId,
                      );

                      if (!mounted || rootContext == null) return;
                      Future.delayed(const Duration(milliseconds: 100), () {
                        ScaffoldMessenger.of(rootContext).showSnackBar(
                          const SnackBar(
                            content: Text('อัปโหลดจากกล้องสำเร็จแล้ว 🎉'),
                          ),
                        );
                      });
                    } catch (e) {
                      if (!mounted || rootContext == null) return;
                      ScaffoldMessenger.of(rootContext).showSnackBar(
                        SnackBar(content: Text("เกิดข้อผิดพลาด: $e")),
                      );
                    }
                  }
                },
              ),
            ],
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    if (patient == null) {
      return Scaffold(
        appBar: AppBar(
          title: const Text('รายละเอียดคนไข้'),
          backgroundColor: AppTheme.primaryLight,
        ),
        body: const Center(child: CircularProgressIndicator(color: AppTheme.primary)),
      );
    }
    
    final String prefix = patient!.prefix;
    final String name = patient!.name;
    final String gender = patient!.gender;
    final int age = _calculateAge(patient!.birthDate);
    final String phone = patient!.telephone ?? '-';
    final int rating = patient!.rating;

    final cardColor = switch (rating) {
      >= 5 => AppTheme.rating5Star,
      4    => AppTheme.rating4Star,
      _    => AppTheme.rating3StarAndBelow,
    };

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
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 6,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.8),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: AppTheme.primaryLight),
                          ),
                          child: _buildRatingStars(rating),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '$prefix $name',
                      style: const TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                        color: AppTheme.primary,
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
                                  icon: Image.asset(
                                    'assets/icons/phone.png',
                                    width: 22,
                                    height: 22,
                                  ),
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
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'ประวัติการรักษา',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: AppTheme.primary,
                  ),
                ),
                
                Row(
                  children: [
                    if (patientId.isNotEmpty)
                      StreamBuilder<List<Treatment>>(
                        stream: TreatmentService().getTreatments(patientId),
                        builder: (context, snapshot) {
                          final total =
                              snapshot.data?.fold<double>(
                                    0,
                                    (prev, e) => prev + e.price,
                                  ) ??
                                  0.0;
                          return Text(
                            '🧾 ${total.toStringAsFixed(0)} บาท',
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: AppTheme.primary,
                            ),
                          );
                        },
                      ),
                    const SizedBox(width: 12),
                    Container(
                      width: 64,
                      height: 64,
                      decoration: BoxDecoration(
                        color: AppTheme.buttonEditBg,
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                            color: AppTheme.primaryLight.withOpacity(0.5),
                            blurRadius: 4,
                            offset: const Offset(2, 2),
                          ),
                        ],
                      ),
                      child: IconButton(
                        padding: EdgeInsets.zero,
                        icon: Image.asset(
                          'assets/icons/x_ray.png',
                          width: 48,
                          height: 48,
                        ),
                        onPressed: () {
                          _showImageSourcePicker(context);
                        },
                      ),
                    ),
                  ],
                ),
              ],
            ),
            
            // ✨ [UI-FIX v1.8.0] เพิ่มพื้นที่ว่างระหว่างปุ่มกับแกลเลอรีรูปภาพค่ะ
            const SizedBox(height: 16),

            if (patientId.isNotEmpty)
              MedicalImageGallery(
                imageStream: MedicalImageService().getMedicalImages(patientId),
                patientId: patientId,
                onImageTap: openImageViewer,
              ),

            const SizedBox(height: 12),
            if (patientId.isNotEmpty)
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
                            treatment: treatment,
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
          if (patientId.isNotEmpty) {
            showTreatmentDialog(context, patientId: patientId);
          }
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
