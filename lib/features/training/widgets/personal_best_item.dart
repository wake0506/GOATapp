import 'package:flutter/material.dart';

import '../models/training_page_view_model.dart';

class PersonalBestItem extends StatelessWidget {
  const PersonalBestItem({super.key, required this.personalBest});

  final PersonalBest personalBest;

  @override
  Widget build(BuildContext context) {
    final hasRecord = personalBest.weight != null;
    return Expanded(
      child: Column(
        children: [
          const Icon(
            Icons.fitness_center_outlined,
            size: 24,
            color: Color(0xFF7E8888),
          ),
          const SizedBox(height: 8),
          Text(
            personalBest.label,
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: Color(0xFF3A4442),
              fontSize: 13,
              fontWeight: FontWeight.w500,
            ),
          ),
          Text(
            personalBest.englishLabel,
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: Color(0xFF9AA1A3),
              fontSize: 11,
              fontWeight: FontWeight.w400,
            ),
          ),
          const SizedBox(height: 9),
          FittedBox(
            fit: BoxFit.scaleDown,
            child: Text.rich(
              TextSpan(
                text: hasRecord ? _formatWeight(personalBest.weight!) : '--',
                style: const TextStyle(
                  color: Color(0xFF008C8C),
                  fontSize: 28,
                  fontWeight: FontWeight.w700,
                ),
                children: hasRecord
                    ? const [
                        TextSpan(
                          text: ' kg',
                          style: TextStyle(
                            color: Color(0xFF4E8585),
                            fontSize: 13,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ]
                    : const [],
              ),
            ),
          ),
          const SizedBox(height: 5),
          Text(
            hasRecord ? personalBest.date ?? '--' : '暂无记录',
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: Color(0xFF818A8B),
              fontSize: 12,
              fontWeight: FontWeight.w400,
            ),
          ),
        ],
      ),
    );
  }

  String _formatWeight(double value) {
    return value == value.roundToDouble()
        ? value.toInt().toString()
        : value.toStringAsFixed(1);
  }
}
