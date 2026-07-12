import 'dart:convert';

import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/app_snapshot.dart';
import '../models/consumed_record.dart';
import '../models/exercise_record.dart';
import '../models/food_item.dart';
import '../models/pending_cloud_deletes.dart';

class CloudSyncService {
  final SupabaseClient client;

  CloudSyncService(this.client);

  Future<PendingCloudDeletes> syncSnapshot({
    required User user,
    required AppSnapshot snapshot,
  }) async {
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

    return snapshot.pendingCloudDeletes;
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

  Future<AppSnapshot?> fetchSnapshot(User user) async {
    final profile = await client
        .from('user_profiles')
        .select()
        .eq('id', user.id)
        .maybeSingle();
    final foods = await client
        .from('food_dictionary')
        .select()
        .eq('user_id', user.id);
    final consumed = await client
        .from('diet_logs')
        .select()
        .eq('user_id', user.id);
    final exercises = await client
        .from('exercise_logs')
        .select()
        .eq('user_id', user.id);
    final tracking = await client
        .from('daily_tracking')
        .select()
        .eq('user_id', user.id);

    final trainingJson = profile?['training_data'];
    final training = trainingJson is String
        ? jsonDecode(trainingJson)
        : trainingJson;
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
      'training': training is List ? training : const [],
      'water': {
        for (final row in tracking) row['date'].toString(): row['water_ml'],
      },
      'weight': {
        for (final row in tracking) row['date'].toString(): row['weight_kg'],
      },
    });
  }
}
