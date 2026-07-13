import 'package:flutter/material.dart';

import '../models/training_page_view_model.dart';
import 'personal_best_item.dart';

class PersonalBestCard extends StatelessWidget {
  const PersonalBestCard({super.key, required this.personalBests});

  final List<PersonalBest> personalBests;

  @override
  Widget build(BuildContext context) {
    return Container(
      key: const Key('personal-best-card'),
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.all(Radius.circular(20)),
        boxShadow: [
          BoxShadow(
            color: Color(0x0D17211E),
            blurRadius: 14,
            offset: Offset(0, 5),
          ),
        ],
      ),
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Personal Bests / 核心 PR',
            style: TextStyle(
              color: Color(0xFF1F2725),
              fontSize: 19,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 22),
          IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                PersonalBestItem(personalBest: personalBests[0]),
                const VerticalDivider(
                  width: 1,
                  thickness: 1,
                  color: Color(0xFFE6E9E9),
                ),
                PersonalBestItem(personalBest: personalBests[1]),
                const VerticalDivider(
                  width: 1,
                  thickness: 1,
                  color: Color(0xFFE6E9E9),
                ),
                PersonalBestItem(personalBest: personalBests[2]),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
