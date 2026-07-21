import 'package:flutter/material.dart';

import '../../../exercise_catalog.dart';
import '../models/training_template.dart';
import '../services/training_template_store.dart';

const _marsGreen = Color(0xFF008C8C);

class TrainingTemplateManagerSheet extends StatefulWidget {
  const TrainingTemplateManagerSheet({
    super.key,
    required this.catalog,
    required this.store,
  });

  final List<ExerciseDefinition> catalog;
  final TrainingTemplateStore store;

  static Future<TrainingTemplate?> show(
    BuildContext context, {
    required List<ExerciseDefinition> catalog,
    required TrainingTemplateStore store,
  }) {
    return showModalBottomSheet<TrainingTemplate>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (_) =>
          TrainingTemplateManagerSheet(catalog: catalog, store: store),
    );
  }

  @override
  State<TrainingTemplateManagerSheet> createState() =>
      _TrainingTemplateManagerSheetState();
}

class _TrainingTemplateManagerSheetState
    extends State<TrainingTemplateManagerSheet> {
  late List<TrainingTemplate> _templates;

  @override
  void initState() {
    super.initState();
    _templates = widget.store.load();
  }

  Future<void> _edit([TrainingTemplate? existing]) async {
    final template = await TrainingTemplateEditorSheet.show(
      context,
      catalog: widget.catalog,
      existing: existing,
    );
    if (template == null || !mounted) return;
    await widget.store.save(template);
    if (!mounted) return;
    setState(() => _templates = widget.store.load());
  }

  Future<void> _delete(TrainingTemplate template) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('删除训练方案？'),
        content: Text('“${template.name}”删除后无法恢复。'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('取消'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('删除'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    await widget.store.delete(template.id);
    if (!mounted) return;
    setState(() => _templates = widget.store.load());
  }

  @override
  Widget build(BuildContext context) {
    return FractionallySizedBox(
      heightFactor: 0.92,
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 18, 20, 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  const Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '训练方案',
                          style: TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        SizedBox(height: 3),
                        Text(
                          '创建常用动作组合，下次可以直接开始',
                          style: TextStyle(
                            color: Color(0xFF737B79),
                            fontSize: 13,
                          ),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    key: const Key('training-template-create'),
                    tooltip: '创建训练方案',
                    onPressed: _edit,
                    style: IconButton.styleFrom(
                      backgroundColor: const Color(0xFFDDEEEE),
                      foregroundColor: _marsGreen,
                    ),
                    icon: const Icon(Icons.add_rounded),
                  ),
                ],
              ),
              const SizedBox(height: 18),
              Expanded(
                child: _templates.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(
                              Icons.view_list_outlined,
                              color: Color(0xFF9AA2A0),
                              size: 40,
                            ),
                            const SizedBox(height: 10),
                            const Text(
                              '还没有自定义训练方案',
                              style: TextStyle(
                                color: Color(0xFF737B79),
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            const SizedBox(height: 12),
                            OutlinedButton.icon(
                              onPressed: _edit,
                              icon: const Icon(Icons.add_rounded),
                              label: const Text('创建第一个方案'),
                            ),
                          ],
                        ),
                      )
                    : ListView.separated(
                        itemCount: _templates.length,
                        separatorBuilder: (_, _) => const SizedBox(height: 10),
                        itemBuilder: (context, index) {
                          final template = _templates[index];
                          final exercises = template.resolveExercises(
                            widget.catalog,
                          );
                          return Container(
                            key: Key('training-template-${template.id}'),
                            padding: const EdgeInsets.fromLTRB(16, 14, 8, 14),
                            decoration: BoxDecoration(
                              color: const Color(0xFFF7F8F8),
                              borderRadius: BorderRadius.circular(16),
                            ),
                            child: Row(
                              children: [
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        template.name,
                                        style: const TextStyle(
                                          fontWeight: FontWeight.w700,
                                          fontSize: 16,
                                        ),
                                      ),
                                      const SizedBox(height: 4),
                                      Text(
                                        exercises
                                            .map((exercise) => exercise.name)
                                            .join(' · '),
                                        maxLines: 2,
                                        overflow: TextOverflow.ellipsis,
                                        style: const TextStyle(
                                          color: Color(0xFF737B79),
                                          fontSize: 12,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                IconButton(
                                  key: Key(
                                    'training-template-start-${template.id}',
                                  ),
                                  tooltip: '开始训练',
                                  onPressed: exercises.isEmpty
                                      ? null
                                      : () => Navigator.pop(context, template),
                                  icon: const Icon(Icons.play_arrow_rounded),
                                  color: _marsGreen,
                                ),
                                PopupMenuButton<String>(
                                  key: Key(
                                    'training-template-menu-${template.id}',
                                  ),
                                  onSelected: (action) {
                                    if (action == 'edit') {
                                      _edit(template);
                                    } else if (action == 'delete') {
                                      _delete(template);
                                    }
                                  },
                                  itemBuilder: (_) => const [
                                    PopupMenuItem(
                                      value: 'edit',
                                      child: Text('编辑'),
                                    ),
                                    PopupMenuItem(
                                      value: 'delete',
                                      child: Text('删除'),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          );
                        },
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class TrainingTemplateEditorSheet extends StatefulWidget {
  const TrainingTemplateEditorSheet({
    super.key,
    required this.catalog,
    this.existing,
  });

  final List<ExerciseDefinition> catalog;
  final TrainingTemplate? existing;

  static Future<TrainingTemplate?> show(
    BuildContext context, {
    required List<ExerciseDefinition> catalog,
    TrainingTemplate? existing,
  }) {
    return showModalBottomSheet<TrainingTemplate>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (_) =>
          TrainingTemplateEditorSheet(catalog: catalog, existing: existing),
    );
  }

  @override
  State<TrainingTemplateEditorSheet> createState() =>
      _TrainingTemplateEditorSheetState();
}

class _TrainingTemplateEditorSheetState
    extends State<TrainingTemplateEditorSheet> {
  late final TextEditingController _nameController;
  late String _bodyPart;
  late final List<String> _selectedExerciseIds;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.existing?.name ?? '');
    final catalogIds = widget.catalog.map((exercise) => exercise.id).toSet();
    _selectedExerciseIds = (widget.existing?.exerciseIds ?? const <String>[])
        .where(catalogIds.contains)
        .toSet()
        .toList(growable: true);
    _bodyPart = _initialBodyPart();
  }

  String _initialBodyPart() {
    final ids = widget.existing?.exerciseIds ?? const <String>[];
    final firstId = ids.isEmpty ? null : ids.first;
    if (firstId != null) {
      for (final exercise in widget.catalog) {
        if (exercise.id == firstId) return exercise.bodyPart;
      }
    }
    return exerciseBodyParts.first;
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final visibleExercises = widget.catalog
        .where((exercise) => exercise.bodyPart == _bodyPart)
        .toList(growable: false);
    final canSave =
        _nameController.text.trim().isNotEmpty &&
        _selectedExerciseIds.isNotEmpty;
    return FractionallySizedBox(
      heightFactor: 0.92,
      child: SafeArea(
        child: Padding(
          padding: EdgeInsets.fromLTRB(
            20,
            18,
            20,
            16 + MediaQuery.viewInsetsOf(context).bottom,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                widget.existing == null ? '创建训练方案' : '编辑训练方案',
                style: const TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 14),
              TextField(
                key: const Key('training-template-name'),
                controller: _nameController,
                onChanged: (_) => setState(() {}),
                decoration: InputDecoration(
                  hintText: '例如：背部力量日',
                  filled: true,
                  fillColor: const Color(0xFFF4F5F7),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                    borderSide: BorderSide.none,
                  ),
                ),
              ),
              const SizedBox(height: 14),
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: [
                    for (final bodyPart in exerciseBodyParts)
                      Padding(
                        padding: const EdgeInsets.only(right: 8),
                        child: ChoiceChip(
                          key: Key('template-body-part-$bodyPart'),
                          label: Text(bodyPart),
                          selected: _bodyPart == bodyPart,
                          selectedColor: const Color(0xFFDDEEEE),
                          onSelected: (_) =>
                              setState(() => _bodyPart = bodyPart),
                        ),
                      ),
                  ],
                ),
              ),
              const SizedBox(height: 10),
              Text(
                '已选 ${_selectedExerciseIds.length} 个动作（按选择顺序）',
                style: const TextStyle(
                  color: _marsGreen,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 4),
              Expanded(
                child: ListView.separated(
                  itemCount: visibleExercises.length,
                  separatorBuilder: (_, _) => const Divider(height: 1),
                  itemBuilder: (context, index) {
                    final exercise = visibleExercises[index];
                    final selected = _selectedExerciseIds.contains(exercise.id);
                    final selectedIndex = _selectedExerciseIds.indexOf(
                      exercise.id,
                    );
                    return CheckboxListTile(
                      key: Key('template-exercise-${exercise.id}'),
                      value: selected,
                      activeColor: _marsGreen,
                      contentPadding: EdgeInsets.zero,
                      title: Text(
                        selected
                            ? '${selectedIndex + 1}. ${exercise.name}'
                            : exercise.name,
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
                key: const Key('training-template-save'),
                onPressed: canSave
                    ? () {
                        Navigator.pop(
                          context,
                          TrainingTemplate(
                            id:
                                widget.existing?.id ??
                                DateTime.now().millisecondsSinceEpoch
                                    .toString(),
                            name: _nameController.text.trim(),
                            exerciseIds: List.unmodifiable(
                              _selectedExerciseIds,
                            ),
                            progressionTargets: Map.unmodifiable({
                              for (final exerciseId in _selectedExerciseIds)
                                if (widget.existing?.targetFor(exerciseId) !=
                                    null)
                                  exerciseId: widget.existing!.targetFor(
                                    exerciseId,
                                  )!,
                            }),
                          ),
                        );
                      }
                    : null,
                style: FilledButton.styleFrom(
                  backgroundColor: _marsGreen,
                  minimumSize: const Size.fromHeight(54),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                ),
                child: const Text(
                  '保存训练方案',
                  style: TextStyle(fontWeight: FontWeight.w700),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
