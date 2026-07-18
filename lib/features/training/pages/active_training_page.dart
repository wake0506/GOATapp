import 'package:flutter/material.dart';

import '../../../exercise_catalog.dart';
import '../../../models/training.dart';
import '../../../repositories/training_repository.dart';
import '../domain/active_training_session.dart';
import '../domain/training_session_state.dart';
import '../services/exercise_replacement_service.dart';
import '../services/training_session_engine.dart';
import '../widgets/exercise_replacement_sheet.dart';
import '../widgets/rir_selector.dart';
import '../widgets/training_set_input_card.dart';
import 'training_completion_page.dart';

class ActiveTrainingPage extends StatefulWidget {
  const ActiveTrainingPage({
    super.key,
    required this.initialSession,
    required this.engine,
    required this.repository,
    required this.catalog,
    required this.onSessionChanged,
    required this.onFinished,
  });

  final ActiveTrainingSession initialSession;
  final TrainingSessionEngine engine;
  final TrainingRepository repository;
  final List<ExerciseDefinition> catalog;
  final ValueChanged<ActiveTrainingSession> onSessionChanged;
  final Future<void> Function(TrainingSession) onFinished;

  @override
  State<ActiveTrainingPage> createState() => _ActiveTrainingPageState();
}

class _ActiveTrainingPageState extends State<ActiveTrainingPage> {
  late ActiveTrainingSession _session = widget.initialSession;
  ExercisePerformance? _lastPerformance;
  bool _autofilled = false;
  bool _busy = false;

  TrainingExercise? get _exercise {
    for (final exercise in _session.draft.exercises.reversed) {
      if (exercise.status != TrainingExerciseStatus.replaced &&
          (exercise.exerciseId == _session.currentExerciseId ||
              _session.currentExerciseId == null)) {
        return exercise;
      }
    }
    return null;
  }

  SetRecord? get _set {
    final exercise = _exercise;
    if (exercise == null) return null;
    for (final set in exercise.sets) {
      if (set.id == _session.currentSetId) return set;
    }
    for (final set in exercise.sets) {
      if (set.completedAt == null) return set;
    }
    return exercise.sets.isEmpty ? null : exercise.sets.last;
  }

