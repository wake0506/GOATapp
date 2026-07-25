import 'package:flutter_test/flutter_test.dart';
import 'package:goat_app/features/ai_coach/models/ai_memory.dart';
import 'package:goat_app/features/ai_coach/repositories/ai_coach_local_repository.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  test('profile preference updates one stable USER_PROVIDED value', () async {
    final preferences = await SharedPreferences.getInstance();
    final repository = AiCoachLocalRepository(
      preferences: preferences,
      namespace: 'user-a',
    );

    await repository.setUserProfileValue(
      category: AiProfileCategory.trainingGoal,
      value: '增肌',
      now: DateTime(2026, 7, 1),
    );
    await repository.setUserProfileValue(
      category: AiProfileCategory.trainingGoal,
      value: '力量提升',
      now: DateTime(2026, 7, 2),
    );

    final values = repository
        .load()
        .memories
        .where(
          (item) =>
              item.category == AiProfileCategory.trainingGoal &&
              item.sourceType == AiMemorySourceType.userProvided,
        )
        .toList();
    expect(values, hasLength(1));
    expect(values.single.value, '力量提升');
    expect(values.single.stableKey, 'user_profile_trainingGoal');
    expect(values.single.status, AiMemoryStatus.active);
    expect(values.single.userConfirmed, isTrue);
  });

  test('clearing preference archives it and persists across reload', () async {
    final preferences = await SharedPreferences.getInstance();
    final repository = AiCoachLocalRepository(
      preferences: preferences,
      namespace: 'user-a',
    );
    await repository.setUserProfileValue(
      category: AiProfileCategory.coachingStyle,
      value: '详细解释',
    );
    await repository.setUserProfileValue(
      category: AiProfileCategory.coachingStyle,
      value: null,
    );

    final item = AiCoachLocalRepository(
      preferences: preferences,
      namespace: 'user-a',
    ).load().memories.single;
    expect(item.status, AiMemoryStatus.archived);
  });

  test('profile preferences remain namespace isolated', () async {
    final preferences = await SharedPreferences.getInstance();
    final first = AiCoachLocalRepository(
      preferences: preferences,
      namespace: 'user-a',
    );
    final second = AiCoachLocalRepository(
      preferences: preferences,
      namespace: 'user-b',
    );
    await first.setUserProfileValue(
      category: AiProfileCategory.trainingExperience,
      value: '熟练训练者',
    );

    expect(first.load().memories, hasLength(1));
    expect(second.load().memories, isEmpty);
  });
}
