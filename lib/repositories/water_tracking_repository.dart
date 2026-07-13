import '../models/water_intake_record.dart';

abstract interface class WaterTrackingRepository {
  List<WaterIntakeRecord> waterRecordsForDate(String date);

  Future<void> addWaterRecord(WaterIntakeRecord record);

  Future<void> updateWaterRecord(WaterIntakeRecord record);

  Future<void> deleteWaterRecord(String recordId);
}
