import 'package:flutter/material.dart';

import '../domain/active_training_session.dart';

class ActiveTrainingSessionCard extends StatelessWidget {
  const ActiveTrainingSessionCard({
    super.key,
    required this.session,
    required this.onTap,
  });

  final ActiveTrainingSession session;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final activeExercise = session.draft.exercises
        .where((exercise) => exercise.exerciseId == session.currentExerciseId)
        .firstOrNull;
    final completed = session.draft.exercises.fold<int>(
      0,
      (total, exercise) =>
          total + exercise.sets.where((set) => set.completedAt != null).length,
    );
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(20),
      child: InkWell(
        key: const Key('training-resume-card'),
        onTap: onTap,
        borderRadius: BorderRadius.circular(20),
        child: Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: const Color(0x22008C8C)),
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
              Container(
                width: 42,
                height: 42,
                decoration: const BoxDecoration(
                  color: Color(0x19008C8C),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.play_arrow_rounded,
                  color: Color(0xFF008C8C),
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      '进行中的训练',
                      style: TextStyle(
                        color: Color(0xFF008C8C),
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 5),
                    Text(
                      activeExercise?.exerciseName ?? session.draft.name,
                      style: const TextStyle(
                        color: Color(0xFF1F2725),
                        fontSize: 17,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      '已完成 $completed 组',
                      style: const TextStyle(
                        color: Color(0xFF8A9290),
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
              const Text(
                '继续训练',
                style: TextStyle(
                  color: Color(0xFF008C8C),
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(width: 3),
              const Icon(Icons.chevron_right, color: Color(0xFF008C8C)),
            ],
          ),
        ),
      ),
    );
  }
}

extension _FirstOrNull<T> on Iterable<T> {
  T? get firstOrNull {
    final iterator = this.iterator;
    return iterator.moveNext() ? iterator.current : null;
  }
}
