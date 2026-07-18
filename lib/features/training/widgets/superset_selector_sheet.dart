import 'package:flutter/material.dart';

import '../../../exercise_catalog.dart';
import '../../../models/training.dart';

class SupersetSelection {
  const SupersetSelection.existing(this.exerciseId) : selectOther = false;
  const SupersetSelection.other() : exerciseId = null, selectOther = true;

  final String? exerciseId;
  final bool selectOther;
}

class SupersetSelectorSheet {
  const SupersetSelectorSheet._();

  static Future<SupersetSelection?> show(
    BuildContext context, {
    required List<TrainingExercise> candidates,
  }) => showModalBottomSheet<SupersetSelection>(
    context: context,
    backgroundColor: Colors.white,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
    ),
    builder: (context) => SafeArea(
      child: ListView(
        shrinkWrap: true,
        padding: const EdgeInsets.fromLTRB(16, 14, 16, 18),
        children: [
          const Padding(
            padding: EdgeInsets.fromLTRB(8, 4, 8, 8),
            child: Text(
              '选择搭配动作',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700),
            ),
          ),
          for (final exercise in candidates)
            ListTile(
              title: Text(exercise.exerciseName),
              subtitle: Text(exercise.bodyPart),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => Navigator.pop(
                context,
                SupersetSelection.existing(exercise.exerciseId),
              ),
            ),
          const Divider(height: 1),
          ListTile(
            title: const Text('选择其他动作'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () =>
                Navigator.pop(context, const SupersetSelection.other()),
          ),
        ],
      ),
    ),
  );

  static Future<ExerciseDefinition?> showCatalog(
    BuildContext context, {
    required List<ExerciseDefinition> catalog,
    required Set<String> excludedIds,
  }) => showModalBottomSheet<ExerciseDefinition>(
    context: context,
    backgroundColor: Colors.white,
    isScrollControlled: true,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
    ),
    builder: (context) => FractionallySizedBox(
      heightFactor: 0.78,
      child: SafeArea(
        child: Column(
          children: [
            const Padding(
              padding: EdgeInsets.fromLTRB(24, 20, 24, 10),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  '选择其他动作',
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700),
                ),
              ),
            ),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 18),
                children: [
                  for (final exercise in catalog)
                    if (!excludedIds.contains(exercise.id))
                      ListTile(
                        title: Text(exercise.name),
                        subtitle: Text(
                          '${exercise.bodyPart} · ${exercise.equipment}',
                        ),
                        onTap: () => Navigator.pop(context, exercise),
                      ),
                ],
              ),
            ),
          ],
        ),
      ),
    ),
  );
}
