import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:goat_app/data/builtin_food_database.dart';
import 'package:goat_app/features/tracking/weight_picker_sheet.dart';
import 'package:goat_app/features/training/exercise_time.dart';
import 'package:goat_app/features/voice_entry/voice_entry_sheet.dart';
import 'package:goat_app/features/water/water_tracking_page.dart';
import 'package:goat_app/models/app_snapshot.dart';
import 'package:goat_app/models/pending_cloud_deletes.dart';
import 'package:goat_app/models/water_intake_record.dart';
import 'package:goat_app/repositories/water_tracking_repository.dart';

class _FakeWaterRepository implements WaterTrackingRepository {
  final List<WaterIntakeRecord> records;

  _FakeWaterRepository(this.records);

  @override
  List<WaterIntakeRecord> waterRecordsForDate(String date) =>
      records.where((record) => record.date == date).toList();

  @override
  Future<void> addWaterRecord(WaterIntakeRecord record) async =>
      records.add(record);

  @override
  Future<void> updateWaterRecord(WaterIntakeRecord record) async {
    final index = records.indexWhere((item) => item.id == record.id);
    records[index] = record;
  }

  @override
  Future<void> deleteWaterRecord(String recordId) async =>
      records.removeWhere((record) => record.id == recordId);
}

WaterIntakeRecord _water(String id, int amount, String time) {
  final recordedAt = DateTime.parse('2026-07-13T$time:00');
  return WaterIntakeRecord(
    id: id,
    date: '2026-07-13',
    recordedAt: recordedAt,
    amountMl: amount,
  );
}

