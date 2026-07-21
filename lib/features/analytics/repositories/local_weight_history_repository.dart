import '../../../services/local_storage_service.dart';
import '../models/analytics_date_range.dart';
import '../models/weight_trend.dart';
import 'weight_history_repository.dart';

class LocalWeightHistoryRepository implements WeightHistoryRepository {
  const LocalWeightHistoryRepository({
    required this.storage,
    required this.namespace,
  });

  final LocalStorageService storage;
  final String namespace;

  @override
  Future<List<WeightRecord>> getWeightRecordsInRange({
    required DateTime startDate,
    required DateTime endDate,
  }) async {
    final range = AnalyticsDateRange(start: startDate, end: endDate);
    final snapshot = storage.load(namespace);
    if (snapshot == null) return const [];

    final latestByDay = <DateTime, WeightRecord>{};
    for (final entry in snapshot.weight.entries) {
      final recordedAt = DateTime.tryParse(entry.key);
      if (recordedAt == null ||
          !entry.value.isFinite ||
          entry.value <= 0 ||
          !range.contains(recordedAt)) {
        continue;
      }
      final day = dateOnly(recordedAt);
      final existing = latestByDay[day];
      if (existing == null || recordedAt.isAfter(existing.recordedAt)) {
        latestByDay[day] = WeightRecord(
          recordedAt: recordedAt,
          weightKg: entry.value,
        );
      }
    }
    final records = latestByDay.values.toList()
      ..sort((a, b) => a.recordedAt.compareTo(b.recordedAt));
    return List.unmodifiable(records);
  }
}
