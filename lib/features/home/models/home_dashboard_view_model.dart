import '../../../models/consumed_record.dart';
import '../../../models/daily_macro_stats.dart';
import '../../analytics/models/weight_trend.dart';

class HomeMealSummary {
  const HomeMealSummary({
    required this.mealType,
    required this.displayName,
    required this.kcal,
    required this.protein,
    required this.carbs,
    required this.fat,
    required this.foodNames,
  });

  final String mealType;
  final String displayName;
  final double kcal;
  final double protein;
  final double carbs;
  final double fat;
  final List<String> foodNames;

  bool get hasRecords => foodNames.isNotEmpty;
}

class HomeDashboardViewModel {
  const HomeDashboardViewModel({
    required this.stats,
    required this.targetKcal,
    required this.targetProtein,
    required this.targetCarbs,
    required this.targetFat,
    required this.waterMl,
    required this.waterGoalMl,
    required this.weight,
    required this.previousWeight,
    required this.meals,
    this.weightTrend,
  });

  final DailyMacroStats stats;
  final double targetKcal;
  final double targetProtein;
  final double targetCarbs;
  final double targetFat;
  final int waterMl;
  final int waterGoalMl;
  final double weight;
  final double? previousWeight;
  final List<HomeMealSummary> meals;
  final WeightTrend? weightTrend;

  double get netKcal => stats.kcalIn - stats.burn;

  double get waterProgress =>
      waterGoalMl <= 0 ? 0 : (waterMl / waterGoalMl).clamp(0, 1).toDouble();

  double? get weightDelta =>
      previousWeight == null || weight <= 0 ? null : weight - previousWeight!;

  factory HomeDashboardViewModel.fromData({
    required DailyMacroStats stats,
    required double targetKcal,
    required double targetProtein,
    required double targetCarbs,
    required double targetFat,
    required int waterMl,
    required int waterGoalMl,
    required double weight,
    required double? previousWeight,
    required Iterable<ConsumedRecord> consumed,
    WeightTrend? weightTrend,
  }) {
    final records = consumed.toList(growable: false);
    const mealDefinitions = [
      ('早餐', '早餐'),
      ('午餐', '午餐'),
      ('晚餐', '晚餐'),
      ('加餐', '加餐'),
    ];

    return HomeDashboardViewModel(
      stats: stats,
      targetKcal: targetKcal,
      targetProtein: targetProtein,
      targetCarbs: targetCarbs,
      targetFat: targetFat,
      waterMl: waterMl,
      waterGoalMl: waterGoalMl,
      weight: weight,
      previousWeight: previousWeight,
      weightTrend: weightTrend,
      meals: mealDefinitions
          .map((definition) {
            final mealRecords = records
                .where((record) {
                  if (definition.$1 == '加餐') {
                    return record.mealType != '早餐' &&
                        record.mealType != '午餐' &&
                        record.mealType != '晚餐';
                  }
                  return record.mealType == definition.$1;
                })
                .toList(growable: false);
            return HomeMealSummary(
              mealType: definition.$1,
              displayName: definition.$2,
              kcal: mealRecords.fold(0, (sum, record) => sum + record.kcal),
              protein: mealRecords.fold(0, (sum, record) => sum + record.p),
              carbs: mealRecords.fold(0, (sum, record) => sum + record.c),
              fat: mealRecords.fold(0, (sum, record) => sum + record.f),
              foodNames: mealRecords
                  .map((record) => record.name)
                  .take(2)
                  .toList(),
            );
          })
          .toList(growable: false),
    );
  }
}
