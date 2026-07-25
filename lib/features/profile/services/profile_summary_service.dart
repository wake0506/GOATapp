import '../../ai_coach/models/ai_coach_state.dart';
import '../../ai_coach/models/ai_memory.dart';
import '../../analytics/models/weight_trend.dart';
import '../../analytics/services/trend_weight_calculator.dart';
import '../../analytics/services/weekly_training_review_calculator.dart';
import '../../../repositories/training_repository.dart';
import '../models/profile_summary.dart';

class ProfileSummaryService {
  const ProfileSummaryService({
    this.weeklyReviewCalculator = const WeeklyTrainingReviewCalculator(),
    this.trendWeightCalculator = const TrendWeightCalculator(),
  });

  final WeeklyTrainingReviewCalculator weeklyReviewCalculator;
  final TrendWeightCalculator trendWeightCalculator;

  Future<ProfileSummary> load({
    required ProfileIdentity identity,
    required TrainingRepository trainingRepository,
    required Iterable<WeightRecord> weightRecords,
    required AiCoachState aiState,
    required int trainingTemplateCount,
    required DateTime anchorDate,
  }) async {
    final sessions = await trainingRepository.listCompletedSessions();
    final weekly = weeklyReviewCalculator.calculate(
      completedSessions: sessions,
      anchorDate: anchorDate,
    );
    final trend = trendWeightCalculator.calculate(
      records: weightRecords,
      anchorDate: anchorDate,
    );

    return ProfileSummary(
      identity: identity,
      totalTrainingSessions: sessions.length,
      weeklyTrainingDays: weekly.trainingDays,
      weeklyEffectiveSets: weekly.effectiveSets,
      trendWeightKg: trend.sevenDayAverageKg,
      latestWeightKg: trend.latestMeasuredWeightKg,
      templateCount: trainingTemplateCount,
      activeMemoryCount: aiState.memories
          .where((item) => item.status == AiMemoryStatus.active)
          .length,
      pendingMemoryCount: aiState.memories
          .where((item) => item.status == AiMemoryStatus.pendingConfirmation)
          .length,
      trainingGoal: _profileValue(aiState, AiProfileCategory.trainingGoal),
      trainingExperience: _profileValue(
        aiState,
        AiProfileCategory.trainingExperience,
      ),
      availableEquipment:
          _profileValue(
            aiState,
            AiProfileCategory.availableEquipment,
          )?.split('、').where((item) => item.trim().isNotEmpty).toList() ??
          const [],
      trainingPreference: _profileValue(
        aiState,
        AiProfileCategory.trainingPreference,
      ),
      coachingStyle: _profileValue(aiState, AiProfileCategory.coachingStyle),
    );
  }

  String? _profileValue(AiCoachState state, AiProfileCategory category) {
    final matches =
        state.memories
            .where(
              (item) =>
                  item.category == category &&
                  item.sourceType == AiMemorySourceType.userProvided &&
                  item.status == AiMemoryStatus.active,
            )
            .toList()
          ..sort((left, right) => right.updatedAt.compareTo(left.updatedAt));
    if (matches.isEmpty) return null;
    final value = matches.first.value.trim();
    return value.isEmpty ? null : value;
  }
}
