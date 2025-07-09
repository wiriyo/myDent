// ----------------------------------------------------------------
// 📁 lib/widgets/gap_card.dart
// v1.1.0 - ✨ Made layout adaptive to prevent overflows
// ----------------------------------------------------------------

import 'package:flutter/material.dart';

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

    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 2.0, horizontal: 1.0),
        child: CustomPaint(
          painter: _DashedBorderPainter(
            color: Colors.purple.shade200,
            strokeWidth: 1.5,
            radius: 12,
          ),
          child: Container(
            color: Colors.purple.shade50.withOpacity(0.4),
            // 💖 [OVERFLOW-FIX v1.1.0] ใช้ LayoutBuilder เพื่อเช็คความสูงที่มี
            // แล้วปรับการแสดงผลให้เหมาะสมค่ะ
            child: LayoutBuilder(
              builder: (context, constraints) {
                // ถ้าความสูงน้อยมาก (น้อยกว่า 35) ให้แสดงแค่ไอคอน
                if (constraints.maxHeight < 35) {
                  return Icon(
                    Icons.add,
                    color: Colors.purple.shade400.withOpacity(0.8),
                    size: 20,
                  );
                }
                // ถ้าความสูงพอประมาณ ให้แสดงไอคอนและข้อความหลัก
                return Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.add_circle_outline,
                        color: Colors.purple.shade400,
                        size: 22,
                      ),
                      // ถ้าความสูงมากพอ (มากกว่า 60) ถึงจะแสดงข้อความ "เพิ่มนัดหมาย"
                      if (constraints.maxHeight > 60) ...[
                        const SizedBox(height: 4),
                        Text(
                          'เพิ่มนัดหมาย',
                          style: TextStyle(
                            color: Colors.purple.shade700,
                            fontWeight: FontWeight.w600,
                            fontSize: 14,
                          ),
                        ),
                      ],
                      // ถ้าความสูงมากพอ (มากกว่า 80) และมีเวลามากกว่า 30 นาที ถึงจะแสดงระยะเวลา
                      if (constraints.maxHeight > 80 && durationInMinutes > 30)
                        Text(
                          '($durationInMinutes นาที)',
                          style: TextStyle(
                            color: Colors.purple.shade400,
                            fontSize: 11,
                          ),
                        ),
                    ],
                  ),
                );
              },
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
  final double dashWidth = 5.0;
  final double dashSpace = 5.0;

  _DashedBorderPainter({
    this.color = Colors.black,
    this.strokeWidth = 2.0,
    this.radius = 8.0,
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
