import 'package:flutter_test/flutter_test.dart';
import 'package:goat_app/exercise_catalog.dart';
import 'package:goat_app/main.dart' show FoodItem, SetRecord, TrainingExercise, TrainingSession;

void main() {
  test('食物数据序列化后保留营养与单位信息', () {
    final food = FoodItem(
      id: 'food-1',
      name: '鸡胸肉',
      protein: 31,
      carbs: 0,
      fat: 3.6,
      calories: 165,
      category: '肉类',
      unit: '块',
      weightPerUnit: 120,
    );

    final restored = FoodItem.fromJson(food.toJson());

    expect(restored.id, 'food-1');
    expect(restored.name, '鸡胸肉');
    expect(restored.protein, 31);
    expect(restored.unit, '块');
    expect(restored.weightPerUnit, 120);
  });

  test('训练课数据序列化后保留训练容量', () {
    final session = TrainingSession(
      id: 'session-1',
      name: '上肢训练',
      date: '2026-07-11',
      exercises: [
        TrainingExercise(
          exerciseName: '杠铃平板卧推',
          bodyPart: '胸部',
          sets: [SetRecord(weight: 60, reps: 8), SetRecord(weight: 60, reps: 8)],
        ),
      ],
    );

    final restored = TrainingSession.fromJson(session.toJson());

    expect(restored.sessionVolume, 960);
    expect(restored.exercises.single.exerciseName, '杠铃平板卧推');
  });

  test('动作库覆盖主要部位和多种器械类型', () {
    expect(exerciseCatalog.length, greaterThanOrEqualTo(140));
    expect(exerciseCatalog.map((exercise) => exercise.bodyPart).toSet(), containsAll(exerciseBodyParts));
    expect(exerciseCatalog.map((exercise) => exercise.equipment).toSet(), containsAll(['徒手', '自由重量', '器械', '绳索', '壶铃']));
  });
}
