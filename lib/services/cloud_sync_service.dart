import 'dart:convert';

import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/app_snapshot.dart';
import '../models/consumed_record.dart';
import '../models/exercise_record.dart';
import '../models/food_item.dart';
import '../models/pending_cloud_deletes.dart';
import '../models/sync_operation.dart';
import '../repositories/sync_repository.dart';
import 'versioned_sync_rollout.dart';

class CloudSyncService implements SyncRepository {
  final SupabaseClient client;
  final bool versionedSyncEnabled;

  CloudSyncService(this.client, {bool? enableVersionedSync})
    : versionedSyncEnabled = enableVersionedSync ?? enableVersionedCloudSync;

  @override
  Future<PendingCloudDeletes> syncSnapshot({
    required User user,
    required AppSnapshot snapshot,
    List<SyncOperation> operations = const [],
  }) async {
    if (versionedSyncEnabled) {
      await _syncOperations(user, operations);
      await _upsertTombstones(user, snapshot.pendingCloudDeletes);
    }
    await client.from('user_profiles').upsert({
      'id': user.id,
      'target_kcal': snapshot.targetKcal,
      'target_p': snapshot.targetP,
      'target_c': snapshot.targetC,
      'target_f': snapshot.targetF,
      'gender': snapshot.gender,
      'birth_year': snapshot.birthYear,
      'birth_month': snapshot.birthMonth,
      'birth_day': snapshot.birthDay,
      'height': snapshot.height,
      'current_weight': snapshot.currentWeight,
      'training_data': jsonEncode(
        snapshot.training.map((e) => e.toJson()).toList(),
      ),
    });

    await _syncTable<FoodItem>(
      table: 'food_dictionary',
      user: user,
      localRows: snapshot.foods
          .map(
            (food) => {
              'id': food.id,
              'user_id': user.id,
              'name': food.name,
              'protein': food.protein,
              'carbs': food.carbs,
              'fat': food.fat,
              'calories': food.calories,
              'category': food.category,
              'unit': food.unit,
              'weight_per_unit': food.weightPerUnit,
            },
          )
          .toList(),
      pendingIds: snapshot.pendingCloudDeletes.foodIds,
    );

    await _syncTable<ConsumedRecord>(
      table: 'diet_logs',
      user: user,
      localRows: snapshot.consumed
          .map(
            (food) => {
              'id': food.id,
              'user_id': user.id,
              'food_name': food.name,
              'p': food.p,
              'c': food.c,
              'f': food.f,
              'kcal': food.kcal,
              'meal_type': food.mealType,
              'date': food.date,
              'amount': food.amount,
              'unit': food.unit,
            },
          )
          .toList(),
      pendingIds: snapshot.pendingCloudDeletes.dietRecordIds,
    );

    await _syncTable<ExerciseRecord>(
      table: 'exercise_logs',
      user: user,
      localRows: snapshot.exercises
          .map(
            (exercise) => {
              'id': exercise.id,
              'user_id': user.id,
              'type': exercise.type,
              'kcal': exercise.kcal,
              'start_time': exercise.startTime,
              'end_time': exercise.endTime,
              'date': exercise.date,
            },
          )
          .toList(),
      pendingIds: snapshot.pendingCloudDeletes.exerciseRecordIds,
    );

    final trackingRows = <Map<String, dynamic>>[];
    final dates = {...snapshot.water.keys, ...snapshot.weight.keys};
    for (final date in dates) {
      trackingRows.add({
        'user_id': user.id,
        'date': date,
        'water_ml': snapshot.water[date] ?? 0,
        'weight_kg': snapshot.weight[date] ?? 0,
      });
    }
    if (trackingRows.isNotEmpty) {
      await client.from('daily_tracking').upsert(trackingRows);
    }
    final pendingDates = snapshot.pendingCloudDeletes.trackingDates.toList();
    if (pendingDates.isNotEmpty) {
      await client
          .from('daily_tracking')
          .delete()
          .eq('user_id', user.id)
          .inFilter('date', pendingDates);
    }

    if (versionedSyncEnabled) {
      await _syncWaterRecords(user, snapshot);
      await _syncWeightRecords(user, snapshot);
      await _syncTrainingSessions(user, snapshot);
    }

    // The compatibility path can still sync the phase-one tables before the
    // additive migration is deployed. Once enabled, all delete IDs are safe
    // to acknowledge because their tombstones were written first.
    return versionedSyncEnabled
        ? snapshot.pendingCloudDeletes
        : snapshot.pendingCloudDeletes.copyWith(waterRecordIds: const {});
  }

  Future<void> _syncOperations(
    User user,
    Iterable<SyncOperation> operations,
  ) async {
    final rows = operations
        .where(
          (operation) =>
              operation.userId == user.id &&
              operation.entityType != 'nutrition-ai',
        )
        .map(
          (operation) => {
            'operation_id': operation.operationId,
            'user_id': user.id,
            'entity_type': operation.entityType,
            'entity_id': operation.entityId,
            'action': operation.action.name,
            'payload': operation.payload,
          },
        )
        .toList();
    if (rows.isNotEmpty) {
      await client
          .from('client_operations')
          .upsert(rows, onConflict: 'user_id,operation_id');
    }
  }