  int get _setIndex {
    final exercise = _exercise;
    final set = _set;
    if (exercise == null || set == null) return -1;
    return exercise.sets.indexOf(set);
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _bootstrap());
  }

  Future<void> _bootstrap() async {
    try {
      var active = await widget.engine.restore() ?? _session;
      if (active.state == TrainingSessionState.preparing) {
        active = await widget.engine.confirmSession();
      } else if (active.state == TrainingSessionState.paused) {
        active = await widget.engine.resume();
      }
      _setSession(active);
      if (active.state == TrainingSessionState.readyForNextSet) {
        await _activateNextSet();
      } else {
        await _loadLastPerformance();
      }
    } catch (error) {
      _showSaveError(error);
    }
  }

  Future<void> _activateNextSet() async {
    final exercise = _exercise;
    if (exercise == null) return;
    final next = exercise.sets
        .where((set) => set.completedAt == null)
        .firstOrNull;
    if (next?.id == null || exercise.exerciseId == null) return;
    final active = await widget.engine.startSet(
      exerciseId: exercise.exerciseId!,
      setId: next!.id!,
    );
    _setSession(active);
    await _loadLastPerformance();
    final current = _set;
    if (current != null &&
        current.weight == 0 &&
        current.reps == 0 &&
        _lastPerformance != null) {
      final performance = _lastPerformance!.set;
      final updated = await widget.engine.updateSet(
        setId: current.id!,
        weight: performance.weight,
        reps: performance.reps,
        rir: performance.rir,
      );
      _autofilled = true;
      _setSession(updated);
    }
  }

  Future<void> _loadLastPerformance() async {
    final exercise = _exercise;
    if (exercise == null) return;
    final result = await widget.repository.findLastPerformance(
      ExerciseReference(
        exerciseId: exercise.exerciseId,
        exerciseName: exercise.exerciseName,
      ),
      setOrdinal: _setIndex < 0 ? null : _setIndex,
    );
    if (mounted) setState(() => _lastPerformance = result);
  }

  void _setSession(ActiveTrainingSession value) {
    _session = value;
    widget.onSessionChanged(value);
    if (mounted) setState(() {});
  }

  Future<void> _updateSet({double? weight, int? reps, int? rir}) async {
    final set = _set;
    if (set?.id == null || _busy) return;
    setState(() => _busy = true);
    try {
      final updated = await widget.engine.updateSet(
        setId: set!.id!,
        weight: weight,
        reps: reps,
        rir: rir,
      );
      _autofilled = false;
      _setSession(updated);
    } catch (error) {
      _showSaveError(error);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _completeOrNext() async {
    if (_busy) return;
    if (_session.state == TrainingSessionState.setCompleted) {
      final remaining =
          _exercise?.sets.any((set) => set.completedAt == null) == true;
      if (remaining) {
        final ready = await widget.engine.nextSet();
        _setSession(ready);
        await _activateNextSet();
      } else {
        await _finishTraining();
      }
      return;
    }
    final set = _set;
    if (set?.id == null) return;
    setState(() => _busy = true);
    try {
      final completed = await widget.engine.completeSet(setId: set!.id!);
      _setSession(completed);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            duration: const Duration(milliseconds: 1100),
            backgroundColor: const Color(0xFF008C8C),
            content: Text(
              '第 ${_setIndex + 1} 组已记录  ·  ${set.weight.toStringAsFixed(1)} kg × ${set.reps}',
            ),
          ),
        );
      }
    } catch (error) {
      _showSaveError(error);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _replaceExercise() async {
    final exercise = _exercise;
    if (exercise?.exerciseId == null) return;
    final original = widget.catalog
        .where((item) => item.id == exercise!.exerciseId)
        .firstOrNull;
    if (original == null) return;
    final candidates = const ExerciseReplacementService()
        .rank(original: original, catalog: widget.catalog)
        .take(12)
        .toList();
    final replacement = await ExerciseReplacementSheet.show(
      context,
      original: original,
      candidates: candidates,
    );
    if (replacement == null || !mounted) return;
    try {
      final sets = List.generate(
        exercise!.sets.isEmpty ? 4 : exercise.sets.length,
        (index) => SetRecord(
          id: '${_session.id}-${replacement.id}-${index + 1}',
          setType: TrainingSetType.working,
        ),
      );
      var updated = await widget.engine.replaceExercise(
        originalExerciseId: original.id,
        replacement: TrainingExercise(
          exerciseId: replacement.id,
          exerciseName: replacement.name,
          bodyPart: replacement.bodyPart,
          sets: sets,
        ),
      );
      _setSession(updated);
      if (updated.state == TrainingSessionState.readyForNextSet) {
        await _activateNextSet();
      }
    } catch (error) {
      _showSaveError(error);
    }
  }

  Future<void> _pauseOrResume() async {
    try {
      final updated = _session.state == TrainingSessionState.paused
          ? await widget.engine.resume()
          : await widget.engine.pause();
      _setSession(updated);
    } catch (error) {
      _showSaveError(error);
    }
  }

  Future<void> _finishTraining() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('结束本次训练？'),
        content: const Text('已完成的训练组会被保存，尚未完成的组不会计入训练记录。'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            style: FilledButton.styleFrom(
              backgroundColor: const Color(0xFF008C8C),
            ),
            child: const Text('结束训练'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    try {
      final completed = await widget.engine.finishSession();
      await widget.onFinished(completed);
      if (!mounted) return;
      final minutes = DateTime.now()
          .difference(_session.startedAt)
          .inMinutes
          .clamp(1, 9999);
      await Navigator.of(context).pushReplacement(
        MaterialPageRoute<void>(
          builder: (_) => TrainingCompletionPage(
            session: completed,
            durationMinutes: minutes,
            onDone: () => Navigator.of(context).pop(),
          ),
        ),
      );
    } catch (error) {
      _showSaveError(error);
    }
  }

  Future<void> _showExactInput({required bool weight}) async {
    final controller = TextEditingController(
      text: weight ? _set?.weight.toStringAsFixed(1) : '${_set?.reps ?? 0}',
    );
    final value = await showModalBottomSheet<double>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (sheetContext) => Padding(
        padding: EdgeInsets.fromLTRB(
          24,
          24,
          24,
          MediaQuery.of(sheetContext).viewInsets.bottom + 24,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              weight ? '精确输入重量' : '精确输入次数',
              style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: controller,
              autofocus: true,
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
            ),
            const SizedBox(height: 18),
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: () => Navigator.pop(
                  sheetContext,
                  double.tryParse(controller.text),
                ),
                style: FilledButton.styleFrom(
                  backgroundColor: const Color(0xFF008C8C),
                ),
                child: const Text('保存'),
              ),
            ),
          ],
        ),
      ),
    );
    controller.dispose();
    if (value == null) return;
    await _updateSet(
      weight: weight ? value.clamp(0, 9999) : null,
      reps: weight ? null : value.round().clamp(0, 999),
    );
  }

  void _showRirHelp() => showModalBottomSheet<void>(
    context: context,
    backgroundColor: Colors.white,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
    ),
    builder: (context) => const SafeArea(
      child: Padding(
        padding: EdgeInsets.all(24),
        child: Text(
          '3+：还能完成至少约 3 次\n\n2：还能约 2 次\n\n1：还能约 1 次\n\n0：已接近极限',
          style: TextStyle(fontSize: 15, height: 1.45),
        ),
      ),
    ),
  );

  void _showSaveError(Object error) {
    if (!mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('本次修改暂未保存，请重试')));
  }

  @override
  Widget build(BuildContext context) {
    final exercise = _exercise;
    final set = _set;
    final visibleExercises = _session.draft.exercises
        .where((item) => item.status != TrainingExerciseStatus.replaced)
        .toList(growable: false);
    final exerciseNumber = exercise == null
        ? 0
        : visibleExercises.indexOf(exercise) + 1;
    final completedSets =
        exercise?.sets.where((item) => item.completedAt != null).length ?? 0;
    final isSetCompleted = _session.state == TrainingSessionState.setCompleted;
    return Scaffold(
      key: const Key('active-training-page'),
      backgroundColor: const Color(0xFFF4F5F7),
      appBar: AppBar(
        backgroundColor: const Color(0xFFF4F5F7),
        elevation: 0,
        centerTitle: true,
        title: Column(
          children: [
            Text(
              _session.draft.name,
              style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w700),
            ),
            Text(
              '动作 $exerciseNumber / ${visibleExercises.length}',
              style: const TextStyle(fontSize: 11, color: Color(0xFF8A9290)),
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.more_horiz),
            onPressed: () => showModalBottomSheet<void>(
              context: context,
              backgroundColor: Colors.white,
              shape: const RoundedRectangleBorder(
                borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
              ),
              builder: (sheetContext) => SafeArea(
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      ListTile(
                        leading: const Icon(Icons.swap_horiz),
                        title: const Text('替换动作'),
                        onTap: () {
                          Navigator.pop(sheetContext);
                          _replaceExercise();
                        },
                      ),
                      ListTile(
                        leading: const Icon(Icons.pause_outlined),
                        title: Text(
                          _session.state == TrainingSessionState.paused
                              ? '恢复训练'
                              : '暂停训练',
                        ),
                        onTap: () {
                          Navigator.pop(sheetContext);
                          _pauseOrResume();
                        },
                      ),
                      ListTile(
                        leading: const Icon(Icons.flag_outlined),
                        title: const Text('结束训练'),
                        onTap: () {
                          Navigator.pop(sheetContext);
                          _finishTraining();
                        },
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
      body: exercise == null || set == null
          ? const Center(child: Text('当前训练没有可记录的动作'))
          : ListView(
              padding: const EdgeInsets.fromLTRB(16, 18, 16, 30),
              children: [
                Text(
                  exercise.exerciseName,
                  style: const TextStyle(
                    color: Color(0xFF1F2725),
                    fontSize: 30,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  '第 ${_setIndex + 1} / ${exercise.sets.length} 组  ·  已完成 $completedSets 组',
                  style: const TextStyle(
                    color: Color(0xFF7D8583),
                    fontSize: 14,
                  ),
                ),
                if (_lastPerformance != null) ...[
                  const SizedBox(height: 18),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 12,
                    ),
                    decoration: BoxDecoration(
                      color: const Color(0xFFEFF2F1),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Text(
                      '上次  ${_lastPerformance!.set.weight.toStringAsFixed(1)} kg × ${_lastPerformance!.set.reps}${_lastPerformance!.set.rir == null ? '' : '  ·  RIR ${_lastPerformance!.set.rir}'}${_autofilled ? '   沿用上次' : ''}',
                      style: const TextStyle(
                        color: Color(0xFF68716F),
                        fontSize: 13,
                      ),
                    ),
                  ),
                ],
                const SizedBox(height: 18),
                TrainingSetInputCard(
                  weight: set.weight,
                  reps: set.reps,
                  onWeightDecrease: () =>
                      _updateSet(weight: (set.weight - 2.5).clamp(0, 9999)),
                  onWeightIncrease: () => _updateSet(weight: set.weight + 2.5),
                  onWeightTap: () => _showExactInput(weight: true),
                  onRepsDecrease: () =>
                      _updateSet(reps: (set.reps - 1).clamp(0, 999)),
                  onRepsIncrease: () => _updateSet(reps: set.reps + 1),
                  onRepsTap: () => _showExactInput(weight: false),
                ),
                const SizedBox(height: 20),
                RirSelector(
                  value: set.rir,
                  onChanged: (rir) => _updateSet(rir: rir),
                  onHelp: _showRirHelp,
                ),
                const SizedBox(height: 28),
                SizedBox(
                  height: 56,
                  child: FilledButton(
                    key: const Key('training-complete-set'),
                    onPressed:
                        _busy || _session.state == TrainingSessionState.paused
                        ? null
                        : _completeOrNext,
                    style: FilledButton.styleFrom(
                      backgroundColor: const Color(0xFF008C8C),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                    ),
                    child: Text(
                      isSetCompleted
                          ? (exercise.sets.any(
                                  (item) => item.completedAt == null,
                                )
                                ? '下一组'
                                : '完成训练')
                          : '完成本组',
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ),
                if (isSetCompleted) ...[
                  const SizedBox(height: 14),
                  const Center(
                    child: Text(
                      '本组已记录，下一组会继续留在当前训练上下文',
                      style: TextStyle(color: Color(0xFF8A9290), fontSize: 12),
                    ),
                  ),
                ],
              ],
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
