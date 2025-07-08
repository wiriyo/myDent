// ----------------------------------------------------------------
// 📁 lib/screens/appointment_search_screen.dart (UPGRADED)
// v1.2.0 - ✨ Add Autocomplete Search Feature
// ----------------------------------------------------------------
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import '../models/appointment_search_model.dart';
import '../models/patient.dart'; // ✨ [NEW v1.2] import Patient model
import '../services/appointment_search_service.dart';
import '../services/patient_service.dart'; // ✨ [NEW v1.2] import Patient service
import '../styles/app_theme.dart';
import '../widgets/custom_bottom_nav_bar.dart';

class AppointmentSearchScreen extends StatefulWidget {
  const AppointmentSearchScreen({super.key});

  @override
  State<AppointmentSearchScreen> createState() => _AppointmentSearchScreenState();
}

class _AppointmentSearchScreenState extends State<AppointmentSearchScreen> {
  final _searchController = TextEditingController();
  final _scrollController = ScrollController();
  final _appointmentSearchService = AppointmentSearchService();
  final _patientService = PatientService(); // ✨ [NEW v1.2]
  Timer? _debounce;

  List<AppointmentSearchModel> _appointments = [];
  List<Patient> _allPatients = []; // ✨ [NEW v1.2] สำหรับเก็บรายชื่อคนไข้ทั้งหมด
  bool _isLoading = false;
  bool _isFirstLoad = true;
  bool _isLoadingMore = false;
  bool _hasMore = true;
  DocumentSnapshot? _lastDocument;
  final int _limit = 20;

  @override
  void initState() {
    super.initState();
    _loadPatientsForSuggestions(); // ✨ [NEW v1.2] โหลดรายชื่อคนไข้ตอนเริ่ม
    _searchController.addListener(_onSearchChanged);
    _scrollController.addListener(_onScroll);
  }

  // ✨ [NEW v1.2] เมธอดสำหรับโหลดรายชื่อคนไข้ทั้งหมดมาเตรียมไว้
  Future<void> _loadPatientsForSuggestions() async {
    _allPatients = await _patientService.fetchPatientsOnce();
  }

  @override
  void dispose() {
    _searchController.removeListener(_onSearchChanged);
    _searchController.dispose();
    _scrollController.dispose();
    _debounce?.cancel();
    super.dispose();
  }

  void _onScroll() {
    if (_scrollController.position.pixels >= _scrollController.position.maxScrollExtent - 200 && !_isLoadingMore) {
      _performSearch();
    }
  }

  void _onSearchChanged() {
    if (_debounce?.isActive ?? false) _debounce!.cancel();
    _debounce = Timer(const Duration(milliseconds: 600), () {
      _performSearch(isNewSearch: true);
    });
  }

