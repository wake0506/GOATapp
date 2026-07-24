import 'package:flutter_test/flutter_test.dart';
import 'package:goat_app/exercise_catalog.dart';
import 'package:goat_app/features/training/domain/active_training_session.dart';
import 'package:goat_app/features/training/domain/training_session_state.dart';
import 'package:goat_app/features/training/models/exercise_rest_profile_catalog.dart';
import 'package:goat_app/features/training/models/training_template.dart';
import 'package:goat_app/features/training/services/rest_prescription_engine.dart';
import 'package:goat_app/features/training/services/training_draft_factory.dart';
import 'package:goat_app/features/training/services/training_session_engine.dart';
import 'package:goat_app/models/rest_prescription.dart';
import 'package:goat_app/models/training.dart';
import 'package:goat_app/repositories/in_memory_training_repository.dart';
import 'package:goat_app/repositories/local_training_repository.dart';
import 'package:goat_app/services/local_storage_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  const engine = RestPrescriptionEngine();

  ExerciseRestProfile profile(ExerciseRestClass restClass) =>
      ExerciseRestProfile(exerciseId: restClass.name, restClass: restClass);

  RestRecommendation recommend({
    ExerciseRestClass restClass = ExerciseRestClass.standardCompound,
    TrainingSetType setType = TrainingSetType.working,
    int? rir,
    bool reachedFailure = false,
    bool isLastSetOfExercise = false,
    bool isLastSetOfSession = false,
    ExerciseRestClass? nextClass,
    String currentBodyPart = '胸部',
    String nextBodyPart = '胸部',
    RestPrescription prescription = const RestPrescription.recommended(),
    int? sessionOverride,
  }) => engine.recommend(
    RestPrescriptionRequest(
      currentProfile: profile(restClass),
      setType: setType,
      rir: rir,
      reachedFailure: reachedFailure,
      isLastSetOfExercise: isLastSetOfExercise,
      isLastSetOfSession: isLastSetOfSession,
      currentBodyPart: currentBodyPart,
      nextProfile: nextClass == null ? null : profile(nextClass),
      nextBodyPart: nextBodyPart,
      nextExerciseId: nextClass?.name,
      prescription: prescription,
      sessionExerciseOverrideSeconds: sessionOverride,
    ),
  );

  group('rest profile integrity', () {
    test('all 143 stable catalog IDs have one explicit profile', () {
      final report = ExerciseRestProfileCatalog.validate();
      expect(exerciseCatalog, hasLength(143));
      expect(report.catalogCount, 143);
      expect(report.mappedCount, 143);
      expect(report.missingExerciseIds, isEmpty);
      expect(report.unknownExerciseIds, isEmpty);
      expect(report.duplicateExerciseIds, isEmpty);
      expect(report.isValid, isTrue);
    });

    test('complex lifts have rest profiles independent of muscle metadata', () {
      expect(
        ExerciseRestProfileCatalog.find('clean')?.restClass,
        ExerciseRestClass.olympicPower,
      );
      expect(
        ExerciseRestProfileCatalog.find('snatch')?.restClass,
        ExerciseRestClass.olympicPower,
      );
      expect(
        ExerciseRestProfileCatalog.find('clean_and_jerk')?.restClass,
        ExerciseRestClass.olympicPower,
      );
      expect(
        ExerciseRestProfileCatalog.find('turkish_get_up')?.restClass,
        ExerciseRestClass.heavyCompound,
      );
    });
  });

  group('base rest and dynamic fatigue', () {
    for (final entry in const {
      ExerciseRestClass.olympicPower: 240,
      ExerciseRestClass.heavyCompound: 180,
      ExerciseRestClass.standardCompound: 150,
      ExerciseRestClass.machineCompound: 120,
      ExerciseRestClass.isolation: 90,
      ExerciseRestClass.smallMuscleIsolation: 75,
      ExerciseRestClass.other: 90,
    }.entries) {
      test('${entry.key.name} uses ${entry.value} seconds', () {
        expect(recommend(restClass: entry.key).recommendedSeconds, entry.value);
      });
    }

    test('RIR 3, RIR 2, and null keep base rest', () {
      expect(recommend(rir: 3).recommendedSeconds, 150);
      expect(recommend(rir: 2).recommendedSeconds, 150);
      expect(recommend().recommendedSeconds, 150);
    });

    test('RIR 1 adds 30 and RIR 0 adds 60', () {
      expect(recommend(rir: 1).recommendedSeconds, 180);
      expect(recommend(rir: 0).recommendedSeconds, 210);
    });

    test('failure signals use max modifier without double counting', () {
      expect(recommend(reachedFailure: true).recommendedSeconds, 210);
      expect(recommend(rir: 0, reachedFailure: true).recommendedSeconds, 210);
      expect(
        recommend(
          setType: TrainingSetType.failure,
          rir: 0,
          reachedFailure: true,
        ).recommendedSeconds,
        210,
      );
    });

    test('drop and AMRAP add 30 while working and superset add none', () {
      expect(recommend(setType: TrainingSetType.drop).recommendedSeconds, 180);
      expect(recommend(setType: TrainingSetType.amrap).recommendedSeconds, 180);
      expect(
        recommend(setType: TrainingSetType.working).recommendedSeconds,
        150,
      );
      expect(
        recommend(setType: TrainingSetType.superset).recommendedSeconds,
        150,
      );
    });

    test(
      'recommended values clamp at 300 but user fixed remains up to 600',
      () {
        final clamped = recommend(
          restClass: ExerciseRestClass.olympicPower,
          rir: 0,
        );
        expect(clamped.recommendedSeconds, 300);
        final fixed = recommend(
          prescription: const RestPrescription.fixed(540),
          rir: 0,
        );
        expect(fixed.recommendedSeconds, 150);
        expect(fixed.plannedSeconds, 540);
        expect(fixed.modifierSeconds, 0);
      },
    );
  });

  group('warm-up rest', () {
    RestRecommendation warmup({
      required double? weight,
      required double? reference,
      bool isFinal = false,
      ExerciseRestClass restClass = ExerciseRestClass.standardCompound,
    }) => engine.recommend(
      RestPrescriptionRequest(
        currentProfile: profile(restClass),
        setType: TrainingSetType.warmup,
        currentWeight: weight,
        referenceWorkingWeight: reference,
        isFinalWarmup: isFinal,
      ),
    );

    test('load tiers use 45, 60, 90, and 120 seconds', () {
      expect(warmup(weight: 40, reference: 100).plannedSeconds, 45);
      expect(warmup(weight: 60, reference: 100).plannedSeconds, 60);
      expect(warmup(weight: 80, reference: 100).plannedSeconds, 90);
      expect(warmup(weight: 90, reference: 100).plannedSeconds, 120);
    });

    test('final warm-up respects pre-working recovery by rest class', () {
      expect(
        warmup(
          weight: 40,
          reference: 100,
          isFinal: true,
          restClass: ExerciseRestClass.standardCompound,
        ).plannedSeconds,
        150,
      );
      expect(
        warmup(
          weight: 40,
          reference: 100,
          isFinal: true,
          restClass: ExerciseRestClass.heavyCompound,
        ).plannedSeconds,
        180,
      );
      expect(
        warmup(
          weight: 40,
          reference: 100,
          isFinal: true,
          restClass: ExerciseRestClass.olympicPower,
        ).plannedSeconds,
        240,
      );
    });

    test('missing reference safely uses 60 or final pre-working recovery', () {
      expect(warmup(weight: 20, reference: null).plannedSeconds, 60);
      expect(
        warmup(
          weight: 20,
          reference: 0,
          isFinal: true,
          restClass: ExerciseRestClass.heavyCompound,
        ).plannedSeconds,
        180,
      );
    });

    test('template fixed time does not force empty-bar warm-up rest', () {
      final value = engine.recommend(
        RestPrescriptionRequest(
          currentProfile: profile(ExerciseRestClass.standardCompound),
          setType: TrainingSetType.warmup,
          currentWeight: 20,
          referenceWorkingWeight: 80,
          prescription: const RestPrescription.fixed(180),
        ),
      );
      expect(value.plannedSeconds, 45);
    });
  });

  group('exercise transitions', () {
    test('session final set starts no timer', () {
      final value = recommend(isLastSetOfSession: true);
      expect(value.shouldStartTimer, isFalse);
      expect(value.transitionType, RestTransitionType.sessionComplete);
    });

    test('same body part uses deterministic 90 to 150 second rule', () {
      final value = recommend(
        restClass: ExerciseRestClass.standardCompound,
        isLastSetOfExercise: true,
        nextClass: ExerciseRestClass.isolation,
      );
      expect(value.plannedSeconds, 150);
      expect(
        value.reasonCodes,
        contains(RestReasonCode.sameBodyPartTransition),
      );
    });

    test('different body part defaults to 75 seconds', () {
      final value = recommend(
        isLastSetOfExercise: true,
        nextClass: ExerciseRestClass.isolation,
        nextBodyPart: '肩部',
      );
      expect(value.plannedSeconds, 75);
    });

    test('heavy and olympic next exercise receive at least their base', () {
      expect(
        recommend(
          isLastSetOfExercise: true,
          nextClass: ExerciseRestClass.heavyCompound,
          nextBodyPart: '腿部',
        ).plannedSeconds,
        180,
      );
      expect(
        recommend(
          isLastSetOfExercise: true,
          nextClass: ExerciseRestClass.olympicPower,
          nextBodyPart: '全身/体能',
        ).plannedSeconds,
        240,
      );
    });

    test('current exercise override does not leak into transition rest', () {
      final value = recommend(
        isLastSetOfExercise: true,
        nextClass: ExerciseRestClass.isolation,
        nextBodyPart: '肩部',
        sessionOverride: 300,
      );
      expect(value.plannedSeconds, 75);
      expect(value.isUserOverridden, isFalse);
    });
  });

  group('superset cycle', () {
    test('uses max profile and max fatigue modifier', () {
      final value = engine.recommend(
        RestPrescriptionRequest(
          currentProfile: profile(ExerciseRestClass.smallMuscleIsolation),
          setType: TrainingSetType.superset,
          rir: 2,
          isSupersetCycle: true,
          supersetPartnerProfile: profile(ExerciseRestClass.isolation),
          supersetPartnerFatigueModifier: 60,
        ),
      );
      expect(value.baseSeconds, 90);
      expect(value.modifierSeconds, 60);
      expect(value.plannedSeconds, 150);
    });

    test('group override wins without changing GOAT recommendation', () {
      final value = engine.recommend(
        RestPrescriptionRequest(
          currentProfile: profile(ExerciseRestClass.smallMuscleIsolation),
          setType: TrainingSetType.superset,
          isSupersetCycle: true,
          supersetPartnerProfile: profile(ExerciseRestClass.isolation),
          supersetGroupOverrideSeconds: 120,
        ),
      );
      expect(value.recommendedSeconds, 90);
      expect(value.plannedSeconds, 120);
      expect(value.source, RestSource.supersetOverride);
    });
  });

  group('models and snapshots', () {
    test('old JSON remains compatible without Rest V2 fields', () {
      final set = SetRecord.fromJson({'weight': 60, 'reps': 8});
      expect(set.restSeconds, 90);
      expect(set.recommendedRestSeconds, isNull);
      expect(set.plannedRestSeconds, isNull);
      expect(set.actualRestSeconds, isNull);
      expect(set.restPolicyVersion, isNull);

      final template = TrainingTemplate.fromJson({
        'id': 'old',
        'name': '旧方案',
        'exerciseIds': ['barbell_flat_bench_press'],
      });
      expect(template.restPrescriptions, isEmpty);
      expect(
        template.restFor('barbell_flat_bench_press').mode,
        RestPrescriptionMode.recommended,
      );
    });

    test('new SetRecord fields and stable source round-trip', () {
      final original = SetRecord(
        id: 'set',
        restSeconds: 180,
        recommendedRestSeconds: 150,
        plannedRestSeconds: 180,
        actualRestSeconds: 132,
        restPolicyVersion: 2,
        restSource: RestSource.sessionExerciseOverride,
      );
      final restored = SetRecord.fromJson(original.toJson());
      expect(restored.recommendedRestSeconds, 150);
      expect(restored.plannedRestSeconds, 180);
      expect(restored.actualRestSeconds, 132);
      expect(restored.restPolicyVersion, 2);
      expect(restored.restSource, RestSource.sessionExerciseOverride);
    });

    test('template prescription snapshots into active draft', () {
      final bench = exerciseCatalog.firstWhere(
        (exercise) => exercise.id == 'barbell_flat_bench_press',
      );
      const fixed = RestPrescription.fixed(180);
      final draft = const TrainingDraftFactory().create(
        id: 'draft',
        name: 'Push',
        date: '2026-07-24',
        exercises: [bench],
        restPrescriptions: {'barbell_flat_bench_press': fixed},
      );
      expect(draft.exercises.single.restPrescription?.validFixedSeconds, 180);
    });

    test('active-session overrides round-trip and reject invalid values', () {
      final now = DateTime.utc(2026, 7, 24);
      final session = ActiveTrainingSession(
        id: 'active',
        draft: TrainingSession(
          id: 'draft',
          name: 'Push',
          date: '2026-07-24',
          exercises: const [],
        ),
        state: TrainingSessionState.readyForNextSet,
        startedAt: now,
        updatedAt: now,
        exerciseRestOverrides: const {'bench': 180},
        supersetRestOverrides: const {'sg-1': 120},
      );
      final json = session.toJson();
      json['exerciseRestOverrides'] = {
        ...Map<String, dynamic>.from(json['exerciseRestOverrides'] as Map),
        'bad': 800,
      };
      final restored = ActiveTrainingSession.fromJson(json);
      expect(restored.exerciseRestOverrides, {'bench': 180});
      expect(restored.supersetRestOverrides, {'sg-1': 120});
    });

    test(
      'session override survives restart and remains user-namespaced',
      () async {
        SharedPreferences.setMockInitialValues({});
        final now = DateTime.utc(2026, 7, 24);
        final storage = await LocalStorageService.create();
        final active = ActiveTrainingSession(
          id: 'active',
          draft: TrainingSession(
            id: 'draft',
            name: 'Push',
            date: '2026-07-24',
            exercises: const [],
          ),
          state: TrainingSessionState.readyForNextSet,
          startedAt: now,
          updatedAt: now,
          exerciseRestOverrides: const {'bench': 180},
        );
        await LocalTrainingRepository(
          storage: storage,
          namespace: 'user-a',
        ).saveActiveSession(active);

        final restarted = LocalTrainingRepository(
          storage: await LocalStorageService.create(),
          namespace: 'user-a',
        );
        final otherUser = LocalTrainingRepository(
          storage: await LocalStorageService.create(),
          namespace: 'user-b',
        );
        expect((await restarted.loadActiveSession())?.exerciseRestOverrides, {
          'bench': 180,
        });
        expect(await otherUser.loadActiveSession(), isNull);
      },
    );
  });

  group('active session integration', () {
    late DateTime clock;
    late InMemoryTrainingRepository repository;
    late TrainingSessionEngine sessionEngine;

    TrainingSession benchDraft({int sets = 3}) => TrainingSession(
      id: 'draft',
      name: 'Bench',
      date: '2026-07-24',
      exercises: [
        TrainingExercise(
          exerciseId: 'barbell_flat_bench_press',
          exerciseName: '杠铃平板卧推',
          bodyPart: '胸部',
          restPrescription: const RestPrescription.recommended(),
          sets: List.generate(
            sets,
            (index) => SetRecord(
              id: 'set-${index + 1}',
              weight: 80,
              reps: 8,
              setType: TrainingSetType.working,
            ),
          ),
        ),
      ],
    );

    setUp(() {
      clock = DateTime.utc(2026, 7, 24, 10);
      repository = InMemoryTrainingRepository();
      sessionEngine = TrainingSessionEngine(
        repository: repository,
        clock: () => clock,
      );
    });

    Future<void> start(TrainingSession draft) async {
      await sessionEngine.startSession(activeSessionId: 'active', draft: draft);
      await sessionEngine.confirmSession();
      await sessionEngine.startSet(
        exerciseId: draft.exercises.first.exerciseId!,
        setId: draft.exercises.first.sets.first.id!,
      );
    }

    test('bench RIR2 starts 150 seconds and tracks planned metadata', () async {
      await start(benchDraft());
      await sessionEngine.updateSet(setId: 'set-1', rir: 2);
      final resting = await sessionEngine.completeSetForFlow(setId: 'set-1');
      final set = resting.draft.exercises.single.sets.first;
      expect(resting.rest?.restDurationSeconds, 150);
      expect(set.recommendedRestSeconds, 150);
      expect(set.plannedRestSeconds, 150);
      expect(set.restPolicyVersion, 2);
    });

    test(
      'session override persists, restores, and can return to GOAT',
      () async {
        await start(benchDraft());
        await sessionEngine.completeSetForFlow(setId: 'set-1');
        var active = await sessionEngine.setCurrentRestOverride(
          exerciseId: 'barbell_flat_bench_press',
          durationSeconds: 180,
        );
        expect(active.exerciseRestOverrides.values.single, 180);
        expect(active.rest?.restDurationSeconds, 180);

        clock = clock.add(const Duration(seconds: 60));
        await sessionEngine.skipRest();
        await sessionEngine.startNextAvailableSet();
        await sessionEngine.updateSet(setId: 'set-2', rir: 0);
        active = await sessionEngine.completeSetForFlow(setId: 'set-2');
        expect(active.rest?.recommendation?.recommendedSeconds, 210);
        expect(active.rest?.restDurationSeconds, 180);

        active = await sessionEngine.restoreCurrentRestRecommendation(
          exerciseId: 'barbell_flat_bench_press',
        );
        expect(active.exerciseRestOverrides, isEmpty);
        expect(active.rest?.restDurationSeconds, 210);
      },
    );

    test(
      '+30 changes current planned rest only and actual uses clock',
      () async {
        await start(benchDraft());
        await sessionEngine.completeSetForFlow(setId: 'set-1');
        var active = await sessionEngine.extendCurrentRest();
        expect(active.rest?.restDurationSeconds, 180);
        expect(
          active.draft.exercises.single.sets.first.plannedRestSeconds,
          180,
        );
        expect(active.exerciseRestOverrides, isEmpty);

        clock = clock.add(const Duration(seconds: 132));
        await sessionEngine.skipRest();
        active = (await repository.loadActiveSession())!;
        expect(active.draft.exercises.single.sets.first.actualRestSeconds, 132);

        await sessionEngine.startNextAvailableSet();
        active = await sessionEngine.completeSetForFlow(setId: 'set-2');
        expect(active.rest?.restDurationSeconds, 150);
      },
    );

    test(
      'background expiry measures actual rest until next set begins',
      () async {
        await start(benchDraft());
        await sessionEngine.completeSetForFlow(setId: 'set-1');
        clock = clock.add(const Duration(seconds: 170));

        var active = await sessionEngine.restore();
        expect(active?.state, TrainingSessionState.readyForNextSet);
        expect(active?.rest, isNotNull);
        active = await sessionEngine.startNextAvailableSet();
        expect(active.currentSetId, 'set-2');
        expect(active.draft.exercises.single.sets.first.actualRestSeconds, 170);
      },
    );

    test('fixed template disables RIR modifier for working sets', () async {
      final draft = benchDraft()
        ..exercises.single.restPrescription = const RestPrescription.fixed(180);
      await start(draft);
      await sessionEngine.updateSet(setId: 'set-1', rir: 0);
      final active = await sessionEngine.completeSetForFlow(setId: 'set-1');
      expect(active.rest?.recommendation?.recommendedSeconds, 150);
      expect(active.rest?.restDurationSeconds, 180);
      expect(active.rest?.recommendation?.source, RestSource.templateFixed);
    });

    test('final session set never starts a rest timer', () async {
      await start(benchDraft(sets: 1));
      final active = await sessionEngine.completeSetForFlow(setId: 'set-1');
      expect(active.state, TrainingSessionState.setCompleted);
      expect(active.rest, isNull);
    });
  });
}