  Future<void> _syncWaterRecords(User user, AppSnapshot snapshot) async {
    final rows = snapshot.waterRecords
        .map(
          (record) => {
            'id': record.id,
            'user_id': user.id,
            'date': record.date,
            'recorded_at': record.recordedAt?.toUtc().toIso8601String(),
            'amount_ml': record.amountMl,
            'is_legacy_aggregate': record.isLegacyAggregate,
          },
        )
        .toList();
    if (rows.isNotEmpty) {
      await client.from('water_intake_records').upsert(rows);
    }
    final ids = snapshot.pendingCloudDeletes.waterRecordIds;
    if (ids.isNotEmpty) {
      await client
          .from('water_intake_records')
          .delete()
          .eq('user_id', user.id)
          .inFilter('id', ids.toList());
    }
  }

  Future<void> _syncWeightRecords(User user, AppSnapshot snapshot) async {
    final rows = snapshot.weight.entries
        .map(
          (entry) => {
            'id': 'legacy_weight_${user.id}_${entry.key}',
            'user_id': user.id,
            'date': entry.key,
            'weight_kg': entry.value,
          },
        )
        .toList();
    if (rows.isNotEmpty) {
      await client.from('body_weight_logs').upsert(rows);
    }
  }

  Future<void> _syncTrainingSessions(User user, AppSnapshot snapshot) async {
    final rows = snapshot.training
        .map(
          (session) => {
            'id': session.id,
            'user_id': user.id,
            'name': session.name,
            'date': session.date,
            'exercises': session.exercises
                .map((exercise) => exercise.toJson())
                .toList(),
          },
        )
        .toList();
    if (rows.isNotEmpty) {
      await client.from('training_sessions').upsert(rows);
    }
  }

  Future<void> _upsertTombstones(User user, PendingCloudDeletes pending) async {
    final rows = <Map<String, dynamic>>[];
    void add(String entityType, Iterable<String> ids) {
      for (final id in ids) {
        rows.add({
          'id': '$entityType:$id',
          'user_id': user.id,
          'entity_type': entityType,
          'entity_id': id,
          'deleted_at': DateTime.now().toUtc().toIso8601String(),
        });
      }
    }

    add('food_dictionary', pending.foodIds);
    add('diet_logs', pending.dietRecordIds);
    add('exercise_logs', pending.exerciseRecordIds);
    add('water_intake_records', pending.waterRecordIds);
    if (rows.isNotEmpty) {
      await client.from('sync_tombstones').upsert(rows);
    }
  }

  Future<void> _syncTable<T>({
    required String table,
    required User user,
    required List<Map<String, dynamic>> localRows,
    required Set<String> pendingIds,
  }) async {
    if (localRows.isNotEmpty) {
      await client.from(table).upsert(localRows);
    }
    if (pendingIds.isNotEmpty) {
      await client
          .from(table)
          .delete()
          .eq('user_id', user.id)
          .inFilter('id', pendingIds.toList());
    }
  }

