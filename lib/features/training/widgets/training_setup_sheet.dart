import 'package:flutter/material.dart';

import '../../../exercise_catalog.dart';

class TrainingSetupSelection {
  const TrainingSetupSelection({
    required this.bodyPart,
    required this.exercises,
  });

  final String bodyPart;
  final List<ExerciseDefinition> exercises;

  String get sessionName => bodyPart == '全身/体能' ? '全身训练' : '$bodyPart训练';
}

class TrainingSetupSheet extends StatefulWidget {
  const TrainingSetupSheet({super.key, required this.catalog});

  final List<ExerciseDefinition> catalog;

  static Future<TrainingSetupSelection?> show(
    BuildContext context, {
    required List<ExerciseDefinition> catalog,
  }) => showModalBottomSheet<TrainingSetupSelection>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.white,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
    ),
    builder: (_) => TrainingSetupSheet(catalog: catalog),
  );

  @override
  State<TrainingSetupSheet> createState() => _TrainingSetupSheetState();
}

class _TrainingSetupSheetState extends State<TrainingSetupSheet> {
  String? _bodyPart;
  final List<String> _selectedExerciseIds = [];

  List<ExerciseDefinition> get _visibleExercises {
    final bodyPart = _bodyPart;
    if (bodyPart == null) return const [];
    return widget.catalog
        .where((exercise) => exercise.bodyPart == bodyPart)
        .toList(growable: false);
  }

  @override
  Widget build(BuildContext context) {
    final visibleExercises = _visibleExercises;
    return FractionallySizedBox(
      heightFactor: 0.9,
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 18, 20, 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text(
                '开始一次新训练',
                style: TextStyle(fontSize: 22, fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 4),
              const Text(
                '先选择本次训练部位，再选择要练的动作',
                style: TextStyle(color: Color(0xFF737B79), fontSize: 13),
              ),
              const SizedBox(height: 16),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (final bodyPart in exerciseBodyParts)
                    ChoiceChip(
                      key: Key('training-body-part-$bodyPart'),
                      label: Text(bodyPart),
                      selected: _bodyPart == bodyPart,
                      selectedColor: const Color(0xFFDDEEEE),
                      checkmarkColor: const Color(0xFF008C8C),
                      labelStyle: TextStyle(
                        color: _bodyPart == bodyPart
                            ? const Color(0xFF006F6F)
                            : const Color(0xFF606866),
                        fontWeight: _bodyPart == bodyPart
                            ? FontWeight.w700
                            : FontWeight.w500,
                      ),
                      side: BorderSide(
                        color: _bodyPart == bodyPart
                            ? const Color(0xFF008C8C)
                            : const Color(0xFFD9DEDC),
                      ),
                      onSelected: (_) => setState(() {
                        _bodyPart = bodyPart;
                        _selectedExerciseIds.clear();
                      }),
                    ),
                ],
              ),
              const SizedBox(height: 14),
              Row(
                children: [
                  Text(
                    _bodyPart == null ? '选择训练部位' : '选择动作',
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const Spacer(),
                  if (_selectedExerciseIds.isNotEmpty)
                    Text(
                      '已选 ${_selectedExerciseIds.length} 个',
                      style: const TextStyle(
                        color: Color(0xFF008C8C),
                        fontSize: 13,
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 6),
              Expanded(
                child: _bodyPart == null
                    ? const Center(
                        child: Text(
                          '选择一个部位后显示对应动作',
                          style: TextStyle(color: Color(0xFF8A9290)),
                        ),
                      )
                    : ListView.separated(
                        itemCount: visibleExercises.length,
                        separatorBuilder: (_, _) => const Divider(height: 1),
                        itemBuilder: (context, index) {
                          final exercise = visibleExercises[index];
                          final selected = _selectedExerciseIds.contains(
                            exercise.id,
                          );
                          return CheckboxListTile(
                            key: Key('training-exercise-${exercise.id}'),
                            value: selected,
                            activeColor: const Color(0xFF008C8C),
                            contentPadding: EdgeInsets.zero,
                            controlAffinity: ListTileControlAffinity.trailing,
                            title: Text(
                              exercise.name,
                              style: const TextStyle(
                                color: Color(0xFF242C2A),
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            subtitle: Text(exercise.equipment),
                            onChanged: (checked) => setState(() {
                              if (checked == true) {
                                _selectedExerciseIds.add(exercise.id);
                              } else {
                                _selectedExerciseIds.remove(exercise.id);
                              }
                            }),
                          );
                        },
                      ),
              ),
              const SizedBox(height: 12),
              FilledButton(
                key: const Key('training-setup-start'),
                onPressed: _selectedExerciseIds.isEmpty
                    ? null
                    : () {
                        final bodyPart = _bodyPart!;
                        final byId = {
                          for (final exercise in widget.catalog)
                            exercise.id: exercise,
                        };
                        final selected = _selectedExerciseIds
                            .map((id) => byId[id])
                            .whereType<ExerciseDefinition>()
                            .toList(growable: false);
                        Navigator.pop(
                          context,
                          TrainingSetupSelection(
                            bodyPart: bodyPart,
                            exercises: selected,
                          ),
                        );
                      },
                style: FilledButton.styleFrom(
                  backgroundColor: const Color(0xFF008C8C),
                  minimumSize: const Size.fromHeight(54),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                ),
                child: Text(
                  _selectedExerciseIds.isEmpty
                      ? '请选择训练动作'
                      : '开始训练 · ${_selectedExerciseIds.length} 个动作',
                  style: const TextStyle(fontWeight: FontWeight.w700),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
