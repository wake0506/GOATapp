import 'package:flutter_test/flutter_test.dart';
import 'package:goat_app/exercise_catalog.dart';
import 'package:goat_app/features/training/domain/training_session_state.dart';
import 'package:goat_app/features/training/models/exercise_metadata.dart';
import 'package:goat_app/features/training/models/exercise_recommendation.dart';
import 'package:goat_app/features/training/services/exercise_recommendation_engine.dart';
import 'package:goat_app/features/training/services/exercise_replacement_service.dart';
import 'package:goat_app/features/training/services/training_coverage_calculator.dart';
import 'package:goat_app/features/training/services/training_session_engine.dart';
import 'package:goat_app/models/training.dart';
import 'package:goat_app/repositories/local_training_repository.dart';
import 'package:goat_app/services/local_storage_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  final now = DateTime.utc(2026, 7, 20, 10);

  SetRecord completedSet(String id) => SetRecord(
    id: id,
    reps: 8,
    setType: TrainingSetType.working,
    completedAt: now,
  );

  TrainingSession backSession() => TrainingSession(
    id: 'back-day',
    name: 'Back Day',
    date: '2026-07-20',
    exercises: [
      TrainingExercise(
        exerciseId: 'lat_pulldown',
        exerciseName: '高位下拉',
        bodyPart: '背部',
        sets: [
          completedSet('lat-1'),
          completedSet('lat-2'),
          completedSet('lat-3'),
        ],
      ),
      TrainingExercise(
        exerciseId: 'pull_up',
        exerciseName: '引体向上',
        bodyPart: '背部',
        sets: [
          completedSet('pull-1'),
          completedSet('pull-2'),
          completedSet('pull-3'),
        ],
      ),
      TrainingExercise(
        exerciseId: 'seated_cable_row',
        exerciseName: '坐姿划船',
        bodyPart: '背部',
        sets: [SetRecord(id: 'row-1', setType: TrainingSetType.working)],
      ),
    ],
  );

  test('planned horizontal row is prioritized after vertical pulls', () {
    final session = backSession();
    final coverage = const TrainingCoverageCalculator().calculateSession(
      session: session,
      isActiveSession: true,
    );
    final ranked = const ExerciseRecommendationEngine().complementary(
      currentSession: session,
      coverageResult: coverage,
      catalog: exerciseCatalog,
    );
    expect(ranked, isNotEmpty);
    expect(ranked.first.exercise.id, 'seated_cable_row');
    expect(
      ranked.first.reasonCodes,
      contains(ExerciseRecommendationReason.missingMovementPattern),
    );
    expect(ranked.first.movementPattern.name, 'horizontalPull');
  });

  test('equipment constraints and performed exercises are hard filters', () {
    final session = backSession();
    final coverage = const TrainingCoverageCalculator().calculateSession(
      session: session,
      isActiveSession: true,
    );
    final ranked = const ExerciseRecommendationEngine().complementary(
      currentSession: session,
      coverageResult: coverage,
      catalog: exerciseCatalog,
      constraints: const ExerciseConstraints(
        unavailableEquipment: {'器械'},
        excludedExerciseIds: {'barbell_bent_over_row'},
      ),
    );
    expect(
      ranked.map((item) => item.exercise.equipment),
      isNot(contains('器械')),
    );
    expect(
      ranked.map((item) => item.exercise.id),
      isNot(contains('barbell_bent_over_row')),
    );
    expect(
      ranked.map((item) => item.exercise.id),
      isNot(contains('lat_pulldown')),
    );
  });

  test(
    'unresolved candidates are not used for precise complementary advice',
    () {
      final session = TrainingSession(
        id: 'full-body',
        name: 'Full Body',
        date: '2026-07-20',
        exercises: [
          TrainingExercise(
            exerciseId: 'kettlebell_goblet_squat',
            exerciseName: '壶铃高脚杯深蹲',
            bodyPart: '全身/体能',
            sets: [completedSet('goblet')],
          ),
        ],
      );
      final coverage = const TrainingCoverageCalculator().calculateSession(
        session: session,
        isActiveSession: true,
      );
      final ranked = const ExerciseRecommendationEngine().complementary(
        currentSession: session,
        coverageResult: coverage,
        catalog: exerciseCatalog,
      );
      for (final id in [
        'clean',
        'snatch',
        'clean_and_jerk',
        'turkish_get_up',
      ]) {
        expect(ranked.map((item) => item.exercise.id), isNot(contains(id)));
      }
    },
  );

  test('flat pressing can produce a reviewed complementary chest region', () {
    final session = TrainingSession(
      id: 'chest-day',
      name: 'Chest Day',
      date: '2026-07-20',
      exercises: [
        TrainingExercise(
          exerciseId: 'barbell_flat_bench_press',
          exerciseName: '杠铃平板卧推',
          bodyPart: '胸部',
          sets: [completedSet('bench-1'), completedSet('bench-2')],
        ),
      ],
    );
    final coverage = const TrainingCoverageCalculator().calculateSession(
      session: session,
      isActiveSession: true,
    );
    final ranked = const ExerciseRecommendationEngine().complementary(
      currentSession: session,
      coverageResult: coverage,
      catalog: exerciseCatalog,
    );
    expect(ranked, isNotEmpty);
    expect(
      ranked.first.reasonCodes,
      contains(ExerciseRecommendationReason.undercoveredPrimaryRegion),
    );
    expect(ranked.first.targetRegions, isNot(contains(MuscleRegion.midChest)));
  });

  test('returns no candidate when every safe option is excluded', () {
    final session = backSession();
    final coverage = const TrainingCoverageCalculator().calculateSession(
      session: session,
      isActiveSession: true,
    );
    final original = exerciseCatalog.firstWhere(
      (exercise) => exercise.id == 'lat_pulldown',
    );
    final ranked = const ExerciseRecommendationEngine().complementary(
      currentSession: session,
      coverageResult: coverage,
      catalog: [original],
    );
    expect(ranked, isEmpty);
  });

  test('unified replacement mode preserves legacy service order', () {
    final original = exerciseCatalog.firstWhere(
      (exercise) => exercise.id == 'barbell_flat_bench_press',
    );
    const constraints = ExerciseConstraints(unavailableEquipment: {'器械'});
    final legacy = const ExerciseReplacementService().rank(
      original: original,
      catalog: exerciseCatalog,
      constraints: constraints,
    );
    final unified = const ExerciseRecommendationEngine().replacement(
      original: original,
      catalog: exerciseCatalog,
      constraints: constraints,
    );
    expect(
      unified.map((item) => item.exercise.id),
      legacy.map((item) => item.exercise.id),
    );
  });

  test(
    'adopted recommendation persists after local repository restart',
    () async {
      SharedPreferences.setMockInitialValues({});
      final preferences = await SharedPreferences.getInstance();
      var repository = LocalTrainingRepository(
        storage: LocalStorageService(preferences),
        namespace: 'stage2d-restart',
        clock: () => now,
      );
      var engine = TrainingSessionEngine(
        repository: repository,
        clock: () => now,
      );
      final session = TrainingSession(
        id: 'draft',
        name: 'Back',
        date: '2026-07-20',
        exercises: [
          TrainingExercise(
            exerciseId: 'lat_pulldown',
            exerciseName: '高位下拉',
            bodyPart: '背部',
            sets: [SetRecord(id: 'lat', reps: 8)],
          ),
        ],
      );
      await engine.startSession(activeSessionId: 'active', draft: session);
      await engine.adoptRecommendedExercise(
        recommendation: TrainingExercise(
          exerciseId: 'seated_cable_row',
          exerciseName: '坐姿划船',
          bodyPart: '背部',
          sets: [SetRecord(id: 'row', setType: TrainingSetType.working)],
        ),
      );

      repository = LocalTrainingRepository(
        storage: LocalStorageService(preferences),
        namespace: 'stage2d-restart',
        clock: () => now,
      );
      engine = TrainingSessionEngine(repository: repository, clock: () => now);
      final restored = await engine.restore();
      expect(restored?.currentExerciseId, 'seated_cable_row');
      expect(
        restored?.draft.exercises.map((exercise) => exercise.exerciseId),
        contains('seated_cable_row'),
      );
    },
  );
}
