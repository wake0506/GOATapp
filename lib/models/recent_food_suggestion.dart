class RecentFoodSuggestion {
  final String normalizedKey;
  final String displayName;
  final double amount;
  final String unit;
  final double kcal;
  final double protein;
  final double carbs;
  final double fat;
  final String lastMealType;
  final DateTime lastUsedAt;
  final int usageCount;

  const RecentFoodSuggestion({
    required this.normalizedKey,
    required this.displayName,
    required this.amount,
    required this.unit,
    required this.kcal,
    required this.protein,
    required this.carbs,
    required this.fat,
    required this.lastMealType,
    required this.lastUsedAt,
    required this.usageCount,
  });
}
