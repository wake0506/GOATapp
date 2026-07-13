import '../models/app_snapshot.dart';
import '../models/sync_operation.dart';
import '../models/sync_cursor.dart';

class SyncQueueService {
  final List<SyncOperation> operations;
  SyncCursor cursor;

  SyncQueueService({List<SyncOperation>? operations, SyncCursor? cursor})
    : operations = operations ?? <SyncOperation>[],
      cursor = cursor ?? const SyncCursor.empty();

  factory SyncQueueService.fromSnapshot(
    AppSnapshot snapshot, {
    String? userId,
  }) => SyncQueueService(
    operations: [
      ...snapshot.syncOperations.where(
        (operation) => userId == null || operation.userId == userId,
      ),
    ],
    cursor: snapshot.syncCursor,
  );

  List<SyncOperation> ready([DateTime? now]) =>
      operations.where((operation) => operation.isReady(now)).toList();

  void enqueue(SyncOperation operation) {
    final index = operations.indexWhere(
      (item) =>
          item.userId == operation.userId &&
          item.entityType == operation.entityType &&
          item.entityId == operation.entityId &&
          item.action == operation.action,
    );
    if (index == -1) {
      operations.add(operation);
      return;
    }
    final previous = operations[index];
    operations[index] = SyncOperation(
      operationId: previous.operationId,
      userId: operation.userId,
      entityType: operation.entityType,
      entityId: operation.entityId,
      action: operation.action,
      payload: operation.payload,
      createdAt: previous.createdAt,
      retryCount: previous.retryCount,
      nextRetryAt: previous.nextRetryAt,
    );
  }

  void enqueueSnapshot({
    required String userId,
    required AppSnapshot snapshot,
  }) {
    final now = DateTime.now().toUtc();
    void add(
      String type,
      String id,
      SyncAction action,
      Map<String, dynamic> payload,
    ) {
      enqueue(
        SyncOperation(
          operationId: '$userId:$type:$id:${action.name}',
          userId: userId,
          entityType: type,
          entityId: id,
          action: action,
          payload: payload,
          createdAt: now,
        ),
      );
    }

    add('user_profiles', userId, SyncAction.upsert, {
      'current_weight': snapshot.currentWeight,
      'target_kcal': snapshot.targetKcal,
    });
    for (final food in snapshot.foods) {
      add('food_dictionary', food.id, SyncAction.upsert, food.toJson());
    }
    for (final record in snapshot.consumed) {
      add('diet_logs', record.id, SyncAction.upsert, record.toJson());
    }
    for (final exercise in snapshot.exercises) {
      add('exercise_logs', exercise.id, SyncAction.upsert, exercise.toJson());
    }
    for (final record in snapshot.waterRecords) {
      add(
        'water_intake_records',
        record.id,
        SyncAction.upsert,
        record.toJson(),
      );
    }
    for (final entry in snapshot.weight.entries) {
      add('body_weight_logs', entry.key, SyncAction.upsert, {
        'date': entry.key,
        'weight_kg': entry.value,
      });
    }
    for (final session in snapshot.training) {
      add('training_sessions', session.id, SyncAction.upsert, session.toJson());
    }
    for (final id in snapshot.pendingCloudDeletes.foodIds) {
      add('food_dictionary', id, SyncAction.delete, const {});
    }
    for (final id in snapshot.pendingCloudDeletes.dietRecordIds) {
      add('diet_logs', id, SyncAction.delete, const {});
    }
    for (final id in snapshot.pendingCloudDeletes.exerciseRecordIds) {
      add('exercise_logs', id, SyncAction.delete, const {});
    }
    for (final id in snapshot.pendingCloudDeletes.waterRecordIds) {
      add('water_intake_records', id, SyncAction.delete, const {});
    }
  }

  void markSucceeded(String operationId) {
    operations.removeWhere((operation) => operation.operationId == operationId);
  }

  void markAllSucceeded() => operations.clear();

  void markFailed(String operationId, {DateTime? now}) {
    final index = operations.indexWhere(
      (item) => item.operationId == operationId,
    );
    if (index == -1) return;
    final operation = operations[index];
    final retryCount = operation.retryCount + 1;
    final seconds = (1 << retryCount.clamp(0, 8)).clamp(1, 300);
    operations[index] = operation.copyWith(
      retryCount: retryCount,
      nextRetryAt: (now ?? DateTime.now()).add(Duration(seconds: seconds)),
    );
  }

  void advanceCursor(DateTime processedAt) {
    cursor = SyncCursor(lastSyncedAt: processedAt.toUtc());
  }
}
