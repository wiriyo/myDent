import 'dart:typed_data';

import 'package:image_picker/image_picker.dart';

class UploadImagePayload {
  final Uint8List bytes;
  final String? fileName;
  final String? contentType;

  const UploadImagePayload({
    required this.bytes,
    this.fileName,
    this.contentType,
  });

  UploadImagePayload copyWith({
    Uint8List? bytes,
    String? fileName,
    String? contentType,
  }) {
    return UploadImagePayload(
      bytes: bytes ?? this.bytes,
      fileName: fileName ?? this.fileName,
      contentType: contentType ?? this.contentType,
    );
  }

  static Future<UploadImagePayload?> fromXFile(XFile? file) async {
    if (file == null) return null;
    final bytes = await file.readAsBytes();
    String? mimeType;
    try {
      mimeType = file.mimeType;
    } catch (_) {
      mimeType = null;
    }
    return UploadImagePayload(
      bytes: bytes,
      fileName: file.name,
      contentType: mimeType,
    );
  }
}
