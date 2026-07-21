import '../models/weight_trend.dart';

abstract interface class WeightHistoryRepository {
  Future<List<WeightRecord>> getWeightRecordsInRange({
    required DateTime startDate,
    required DateTime endDate,
  });
}
