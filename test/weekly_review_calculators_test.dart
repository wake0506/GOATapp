import 'package:flutter_test/flutter_test.dart';
import 'package:goat_app/features/analytics/models/effective_set_summary.dart';
import 'package:goat_app/features/analytics/models/weight_trend.dart';
import 'package:goat_app/features/analytics/models/weekly_review.dart';
import 'package:goat_app/features/analytics/services/weekly_nutrition_review_calculator.dart';
import 'package:goat_app/features/analytics/services/weekly_training_review_calculator.dart';
import 'package:goat_app/features/training/domain/training_session_state.dart';
import 'package:goat_app/models/consumed_record.dart';
import 'package:goat_app/models/training.dart';

void main() {
  const trainingCalculator = WeeklyTrainingReviewCalculator();
  const nutritionCalculator = WeeklyNutritionReviewCalculator();
  final anchor = DateTime(2026, 7, 21);

  group('weekly training review', () {
    test('handles no training without inventing comparisons', () {
      final review = trainingCalculator.calculate(
        completedSessions: const [],
        anchorDate: anchor,
      );
      expect(review.trainingDays, 0);
      expect(review.sessionCount, 0);
      expect(review.effectiveSets, 0);
      expect(review.previousEffectiveSets, isNull);
      expect(review.dataQuality, WeeklyReviewDataQuality.insufficient);
    });

    test('reuses effective sets, groups days and compares previous period', () {
      final review = trainingCalculator.calculate(
        completedSessions: [
          _session('2026-07-21', 'chest', [
            _set(10, TrainingSetType.warmup),
            _set(10, TrainingSetType.working),
            _set(8, TrainingSetType.drop),
          ]),
          _session('2026-07-19', 'back', [_set(10, TrainingSetType.working)]),
          _session('2026-07-14', 'legs', [_set(5, TrainingSetType.working)]),
        ],
        anchorDate: anchor,
      );
      expect(review.trainingDays, 2);
      expect(review.sessionCount, 2);
      expect(review.completedSets, 4);
      expect(review.effectiveSets, 3);
      expect(review.muscleGroups, hasLength(2));
      expect(review.topTrainedGroup, AnalyticsMuscleGroup.chest);
      expect(review.previousSessionCount, 1);
      expect(review.previousEffectiveSets, 1);
    });

    test('keeps legacy sets and reports partial quality', () {
      final review = trainingCalculator.calculate(
        completedSessions: [
          TrainingSession(
            id: 'legacy',
            name: 'Legacy',
            date: '2026-07-21',
            exercises: [
              TrainingExercise(
                exerciseId: null,
                exerciseName: 'Legacy press',
                bodyPart: 'chest',
                sets: [SetRecord(reps: 10)],
              ),
            ],
          ),
        ],
        anchorDate: anchor,
      );
      expect(review.effectiveSets, 1);
      expect(review.dataQuality, WeeklyReviewDataQuality.partial);
      expect(review.reasons, contains(WeeklyReviewReason.legacyTrainingData));
    });
  });

  group('weekly nutrition review', () {
    test('handles zero recorded days and unavailable weight trend', () {
      final review = nutritionCalculator.calculate(
        records: const [],
        weightRecords: const [],
        anchorDate: anchor,
      );
      expect(review.recordedDays, 0);
      expect(review.averageCalories, isNull);
      expect(
        review.weightTrend.dataQuality,
        WeightTrendDataQuality.unavailable,
      );
      expect(review.dataQuality, WeeklyReviewDataQuality.insufficient);
    });

    test('averages only three recorded days and discloses partial logging', () {
      final review = nutritionCalculator.calculate(
        records: [
          _food('2026-07-21', kcal: 2000, p: 100, c: 200, f: 60),
          _food('2026-07-20', kcal: 2200, p: 120, c: 220, f: 70),
          _food('2026-07-18', kcal: 1800, p: 80, c: 180, f: 50),
        ],
        weightRecords: const [],
        anchorDate: anchor,
      );
      expect(review.recordedDays, 3);
      expect(review.averageCalories, 2000);
      expect(review.averageProtein, 100);
      expect(review.averageCarbs, 200);
      expect(review.averageFat, 60);
      expect(review.dataQuality, WeeklyReviewDataQuality.partial);
      expect(
        review.reasons,
        contains(WeeklyReviewReason.partialNutritionLogging),
      );
    });

    test('reports a complete week, trend reuse and valid prior comparison', () {
      final current = [
        for (var day = 15; day <= 21; day++)
          _food(
            '2026-07-${day.toString().padLeft(2, '0')}',
            kcal: 2100,
            p: 140,
            c: 210,
            f: 65,
          ),
      ];
      final previous = [
        for (var day = 8; day <= 14; day++)
          _food(
            '2026-07-${day.toString().padLeft(2, '0')}',
            kcal: 2200,
            p: 130,
            c: 220,
            f: 70,
          ),
      ];
      final weights = [
        for (var day = 1; day <= 21; day++)
          WeightRecord(
            recordedAt: DateTime(2026, 7, day),
            weightKg: 70 + day / 10,
          ),
      ];
      final review = nutritionCalculator.calculate(
        records: [...current, ...previous],
        weightRecords: weights,
        anchorDate: anchor,
      );
      expect(review.recordedDays, 7);
      expect(review.averageCalories, 2100);
      expect(review.previousAverageCalories, 2200);
      expect(review.weightTrend.change7dKg, closeTo(0.7, 0.000001));
      expect(review.dataQuality, WeeklyReviewDataQuality.complete);
      expect(review.reasons, contains(WeeklyReviewReason.weightTrendAvailable));
    });

    test(
      'does not compare periods when either side has fewer than three days',
      () {
        final review = nutritionCalculator.calculate(
          records: [
            _food('2026-07-21', kcal: 2000),
            _food('2026-07-20', kcal: 2000),
            _food('2026-07-19', kcal: 2000),
            _food('2026-07-14', kcal: 2300),
            _food('2026-07-13', kcal: 2300),
          ],
          weightRecords: const [],
          anchorDate: anchor,
        );
        expect(review.previousAverageCalories, isNull);
      },
    );
  });
}

TrainingSession _session(String date, String bodyPart, List<SetRecord> sets) =>
    TrainingSession(
      id: '$date-$bodyPart',
      name: 'Training',
      date: date,
      exercises: [
        TrainingExercise(
          exerciseId: bodyPart,
          exerciseName: bodyPart,
          bodyPart: bodyPart,
          sets: sets,
        ),
      ],
    );

SetRecord _set(int reps, TrainingSetType type) => SetRecord(
  weight: 50,
  reps: reps,
  setType: type,
  completedAt: DateTime(2026, 7, 21),
);

ConsumedRecord _food(
  String date, {
  required double kcal,
  double p = 0,
  double c = 0,
  double f = 0,
}) => ConsumedRecord(
  id: '$date-$kcal',
  name: 'Food',
  p: p,
  c: c,
  f: f,
  kcal: kcal,
  mealType: '餐',
  date: date,
);
