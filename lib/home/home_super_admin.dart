import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:provider/provider.dart';

import '../auth/auth_provider.dart';
import '../styles/app_theme.dart';

class HomeSuperAdminScreen extends StatefulWidget {
  const HomeSuperAdminScreen({super.key});

  @override
  State<HomeSuperAdminScreen> createState() => _HomeSuperAdminScreenState();
}

class _HomeSuperAdminScreenState extends State<HomeSuperAdminScreen> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  late Future<_DashboardCounts> _countsFuture;
  String? _processingRequestId;
  final Set<String> _clinicActionsInProgress = <String>{};

  @override
  void initState() {
    super.initState();
    _countsFuture = _loadCounts();
  }

  Future<_DashboardCounts> _loadCounts() async {
    final clinicsCount = await _firestore.collection('clinics').count().get();
    final usersCount = await _firestore.collection('users').count().get();
    final pendingApprovals =
        await _firestore
            .collection('approval_requests')
            .where('status', isEqualTo: 'pending')
            .count()
            .get();

    return _DashboardCounts(
      clinics: clinicsCount.count ?? 0,
      pendingApprovals: pendingApprovals.count ?? 0,
      totalUsers: usersCount.count ?? 0,
    );
  }

  Future<void> _refresh() async {
    setState(() {
      _countsFuture = _loadCounts();
    });
    await _countsFuture;
  }

  String _functionsBaseUrl() {
    const defaultRegion = 'us-central1';
    final projectId = Firebase.app().options.projectId;
    return 'https://$defaultRegion-$projectId.cloudfunctions.net';
  }

  Future<void> _handleApprovalAction(
    DocumentSnapshot<Map<String, dynamic>> snapshot, {
    required bool approve,
  }) async {
    final data = snapshot.data();
    if (data == null) {
      _showSnackBar('ไม่พบข้อมูลคำขออนุมัติ');
      return;
    }

    final tokenField = approve ? 'approveToken' : 'rejectToken';
    final token = data[tokenField] as String?;
    if (token == null || token.isEmpty) {
      _showSnackBar('ไม่พบโทเคนสำหรับการดำเนินการ');
      return;
    }

    final endpoint = approve ? 'approveClinicRequest' : 'rejectClinicRequest';
    final url = Uri.parse('${_functionsBaseUrl()}/$endpoint?token=$token');

    setState(() => _processingRequestId = '${snapshot.id}_$endpoint');
    try {
      final response = await http.get(url);
      if (response.statusCode >= 200 && response.statusCode < 300) {
        _showSnackBar(
          approve ? 'อนุมัติคำขอเรียบร้อยแล้ว' : 'ปฏิเสธคำขอเรียบร้อยแล้ว',
        );
      } else {
        _showSnackBar(
          'ติดต่อ Cloud Functions ไม่สำเร็จ (${response.statusCode})',
        );
      }
    } catch (error) {
      _showSnackBar('เกิดข้อผิดพลาด: $error');
    } finally {
      setState(() => _processingRequestId = null);
    }
  }

  void _setClinicActionInProgress(String clinicId, String action, bool value) {
    final key = '$clinicId-$action';
    setState(() {
      if (value) {
        _clinicActionsInProgress.add(key);
      } else {
        _clinicActionsInProgress.remove(key);
      }
    });
  }

  bool _isClinicActionProcessing(String clinicId, String action) {
    return _clinicActionsInProgress.contains('$clinicId-$action');
  }

  Future<bool?> _confirmAction({
    required String title,
    required String message,
    required String confirmLabel,
    Color? confirmColor,
  }) {
    return showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text(title),
          content: Text(message),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('ยกเลิก'),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: confirmColor ?? AppTheme.primary,
              ),
              onPressed: () => Navigator.of(context).pop(true),
              child: Text(confirmLabel),
            ),
          ],
        );
      },
    );
  }

  Future<void> _revokeClinic(
    String clinicId,
    String ownerUid,
    String clinicName,
  ) async {
    final confirmed = await _confirmAction(
      title: 'ลบสิทธิ์การใช้งาน',
      message:
          'ต้องการปิดสิทธิ์การเข้าใช้งานของคลินิก "$clinicName" หรือไม่?\nผู้ใช้ทั้งหมดของคลินิกนี้จะไม่สามารถล็อกอินได้จนกว่าจะเปิดสิทธิ์ใหม่',
      confirmLabel: 'ลบสิทธิ์',
      confirmColor: Colors.orange,
    );
    if (confirmed != true) return;

    _setClinicActionInProgress(clinicId, 'revoke', true);
    try {
      await FirebaseFunctions.instance.httpsCallable('revokeClinicAccess').call(
        <String, dynamic>{'clinicId': clinicId, 'userId': ownerUid},
      );
      _showSnackBar('ลบสิทธิ์การใช้งานของคลินิกเรียบร้อยแล้ว');
      await _refresh();
    } on FirebaseFunctionsException catch (error) {
      _showSnackBar(error.message ?? 'ไม่สามารถลบสิทธิ์ได้');
    } catch (error) {
      _showSnackBar('เกิดข้อผิดพลาด: $error');
    } finally {
      _setClinicActionInProgress(clinicId, 'revoke', false);
    }
  }

  Future<void> _reinstateClinic(
    String clinicId,
    String ownerUid,
    String clinicName,
  ) async {
    final confirmed = await _confirmAction(
      title: 'คืนสิทธิ์การใช้งาน',
      message:
          'ต้องการคืนสิทธิ์ให้คลินิก "$clinicName" หรือไม่?\nผู้ใช้ทั้งหมดจะกลับมาใช้งานได้ตามปกติ',
      confirmLabel: 'คืนสิทธิ์',
      confirmColor: Colors.green,
    );
    if (confirmed != true) return;

    _setClinicActionInProgress(clinicId, 'reinstate', true);
    try {
      await FirebaseFunctions.instance
          .httpsCallable('reinstateClinicAccess')
          .call(<String, dynamic>{'clinicId': clinicId, 'userId': ownerUid});
      _showSnackBar('คืนสิทธิ์ให้คลินิกเรียบร้อยแล้ว');
      await _refresh();
    } on FirebaseFunctionsException catch (error) {
      _showSnackBar(error.message ?? 'ไม่สามารถคืนสิทธิ์ได้');
    } catch (error) {
      _showSnackBar('เกิดข้อผิดพลาด: $error');
    } finally {
      _setClinicActionInProgress(clinicId, 'reinstate', false);
    }
  }

  Future<void> _deleteClinic(
    String clinicId,
    String ownerUid,
    String clinicName,
  ) async {
    final confirmed = await _confirmAction(
      title: 'ลบข้อมูลทั้งหมด',
      message:
          'ต้องการลบข้อมูลทั้งหมดของคลินิก "$clinicName" หรือไม่?\nข้อมูลผู้ใช้ คลินิก และข้อมูลที่เกี่ยวข้องทั้งหมดจะถูกลบอย่างถาวร',
      confirmLabel: 'ลบทั้งหมด',
      confirmColor: Colors.red,
    );
    if (confirmed != true) return;

    _setClinicActionInProgress(clinicId, 'delete', true);
    try {
      await FirebaseFunctions.instance.httpsCallable('deleteClinicData').call(
        <String, dynamic>{'clinicId': clinicId, 'userId': ownerUid},
      );
      _showSnackBar('ลบคลินิกและข้อมูลทั้งหมดเรียบร้อยแล้ว');
      await _refresh();
    } on FirebaseFunctionsException catch (error) {
      _showSnackBar(error.message ?? 'ไม่สามารถลบข้อมูลได้');
    } catch (error) {
      _showSnackBar('เกิดข้อผิดพลาด: $error');
    } finally {
      _setClinicActionInProgress(clinicId, 'delete', false);
    }
  }

  Future<void> _signOut() async {
    final confirmed = await _confirmAction(
      title: 'ยืนยันการออกจากระบบ',
      message: 'ต้องการออกจากระบบผู้ดูแลสูงสุดหรือไม่?',
      confirmLabel: 'ออกจากระบบ',
      confirmColor: Colors.redAccent,
    );
    if (confirmed != true) return;

    try {
      await FirebaseAuth.instance.signOut();
      if (!mounted) return;
      Provider.of<AppAuthProvider>(context, listen: false).logout();
      Navigator.of(context).pushNamedAndRemoveUntil('/login', (route) => false);
    } catch (error) {
      _showSnackBar('ออกจากระบบไม่สำเร็จ: $error');
    }
  }

  void _showSnackBar(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(
        title: const Text('แดชบอร์ดผู้ดูแลสูงสุด'),
        centerTitle: true,
        backgroundColor: AppTheme.primary,
        elevation: 2,
        actions: [
          IconButton(
            tooltip: 'ออกจากระบบ',
            onPressed: _signOut,
            icon: const Icon(Icons.logout),
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _refresh,
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              FutureBuilder<_DashboardCounts>(
                future: _countsFuture,
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Center(
                      child: Padding(
                        padding: EdgeInsets.symmetric(vertical: 32),
                        child: CircularProgressIndicator(),
                      ),
                    );
                  }

                  if (!snapshot.hasData) {
                    return const Padding(
                      padding: EdgeInsets.symmetric(vertical: 24),
                      child: Text('ไม่สามารถโหลดสถิติได้ในขณะนี้'),
                    );
                  }

                  final counts = snapshot.data!;
                  return Row(
                    children: [
                      Expanded(
                        child: _buildSummaryCard(
                          'จำนวนคลินิกทั้งหมด',
                          counts.clinics,
                          Icons.apartment,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _buildSummaryCard(
                          'คำขอรอการอนุมัติ',
                          counts.pendingApprovals,
                          Icons.pending_actions,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _buildSummaryCard(
                          'ผู้ใช้งานทั้งหมด',
                          counts.totalUsers,
                          Icons.people_alt,
                        ),
                      ),
                    ],
                  );
                },
              ),
              const SizedBox(height: 24),
              Text(
                'คำขอใช้งานที่รอการอนุมัติ',
                style: Theme.of(
                  context,
                ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 12),
              StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                stream:
                    _firestore
                        .collection('approval_requests')
                        .where('status', isEqualTo: 'pending')
                        .orderBy('createdAt', descending: true)
                        .limit(20)
                        .snapshots(),
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Center(child: CircularProgressIndicator());
                  }

                  if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                    return const Card(
                      child: Padding(
                        padding: EdgeInsets.all(16.0),
                        child: Text('ไม่มีคำขอรอการอนุมัติ'),
                      ),
                    );
                  }

                  return Column(
                    children:
                        snapshot.data!.docs.map((doc) {
                          final data = doc.data();
                          final clinicName =
                              data['clinicName'] as String? ?? '-';
                          final clinicId = data['clinicId'] as String? ?? '-';
                          final userName = data['userName'] as String? ?? '-';
                          final userEmail = data['userEmail'] as String? ?? '-';
                          final createdAt =
                              (data['createdAt'] as Timestamp?)?.toDate();
                          final approveProcessing =
                              _processingRequestId ==
                              '${doc.id}_approveClinicRequest';
                          final rejectProcessing =
                              _processingRequestId ==
                              '${doc.id}_rejectClinicRequest';

                          return Card(
                            margin: const EdgeInsets.only(bottom: 12),
                            child: Padding(
                              padding: const EdgeInsets.all(16.0),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    clinicName,
                                    style: const TextStyle(
                                      fontSize: 18,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text('Clinic ID: $clinicId'),
                                  Text('ผู้ขอใช้งาน: $userName'),
                                  GestureDetector(
                                    onLongPress:
                                        () => Clipboard.setData(
                                          ClipboardData(text: userEmail),
                                        ),
                                    child: Text('อีเมล: $userEmail'),
                                  ),
                                  if (createdAt != null)
                                    Text(
                                      'ส่งคำขอเมื่อ: ${_formatThaiDateTime(createdAt)}',
                                    ),
                                  const SizedBox(height: 12),
                                  Row(
                                    children: [
                                      Expanded(
                                        child: ElevatedButton.icon(
                                          onPressed:
                                              approveProcessing
                                                  ? null
                                                  : () => _handleApprovalAction(
                                                    doc,
                                                    approve: true,
                                                  ),
                                          icon:
                                              approveProcessing
                                                  ? const SizedBox(
                                                    width: 16,
                                                    height: 16,
                                                    child:
                                                        CircularProgressIndicator(
                                                          strokeWidth: 2,
                                                          color: Colors.white,
                                                        ),
                                                  )
                                                  : const Icon(
                                                    Icons.check_circle_outline,
                                                  ),
                                          label: const Text('อนุมัติ'),
                                          style: ElevatedButton.styleFrom(
                                            backgroundColor: Colors.green,
                                          ),
                                        ),
                                      ),
                                      const SizedBox(width: 12),
                                      Expanded(
                                        child: OutlinedButton.icon(
                                          onPressed:
                                              rejectProcessing
                                                  ? null
                                                  : () => _handleApprovalAction(
                                                    doc,
                                                    approve: false,
                                                  ),
                                          icon:
                                              rejectProcessing
                                                  ? const SizedBox(
                                                    width: 16,
                                                    height: 16,
                                                    child:
                                                        CircularProgressIndicator(
                                                          strokeWidth: 2,
                                                        ),
                                                  )
                                                  : const Icon(
                                                    Icons.cancel_outlined,
                                                  ),
                                          label: const Text('ปฏิเสธ'),
                                          style: OutlinedButton.styleFrom(
                                            foregroundColor: Colors.red,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                          );
                        }).toList(),
                  );
                },
              ),
              const SizedBox(height: 24),
              Text(
                'คลินิกล่าสุด',
                style: Theme.of(
                  context,
                ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 12),
              StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                stream:
                    _firestore
                        .collection('clinics')
                        .orderBy('created_at', descending: true)
                        .limit(10)
                        .snapshots(),
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Center(child: CircularProgressIndicator());
                  }

                  if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                    return const Card(
                      child: Padding(
                        padding: EdgeInsets.all(16.0),
                        child: Text('ยังไม่มีข้อมูลคลินิก'),
                      ),
                    );
                  }

                  return Column(
                    children:
                        snapshot.data!.docs.map((doc) {
                          final data = doc.data();
                          final clinicId = doc.id;
                          final name = data['name'] as String? ?? '-';
                          final ownerUid = data['owner_uid'] as String? ?? '';
                          final createdAt =
                              (data['created_at'] as Timestamp?)?.toDate();
                          final status =
                              data['status'] as String? ?? 'approved';
                          final isRevoked = status == 'revoked';
                          final isRevoking = _isClinicActionProcessing(
                            clinicId,
                            'revoke',
                          );
                          final isReinstating = _isClinicActionProcessing(
                            clinicId,
                            'reinstate',
                          );
                          final isDeleting = _isClinicActionProcessing(
                            clinicId,
                            'delete',
                          );
                          final revokeProcessing = isRevoking || isReinstating;

                          return Card(
                            margin: const EdgeInsets.only(bottom: 12),
                            child: Padding(
                              padding: const EdgeInsets.all(16.0),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    name,
                                    style: const TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 18,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text('Clinic ID: $clinicId'),
                                  Text(
                                    'Owner UID: ${ownerUid.isEmpty ? '-' : ownerUid}',
                                  ),
                                  Text('สถานะ: ${_formatStatus(status)}'),
                                  if (createdAt != null)
                                    Text(
                                      'สร้างเมื่อ: ${_formatThaiDateTime(createdAt)}',
                                    ),
                                  const SizedBox(height: 12),
                                  Row(
                                    children: [
                                      Expanded(
                                        child: OutlinedButton.icon(
                                          onPressed:
                                              revokeProcessing
                                                  ? null
                                                  : () {
                                                    if (isRevoked) {
                                                      _reinstateClinic(
                                                        clinicId,
                                                        ownerUid,
                                                        name,
                                                      );
                                                    } else {
                                                      _revokeClinic(
                                                        clinicId,
                                                        ownerUid,
                                                        name,
                                                      );
                                                    }
                                                  },
                                          icon:
                                              revokeProcessing
                                                  ? const SizedBox(
                                                    width: 16,
                                                    height: 16,
                                                    child:
                                                        CircularProgressIndicator(
                                                          strokeWidth: 2,
                                                        ),
                                                  )
                                                  : Icon(
                                                    isRevoked
                                                        ? Icons.lock_open
                                                        : Icons.lock_reset,
                                                  ),
                                          label: Text(
                                            isRevoked
                                                ? 'คืนสิทธิ์'
                                                : 'ลบสิทธิ์',
                                          ),
                                          style: OutlinedButton.styleFrom(
                                            foregroundColor:
                                                isRevoked
                                                    ? Colors.green
                                                    : Colors.orange,
                                          ),
                                        ),
                                      ),
                                      const SizedBox(width: 12),
                                      Expanded(
                                        child: ElevatedButton.icon(
                                          onPressed:
                                              isDeleting
                                                  ? null
                                                  : () => _deleteClinic(
                                                    clinicId,
                                                    ownerUid,
                                                    name,
                                                  ),
                                          icon:
                                              isDeleting
                                                  ? const SizedBox(
                                                    width: 16,
                                                    height: 16,
                                                    child:
                                                        CircularProgressIndicator(
                                                          strokeWidth: 2,
                                                          color: Colors.white,
                                                        ),
                                                  )
                                                  : const Icon(
                                                    Icons.delete_forever,
                                                  ),
                                          label: const Text('ลบทั้งหมด'),
                                          style: ElevatedButton.styleFrom(
                                            backgroundColor: Colors.red,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                          );
                        }).toList(),
                  );
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSummaryCard(String title, int value, IconData icon) {
    return Card(
      color: Colors.white,
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, color: AppTheme.primary, size: 32),
            const SizedBox(height: 12),
            Text(
              value.toString(),
              style: const TextStyle(fontSize: 28, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 4),
            Text(title, style: const TextStyle(fontSize: 14)),
          ],
        ),
      ),
    );
  }

  String _formatStatus(String status) {
    switch (status) {
      case 'pending':
        return 'รออนุมัติ';
      case 'revoked':
        return 'ถูกเพิกถอนสิทธิ์';
      case 'approved':
        return 'ใช้งานปกติ';
      default:
        return status;
    }
  }

  String _formatThaiDateTime(DateTime dateTime) {
    return '${dateTime.day.toString().padLeft(2, '0')}/${dateTime.month.toString().padLeft(2, '0')}/${dateTime.year + 543} '
        '${dateTime.hour.toString().padLeft(2, '0')}:${dateTime.minute.toString().padLeft(2, '0')}';
  }
}

class _DashboardCounts {
  final int clinics;
  final int pendingApprovals;
  final int totalUsers;

  const _DashboardCounts({
    required this.clinics,
    required this.pendingApprovals,
    required this.totalUsers,
  });
}
