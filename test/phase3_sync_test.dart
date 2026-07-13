import 'package:flutter_test/flutter_test.dart';
import 'package:goat_app/models/app_snapshot.dart';
import 'package:goat_app/models/food_item.dart';
import 'package:goat_app/models/sync_operation.dart';
import 'package:goat_app/models/pending_cloud_deletes.dart';
import 'package:goat_app/services/sync_queue_service.dart';

void main() {
  test(
    'sync queue survives snapshot serialization and is namespace scoped',
    () {
      final snapshot = AppSnapshot(
        gender: '男',
        birthYear: 2000,
        birthMonth: 1,
        birthDay: 1,
        height: 175,
        currentWeight: 70,
        searchHistory: const [],
        targetP: 150,
        targetC: 200,
        targetF: 60,
        targetKcal: 2000,
        resetHour: 0,
        aiDismissedDate: '',
        foods: [
          FoodItem(
            id: 'food-1',
            name: '米饭',
            protein: 3,
            carbs: 28,
            fat: 0,
            calories: 130,
          ),
        ],
        consumed: const [],
        exercises: const [],
        training: const [],
        waterRecords: const [],
        water: const {},
        weight: const {},
      );
      final queue = SyncQueueService();
      queue.enqueueSnapshot(userId: 'user-a', snapshot: snapshot);
      final restored = AppSnapshot.fromJson(
        AppSnapshot(
          gender: snapshot.gender,
          birthYear: snapshot.birthYear,
          birthMonth: snapshot.birthMonth,
          birthDay: snapshot.birthDay,
          height: snapshot.height,
          currentWeight: snapshot.currentWeight,
          searchHistory: snapshot.searchHistory,
          targetP: snapshot.targetP,
          targetC: snapshot.targetC,
          targetF: snapshot.targetF,
          targetKcal: snapshot.targetKcal,
          resetHour: snapshot.resetHour,
          aiDismissedDate: snapshot.aiDismissedDate,
          foods: snapshot.foods,
          consumed: snapshot.consumed,
          exercises: snapshot.exercises,
          training: snapshot.training,
          waterRecords: snapshot.waterRecords,
          water: snapshot.water,
          weight: snapshot.weight,
          syncOperations: queue.operations,
          syncCursor: queue.cursor,
        ).toJson(),
      );
      final restoredQueue = SyncQueueService.fromSnapshot(
        restored,
        userId: 'user-a',
      );

      expect(restoredQueue.operations, hasLength(2));
      expect(
        restoredQueue.operations.every((op) => op.userId == 'user-a'),
        isTrue,
      );
      expect(
        SyncQueueService.fromSnapshot(
          AppSnapshot.empty(),
          userId: 'user-b',
        ).operations,
        isEmpty,
      );
    },
  );

  test('same entity update is idempotent and keeps operation id', () {
    final queue = SyncQueueService();
    final first = SyncOperation(
      operationId: 'operation-1',
      userId: 'user-a',
      entityType: 'diet_logs',
      entityId: 'diet-1',
      action: SyncAction.upsert,
      payload: const {'kcal': 100},
      createdAt: DateTime.utc(2026, 7, 13),
    );
    queue.enqueue(first);
    queue.enqueue(
      SyncOperation(
        operationId: 'operation-2',
        userId: 'user-a',
        entityType: 'diet_logs',
        entityId: 'diet-1',
        action: SyncAction.upsert,
        payload: const {'kcal': 200},
        createdAt: DateTime.utc(2026, 7, 13),
      ),
    );

    expect(queue.operations, hasLength(1));
    expect(queue.operations.single.operationId, 'operation-1');
    expect(queue.operations.single.payload['kcal'], 200);
  });

  test('failed operation remains queued with retry backoff', () {
    final queue = SyncQueueService();
    queue.enqueue(
      SyncOperation(
        operationId: 'operation-1',
        userId: 'user-a',
        entityType: 'diet_logs',
        entityId: 'diet-1',
        action: SyncAction.delete,
        payload: const {},
        createdAt: DateTime.utc(2026, 7, 13),
      ),
    );
    queue.markFailed('operation-1', now: DateTime.utc(2026, 7, 13));

    expect(queue.operations, hasLength(1));
    expect(queue.operations.single.retryCount, 1);
    expect(queue.operations.single.nextRetryAt, isNotNull);
  });

  test('legacy aggregate dates are retained beside detail records', () {
    final snapshot = AppSnapshot.fromJson({
      'water': {'2026-07-12': 800, '2026-07-13': 500},
      'waterRecords': [
        {
          'id': 'water-13',
          'date': '2026-07-13',
          'recordedAt': '2026-07-13T08:00:00Z',
          'amountMl': 300,
        },
      ],
    });

    expect(snapshot.water['2026-07-12'], 800);
    expect(snapshot.water['2026-07-13'], 300);
  });

  test('remote tombstones remove local records without re-queueing them', () {
    final snapshot = AppSnapshot(
      gender: '男',
      birthYear: 2000,
      birthMonth: 1,
      birthDay: 1,
      height: 175,
      currentWeight: 70,
      searchHistory: const [],
      targetP: 150,
      targetC: 200,
      targetF: 60,
      targetKcal: 2000,
      resetHour: 0,
      aiDismissedDate: '',
      foods: [
        FoodItem(
          id: 'deleted-food',
          name: '已删除',
          protein: 1,
          carbs: 1,
          fat: 1,
          calories: 1,
        ),
      ],
      consumed: const [],
      exercises: const [],
      training: const [],
      waterRecords: const [],
      water: const {},
      weight: const {},
      pendingCloudDeletes: const PendingCloudDeletes(foodIds: {'deleted-food'}),
    );

    final restored = snapshot.applyDeletes(snapshot.pendingCloudDeletes);
    expect(restored.foods, isEmpty);
    expect(restored.pendingCloudDeletes.isEmpty, isTrue);
  });
}