  Future<void> _performSearch({bool isNewSearch = false}) async {
    if (isNewSearch) {
      _lastDocument = null;
      _hasMore = true;
      setState(() {
        _appointments = [];
        _isLoading = true;
        _isFirstLoad = false;
      });
    }

    if (!_hasMore || _isLoadingMore) return;

    setState(() { _isLoadingMore = true; });

    final query = _searchController.text.trim();
    if (query.isEmpty) {
      setState(() {
        _appointments = [];
        _isLoading = false;
        _isLoadingMore = false;
        _isFirstLoad = true;
      });
      return;
    }

    try {
      final result = await _appointmentSearchService.searchAppointments(
        query: query,
        limit: _limit,
        lastDocument: _lastDocument,
      );

      final newAppointments = result['appointments'] as List<AppointmentSearchModel>;
      
      setState(() {
        _appointments.addAll(newAppointments);
        _lastDocument = result['lastDocument'];
        _hasMore = newAppointments.length == _limit;
        _isLoading = false;
        _isLoadingMore = false;
      });
    } catch (e) {
      setState(() {
        _isLoading = false;
        _isLoadingMore = false;
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('เกิดข้อผิดพลาดในการค้นหา: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(
        automaticallyImplyLeading: false,
        title: const Text('ค้นหานัดหมาย'),
        backgroundColor: AppTheme.primaryLight,
        elevation: 0,
      ),
      body: Column(
        children: [
          _buildSearchBar(),
          Expanded(child: _buildContent()),
        ],
      ),
      bottomNavigationBar: const CustomBottomNavBar(selectedIndex: 3),
    );
  }

  // ✨ [UPGRADED v1.2] เปลี่ยนช่องค้นหาเป็น Autocomplete
  Widget _buildSearchBar() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
      child: Autocomplete<Patient>(
        displayStringForOption: (patient) => patient.name,
        optionsBuilder: (TextEditingValue textEditingValue) {
          if (textEditingValue.text.isEmpty) {
            return const Iterable<Patient>.empty();
          }
          // กรองจากรายชื่อคนไข้ที่เราโหลดมาเตรียมไว้
          return _allPatients.where((patient) {
            final query = textEditingValue.text.toLowerCase();
            final name = patient.name.toLowerCase();
            final hn = patient.hnNumber?.toLowerCase() ?? '';
            final phone = patient.telephone?.toLowerCase() ?? '';
            return name.contains(query) || hn.contains(query) || phone.contains(query);
          });
        },
        onSelected: (Patient selection) {
          // เมื่อเลือกแล้ว ให้ใช้ HN เป็นคำค้นหาเพื่อความแม่นยำ
          _searchController.text = selection.hnNumber ?? selection.name;
          _performSearch(isNewSearch: true);
        },
        fieldViewBuilder: (context, controller, focusNode, onFieldSubmitted) {
          // เชื่อม controller ของ Autocomplete กับของเรา
          _searchController.value = controller.value;
          return TextField(
            controller: controller,
            focusNode: focusNode,
            style: const TextStyle(fontFamily: AppTheme.fontFamily),
            decoration: InputDecoration(
              hintText: 'ค้นหาด้วยชื่อ, เบอร์โทร, หรือ HN...',
              hintStyle: const TextStyle(fontFamily: AppTheme.fontFamily),
              prefixIcon: const Icon(Icons.search, color: Colors.grey),
              suffixIcon: controller.text.isNotEmpty
                  ? IconButton(
                      icon: const Icon(Icons.clear, color: Colors.grey),
                      onPressed: () {
                        controller.clear();
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
          );
        },
        optionsViewBuilder: (context, onSelected, options) {
          return Align(
            alignment: Alignment.topLeft,
            child: Material(
              elevation: 4.0,
              color: const Color(0xFFFCF5FF),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
                side: BorderSide(color: AppTheme.primary.withOpacity(0.3)),
              ),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxHeight: 250),
                child: ListView.builder(
                  padding: const EdgeInsets.all(8.0),
                  itemCount: options.length,
                  itemBuilder: (BuildContext context, int index) {
                    final option = options.elementAt(index);
                    return InkWell(
                      onTap: () => onSelected(option),
                      borderRadius: BorderRadius.circular(12),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                        child: Row(
                          children: [
                            Image.asset('assets/icons/user.png', width: 24, height: 24),
                            const SizedBox(width: 16),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(option.name, style: const TextStyle(fontWeight: FontWeight.bold)),
                                  Text('HN: ${option.hnNumber ?? 'N/A'}', style: const TextStyle(color: AppTheme.textSecondary)),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildContent() {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator(color: AppTheme.primary));
    }
    if (_isFirstLoad) {
      return _buildEmptyState('เริ่มต้นค้นหานัดหมายได้เลยค่ะ', Icons.search_off_rounded);
    }
    if (_appointments.isEmpty) {
      return _buildEmptyState('ไม่พบผลการค้นหา', Icons.find_in_page_outlined);
    }

    return ListView.builder(
      controller: _scrollController,
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
      itemCount: _appointments.length + (_hasMore ? 1 : 0),
      itemBuilder: (context, index) {
        if (index == _appointments.length) {
          return _buildLoadMoreButton();
        }
        final appointment = _appointments[index];
        return _AppointmentCard(appointment: appointment);
      },
    );
  }

  Widget _buildLoadMoreButton() {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 16.0),
      child: Center(
        child: _isLoadingMore
            ? const CircularProgressIndicator(color: AppTheme.primary)
            : OutlinedButton.icon(
                onPressed: _performSearch,
                icon: const Icon(Icons.add),
                label: const Text('แสดงเพิ่ม'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppTheme.primary,
                  side: const BorderSide(color: AppTheme.primaryLight),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(20),
                  ),
                ),
              ),
      ),
    );
  }
  
  Widget _buildEmptyState(String message, IconData icon) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, size: 80, color: AppTheme.primaryLight),
          const SizedBox(height: 16),
          Text(
            message,
            style: const TextStyle(fontSize: 18, color: AppTheme.textSecondary),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}

class _AppointmentCard extends StatelessWidget {
  final AppointmentSearchModel appointment;

  const _AppointmentCard({required this.appointment});

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final isPast = appointment.startTime.isBefore(now);
    final cardColor = isPast ? Colors.grey.shade200 : Colors.white;
    final textColor = isPast ? AppTheme.textDisabled : AppTheme.textPrimary;
    final statusColor = _getStatusColor(appointment.status);

    return Card(
      color: cardColor,
      margin: const EdgeInsets.symmetric(vertical: 8),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: isPast ? Colors.grey.shade300 : AppTheme.primaryLight)
      ),
      elevation: 2,
      shadowColor: AppTheme.primary.withOpacity(0.1),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildHeader(textColor, statusColor),
            const Divider(height: 24),
            _buildInfoRow(Icons.person_outline, 'คนไข้', '${appointment.patientName} (HN: ${appointment.hnNumber ?? 'N/A'})', textColor),
            const SizedBox(height: 8),
            _buildInfoRow(Icons.medical_services_outlined, 'หัตถการ', appointment.treatment, textColor),
            if (appointment.teeth != null && appointment.teeth!.isNotEmpty) ...[
              const SizedBox(height: 8),
              _buildInfoRow(Icons.tag, 'ซี่ฟัน', appointment.teeth!.join(', '), textColor),
            ],
            if (appointment.notes != null && appointment.notes!.isNotEmpty) ...[
              const SizedBox(height: 8),
              _buildInfoRow(Icons.notes_outlined, 'หมายเหตุ', appointment.notes!, textColor),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildHeader(Color textColor, Color statusColor) {
    final dayFormat = DateFormat('dd MMMM', 'th_TH');
    final timeFormat = DateFormat('HH:mm');
    final buddhistYear = appointment.startTime.year + 543;

    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '${dayFormat.format(appointment.startTime)} $buddhistYear',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: textColor),
            ),
            const SizedBox(height: 4),
            Text(
              '${timeFormat.format(appointment.startTime)} - ${timeFormat.format(appointment.endTime)} น. (${appointment.duration} นาที)',
              style: TextStyle(fontSize: 14, color: textColor.withOpacity(0.8)),
            ),
          ],
        ),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            color: statusColor.withOpacity(0.15),
            borderRadius: BorderRadius.circular(20),
          ),
          child: Text(
            appointment.status,
            style: TextStyle(color: statusColor, fontWeight: FontWeight.bold, fontSize: 12),
          ),
        ),
      ],
    );
  }

  Widget _buildInfoRow(IconData icon, String label, String value, Color textColor) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 18, color: textColor.withOpacity(0.7)),
        const SizedBox(width: 12),
        Expanded(
          child: Text.rich(
            TextSpan(
              text: '$label: ',
              style: TextStyle(fontWeight: FontWeight.bold, color: textColor),
              children: [
                TextSpan(
                  text: value,
                  style: TextStyle(fontWeight: FontWeight.normal, color: textColor),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Color _getStatusColor(String status) {
    return switch (status) {
      'เสร็จแล้ว' => Colors.green.shade700,
      'รอยืนยัน' => Colors.blue.shade700,
      'เลื่อนนัด' => Colors.orange.shade800,
      'ยกเลิก' => Colors.red.shade700,
      'ไม่มาตามนัด' => Colors.red.shade700,
      _ => AppTheme.textSecondary,
    };
  }
}
