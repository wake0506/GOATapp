import 'package:flutter/material.dart';

class TrainingEmptyHint extends StatelessWidget {
  const TrainingEmptyHint({super.key, required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: const TextStyle(
        color: Color(0xFF91999B),
        fontSize: 13,
        fontWeight: FontWeight.w400,
      ),
    );
  }
}
