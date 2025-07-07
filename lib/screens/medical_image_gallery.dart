// lib/screens/medical_image_gallery.dart

import 'package:flutter/material.dart';

class MedicalImageGallery extends StatelessWidget {
  final Stream<List<Map<String, dynamic>>>? imageStream;
  final Function({
    required BuildContext context,
    required List<Map<String, dynamic>> images,
    required int startIndex,
    required String patientId,
  }) onImageTap;
  final String patientId;

  const MedicalImageGallery({
    super.key,
    required this.imageStream,
    required this.onImageTap,
    required this.patientId,
  });

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<Map<String, dynamic>>>(
      stream: imageStream,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Padding(
            padding: EdgeInsets.all(16.0),
            child: Center(child: CircularProgressIndicator()),
          );
        }

        if (!snapshot.hasData || snapshot.data!.isEmpty) {
          return const Padding(
            padding: EdgeInsets.all(16.0),
            child: Text('ยังไม่มีภาพทางการแพทย์'),
          );
        }

        final images = snapshot.data!;
        return SizedBox(
          height: 160,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 12),
            itemCount: images.length,
            itemBuilder: (context, index) {
              final image = images[index];
              return GestureDetector(
                onTap: () {
                  onImageTap(
                    context: context,
                    images: images,
                    startIndex: index,
                    patientId: patientId,
                  );
                },
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(16),
                    child: AspectRatio(
                      aspectRatio: 3 / 4,
                      child: Image.network(
                        image['url'] ?? '',
                        fit: BoxFit.cover,
                        loadingBuilder: (context, child, loadingProgress) {
                          if (loadingProgress == null) return child;
                          return Container(
                            color: Colors.purple.shade50,
                            child: const Center(
                              child: CircularProgressIndicator(),
                            ),
                          );
                        },
                        errorBuilder: (context, error, stackTrace) {
                          return Container(
                            color: Colors.grey.shade200,
                            child: const Icon(Icons.broken_image, size: 40),
                          );
                        },
                      ),
                    ),
                  ),
                ),
              );
            },
          ),
        );
      },
    );
  }
}
