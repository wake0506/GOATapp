import 'consumed_record.dart';

class DietCopyPlan {
  final String sourceDate;
  final List<ConsumedRecord> records;

  const DietCopyPlan({required this.sourceDate, required this.records});

  bool get isEmpty => records.isEmpty;

  double get totalKcal => records.fold(0, (sum, record) => sum + record.kcal);
}
