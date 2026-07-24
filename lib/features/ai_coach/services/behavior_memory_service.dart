import '../../../models/training.dart';
import '../models/ai_memory.dart';

class BehaviorMemoryService {
  const BehaviorMemoryService();

  List<AiMemoryItem> derive({
    required List<TrainingSession> sessions,
    DateTime? now,
  }) {
    final anchor = DateUtils.dateOnly(now ?? DateTime.now());
    final start = anchor.subtract(const Duration(days: 41));
    final recent = sessions.where((session) {
      final date = DateTime.tryParse(session.date);
      if (date == null) return false;
      final day = DateUtils.dateOnly(date);
      return !day.isBefore(start) && !day.isAfter(anchor);
    }).toList();
    if (recent.isEmpty) return const [];

    final timestamp = now ?? DateTime.now();
    final sessionRefs = recent
        .take(12)
        .map(
          (session) => AiMemorySourceRef(
            type: 'training_session',
            id: session.id,
            label: session.name,
            dateRangeStart: _date(start),
            dateRangeEnd: _date(anchor),
            analyticsType: 'training_history_6w',
          ),
        )
        .toList();
    final result = <AiMemoryItem>[];

    if (recent.length >= 2) {
      final frequency = recent.length / 6;
      result.add(
        _derived(
          key: 'training_frequency_6w',
          category: AiProfileCategory.trainingHabit,
          value: '最近 6 周平均每周训练约 ${frequency.toStringAsFixed(1)} 次',
          structuredValue: {
            'weeks': 6,
            'sessionCount': recent.length,
            'averagePerWeek': double.parse(frequency.toStringAsFixed(1)),
          },
          refs: sessionRefs,
          now: timestamp,
        ),
      );
    }

    final exercises = recent.expand((session) => session.exercises).toList();
    final equipmentCounts = <String, int>{};
    final bodyPartCounts = <String, int>{};
    final exerciseCounts = <String, ({String name, int count})>{};
    for (final exercise in exercises) {
      final equipment = _equipmentFor(exercise);
      if (equipment != null) {
        equipmentCounts.update(
          equipment,
          (value) => value + 1,
          ifAbsent: () => 1,
        );
      }
      final bodyPart = exercise.bodyPart.trim();
      if (bodyPart.isNotEmpty) {
        bodyPartCounts.update(
          bodyPart,
          (value) => value + 1,
          ifAbsent: () => 1,
        );
      }
      final id = exercise.exerciseId?.trim().isNotEmpty == true
          ? exercise.exerciseId!.trim()
          : exercise.exerciseName.trim();
      if (id.isNotEmpty) {
        final previous = exerciseCounts[id];
        exerciseCounts[id] = (
          name: exercise.exerciseName.trim().isEmpty
              ? id
              : exercise.exerciseName,
          count: (previous?.count ?? 0) + 1,
        );
      }
    }

    final equipment = _top(equipmentCounts);
    if (equipment != null && equipment.value >= 2) {
      result.add(
        _derived(
          key: 'preferred_equipment',
          category: AiProfileCategory.trainingPreference,
          value: '最近训练中较常使用${equipment.key}',
          structuredValue: {
            'equipment': equipment.key,
            'uses': equipment.value,
          },
          refs: sessionRefs,
          now: timestamp,
        ),
      );
    }

    final bodyParts = bodyPartCounts.entries.toList()..sort(_descendingThenKey);
    if (bodyParts.isNotEmpty && bodyParts.first.value >= 2) {
      final top = bodyParts.take(3).map((item) => item.key).toList();
      result.add(
        _derived(
          key: 'frequent_body_parts',
          category: AiProfileCategory.longTermTrend,
          value: '最近较常训练：${top.join('、')}',
          structuredValue: {
            'bodyParts': top,
            'counts': {
              for (final item in bodyParts.take(3)) item.key: item.value,
            },
          },
          refs: sessionRefs,
          now: timestamp,
        ),
      );
    }

    final frequentExercises = exerciseCounts.entries.toList()
      ..sort((a, b) {
        final count = b.value.count.compareTo(a.value.count);
        return count != 0 ? count : a.key.compareTo(b.key);
      });
    if (frequentExercises.isNotEmpty &&
        frequentExercises.first.value.count >= 2) {
      final top = frequentExercises
          .take(3)
          .map((item) => item.value.name)
          .toList();
      result.add(
        _derived(
          key: 'frequent_exercises',
          category: AiProfileCategory.trainingHabit,
          value: '最近较常记录：${top.join('、')}',
          structuredValue: {'exercises': top},
          refs: sessionRefs,
          now: timestamp,
        ),
      );
    }

    result.addAll(_deriveRestBehavior(recent, timestamp));
    return result;
  }

