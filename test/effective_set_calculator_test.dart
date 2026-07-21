import 'package:flutter_test/flutter_test.dart';
import 'package:goat_app/features/analytics/models/analytics_date_range.dart';
import 'package:goat_app/features/analytics/models/effective_set_summary.dart';
import 'package:goat_app/features/analytics/services/effective_set_calculator.dart';
import 'package:goat_app/features/training/domain/training_session_state.dart';
import 'package:goat_app/models/training.dart';

void main() {
  const calculator = EffectiveSetCalculator();
  final range = AnalyticsDateRange(
    start: DateTime(2026, 7, 1),
    end: DateTime(2026, 7, 7),
  );

  test('counts completed effective warmup and legacy sets exactly once', () {
    final completedAt = DateTime.utc(2026, 7, 3, 10);
    final summary = calculator.calculate(
      completedSessions: [
        _session(
          date: '2026-07-03',
          exercises: [
            TrainingExercise(
              exerciseId: 'bench',
              exerciseName: 'Bench press',
              bodyPart: 'chest',
              sets: [
                SetRecord(
                  reps: 10,
                  setType: TrainingSetType.warmup,
                  completedAt: completedAt,
                ),
                SetRecord(
                  weight: 0,
                  reps: 10,
                  setType: TrainingSetType.working,
                  completedAt: completedAt,
                ),
                SetRecord(
                  reps: 8,
                  setType: TrainingSetType.drop,
                  completedAt: completedAt,
                ),
                SetRecord(reps: 6, setType: TrainingSetType.amrap),
                SetRecord(
                  reps: 5,
                  setType: TrainingSetType.failure,
                  completedAt: completedAt,
                ),
                SetRecord(
                  reps: 0,
                  setType: TrainingSetType.working,
                  completedAt: completedAt,
                ),
                SetRecord(
                  reps: 12,
                  replacementPlaceholder: true,
                  completedAt: completedAt,
                ),
              ],
            ),
          ],
        ),
      ],
      dateRange: range,
    );

    expect(summary.completedSets, 5);
    expect(summary.effectiveSets, 4);
    expect(summary.warmupSets, 1);
    expect(summary.legacyInferredSets, 1);
    expect(summary.dataQuality, EffectiveSetDataQuality.partial);
    final chest = summary.groups.singleWhere(
      (entry) => entry.muscleGroup == AnalyticsMuscleGroup.chest,
    );
    expect(chest.effectiveSets, 4);
  });

  test('uses one canonical group and excludes sessions outside the range', () {
    final completedAt = DateTime.utc(2026, 7, 3);
    final summary = calculator.calculate(
      completedSessions: [
        _session(
          date: '2026-07-03',
          exercises: [
            TrainingExercise(
              exerciseId: 'burpee',
              exerciseName: 'Burpee',
              bodyPart: 'full body',
              sets: [
                SetRecord(
                  reps: 10,
                  setType: TrainingSetType.superset,
                  completedAt: completedAt,
                ),
              ],
            ),
          ],
        ),
        _session(
          date: '2026-07-08',
          exercises: [
            TrainingExercise(
              exerciseId: 'row',
              exerciseName: 'Row',
              bodyPart: 'back',
              sets: [SetRecord(reps: 10, completedAt: completedAt)],
            ),
          ],
        ),
      ],
      dateRange: range,
    );

    expect(summary.effectiveSets, 1);
    expect(
      summary.groups
          .where((entry) => entry.effectiveSets > 0)
          .map((entry) => entry.muscleGroup),
      [AnalyticsMuscleGroup.fullBody],
    );
    expect(summary.dataQuality, EffectiveSetDataQuality.complete);
  });

  test('reports insufficient and legacy-heavy quality explicitly', () {
    final empty = calculator.calculate(
      completedSessions: const [],
      dateRange: range,
    );
    expect(empty.dataQuality, EffectiveSetDataQuality.insufficient);

    final legacy = calculator.calculate(
      completedSessions: [
        _session(
          date: '2026-07-03',
          exercises: [
            TrainingExercise(
              exerciseId: 'squat',
              exerciseName: 'Squat',
              bodyPart: 'legs',
              sets: [SetRecord(reps: 5), SetRecord(reps: 5)],
            ),
          ],
        ),
      ],
      dateRange: range,
    );
    expect(legacy.dataQuality, EffectiveSetDataQuality.legacyHeavy);
  });
}

TrainingSession _session({
  required String date,
  required List<TrainingExercise> exercises,
}) => TrainingSession(
  id: date,
  name: 'Training',
  date: date,
  exercises: exercises,
);
