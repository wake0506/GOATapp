import '../models/consumed_record.dart';
import '../models/diet_copy_plan.dart';
import '../models/recent_food_suggestion.dart';

class NutritionQuickAccessService {
  const NutritionQuickAccessService();

  List<RecentFoodSuggestion> recentFoods({
    required List<ConsumedRecord> records,
    String? mealType,
    int limit = 12,
  }) {
    final grouped = <String, RecentFoodSuggestion>{};
    for (var index = 0; index < records.length; index++) {
      final record = records[index];
      final key = normalize(record.name);
      if (key.isEmpty) continue;
      final previous = grouped[key];
      final candidate = RecentFoodSuggestion(
        normalizedKey: key,
        displayName: record.name.trim(),
        amount: record.amount,
        unit: record.unit,
        kcal: record.kcal,
        protein: record.p,
        carbs: record.c,
        fat: record.f,
        lastMealType: record.mealType,
        lastUsedAt: _dateOrFallback(record.date, index),
        usageCount: (previous?.usageCount ?? 0) + 1,
      );
      if (previous == null ||
          candidate.lastUsedAt.isAfter(previous.lastUsedAt)) {
        grouped[key] = candidate;
      } else {
        grouped[key] = RecentFoodSuggestion(
          normalizedKey: previous.normalizedKey,
          displayName: previous.displayName,
          amount: previous.amount,
          unit: previous.unit,
          kcal: previous.kcal,
          protein: previous.protein,
          carbs: previous.carbs,
          fat: previous.fat,
          lastMealType: previous.lastMealType,
          lastUsedAt: previous.lastUsedAt,
          usageCount: candidate.usageCount,
        );
      }
    }

    final values = grouped.values.toList()
      ..sort((left, right) {
        final mealScore =
            (right.lastMealType == mealType ? 1 : 0) -
            (left.lastMealType == mealType ? 1 : 0);
        if (mealScore != 0) return mealScore;
        final usageScore = right.usageCount.compareTo(left.usageCount);
        if (usageScore != 0) return usageScore;
        return right.lastUsedAt.compareTo(left.lastUsedAt);
      });
    return values.take(limit).toList();
  }

  DietCopyPlan copyPlan({
    required List<ConsumedRecord> records,
    required String sourceDate,
    String? mealType,
  }) {
    final selected = records
        .where((record) => record.date == sourceDate)
        .where((record) => mealType == null || record.mealType == mealType)
        .toList(growable: false);
    return DietCopyPlan(sourceDate: sourceDate, records: selected);
  }

  static String normalize(String value) {
    return value
        .trim()
        .replaceAll(RegExp(r'[（(]\s*\d+(?:\.\d+)?\s*(?:g|克|毫升|ml)\s*[）)]$'), '')
        .replaceAll(RegExp(r'\s+'), '')
        .toLowerCase();
  }

  DateTime _dateOrFallback(String value, int index) {
    return DateTime.tryParse(value) ??
        DateTime.fromMillisecondsSinceEpoch(index);
  }
}
