import 'package:flutter/material.dart';

class TrainingPageHeader extends StatelessWidget {
  const TrainingPageHeader({super.key});

  @override
  Widget build(BuildContext context) => const Padding(
    padding: EdgeInsets.fromLTRB(4, 8, 4, 2),
    child: Row(
      children: [
        Icon(Icons.fitness_center_outlined, size: 23, color: Color(0xFF004D3A)),
        SizedBox(width: 11),
        Text(
          '训 练 记 录',
          style: TextStyle(
            color: Color(0xFF25292D),
            fontSize: 20,
            fontWeight: FontWeight.w600,
            letterSpacing: 2.2,
          ),
        ),
      ],
    ),
  );
}
