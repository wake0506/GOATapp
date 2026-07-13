import 'consumed_record.dart';
import 'exercise_record.dart';
import 'food_item.dart';
import 'json_value.dart';
import 'pending_cloud_deletes.dart';
import 'sync_cursor.dart';
import 'sync_operation.dart';
import 'training.dart';
import 'water_intake_record.dart';

class AppSnapshot {
  final String gender;
  final int birthYear;
  final int birthMonth;
  final int birthDay;
  final double height;
  final double currentWeight;
  final List<String> searchHistory;
  final double targetP;
  final double targetC;
  final double targetF;
  final double targetKcal;
  final int resetHour;
  final String aiDismissedDate;
  final List<FoodItem> foods;
  final List<ConsumedRecord> consumed;
  final List<ExerciseRecord> exercises;
  final List<TrainingSession> training;
  final List<WaterIntakeRecord> waterRecords;
  final Map<String, int> water;
  final Map<String, double> weight;
  final PendingCloudDeletes pendingCloudDeletes;
  final List<SyncOperation> syncOperations;
  final SyncCursor syncCursor;

  const AppSnapshot({
    required this.gender,
    required this.birthYear,
    required this.birthMonth,
    required this.birthDay,
    required this.height,
    required this.currentWeight,
    required this.searchHistory,
    required this.targetP,
    required this.targetC,
    required this.targetF,
    required this.targetKcal,
    required this.resetHour,
    required this.aiDismissedDate,
    required this.foods,
    required this.consumed,
    required this.exercises,
    required this.training,
    required this.waterRecords,
    required this.water,
    required this.weight,
    this.pendingCloudDeletes = const PendingCloudDeletes.empty(),
    this.syncOperations = const [],
    this.syncCursor = const SyncCursor.empty(),
  });

  factory AppSnapshot.empty() => AppSnapshot(
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
    foods: const [],
    consumed: const [],
    exercises: const [],
    training: const [],
    waterRecords: const [],
    water: const {},
    weight: const {},
    pendingCloudDeletes: const PendingCloudDeletes.empty(),
    syncOperations: const [],
    syncCursor: const SyncCursor.empty(),
  );

  bool get hasData =>
      foods.isNotEmpty ||
      consumed.isNotEmpty ||
      exercises.isNotEmpty ||
      training.isNotEmpty ||
      waterRecords.isNotEmpty ||
      water.isNotEmpty ||
      weight.isNotEmpty ||
      searchHistory.isNotEmpty ||
      syncOperations.isNotEmpty;

  Map<String, dynamic> toJson() => {
    'gender': gender,
    'birthYear': birthYear,
    'birthMonth': birthMonth,
    'birthDay': birthDay,
    'height': height,
    'currentWeight': currentWeight,
    'searchHistory': searchHistory,
    'targetP': targetP,
    'targetC': targetC,
    'targetF': targetF,
    'targetKcal': targetKcal,
    'resetHour': resetHour,
    'aiDismissedDate': aiDismissedDate,
    'foods': foods.map((e) => e.toJson()).toList(),
    'consumed': consumed.map((e) => e.toJson()).toList(),
    'exercises': exercises.map((e) => e.toJson()).toList(),
    'training': training.map((e) => e.toJson()).toList(),
    'waterRecords': waterRecords.map((e) => e.toJson()).toList(),
    'water': water,
    'weight': weight,
    'pendingCloudDeletes': pendingCloudDeletes.toJson(),
    'syncOperations': syncOperations.map((e) => e.toJson()).toList(),
    'syncCursor': syncCursor.toJson(),
  };

  factory AppSnapshot.fromJson(Map<String, dynamic> json) {
    final legacyWater = _intMap(json['water']);
    final decodedWater = _objects(
      json['waterRecords'],
    ).map(WaterIntakeRecord.fromJson).toList();
    final decodedDates = decodedWater.map((record) => record.date).toSet();
    final migratedWater = migrateWaterAggregates(
      legacyWater,
    ).where((record) => !decodedDates.contains(record.date));
    final waterRecords = [...decodedWater, ...migratedWater];
    return AppSnapshot(
      gender: stringValue(json['gender'], '男'),
      birthYear: intValue(json['birthYear'], 2000),
      birthMonth: intValue(json['birthMonth'], 1),
      birthDay: intValue(json['birthDay'], 1),
      height: doubleValue(json['height'], 175),
      currentWeight: doubleValue(json['currentWeight'], 70),
      searchHistory: (json['searchHistory'] as List<dynamic>? ?? const [])
          .map((e) => e.toString())
          .toList(),
      targetP: doubleValue(json['targetP'], 150),
      targetC: doubleValue(json['targetC'], 200),
      targetF: doubleValue(json['targetF'], 60),
      targetKcal: doubleValue(json['targetKcal'], 2000),
      resetHour: intValue(json['resetHour']),
      aiDismissedDate: stringValue(json['aiDismissedDate']),
      foods: _objects(json['foods']).map(FoodItem.fromJson).toList(),
      consumed: _objects(
        json['consumed'],
      ).map(ConsumedRecord.fromJson).toList(),
      exercises: _objects(
        json['exercises'],
      ).map(ExerciseRecord.fromJson).toList(),
      training: _objects(
        json['training'],
      ).map(TrainingSession.fromJson).toList(),
      waterRecords: waterRecords,
      water: waterTotals(waterRecords),
      weight: _doubleMap(json['weight']),
      pendingCloudDeletes: PendingCloudDeletes.fromJson(
        json['pendingCloudDeletes'],
      ),
      syncOperations: _objects(
        json['syncOperations'],
      ).map(SyncOperation.fromJson).toList(),
      syncCursor: SyncCursor.fromJson(json['syncCursor']),
    );
  }

