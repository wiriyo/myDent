import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';

class MedicalImageViewer extends StatefulWidget {
  final List<Map<String, dynamic>> images;
  final int initialIndex;
  final String patientId;

  const MedicalImageViewer({
    super.key,
    required this.images,
    required this.initialIndex,
    required this.patientId,
  });

  @override
  State<MedicalImageViewer> createState() => _MedicalImageViewerState();
}

class _MedicalImageViewerState extends State<MedicalImageViewer> {
  late PageController _pageController;
  late int currentIndex;

  @override
  void initState() {
    super.initState();
    currentIndex = widget.initialIndex;
    _pageController = PageController(initialPage: currentIndex);
  }

  Future<void> _deleteImage() async {
    final image = widget.images[currentIndex];
    final String url = image['url'];
    final String docId = image['id'];

    final confirm = await showDialog<bool>(
      context: context,
      builder:
          (context) => AlertDialog(
            backgroundColor: Colors.white,
            title: const Text(
              'ลบภาพนี้หรือไม่?',
              style: TextStyle(color: Colors.purple),
            ),
            content: const Text(
              'การลบจะไม่สามารถกู้คืนได้',
              style: TextStyle(color: Colors.black87),
            ),
            actions: [
              IconButton(
                icon: const Icon(Icons.close, color: Colors.grey),
                onPressed: () => Navigator.pop(context, false),
                tooltip: 'ยกเลิก',
              ),
              Container(
                decoration: BoxDecoration(
                  color: Colors.pinkAccent.shade100,
                  shape: BoxShape.circle,
                ),
                child: IconButton(
                  icon: Image.asset(
                    'assets/icons/delete.png',
                    width: 28,
                    height: 28,
                  ),
                  onPressed: () => Navigator.pop(context, true),
                  tooltip: 'ยืนยันลบ',
                ),
              ),
            ],
          ),
    );

    if (confirm != true) return;

    try {
      // ลบจาก Firebase Storage
      final ref = FirebaseStorage.instance.refFromURL(url);
      await ref.delete();

      // ลบจาก Firestore
      await FirebaseFirestore.instance
          .collection('patients')
          .doc(widget.patientId)
          .collection('medical_images')
          .doc(docId)
          .delete();

      // ลบจาก UI
      setState(() {
        widget.images.removeAt(currentIndex);
        if (currentIndex >= widget.images.length) {
          currentIndex = widget.images.length - 1;
        }
        _pageController.jumpToPage(currentIndex);
      });

      if (widget.images.isEmpty && mounted) {
        Navigator.pop(context); // กลับถ้าไม่มีภาพแล้ว
      }
    } catch (e) {
      print('❌ ลบภาพไม่สำเร็จ: $e');
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('เกิดข้อผิดพลาด: $e')));
    }
  }

  @override
  Widget build(BuildContext context) {
    if (widget.images.isEmpty) {
      return const Scaffold(body: Center(child: Text('ไม่มีภาพให้แสดง')));
    }

    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        iconTheme: const IconThemeData(color: Colors.white),
        actions: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: Container(
              decoration: BoxDecoration(
                color: Colors.pinkAccent.shade100,
                shape: BoxShape.circle,
              ),
              child: IconButton(
                icon: Image.asset(
                  'assets/icons/delete.png',
                  width: 28,
                  height: 28,
                ),
                onPressed: _deleteImage,
                tooltip: 'ลบภาพ',
              ),
            ),
          ),
        ],
      ),
      body: PageView.builder(
        controller: _pageController,
        itemCount: widget.images.length,
        onPageChanged: (index) {
          setState(() => currentIndex = index);
        },
        itemBuilder: (context, index) {
          final image = widget.images[index];
          return InteractiveViewer(
            child: Center(
              child: AspectRatio(
                aspectRatio: 3 / 4,
                child: Image.network(image['url'], fit: BoxFit.contain),
              ),
            ),
          );
        },
      ),
    );
  }
}
