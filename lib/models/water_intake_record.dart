import 'json_value.dart';

class WaterIntakeRecord {
  final String id;
  final String date;
  final DateTime? recordedAt;
  final int amountMl;
  final bool isLegacyAggregate;

  const WaterIntakeRecord({
    required this.id,
    required this.date,
    required this.recordedAt,
    required this.amountMl,
    this.isLegacyAggregate = false,
  });

  Map<String, dynamic> toJson() => {
    'id': id,
    'date': date,
    'recordedAt': recordedAt?.toIso8601String(),
    'amountMl': amountMl,
    'isLegacyAggregate': isLegacyAggregate,
  };

  factory WaterIntakeRecord.fromJson(Map<String, dynamic> json) {
    final date = stringValue(json['date']);
    final isLegacyAggregate = json['isLegacyAggregate'] == true;
    final parsedRecordedAt = DateTime.tryParse(stringValue(json['recordedAt']));
    final recordedAt =
        parsedRecordedAt ??
        (isLegacyAggregate
            ? null
            : (DateTime.tryParse(date) ?? DateTime.now()));
    return WaterIntakeRecord(
      id: stringValue(json['id']),
      date: date,
      recordedAt: recordedAt,
      amountMl: intValue(json['amountMl']),
      isLegacyAggregate: isLegacyAggregate,
    );
  }
}

List<WaterIntakeRecord> migrateWaterAggregates(Map<String, int> water) {
  return water.entries
      .where((entry) => entry.value > 0)
      .map(
        (entry) => WaterIntakeRecord(
          id: 'legacy_water_${entry.key}',
          date: entry.key,
          recordedAt: null,
          amountMl: entry.value,
          isLegacyAggregate: true,
        ),
      )
      .toList();
}

Map<String, int> waterTotals(
  Iterable<WaterIntakeRecord> records, {
  Iterable<String> dates = const [],
}) {
  final totals = <String, int>{for (final date in dates) date: 0};
  for (final record in records) {
    totals.update(
      record.date,
      (value) => value + record.amountMl,
      ifAbsent: () => record.amountMl,
    );
  }
  return totals;
}
