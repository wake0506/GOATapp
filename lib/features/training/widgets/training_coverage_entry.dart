import 'package:flutter/material.dart';

class TrainingCoverageEntry extends StatelessWidget {
  const TrainingCoverageEntry({super.key, required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Material(
    color: Colors.white,
    borderRadius: BorderRadius.circular(18),
    child: InkWell(
      key: const Key('training-coverage-entry'),
      borderRadius: BorderRadius.circular(18),
      onTap: onTap,
      child: const Padding(
        padding: EdgeInsets.symmetric(horizontal: 18, vertical: 15),
        child: Row(
          children: [
            Icon(Icons.accessibility_new, color: Color(0xFF008C8C), size: 22),
            SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('训练覆盖', style: TextStyle(fontWeight: FontWeight.w700)),
                  SizedBox(height: 2),
                  Text(
                    '查看本次与近 7 天肌群、动作模式分布',
                    style: TextStyle(color: Color(0xFF7D8583), fontSize: 11),
                  ),
                ],
              ),
            ),
            Icon(Icons.chevron_right, color: Color(0xFF8A9290)),
          ],
        ),
      ),
    ),
  );
}
