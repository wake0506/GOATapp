enum WeightTrendDataQuality { unavailable, singleReading, partial, complete }

class WeightRecord {
  const WeightRecord({required this.recordedAt, required this.weightKg});

  final DateTime recordedAt;
  final double weightKg;
}

class WeightTrend {
  const WeightTrend({
    required this.anchorDate,
    required this.windowDays,
    required this.readingCount,
    required this.dataQuality,
    this.sevenDayAverageKg,
    this.change7dKg,
    this.change14dKg,
    this.latestMeasuredWeightKg,
    this.latestRecordDate,
  });

  final DateTime anchorDate;
  final int windowDays;
  final int readingCount;
  final WeightTrendDataQuality dataQuality;
  final double? sevenDayAverageKg;
  final double? change7dKg;
  final double? change14dKg;
  final double? latestMeasuredWeightKg;
  final DateTime? latestRecordDate;
}
