import 'package:flutter_test/flutter_test.dart';
import 'package:goat_app/features/ai_coach/models/ai_coach_state.dart';
import 'package:goat_app/features/ai_coach/models/ai_memory.dart';
import 'package:goat_app/features/analytics/models/weight_trend.dart';
import 'package:goat_app/features/profile/models/profile_summary.dart';
import 'package:goat_app/features/profile/services/profile_summary_service.dart';
import 'package:goat_app/models/training.dart';
import 'package:goat_app/repositories/in_memory_training_repository.dart';

void main() {
  test('profile summary reuses training and trend calculators', () async {
    final anchor = DateTime(2026, 7, 25);
    final sessions = [
      _session('one', '2026-07-25'),
      _session('two', '2026-07-23'),
      _session('three', '2026-06-20'),
    ];
    final state = AiCoachState(
      memories: [
        _memory(
          id: 'goal',
          category: AiProfileCategory.trainingGoal,
          value: '增肌',
        ),
        _memory(
          id: 'experience',
          category: AiProfileCategory.trainingExperience,
          value: '有一定经验',
        ),
        _memory(
          id: 'equipment',
          category: AiProfileCategory.availableEquipment,
          value: '自由重量、绳索',
        ),
        _memory(
          id: 'pending',
          category: AiProfileCategory.trainingHabit,
          value: '每周训练 4 次',
          sourceType: AiMemorySourceType.aiInferred,
          status: AiMemoryStatus.pendingConfirmation,
        ),
      ],
    );

    final result = await const ProfileSummaryService().load(
      identity: const ProfileIdentity(
        isLoggedIn: true,
        displayName: 'Zhuoyang Xu',
        email: 'user@example.com',
      ),
      trainingRepository: InMemoryTrainingRepository(
        completedSessions: sessions,
      ),
      weightRecords: [
        for (var index = 0; index < 7; index++)
          WeightRecord(
            recordedAt: anchor.subtract(Duration(days: index)),
            weightKg: 71 + index * 0.1,
          ),
      ],
      aiState: state,
      trainingTemplateCount: 3,
      anchorDate: anchor,
    );

    expect(result.totalTrainingSessions, 3);
    expect(result.weeklyTrainingDays, 2);
    expect(result.weeklyEffectiveSets, 2);
    expect(result.trendWeightKg, closeTo(71.3, 0.001));
    expect(result.trainingGoal, '增肌');
    expect(result.trainingExperience, '有一定经验');
    expect(result.availableEquipment, ['自由重量', '绳索']);
    expect(result.activeMemoryCount, 3);
    expect(result.pendingMemoryCount, 1);
    expect(result.templateCount, 3);
  });

  test(
    'profile summary ignores archived and inferred profile values',
    () async {
      final state = AiCoachState(
        memories: [
          _memory(
            id: 'old',
            category: AiProfileCategory.trainingGoal,
            value: '减脂',
            status: AiMemoryStatus.archived,
          ),
          _memory(
            id: 'inferred',
            category: AiProfileCategory.trainingGoal,
            value: '增肌',
            sourceType: AiMemorySourceType.aiInferred,
          ),
        ],
      );

      final result = await const ProfileSummaryService().load(
        identity: const ProfileIdentity(
          isLoggedIn: false,
          displayName: '',
          email: '',
        ),
        trainingRepository: InMemoryTrainingRepository(),
        weightRecords: const [],
        aiState: state,
        trainingTemplateCount: 0,
        anchorDate: DateTime(2026, 7, 25),
      );

      expect(result.trainingGoal, isNull);
      expect(result.totalTrainingSessions, 0);
      expect(result.weightLabel, '--');
    },
  );
}

TrainingSession _session(String id, String date) => TrainingSession(
  id: id,
  name: '训练 $id',
  date: date,
  exercises: [
    TrainingExercise(
      exerciseName: '杠铃平板卧推',
      bodyPart: '胸部',
      sets: [SetRecord(weight: 60, reps: 8)],
    ),
  ],
);

AiMemoryItem _memory({
  required String id,
  required AiProfileCategory category,
  required String value,
  AiMemorySourceType sourceType = AiMemorySourceType.userProvided,
  AiMemoryStatus status = AiMemoryStatus.active,
}) => AiMemoryItem(
  id: id,
  category: category,
  value: value,
  sourceType: sourceType,
  status: status,
  createdAt: DateTime(2026, 7, 1),
  updatedAt: DateTime(2026, 7, 1),
  userConfirmed: sourceType == AiMemorySourceType.userProvided,
);
