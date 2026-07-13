import '../models/consumed_record.dart';
import '../models/parsed_diet_item.dart';

abstract interface class NutritionRepository {
  List<ConsumedRecord> recordsForDate(String date);

  Future<void> addRecords(List<ParsedDietItem> items);

  Future<void> addConsumedRecords(List<ConsumedRecord> records);

  Future<void> updateRecord(ConsumedRecord record);

  Future<void> deleteRecord(String recordId);

  Future<void> restoreRecord(ConsumedRecord record);

  Future<void> replaceRecordsForOperation(List<ConsumedRecord> records);
}