void main() {
  test('weight saves and displays two decimal places', () {
    expect(weightFromParts(71, 25), 71.25);
    expect(formatWeightValue(71), '71.00 kg');
    expect(formatWeightValue(71.25), '71.25 kg');
  });

  test(
    'weight picker updates today and preserves current weight for history edits',
    () {
      final today = applyWeightChange(
        dailyWeight: {'2026-07-12': 70.5},
        date: '2026-07-13',
        today: '2026-07-13',
        currentWeight: 70.5,
        value: 71.25,
      );
      expect(today.currentWeight, 71.25);
      expect(today.dailyWeight['2026-07-13'], 71.25);

      final history = applyWeightChange(
        dailyWeight: today.dailyWeight,
        date: '2026-07-12',
        today: '2026-07-13',
        currentWeight: today.currentWeight,
        value: 69.75,
      );
      expect(history.currentWeight, 71.25);
      expect(history.dailyWeight['2026-07-12'], 69.75);
    },
  );

  testWidgets('weight picker shows integer and two decimal wheels', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(home: WeightPickerSheet(initialWeight: 71.25)),
    );
    expect(find.text('71 | 25 kg'), findsOneWidget);
    expect(find.byType(CupertinoPicker), findsNWidgets(2));
  });

  test('AI meal button cycles breakfast, lunch, dinner, snack', () {
    expect(nextMealType('早餐'), '午餐');
    expect(nextMealType('午餐'), '晚餐');
    expect(nextMealType('晚餐'), '加餐');
    expect(nextMealType('加餐'), '早餐');
  });

  test('built-in food database covers original categories', () {
    final foods = buildBuiltinFoodDatabase();
    expect(
      foods.map((food) => food.category).toSet(),
      containsAll(['主食', '肉蛋奶', '蔬菜', '水果', '饮料', '其他']),
    );
    expect(foods.map((food) => food.name), containsAll(['米饭', '鸡蛋', '苹果']));
  });

  test('keyboard exercise time validates and computes normal duration', () {
    expect(parse24HourTime('11:41'), 701);
    expect(parse24HourTime('24:00'), isNull);
    expect(parse24HourTime('11:60'), isNull);
    final result = calculateExerciseEndTime(
      startTime: '11:41',
      hours: 0,
      minutes: 45,
    );
    expect(result.value, '12:26');
    expect(result.isNextDay, isFalse);
  });

  test('exercise duration crosses midnight', () {
    final result = calculateExerciseEndTime(
      startTime: '23:50',
      hours: 0,
      minutes: 36,
    );
    expect(result.value, '00:26');
    expect(result.isNextDay, isTrue);
    expect(
      () => calculateExerciseEndTime(startTime: '11:41', hours: 0, minutes: 0),
      throwsFormatException,
    );
  });

  test('water totals are derived from individual records', () {
    final records = [_water('a', 300, '08:20'), _water('b', 250, '10:45')];
    expect(waterTotals(records)['2026-07-13'], 550);
    expect(waterTotals(records)['2026-07-12'], isNull);
  });

  test('legacy aggregate migrates without inventing a time', () {
    final migrated = migrateWaterAggregates({'2026-07-13': 1850});
    expect(migrated.single.id, 'legacy_water_2026-07-13');
    expect(migrated.single.amountMl, 1850);
    expect(migrated.single.isLegacyAggregate, isTrue);
    expect(migrated.single.recordedAt, isNull);
  });

  test('old snapshot water aggregate remains readable as a record', () {
    final snapshot = AppSnapshot.fromJson({
      'water': {'2026-07-13': 1850},
    });
    expect(snapshot.waterRecords.single.amountMl, 1850);
    expect(snapshot.water['2026-07-13'], 1850);
  });

  test('water record serialization preserves id and timestamp', () {
    final original = _water('water-1', 500, '20:15');
    final restored = WaterIntakeRecord.fromJson(original.toJson());
    expect(restored.id, 'water-1');
    expect(restored.amountMl, 500);
    expect(restored.recordedAt, original.recordedAt);
  });

  testWidgets('water page adds, edits, deletes and recomputes total', (
    tester,
  ) async {
    final repository = _FakeWaterRepository([_water('a', 300, '08:20')]);
    await tester.pumpWidget(
      MaterialApp(
        home: WaterTrackingPage(
          date: '2026-07-13',
          repository: repository,
          onTotalChanged: (_) {},
        ),
      ),
    );
    expect(find.text('300 ml'), findsNWidgets(2));
    await tester.tap(find.text('记录饮水'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('500 ml'));
    await tester.tap(find.text('添加记录'));
    await tester.pumpAndSettle();
    expect(repository.records, hasLength(2));
    expect(
      repository.records.fold(0, (sum, record) => sum + record.amountMl),
      800,
    );

    final edit = find.byTooltip('编辑饮水');
    expect(edit, findsNWidgets(2));
    await tester.tap(edit.first);
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField).first, '250');
    await tester.tap(find.text('保存修改'));
    await tester.pumpAndSettle();
    expect(repository.records.map((record) => record.amountMl), contains(250));

    final delete = find.byTooltip('删除饮水');
    expect(delete, findsNWidgets(2));
    await tester.tap(delete.first);
    await tester.pumpAndSettle();
    expect(repository.records, hasLength(1));
  });

  testWidgets('legacy water displays history summary without a fake time', (
    tester,
  ) async {
    final repository = _FakeWaterRepository([
      const WaterIntakeRecord(
        id: 'legacy-water',
        date: '2026-07-13',
        recordedAt: null,
        amountMl: 300,
        isLegacyAggregate: true,
      ),
    ]);
    await tester.pumpWidget(
      MaterialApp(
        home: WaterTrackingPage(
          date: '2026-07-13',
          repository: repository,
          onTotalChanged: (_) {},
        ),
      ),
    );
    expect(find.text('历史汇总'), findsOneWidget);
    expect(find.text('00:00'), findsNothing);
  });

  test('water deletion uses an explicit pending delete id', () {
    final pending = const PendingCloudDeletes.empty().copyWith(
      waterRecordIds: {'water-1'},
    );
    expect(pending.waterRecordIds, contains('water-1'));
    expect(pending.isEmpty, isFalse);
    expect(pending.without(pending).waterRecordIds, isEmpty);
  });
}
