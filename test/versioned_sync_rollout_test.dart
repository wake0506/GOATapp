import 'package:flutter_test/flutter_test.dart';
import 'package:goat_app/models/app_snapshot.dart';
import 'package:goat_app/models/consumed_record.dart';
import 'package:goat_app/models/exercise_record.dart';
import 'package:goat_app/models/water_intake_record.dart';
import 'package:goat_app/services/cloud_sync_service.dart';
import 'package:goat_app/services/sync_queue_service.dart';
import 'package:goat_app/services/versioned_sync_rollout.dart';

void main() {
  test('versioned sync is disabled by default', () {
    const rollout = VersionedSyncRollout(enabledByBuild: false);

    expect(rollout.isEnabled, isFalse);
  });

  test('an explicit QA build enables versioned sync', () {
    const rollout = VersionedSyncRollout(enabledByBuild: true);

    expect(rollout.isEnabled, isTrue);
  });

  test('active rollout queues diet water weight and exercise operations', () {
    final snapshot = AppSnapshot(
      gender: '男',
      birthYear: 2000,
      birthMonth: 1,
      birthDay: 1,
      height: 175,
      currentWeight: 70.25,
      searchHistory: const [],
      targetP: 150,
      targetC: 200,
      targetF: 60,
      targetKcal: 2000,
      resetHour: 0,
      aiDismissedDate: '',
      foods: const [],
      consumed: [
        ConsumedRecord(
          id: 'diet-1',
          name: '米饭',
          p: 2,
          c: 28,
          f: 0,
          kcal: 130,
          mealType: '午餐',
          date: '2026-07-14',
        ),
      ],
      exercises: [
        ExerciseRecord(
          id: 'exercise-1',
          type: '跑步',
          kcal: 200,
          startTime: '08:00',
          endTime: '08:30',
          date: '2026-07-14',
        ),
      ],
      training: const [],
      waterRecords: [
        WaterIntakeRecord(
          id: 'water-1',
          date: '2026-07-14',
          recordedAt: DateTime.utc(2026, 7, 14, 8),
          amountMl: 300,
        ),
      ],
      water: const {'2026-07-14': 300},
      weight: const {'2026-07-14': 70.25},
    );
    final queue = SyncQueueService();

    queue.enqueueSnapshot(userId: 'user-a', snapshot: snapshot);

    expect(
      queue.operations.map((operation) => operation.entityType),
      containsAll([
        'diet_logs',
        'exercise_logs',
        'water_intake_records',
        'body_weight_logs',
      ]),
    );
  });

  test(
    'legacy training data remains readable when the text payload is empty or malformed',
    () {
      expect(decodeLegacyTrainingData(''), isEmpty);
      expect(decodeLegacyTrainingData('{not-json'), isEmpty);
      expect(decodeLegacyTrainingData('[]'), isEmpty);
    },
  );
}