  AppSnapshot merge(AppSnapshot other) => AppSnapshot(
    gender: gender == '男' && other.gender != '男' ? other.gender : gender,
    birthYear: birthYear == 2000 ? other.birthYear : birthYear,
    birthMonth: birthMonth == 1 ? other.birthMonth : birthMonth,
    birthDay: birthDay == 1 ? other.birthDay : birthDay,
    height: height == 175 ? other.height : height,
    currentWeight: currentWeight == 70 ? other.currentWeight : currentWeight,
    searchHistory: _mergeStrings(searchHistory, other.searchHistory),
    targetP: targetP == 150 ? other.targetP : targetP,
    targetC: targetC == 200 ? other.targetC : targetC,
    targetF: targetF == 60 ? other.targetF : targetF,
    targetKcal: targetKcal == 2000 ? other.targetKcal : targetKcal,
    resetHour: resetHour == 0 ? other.resetHour : resetHour,
    aiDismissedDate: aiDismissedDate.isEmpty
        ? other.aiDismissedDate
        : aiDismissedDate,
    foods: _mergeById(foods, other.foods, (e) => e.id),
    consumed: _mergeById(consumed, other.consumed, (e) => e.id),
    exercises: _mergeById(exercises, other.exercises, (e) => e.id),
    training: _mergeById(training, other.training, (e) => e.id),
    waterRecords: _mergeById(waterRecords, other.waterRecords, (e) => e.id),
    water: waterTotals(
      _mergeById(waterRecords, other.waterRecords, (e) => e.id),
    ),
    weight: {...other.weight, ...weight},
    pendingCloudDeletes: pendingCloudDeletes.merge(other.pendingCloudDeletes),
    syncOperations: _mergeSyncOperations(syncOperations, other.syncOperations),
    syncCursor: _mergeCursors(syncCursor, other.syncCursor),
  );

  AppSnapshot applyDeletes(PendingCloudDeletes deletes) {
    if (deletes.isEmpty) return this;
    final foodIds = deletes.foodIds;
    final dietIds = deletes.dietRecordIds;
    final exerciseIds = deletes.exerciseRecordIds;
    final waterIds = deletes.waterRecordIds;
    final nextWaterRecords = waterRecords
        .where((record) => !waterIds.contains(record.id))
        .toList();
    return AppSnapshot(
      gender: gender,
      birthYear: birthYear,
      birthMonth: birthMonth,
      birthDay: birthDay,
      height: height,
      currentWeight: currentWeight,
      searchHistory: searchHistory,
      targetP: targetP,
      targetC: targetC,
      targetF: targetF,
      targetKcal: targetKcal,
      resetHour: resetHour,
      aiDismissedDate: aiDismissedDate,
      foods: foods.where((item) => !foodIds.contains(item.id)).toList(),
      consumed: consumed.where((item) => !dietIds.contains(item.id)).toList(),
      exercises: exercises
          .where((item) => !exerciseIds.contains(item.id))
          .toList(),
      training: training,
      waterRecords: nextWaterRecords,
      water: waterTotals(nextWaterRecords),
      weight: weight,
      pendingCloudDeletes: pendingCloudDeletes.without(deletes),
      syncOperations: syncOperations
          .where(
            (operation) =>
                !(operation.entityType == 'food_dictionary' &&
                    foodIds.contains(operation.entityId)) &&
                !(operation.entityType == 'diet_logs' &&
                    dietIds.contains(operation.entityId)) &&
                !(operation.entityType == 'exercise_logs' &&
                    exerciseIds.contains(operation.entityId)) &&
                !(operation.entityType == 'water_intake_records' &&
                    waterIds.contains(operation.entityId)),
          )
          .toList(),
      syncCursor: syncCursor,
    );
  }
}

List<Map<String, dynamic>> _objects(Object? value) {
  if (value is! List) return const [];
  return value
      .whereType<Map>()
      .map((e) => Map<String, dynamic>.from(e))
      .toList();
}

Map<String, int> _intMap(Object? value) {
  if (value is! Map) return {};
  return value.map((key, value) => MapEntry(key.toString(), intValue(value)));
}

Map<String, double> _doubleMap(Object? value) {
  if (value is! Map) return {};
  return value.map(
    (key, value) => MapEntry(key.toString(), doubleValue(value)),
  );
}

List<String> _mergeStrings(List<String> left, List<String> right) {
  return {...right, ...left}.toList();
}

List<T> _mergeById<T>(List<T> left, List<T> right, String Function(T) idOf) {
  final merged = <String, T>{};
  for (final value in right) {
    merged[idOf(value)] = value;
  }
  for (final value in left) {
    merged[idOf(value)] = value;
  }
  return merged.values.toList();
}

List<SyncOperation> _mergeSyncOperations(
  List<SyncOperation> left,
  List<SyncOperation> right,
) {
  final merged = <String, SyncOperation>{};
  for (final operation in right) {
    merged[operation.operationId] = operation;
  }
  for (final operation in left) {
    merged[operation.operationId] = operation;
  }
  return merged.values.toList();
}

SyncCursor _mergeCursors(SyncCursor left, SyncCursor right) {
  final leftAt = left.lastSyncedAt;
  final rightAt = right.lastSyncedAt;
  if (leftAt == null) return right;
  if (rightAt == null || !rightAt.isAfter(leftAt)) return left;
  return right;
}
