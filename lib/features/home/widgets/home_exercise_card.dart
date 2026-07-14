import 'package:flutter/material.dart';

class HomeExerciseCard extends StatelessWidget {
  const HomeExerciseCard({
    super.key,
    required this.totalBurn,
    required this.hasExercise,
    required this.onOpenTraining,
    required this.onAddExercise,
  });

  final double totalBurn;
  final bool hasExercise;
  final VoidCallback onOpenTraining;
  final VoidCallback onAddExercise;

  @override
  Widget build(BuildContext context) => Container(
    key: const Key('home-exercise-card'),
    padding: const EdgeInsets.fromLTRB(17, 15, 12, 15),
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(20),
      boxShadow: const [
        BoxShadow(
          color: Color(0x0D17211E),
          blurRadius: 14,
          offset: Offset(0, 5),
        ),
      ],
    ),
    child: Row(
      children: [
        const Icon(
          Icons.local_fire_department_outlined,
          color: Color(0xFFE77A68),
          size: 25,
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                '运动消耗',
                style: TextStyle(
                  color: Color(0xFF26302E),
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 2),
              Text.rich(
                TextSpan(
                  text: '-${totalBurn.toInt()}',
                  style: const TextStyle(
                    color: Color(0xFFE46F60),
                    fontSize: 25,
                    fontWeight: FontWeight.w700,
                  ),
                  children: const [
                    TextSpan(
                      text: ' kcal',
                      style: TextStyle(
                        color: Color(0xFFD5897E),
                        fontSize: 11,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
              if (!hasExercise)
                const Text(
                  '暂无训练记录',
                  style: TextStyle(color: Color(0xFF899291), fontSize: 10),
                ),
            ],
          ),
        ),
        TextButton.icon(
          onPressed: onOpenTraining,
          icon: const Icon(Icons.chevron_right_rounded, size: 17),
          label: const Text('同步自训练看板'),
          style: TextButton.styleFrom(
            foregroundColor: const Color(0xFF397C70),
            visualDensity: VisualDensity.compact,
            textStyle: const TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
        IconButton(
          tooltip: '记录运动',
          onPressed: onAddExercise,
          icon: const Icon(Icons.add),
          color: const Color(0xFF008C8C),
          style: IconButton.styleFrom(
            side: const BorderSide(color: Color(0xFF83AAA4)),
            minimumSize: const Size(34, 34),
          ),
        ),
      ],
    ),
  );
}
