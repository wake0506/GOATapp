import '../models/parsed_diet_item.dart';

abstract interface class NutritionRepository {
  Future<void> addRecords(List<ParsedDietItem> items);
}