  @override
  Future<AppSnapshot?> fetchSnapshot(
    User user, {
    DateTime? lastSyncedAt,
  }) async {
    final useIncremental = versionedSyncEnabled && lastSyncedAt != null;
    final profile = await client
        .from('user_profiles')
        .select()
        .eq('id', user.id)
        .maybeSingle();
    final foodsQuery = client
        .from('food_dictionary')
        .select()
        .eq('user_id', user.id);
    final consumedQuery = client
        .from('diet_logs')
        .select()
        .eq('user_id', user.id);
    final exercisesQuery = client
        .from('exercise_logs')
        .select()
        .eq('user_id', user.id);
    final trackingQuery = client
        .from('daily_tracking')
        .select()
        .eq('user_id', user.id);
    if (useIncremental) {
      final cursor = lastSyncedAt.toUtc().toIso8601String();
      foodsQuery.gt('updated_at', cursor);
      consumedQuery.gt('updated_at', cursor);
      exercisesQuery.gt('updated_at', cursor);
      trackingQuery.gt('updated_at', cursor);
    }
    final foods = await foodsQuery;
    final consumed = await consumedQuery;
    final exercises = await exercisesQuery;
    final tracking = await trackingQuery;

    List<Map<String, dynamic>> waterRecords = const [];
    List<Map<String, dynamic>> bodyWeights = const [];
    List<Map<String, dynamic>> trainingSessions = const [];
    List<Map<String, dynamic>> tombstones = const [];
    Set<String> tombstoneKeys = const {};
    if (versionedSyncEnabled) {
      final waterQuery = client
          .from('water_intake_records')
          .select()
          .eq('user_id', user.id);
      final weightQuery = client
          .from('body_weight_logs')
          .select()
          .eq('user_id', user.id);
      final tombstoneQuery = client
          .from('sync_tombstones')
          .select('entity_type, entity_id')
          .eq('user_id', user.id);
      final trainingQuery = client
          .from('training_sessions')
          .select()
          .eq('user_id', user.id);
      if (useIncremental) {
        final cursor = lastSyncedAt.toUtc().toIso8601String();
        waterQuery.gt('updated_at', cursor);
        weightQuery.gt('updated_at', cursor);
        tombstoneQuery.gt('updated_at', cursor);
        trainingQuery.gt('updated_at', cursor);
      }
      waterRecords = List<Map<String, dynamic>>.from(await waterQuery);
      bodyWeights = List<Map<String, dynamic>>.from(await weightQuery);
      trainingSessions = List<Map<String, dynamic>>.from(await trainingQuery);
      tombstones = List<Map<String, dynamic>>.from(await tombstoneQuery);
      tombstoneKeys = {
        for (final row in tombstones)
          '${row['entity_type']}:${row['entity_id']}',
      };
    }

    final trainingJson = profile?['training_data'];
    final legacyTraining = decodeLegacyTrainingData(trainingJson);
    final tombstoneDeletes = PendingCloudDeletes(
      foodIds: {
        for (final row in tombstonesForType(tombstones, 'food_dictionary'))
          row['entity_id'].toString(),
      },
      dietRecordIds: {
        for (final row in tombstonesForType(tombstones, 'diet_logs'))
          row['entity_id'].toString(),
      },
      exerciseRecordIds: {
        for (final row in tombstonesForType(tombstones, 'exercise_logs'))
          row['entity_id'].toString(),
      },
      waterRecordIds: {
        for (final row in tombstonesForType(tombstones, 'water_intake_records'))
          row['entity_id'].toString(),
      },
    );
    return AppSnapshot.fromJson({
      'gender': profile?['gender'],
      'birthYear': profile?['birth_year'],
      'birthMonth': profile?['birth_month'],
      'birthDay': profile?['birth_day'],
      'height': profile?['height'],
      'currentWeight': profile?['current_weight'],
      'targetP': profile?['target_p'],
      'targetC': profile?['target_c'],
      'targetF': profile?['target_f'],
      'targetKcal': profile?['target_kcal'],
      'foods': foods
          .where(
            (row) => !tombstoneKeys.contains('food_dictionary:${row['id']}'),
          )
          .map(
            (row) => {
              'id': row['id'],
              'name': row['name'],
              'protein': row['protein'],
              'carbs': row['carbs'],
              'fat': row['fat'],
              'calories': row['calories'],
              'category': row['category'],
              'unit': row['unit'],
              'weightPerUnit': row['weight_per_unit'],
            },
          )
          .toList(),
      'consumed': consumed
          .where((row) => !tombstoneKeys.contains('diet_logs:${row['id']}'))
          .map(
            (row) => {
              'id': row['id'],
              'name': row['food_name'],
              'p': row['p'],
              'c': row['c'],
              'f': row['f'],
              'kcal': row['kcal'],
              'mealType': row['meal_type'],
              'date': row['date'],
              'amount': row['amount'],
              'unit': row['unit'],
            },
          )
          .toList(),
      'exercises': exercises
          .where((row) => !tombstoneKeys.contains('exercise_logs:${row['id']}'))
          .map(
            (row) => {
              'id': row['id'],
              'type': row['type'],
              'kcal': row['kcal'],
              'startTime': row['start_time'],
              'endTime': row['end_time'],
              'date': row['date'],
            },
          )
          .toList(),
      'training': trainingSessions.isNotEmpty
          ? trainingSessions
                .map(
                  (row) => {
                    'id': row['id'],
                    'name': row['name'],
                    'date': row['date'],
                    'exercises': row['exercises'],
                  },
                )
                .toList()
          : (legacyTraining is List ? legacyTraining : const []),
      'waterRecords': waterRecords
          .where(
            (row) =>
                !tombstoneKeys.contains('water_intake_records:${row['id']}'),
          )
          .map(
            (row) => {
              'id': row['id'],
              'date': row['date'],
              'recordedAt': row['recorded_at'],
              'amountMl': row['amount_ml'],
              'isLegacyAggregate': row['is_legacy_aggregate'],
            },
          )
          .toList(),
      'water': {
        for (final row in tracking) row['date'].toString(): row['water_ml'],
      },
      'weight': {
        for (final row in (bodyWeights.isEmpty ? tracking : bodyWeights))
          row['date'].toString(): row['weight_kg'],
      },
      'pendingCloudDeletes': tombstoneDeletes.toJson(),
    });
  }
}

Object? decodeLegacyTrainingData(Object? value) {
  if (value is! String) return value;
  if (value.trim().isEmpty) return const [];
  try {
    final decoded = jsonDecode(value);
    return decoded is List ? decoded : const [];
  } on FormatException {
    return const [];
  }
}

List<Map<String, dynamic>> tombstonesForType(
  Iterable<Map<String, dynamic>> rows,
  String type,
) => rows.where((row) => row['entity_type'] == type).toList();
