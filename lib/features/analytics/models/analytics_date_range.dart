class AnalyticsDateRange {
  AnalyticsDateRange({required DateTime start, required DateTime end})
    : start = dateOnly(start),
      end = dateOnly(end) {
    if (this.end.isBefore(this.start)) {
      throw ArgumentError('Analytics date range end must not precede start.');
    }
  }

  final DateTime start;
  final DateTime end;

  bool contains(DateTime date) {
    final day = dateOnly(date);
    return !day.isBefore(start) && !day.isAfter(end);
  }
}

DateTime dateOnly(DateTime value) =>
    DateTime(value.year, value.month, value.day);
