// 📁 lib/widgets/gap_card.dart

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

class GapCard extends StatelessWidget {
  final DateTime gapStart;
  final DateTime gapEnd;
  final VoidCallback onTap;

  const GapCard({
    super.key,
    required this.gapStart,
    required this.gapEnd,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final durationInMinutes = gapEnd.difference(gapStart).inMinutes;

    // ✨ [FIX] สร้างตัวแปรสำหรับเก็บข้อความแสดงเวลาค่ะ
    String durationText = '';
    if (durationInMinutes >= 60) {
      final double hours = durationInMinutes / 60.0;
      // แปลงเป็น ชม. และตัด .0 ที่ไม่จำเป็นออก เช่น 1.0 -> 1, 1.5 -> 1.5
      final formattedHours = hours.toStringAsFixed(1).replaceAll(RegExp(r'\.0$'), '');
      durationText = '($formattedHours ชม.)';
    } else if (durationInMinutes > 30) {
      durationText = '($durationInMinutes นาที)';
    }

    return InkWell(
      onTap: onTap,
      child: Padding(
        // ✨ เพิ่ม Padding ให้การ์ดมีระยะห่างที่สวยงามค่ะ
        padding: const EdgeInsets.symmetric(vertical: 2.0, horizontal: 1.0),
        child: CustomPaint(
          painter: _DashedBorderPainter(
            color: Colors.purple.shade200,
            strokeWidth: 1.5,
            radius: 12,
          ),
          child: Container(
            // ✨ ทำให้พื้นหลังโปร่งใสน่ารัก
            color: Colors.purple.shade50.withOpacity(0.4),
            child: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  // ✨ เปลี่ยนไอคอนเป็นเครื่องหมายบวกที่ดูน่ากดค่ะ
                  Icon(
                    Icons.add_circle_outline,
                    color: Colors.purple.shade400,
                    size: 22,
                  ),
                  const SizedBox(height: 4),
                  // ✨ เปลี่ยนข้อความเป็น "เพิ่มนัดหมาย"
                  Text(
                    'เพิ่มนัดหมาย',
                    style: TextStyle(
                      color: Colors.purple.shade700,
                      fontWeight: FontWeight.w600,
                      fontSize: 14,
                    ),
                  ),
                  // ✨ [FIX] แสดงผลตามเงื่อนไขใหม่ที่เราสร้างขึ้นค่ะ
                  if (durationText.isNotEmpty)
                    Text(
                      durationText,
                      style: TextStyle(
                        color: Colors.purple.shade400,
                        fontSize: 11,
                      ),
                    ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// --- 🎨 ผู้ช่วยตัวน้อยสำหรับวาดเส้นประค่ะ by ไลลา ---
class _DashedBorderPainter extends CustomPainter {
  final Color color;
  final double strokeWidth;
  final double radius;
  final double dashWidth;
  final double dashSpace;

  _DashedBorderPainter({
    this.color = Colors.black,
    this.strokeWidth = 2.0,
    this.radius = 8.0,
    this.dashWidth = 5.0,
    this.dashSpace = 5.0,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = strokeWidth
      ..style = PaintingStyle.stroke;

    final path = Path();
    final rrect = RRect.fromRectAndRadius(
      Rect.fromLTWH(0, 0, size.width, size.height),
      Radius.circular(radius),
    );

    // วาดเส้นประตามแนวของ RRect
    final borderPath = Path()..addRRect(rrect);
    for (final metric in borderPath.computeMetrics()) {
      double distance = 0.0;
      while (distance < metric.length) {
        path.addPath(
          metric.extractPath(distance, distance + dashWidth),
          Offset.zero,
        );
        distance += dashWidth + dashSpace;
      }
    }
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(CustomPainter oldDelegate) => false;
}
