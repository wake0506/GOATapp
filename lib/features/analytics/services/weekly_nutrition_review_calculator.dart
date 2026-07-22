import '../../../models/consumed_record.dart';
import '../models/analytics_date_range.dart';
import '../models/weight_trend.dart';
import '../models/weekly_review.dart';
import 'trend_weight_calculator.dart';

class WeeklyNutritionReviewCalculator {
  const WeeklyNutritionReviewCalculator({
    this.trendWeightCalculator = const TrendWeightCalculator(),
  });

  final TrendWeightCalculator trendWeightCalculator;

  WeeklyNutritionReview calculate({
    required Iterable<ConsumedRecord> records,
    required Iterable<WeightRecord> weightRecords,
    required DateTime anchorDate,
  }) {
    final anchor = dateOnly(anchorDate);
    final currentRange = AnalyticsDateRange(
      start: anchor.subtract(const Duration(days: 6)),
      end: anchor,
    );
    final previousRange = AnalyticsDateRange(
      start: anchor.subtract(const Duration(days: 13)),
      end: anchor.subtract(const Duration(days: 7)),
    );
    final allRecords = records.toList(growable: false);
    final current = _recordsInRange(allRecords, currentRange);
    final previous = _recordsInRange(allRecords, previousRange);
    final currentDays = current.map((record) => record.date).toSet().length;
    final previousDays = previous.map((record) => record.date).toSet().length;
    final trend = trendWeightCalculator.calculate(
      records: weightRecords,
      anchorDate: anchor,
    );
    final reasons = <WeeklyReviewReason>[
      if (currentDays == 7)
        WeeklyReviewReason.completeWeek
      else
        WeeklyReviewReason.partialNutritionLogging,
      if (trend.dataQuality == WeightTrendDataQuality.unavailable)
        WeeklyReviewReason.insufficientWeightHistory
      else
        WeeklyReviewReason.weightTrendAvailable,
    ];

    return WeeklyNutritionReview(
      dateRange: currentRange,
      recordedDays: currentDays,
      averageCalories: _average(current, (record) => record.kcal, currentDays),
      averageProtein: _average(current, (record) => record.p, currentDays),
      averageCarbs: _average(current, (record) => record.c, currentDays),
      averageFat: _average(current, (record) => record.f, currentDays),
      previousAverageCalories: currentDays >= 3 && previousDays >= 3
          ? _average(previous, (record) => record.kcal, previousDays)
          : null,
      weightTrend: trend,
      dataQuality: switch (currentDays) {
        0 => WeeklyReviewDataQuality.insufficient,
        7 => WeeklyReviewDataQuality.complete,
        _ => WeeklyReviewDataQuality.partial,
      },
      reasons: List.unmodifiable(reasons),
    );
  }

  List<ConsumedRecord> _recordsInRange(
    Iterable<ConsumedRecord> records,
    AnalyticsDateRange range,
  ) => records
      .where((record) {
        final date = DateTime.tryParse(record.date);
        return date != null && range.contains(date);
      })
      .toList(growable: false);

  double? _average(
    Iterable<ConsumedRecord> records,
    double Function(ConsumedRecord record) value,
    int recordedDays,
  ) {
    if (recordedDays == 0) return null;
    return records.fold<double>(0, (sum, record) => sum + value(record)) /
        recordedDays;
  }
}
