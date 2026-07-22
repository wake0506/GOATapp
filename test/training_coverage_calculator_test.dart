import 'package:flutter_test/flutter_test.dart';
import 'package:goat_app/features/analytics/models/analytics_date_range.dart';
import 'package:goat_app/features/training/domain/training_session_state.dart';
import 'package:goat_app/features/training/models/exercise_metadata.dart';
import 'package:goat_app/features/training/models/training_coverage.dart';
import 'package:goat_app/features/training/services/training_coverage_calculator.dart';
import 'package:goat_app/models/training.dart';

void main() {
  final completedAt = DateTime.utc(2026, 7, 20, 10);

  SetRecord set({
    TrainingSetType type = TrainingSetType.working,
    bool completed = true,
    int reps = 8,
  }) => SetRecord(
    id: 'set-${type.name}-$reps-$completed',
    reps: reps,
    setType: type,
    completedAt: completed ? completedAt : null,
  );

  TrainingExercise exercise(
    String id,
    String name,
    String bodyPart,
    List<SetRecord> sets,
  ) => TrainingExercise(
    exerciseId: id,
    exerciseName: name,
    bodyPart: bodyPart,
    sets: sets,
  );

  TrainingSession session(List<TrainingExercise> exercises) => TrainingSession(
    id: 'session',
    name: 'Training',
    date: '2026-07-20',
    exercises: exercises,
  );

  test('chest coverage uses effective sets and excludes warmup', () {
    final result = const TrainingCoverageCalculator().calculateSession(
      session: session([
        exercise('barbell_flat_bench_press', '杠铃平板卧推', '胸部', [
          set(type: TrainingSetType.warmup),
          set(),
          set(type: TrainingSetType.drop),
          set(type: TrainingSetType.amrap),
          set(type: TrainingSetType.superset),
        ]),
      ]),
      isActiveSession: true,
    );
    expect(result.completedEffectiveSets, 4);
    expect(result.muscle(MuscleGroup.chest).primaryContribution, 8);
    expect(result.muscle(MuscleGroup.chest).level, CoverageLevel.sufficient);
    expect(result.muscle(MuscleGroup.arms).secondaryContribution, 4);
  });

  test('vertical-only back session exposes missing horizontal pull', () {
    final result = const TrainingCoverageCalculator().calculateSession(
      session: session([
        exercise('lat_pulldown', '高位下拉', '背部', [set(), set(), set()]),
      ]),
      isActiveSession: true,
    );
    expect(
      result.movement(ExerciseMovementPattern.verticalPull).effectiveSetCount,
      3,
    );
    expect(
      result.movement(ExerciseMovementPattern.horizontalPull).effectiveSetCount,
      0,
    );
  });

  test('vertical and horizontal pulls remain separate and explainable', () {
    final result = const TrainingCoverageCalculator().calculateSession(
      session: session([
        exercise('lat_pulldown', '高位下拉', '背部', [set(), set(), set()]),
        exercise('seated_cable_row', '坐姿划船', '背部', [set(), set()]),
      ]),
      isActiveSession: true,
    );
    expect(
      result.movement(ExerciseMovementPattern.horizontalPull).effectiveSetCount,
      2,
    );
    expect(
      result.region(MuscleRegion.midBack).contributingExerciseIds,
      contains('seated_cable_row'),
    );
  });

  test(
    'active session ignores incomplete sets while history keeps legacy sets',
    () {
      final draft = session([
        exercise('barbell_back_squat', '杠铃深蹲', '腿部', [set(completed: false)]),
      ]);
      final active = const TrainingCoverageCalculator().calculateSession(
        session: draft,
        isActiveSession: true,
      );
      final history = const TrainingCoverageCalculator().calculateHistory(
        completedSessions: [draft],
        dateRange: AnalyticsDateRange(
          start: DateTime(2026, 7, 14),
          end: DateTime(2026, 7, 20),
        ),
      );
      expect(active.completedEffectiveSets, 0);
      expect(history.completedEffectiveSets, 1);
    },
  );

  test('legs session keeps squat hinge and lunge patterns distinct', () {
    final result = const TrainingCoverageCalculator().calculateSession(
      session: session([
        exercise('barbell_back_squat', '杠铃深蹲', '腿部', [set()]),
        exercise('romanian_deadlift', '罗马尼亚硬拉', '腿部', [set()]),
        exercise('reverse_lunge', '反向箭步蹲', '腿部', [set()]),
      ]),
      isActiveSession: true,
    );
    expect(result.movement(ExerciseMovementPattern.squat).effectiveSetCount, 1);
    expect(result.movement(ExerciseMovementPattern.hinge).effectiveSetCount, 1);
    expect(result.movement(ExerciseMovementPattern.lunge).effectiveSetCount, 1);
    expect(result.muscle(MuscleGroup.legs).effectiveSetCount, 3);
  });

  test('legacy name fallback degrades quality but keeps coarse coverage', () {
    final result = const TrainingCoverageCalculator().calculateSession(
      session: session([
        exercise('', '杠铃平板卧推', '胸部', [set()])..exerciseId = null,
      ]),
      isActiveSession: true,
    );
    expect(result.legacyResolvedExercises, 1);
    expect(result.muscle(MuscleGroup.chest).effectiveSetCount, 1);
    expect(result.dataQuality, CoverageDataQuality.low);
  });

  test('unresolved action stays trainable without guessed region coverage', () {
    final result = const TrainingCoverageCalculator().calculateSession(
      session: session([
        exercise('clean', '高翻', '全身/体能', [set()]),
      ]),
      isActiveSession: true,
    );
    expect(result.completedEffectiveSets, 1);
    expect(result.unresolvedExerciseIds, ['clean']);
    expect(
      result.regionCoverage,
      everyElement(
        isA<RegionCoverageItem>().having(
          (item) => item.level,
          'level',
          CoverageLevel.untrained,
        ),
      ),
    );
    expect(result.dataQuality, CoverageDataQuality.low);
  });

  test('coverage level boundaries stay discrete and stable', () {
    const calculator = TrainingCoverageCalculator();
    expect(calculator.coverageLevelForUnits(0), CoverageLevel.untrained);
    expect(calculator.coverageLevelForUnits(2), CoverageLevel.light);
    expect(calculator.coverageLevelForUnits(3), CoverageLevel.moderate);
    expect(calculator.coverageLevelForUnits(6), CoverageLevel.sufficient);
    expect(calculator.coverageLevelForUnits(9), CoverageLevel.high);
  });
}
