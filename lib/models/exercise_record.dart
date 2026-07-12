import 'json_value.dart';

class ExerciseRecord {
  final String id;
  final String type;
  final double kcal;
  final String startTime;
  final String endTime;
  final String date;

  ExerciseRecord({
    required this.id,
    required this.type,
    required this.kcal,
    required this.startTime,
    required this.endTime,
    required this.date,
  });

  Map<String, dynamic> toJson() => {
    'id': id,
    'type': type,
    'kcal': kcal,
    'startTime': startTime,
    'endTime': endTime,
    'date': date,
  };

  factory ExerciseRecord.fromJson(Map<String, dynamic> json) => ExerciseRecord(
    id: stringValue(json['id']),
    type: stringValue(json['type'], '运动'),
    kcal: doubleValue(json['kcal']),
    startTime: stringValue(json['startTime']),
    endTime: stringValue(json['endTime']),
    date: stringValue(json['date']),
  );
}
