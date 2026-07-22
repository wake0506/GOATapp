import 'package:flutter/material.dart';

class WeeklyReviewEntry extends StatelessWidget {
  const WeeklyReviewEntry({super.key, required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Material(
    color: Colors.white,
    borderRadius: BorderRadius.circular(16),
    child: InkWell(
      key: const Key('weekly-review-entry'),
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: const Padding(
        padding: EdgeInsets.symmetric(horizontal: 16, vertical: 13),
        child: Row(
          children: [
            Icon(Icons.insights_outlined, color: Color(0xFF008C8C), size: 20),
            SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '本周复盘',
                    style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
                  ),
                  SizedBox(height: 2),
                  Text(
                    '训练、营养与体重趋势',
                    style: TextStyle(color: Color(0xFF7D8583), fontSize: 11),
                  ),
                ],
              ),
            ),
            Icon(Icons.chevron_right, color: Color(0xFF8A9290), size: 20),
          ],
        ),
      ),
    ),
  );
}
