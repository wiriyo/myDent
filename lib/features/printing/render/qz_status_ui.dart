import '../services/qz_models.dart';

String qzStatusEmoji(QzStatusSnapshot status) {
  if (status.lastErrorCode == 'qz_security_error') {
    return '🔴';
  }
  switch (status.state) {
    case QzConnectionState.active:
      if (status.lastErrorCode == null || status.lastErrorCode!.isEmpty) {
        return '🟢';
      }
      return '🟡';
    case QzConnectionState.connecting:
      return '🟡';
    case QzConnectionState.inactive:
      return '🔴';
  }
}

String qzStatusMessage(QzStatusSnapshot status) {
  if (status.state == QzConnectionState.active &&
      (status.lastErrorCode == null || status.lastErrorCode!.isEmpty)) {
    return 'พร้อมพิมพ์ (เชื่อมสำเร็จ + ลายเซ็นผ่าน)';
  }
  if (status.lastErrorCode == 'qz_security_error') {
    return 'certificate หรือ signature ไม่ผ่าน กรุณาปรับการตั้งค่าและรีเฟรชหน้า';
  }
  if (status.state == QzConnectionState.connecting) {
    return 'กำลังเชื่อมต่อ / รอการอนุญาตจาก QZ Tray';
  }
  if (status.lastErrorMessage != null && status.lastErrorMessage!.isNotEmpty) {
    return _firstLine(status.lastErrorMessage!);
  }
  if (status.lastErrorCode != null && status.lastErrorCode!.isNotEmpty) {
    return 'พบข้อผิดพลาด: ${status.lastErrorCode}';
  }
  return 'ยังไม่เชื่อมกับ QZ Tray';
}

String _firstLine(String message) {
  final List<String> parts = message.split('\n');
  if (parts.isEmpty) {
    return message.trim();
  }
  return parts.first.trim().isEmpty ? message.trim() : parts.first.trim();
}