  Iterable<AiMemoryItem> _deriveRestBehavior(
    List<TrainingSession> sessions,
    DateTime now,
  ) sync* {
    final buckets =
        <
          String,
          ({
            String name,
            List<int> planned,
            List<int> actual,
            Set<String> sessions,
          })
        >{};
    for (final session in sessions) {
      for (final exercise in session.exercises) {
        final id = exercise.exerciseId;
        if (id == null || id.trim().isEmpty) continue;
        final previous = buckets[id];
        final planned = [...?previous?.planned];
        final actual = [...?previous?.actual];
        for (final set in exercise.sets) {
          if (set.plannedRestSeconds != null && set.actualRestSeconds != null) {
            planned.add(set.plannedRestSeconds!);
            actual.add(set.actualRestSeconds!);
          }
        }
        buckets[id] = (
          name: exercise.exerciseName,
          planned: planned,
          actual: actual,
          sessions: {...?previous?.sessions, session.id},
        );
      }
    }
    for (final entry in buckets.entries) {
      final bucket = entry.value;
      if (bucket.actual.length < 3) continue;
      final planned =
          bucket.planned.reduce((a, b) => a + b) ~/ bucket.planned.length;
      final actual =
          bucket.actual.reduce((a, b) => a + b) ~/ bucket.actual.length;
      if (actual < planned + 20) continue;
      yield _derived(
        key: 'rest_behavior_${entry.key}',
        category: AiProfileCategory.trainingHabit,
        value: '你在${bucket.name}训练中通常会比计划多休息约 ${actual - planned} 秒',
        structuredValue: {
          'exerciseId': entry.key,
          'plannedAverageSeconds': planned,
          'actualAverageSeconds': actual,
          'sampleCount': bucket.actual.length,
        },
        refs: bucket.sessions
            .map(
              (id) => AiMemorySourceRef(
                type: 'training_session',
                id: id,
                label: '含休息记录的训练',
                analyticsType: 'planned_actual_rest',
              ),
            )
            .toList(),
        now: now,
      );
    }
  }

  AiMemoryItem _derived({
    required String key,
    required AiProfileCategory category,
    required String value,
    required Map<String, dynamic> structuredValue,
    required List<AiMemorySourceRef> refs,
    required DateTime now,
  }) => AiMemoryItem(
    id: 'derived_$key',
    stableKey: key,
    category: category,
    value: value,
    structuredValue: structuredValue,
    sourceType: AiMemorySourceType.behaviorDerived,
    status: AiMemoryStatus.active,
    createdAt: now,
    updatedAt: now,
    sourceRefs: refs,
    confidenceLevel: AiMemoryConfidence.medium,
  );

  String? _equipmentFor(TrainingExercise exercise) {
    final value = '${exercise.exerciseId ?? ''} ${exercise.exerciseName}'
        .toLowerCase();
    if (value.contains('dumbbell') || value.contains('哑铃')) return '哑铃';
    if (value.contains('barbell') || value.contains('杠铃')) return '杠铃';
    if (value.contains('smith') || value.contains('史密斯')) return '史密斯机';
    if (value.contains('cable') ||
        value.contains('绳索') ||
        value.contains('龙门')) {
      return '绳索器械';
    }
    if (value.contains('machine') || value.contains('器械')) return '固定器械';
    if (value.contains('push_up') ||
        value.contains('pull_up') ||
        value.contains('俯卧撑') ||
        value.contains('引体')) {
      return '自重';
    }
    return null;
  }

  MapEntry<String, int>? _top(Map<String, int> values) {
    if (values.isEmpty) return null;
    final entries = values.entries.toList()..sort(_descendingThenKey);
    return entries.first;
  }

  int _descendingThenKey(MapEntry<String, int> a, MapEntry<String, int> b) {
    final count = b.value.compareTo(a.value);
    return count != 0 ? count : a.key.compareTo(b.key);
  }

  String _date(DateTime date) =>
      '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
}

class DateUtils {
  static DateTime dateOnly(DateTime value) =>
      DateTime(value.year, value.month, value.day);
}
