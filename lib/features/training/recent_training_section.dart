import 'package:flutter/material.dart';

import '../../models/training.dart';

class RecentTrainingSection extends StatelessWidget {
  final List<TrainingSession> sessions;
  final ValueChanged<TrainingSession> onOpenSession;

  const RecentTrainingSection({
    super.key,
    required this.sessions,
    required this.onOpenSession,
  });

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      const Text(
        '最近训练',
        style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
      ),
      const SizedBox(height: 10),
      if (sessions.isEmpty)
        const _RecentEmpty()
      else
        ...sessions.map(
          (session) => Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: _RecentSessionCard(
              session: session,
              onTap: () => onOpenSession(session),
            ),
          ),
        ),
    ],
  );
}

class _RecentEmpty extends StatelessWidget {
  const _RecentEmpty();

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(16),
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(12),
    ),
    child: const Text(
      '暂无训练记录，先从上方分类或模板开始',
      style: TextStyle(color: Color(0xFF70757A), fontSize: 13),
    ),
  );
}

class _RecentSessionCard extends StatelessWidget {
  final TrainingSession session;
  final VoidCallback onTap;

  const _RecentSessionCard({required this.session, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final bodyParts = session.exercises
        .map((exercise) => exercise.bodyPart)
        .where((part) => part.isNotEmpty)
        .toSet()
        .join('、');
    final setCount = session.exercises.fold<int>(
      0,
      (sum, exercise) => sum + exercise.sets.length,
    );
    return Semantics(
      button: true,
      label: '查看训练 ${session.name}',
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Ink(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Row(
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: const Color(0x14008C8C),
                  borderRadius: BorderRadius.circular(9),
                ),
                child: const Icon(
                  Icons.fitness_center_rounded,
                  size: 19,
                  color: Color(0xFF008C8C),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      session.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontWeight: FontWeight.w700),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      '${session.date}  ${bodyParts.isEmpty ? '训练记录' : bodyParts}  $setCount 组',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: Color(0xFF70757A),
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
              const Icon(Icons.chevron_right_rounded, color: Color(0xFF9AA0A6)),
            ],
          ),
        ),
      ),
    );
  }
}
