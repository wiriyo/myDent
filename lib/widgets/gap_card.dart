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
    final timeFormat = DateFormat.Hm();
    final startFormatted = timeFormat.format(gapStart);
    final endFormatted = timeFormat.format(gapEnd);

    return InkWell(
      onTap: onTap,
      child: Card(
        color: Colors.grey.shade100,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
        margin: const EdgeInsets.symmetric(
          vertical: 8.0,
          horizontal: 4.0,
        ),
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Row(
            children: [
              Icon(
                Icons.hourglass_empty,
                color: Colors.grey.shade600,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  'ว่าง: $startFormatted - $endFormatted',
                  style: TextStyle(
                    color: Colors.grey.shade700,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}