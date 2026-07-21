import '../models/analytics_date_range.dart';
import '../models/weight_trend.dart';

class TrendWeightCalculator {
  const TrendWeightCalculator();

  WeightTrend calculate({
    required Iterable<WeightRecord> records,
    required DateTime anchorDate,
  }) {
    final anchor = dateOnly(anchorDate);
    final latestByDay = <DateTime, WeightRecord>{};
    for (final record in records) {
      if (!record.weightKg.isFinite || record.weightKg <= 0) continue;
      final day = dateOnly(record.recordedAt);
      if (day.isAfter(anchor)) continue;
      final existing = latestByDay[day];
      if (existing == null || record.recordedAt.isAfter(existing.recordedAt)) {
        latestByDay[day] = record;
      }
    }

    final current = _window(latestByDay.values, end: anchor, days: 7);
    final previous7 = _window(
      latestByDay.values,
      end: anchor.subtract(const Duration(days: 7)),
      days: 7,
    );
    final previous14 = _window(
      latestByDay.values,
      end: anchor.subtract(const Duration(days: 14)),
      days: 7,
    );
    final orderedRecords = latestByDay.values.toList()
      ..sort((a, b) => b.recordedAt.compareTo(a.recordedAt));
    final latestRecord = orderedRecords.isEmpty ? null : orderedRecords.first;

    return WeightTrend(
      anchorDate: anchor,
      windowDays: 7,
      readingCount: current.length,
      sevenDayAverageKg: _meanOrNull(current),
      change7dKg: _difference(current, previous7),
      change14dKg: _difference(current, previous14),
      latestMeasuredWeightKg: latestRecord?.weightKg,
      latestRecordDate: latestRecord == null
          ? null
          : dateOnly(latestRecord.recordedAt),
      dataQuality: switch (current.length) {
        0 => WeightTrendDataQuality.unavailable,
        1 => WeightTrendDataQuality.singleReading,
        < 7 => WeightTrendDataQuality.partial,
        _ => WeightTrendDataQuality.complete,
      },
    );
  }

  List<WeightRecord> _window(
    Iterable<WeightRecord> records, {
    required DateTime end,
    required int days,
  }) {
    final start = end.subtract(Duration(days: days - 1));
    return records
        .where((record) {
          final day = dateOnly(record.recordedAt);
          return !day.isBefore(start) && !day.isAfter(end);
        })
        .toList(growable: false);
  }

  double? _meanOrNull(List<WeightRecord> records) {
    if (records.isEmpty) return null;
    return records.fold<double>(0, (sum, record) => sum + record.weightKg) /
        records.length;
  }

  double? _difference(
    List<WeightRecord> current,
    List<WeightRecord> comparison,
  ) {
    if (current.length < 3 || comparison.length < 3) return null;
    return _meanOrNull(current)! - _meanOrNull(comparison)!;
  }
}
