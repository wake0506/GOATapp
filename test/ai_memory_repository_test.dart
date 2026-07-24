import 'package:flutter_test/flutter_test.dart';
import 'package:goat_app/features/ai_coach/models/ai_memory.dart';
import 'package:goat_app/features/ai_coach/repositories/ai_coach_local_repository.dart';
import 'package:goat_app/features/ai_coach/services/behavior_memory_service.dart';
import 'package:goat_app/models/training.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late SharedPreferences preferences;
  late AiCoachLocalRepository repository;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    preferences = await SharedPreferences.getInstance();
    repository = AiCoachLocalRepository(
      preferences: preferences,
      namespace: 'user_a',
    );
  });

  test(
    'user-provided memory persists with stable JSON compatibility',
    () async {
      final state = await repository.addUserProvided(
        category: AiProfileCategory.trainingGoal,
        value: '增肌',
        now: DateTime.utc(2026, 7, 24),
      );

      expect(state.memories, hasLength(1));
      final loaded = repository.load().memories.single;
      expect(loaded.value, '增肌');
      expect(loaded.sourceType, AiMemorySourceType.userProvided);
      expect(loaded.status, AiMemoryStatus.active);
      expect(loaded.userConfirmed, isTrue);
    },
  );

  test('user-provided memory supports edit and archive deletion', () async {
    var state = await repository.addUserProvided(
      category: AiProfileCategory.trainingPreference,
      value: '哑铃',
    );
    final id = state.memories.single.id;

    state = await repository.editMemory(id, '更喜欢自由重量');
    expect(state.memories.single.value, '更喜欢自由重量');

    state = await repository.archiveMemory(id);
    expect(state.memories.single.status, AiMemoryStatus.archived);
    expect(state.memories.single.isUsableInContext, isFalse);
  });

  test('AI inference stays pending until explicit confirmation', () async {
    final inference = _inference('preferred_equipment');
    var state = await repository.addInference(inference);
    expect(state.memories.single.status, AiMemoryStatus.pendingConfirmation);
    expect(state.memories.single.isUsableInContext, isFalse);

    state = await repository.setMemoryStatus(
      inference.id,
      AiMemoryStatus.active,
    );
    expect(state.memories.single.userConfirmed, isTrue);
    expect(state.memories.single.isUsableInContext, isTrue);
  });

  test('rejected inference suppresses same stable key regeneration', () async {
    final inference = _inference('preferred_equipment');
    await repository.addInference(inference);
    await repository.setMemoryStatus(inference.id, AiMemoryStatus.rejected);

    final state = await repository.addInference(
      _inference('preferred_equipment').copyWith(value: '新的重复推测'),
    );

    expect(state.memories, hasLength(1));
    expect(state.memories.single.status, AiMemoryStatus.rejected);
    expect(state.memories.single.value, isNot('新的重复推测'));
  });

  test('incorrect derived memory suppresses future upserts', () async {
    final first = _derived('training_frequency_6w', '每周 4 次');
    await repository.upsertDerived([first]);
    await repository.setMemoryStatus(first.id, AiMemoryStatus.incorrect);

    final state = await repository.upsertDerived([
      _derived('training_frequency_6w', '每周 4.2 次'),
    ]);

    expect(state.memories, hasLength(1));
    expect(state.memories.single.status, AiMemoryStatus.incorrect);
    expect(state.memories.single.value, '每周 4 次');
  });

  test(
    'derived memory updates an existing stable key instead of appending',
    () async {
      await repository.upsertDerived([
        _derived('training_frequency_6w', '每周 4 次'),
      ]);
      final state = await repository.upsertDerived([
        _derived('training_frequency_6w', '每周 3.8 次'),
      ]);

      expect(state.memories, hasLength(1));
      expect(state.memories.single.value, '每周 3.8 次');
    },
  );

  test('namespaces are isolated between users and guest', () async {
    final userB = AiCoachLocalRepository(
      preferences: preferences,
      namespace: 'user_b',
    );
    final guest = AiCoachLocalRepository(
      preferences: preferences,
      namespace: 'guest',
    );
    await repository.addUserProvided(
      category: AiProfileCategory.trainingGoal,
      value: '用户 A',
    );
    await userB.addUserProvided(
      category: AiProfileCategory.trainingGoal,
      value: '用户 B',
    );

    expect(repository.load().memories.single.value, '用户 A');
    expect(userB.load().memories.single.value, '用户 B');
    expect(guest.load().memories, isEmpty);
  });

  test('guest merge preserves target suppression', () async {
    final guest = AiCoachLocalRepository(
      preferences: preferences,
      namespace: 'guest',
    );
    final suppressed = _inference('preferred_equipment');
    await repository.addInference(suppressed);
    await repository.setMemoryStatus(suppressed.id, AiMemoryStatus.rejected);
    await guest.addInference(
      _inference('preferred_equipment').copyWith(value: '重复内容'),
    );

    final state = await repository.mergeFrom(guest.load());

    expect(state.memories, hasLength(1));
    expect(state.memories.single.status, AiMemoryStatus.rejected);
  });

  group('behavior-derived memory', () {
    test('derives six-week frequency, equipment, body parts and exercises', () {
      final now = DateTime(2026, 7, 24);
      final sessions = List.generate(
        6,
        (index) => TrainingSession(
          id: 'session_$index',
          name: '训练 ${index + 1}',
          date: DateTime(
            2026,
            7,
            20 - index,
          ).toIso8601String().substring(0, 10),
          exercises: [
            TrainingExercise(
              exerciseId: 'dumbbell_row',
              exerciseName: '哑铃划船',
              bodyPart: '背部',
              sets: [SetRecord(weight: 20, reps: 10)],
            ),
          ],
        ),
      );

      final derived = const BehaviorMemoryService().derive(
        sessions: sessions,
        now: now,
      );

      expect(
        derived.map((item) => item.stableKey),
        containsAll([
          'training_frequency_6w',
          'preferred_equipment',
          'frequent_body_parts',
          'frequent_exercises',
        ]),
      );
      expect(
        derived
            .firstWhere((item) => item.stableKey == 'training_frequency_6w')
            .sourceRefs,
        isNotEmpty,
      );
    });

    test('does not create psychological personality judgements', () {
      final derived = const BehaviorMemoryService().derive(
        sessions: [
          TrainingSession(
            id: 'session',
            name: '训练',
            date: '2026-07-24',
            exercises: const [],
          ),
        ],
        now: DateTime(2026, 7, 24),
      );

      final text = derived.map((item) => item.value).join(' ');
      expect(text, isNot(contains('自律')));
      expect(text, isNot(contains('意志力')));
    });

    test('derives longer-rest observation without modifying prescription', () {
      final sessions = List.generate(
        3,
        (index) => TrainingSession(
          id: 'rest_$index',
          name: '卧推',
          date: '2026-07-${20 + index}',
          exercises: [
            TrainingExercise(
              exerciseId: 'barbell_flat_bench_press',
              exerciseName: '杠铃平板卧推',
              bodyPart: '胸部',
              sets: [
                SetRecord(
                  reps: 8,
                  plannedRestSeconds: 150,
                  actualRestSeconds: 185,
                ),
              ],
            ),
          ],
        ),
      );

      final derived = const BehaviorMemoryService().derive(
        sessions: sessions,
        now: DateTime(2026, 7, 24),
      );
      final rest = derived.firstWhere(
        (item) => item.stableKey == 'rest_behavior_barbell_flat_bench_press',
      );

      expect(rest.value, contains('多休息'));
      expect(rest.structuredValue['plannedAverageSeconds'], 150);
      expect(rest.structuredValue['actualAverageSeconds'], 185);
    });
  });
}

AiMemoryItem _inference(String key) => AiMemoryItem(
  id: 'inference_$key',
  stableKey: key,
  category: AiProfileCategory.trainingPreference,
  value: '你可能偏好哑铃动作',
  sourceType: AiMemorySourceType.aiInferred,
  status: AiMemoryStatus.pendingConfirmation,
  createdAt: DateTime.utc(2026, 7, 24),
  updatedAt: DateTime.utc(2026, 7, 24),
  sourceRefs: const [
    AiMemorySourceRef(type: 'suggestion', id: 'suggestion_1', label: 'AI 建议记录'),
  ],
  confidenceLevel: AiMemoryConfidence.low,
);

AiMemoryItem _derived(String key, String value) => AiMemoryItem(
  id: 'derived_$key',
  stableKey: key,
  category: AiProfileCategory.trainingHabit,
  value: value,
  sourceType: AiMemorySourceType.behaviorDerived,
  status: AiMemoryStatus.active,
  createdAt: DateTime.utc(2026, 7, 24),
  updatedAt: DateTime.utc(2026, 7, 24),
);
