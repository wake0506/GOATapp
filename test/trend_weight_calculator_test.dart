import 'package:flutter_test/flutter_test.dart';
import 'package:goat_app/features/analytics/models/weight_trend.dart';
import 'package:goat_app/features/analytics/repositories/local_weight_history_repository.dart';
import 'package:goat_app/features/analytics/services/trend_weight_calculator.dart';
import 'package:goat_app/models/app_snapshot.dart';
import 'package:goat_app/services/local_storage_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  const calculator = TrendWeightCalculator();

  test('calculates calendar-day SMA and 7/14 day changes without rounding', () {
    final records = <WeightRecord>[
      for (var day = 1; day <= 21; day++)
        WeightRecord(
          recordedAt: DateTime(2026, 7, day, 8),
          weightKg: 70 + day / 10,
        ),
    ];
    final result = calculator.calculate(
      records: records,
      anchorDate: DateTime(2026, 7, 21, 23),
    );
    expect(result.readingCount, 7);
    expect(result.dataQuality, WeightTrendDataQuality.complete);
    expect(result.sevenDayAverageKg, closeTo(71.8, 0.0000001));
    expect(result.change7dKg, closeTo(0.7, 0.0000001));
    expect(result.change14dKg, closeTo(1.4, 0.0000001));
    expect(result.windowDays, 7);
    expect(result.latestMeasuredWeightKg, 72.1);
    expect(result.latestRecordDate, DateTime(2026, 7, 21));
  });

  test(
    'uses actual readings only and requires three readings per comparison',
    () {
      final result = calculator.calculate(
        records: [
          WeightRecord(recordedAt: DateTime(2026, 7, 20), weightKg: 70),
          WeightRecord(recordedAt: DateTime(2026, 7, 21, 8), weightKg: 71),
          WeightRecord(recordedAt: DateTime(2026, 7, 21, 20), weightKg: 72),
          WeightRecord(recordedAt: DateTime(2026, 7, 22), weightKg: 99),
          WeightRecord(recordedAt: DateTime(2026, 7, 14), weightKg: 69),
          WeightRecord(recordedAt: DateTime(2026, 7, 13), weightKg: 69),
        ],
        anchorDate: DateTime(2026, 7, 21),
      );
      expect(result.readingCount, 2);
      expect(result.sevenDayAverageKg, 71);
      expect(result.dataQuality, WeightTrendDataQuality.partial);
      expect(result.change7dKg, isNull);
      expect(result.change14dKg, isNull);
    },
  );

  test('reports unavailable and single-reading quality', () {
    expect(
      calculator
          .calculate(records: const [], anchorDate: DateTime(2026, 7, 21))
          .dataQuality,
      WeightTrendDataQuality.unavailable,
    );
    expect(
      calculator
          .calculate(
            records: [
              WeightRecord(recordedAt: DateTime(2026, 7, 21), weightKg: 70),
            ],
            anchorDate: DateTime(2026, 7, 21),
          )
          .dataQuality,
      WeightTrendDataQuality.singleReading,
    );
  });

  test(
    'local repository reads the existing snapshot map and keeps latest per day',
    () async {
      SharedPreferences.setMockInitialValues({});
      final storage = LocalStorageService(
        await SharedPreferences.getInstance(),
      );
      await storage.save(
        'guest',
        AppSnapshot.fromJson({
          'weight': {
            '2026-07-20T08:00:00': 70,
            '2026-07-20T20:00:00': 70.5,
            '2026-07-21': 70.2,
            '2026-07-22': 99,
            'invalid': 80,
          },
        }),
      );
      final repository = LocalWeightHistoryRepository(
        storage: storage,
        namespace: 'guest',
      );
      final records = await repository.getWeightRecordsInRange(
        startDate: DateTime(2026, 7, 20),
        endDate: DateTime(2026, 7, 21),
      );
      expect(records, hasLength(2));
      expect(records.first.weightKg, 70.5);
      expect(records.last.weightKg, 70.2);
    },
  );

  test(
    'local repository never injects currentWeight into empty history',
    () async {
      SharedPreferences.setMockInitialValues({});
      final storage = LocalStorageService(
        await SharedPreferences.getInstance(),
      );
      await storage.save(
        'guest',
        AppSnapshot.fromJson({
          'currentWeight': 99,
          'weight': <String, double>{},
        }),
      );
      final records =
          await LocalWeightHistoryRepository(
            storage: storage,
            namespace: 'guest',
          ).getWeightRecordsInRange(
            startDate: DateTime(2026, 7, 1),
            endDate: DateTime(2026, 7, 21),
          );
      expect(records, isEmpty);
    },
  );
}
