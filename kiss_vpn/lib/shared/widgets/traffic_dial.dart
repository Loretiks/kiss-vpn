import 'package:flutter/material.dart';

import '../theme/app_theme.dart';
import '../utils/format.dart';

class TrafficDial extends StatelessWidget {
  const TrafficDial({
    super.key,
    required this.label,
    required this.icon,
    required this.bytesPerSecond,
    required this.totalBytes,
    required this.color,
  });

  final String label;
  final IconData icon;
  final int bytesPerSecond;
  final int totalBytes;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, size: 18, color: color),
                const SizedBox(width: 8),
                Text(
                  label,
                  style: const TextStyle(
                    color: AppColors.textMid,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Text(
              '${Format.bytes(bytesPerSecond)}/s',
              style: const TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              'Total: ${Format.bytes(totalBytes)}',
              style: const TextStyle(color: AppColors.textLow, fontSize: 12),
            ),
          ],
        ),
      ),
    );
  }
}
