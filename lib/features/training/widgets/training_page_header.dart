import 'package:flutter/material.dart';

class TrainingPageHeader extends StatelessWidget {
  const TrainingPageHeader({super.key});

  @override
  Widget build(BuildContext context) => const Padding(
    padding: EdgeInsets.fromLTRB(4, 8, 4, 2),
    child: Text(
      '训 练 记 录',
      style: TextStyle(
        color: Color(0xFF25292D),
        fontWeight: FontWeight.w200,
        letterSpacing: 4,
        fontSize: 18,
      ),
    ),
  );
}
