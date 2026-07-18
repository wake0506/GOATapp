import 'package:flutter/material.dart';

import '../../../exercise_catalog.dart';
import '../services/exercise_replacement_service.dart';

class ExerciseReplacementSheet extends StatelessWidget {
  const ExerciseReplacementSheet({
    super.key,
    required this.original,
    required this.candidates,
  });

  final ExerciseDefinition original;
  final List<ExerciseReplacementCandidate> candidates;

  static Future<ExerciseDefinition?> show(
    BuildContext context, {
    required ExerciseDefinition original,
    required List<ExerciseReplacementCandidate> candidates,
  }) => showModalBottomSheet<ExerciseDefinition>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.white,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
    ),
    builder: (_) =>
        ExerciseReplacementSheet(original: original, candidates: candidates),
  );

  @override
  Widget build(BuildContext context) => SafeArea(
    child: SizedBox(
      height: MediaQuery.of(context).size.height * 0.72,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 22, 20, 14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  '替换动作',
                  style: TextStyle(fontSize: 22, fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 6),
                Text(
                  '当前 · ${original.name}',
                  style: const TextStyle(color: Color(0xFF7D8583)),
                ),
              ],
            ),
          ),
          const Divider(height: 1),
          Expanded(
            child: candidates.isEmpty
                ? const Center(
                    child: Text(
                      '暂无可靠替代动作',
                      style: TextStyle(color: Color(0xFF8A9290)),
                    ),
                  )
                : ListView.separated(
                    padding: const EdgeInsets.all(16),
                    itemCount: candidates.length,
                    separatorBuilder: (_, _) => const SizedBox(height: 10),
                    itemBuilder: (_, index) {
                      final candidate = candidates[index];
                      return Material(
                        color: const Color(0xFFF8F9F9),
                        borderRadius: BorderRadius.circular(16),
                        child: ListTile(
                          key: Key('replacement-${candidate.exercise.id}'),
                          onTap: () =>
                              Navigator.pop(context, candidate.exercise),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                          ),
                          title: Text(
                            candidate.exercise.name,
                            style: const TextStyle(fontWeight: FontWeight.w600),
                          ),
                          subtitle: Text(
                            candidate.isLowConfidence
                                ? '同部位 · 低置信度候选'
                                : candidate.exercise.movementPattern ==
                                      original.movementPattern
                                ? '相同主肌群 · 相同动作模式'
                                : '相同主肌群',
                          ),
                          trailing: const Icon(
                            Icons.chevron_right,
                            color: Color(0xFF008C8C),
                          ),
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    ),
  );
}
