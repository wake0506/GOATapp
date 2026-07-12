import 'json_value.dart';

class SetRecord {
  double weight;
  int reps;
  String type;
  int restSeconds;
  int durationSec;

  SetRecord({
    this.weight = 0,
    this.reps = 0,
    this.type = '正常',
    this.restSeconds = 90,
    this.durationSec = 45,
  });

  SetRecord copy() => SetRecord(
    weight: weight,
    reps: reps,
    type: type,
    restSeconds: restSeconds,
    durationSec: durationSec,
  );

  double get setVolume => weight * reps;

  Map<String, dynamic> toJson() => {
    'weight': weight,
    'reps': reps,
    'type': type,
    'restSeconds': restSeconds,
    'durationSec': durationSec,
  };

  factory SetRecord.fromJson(Map<String, dynamic> json) => SetRecord(
    weight: doubleValue(json['weight']),
    reps: intValue(json['reps']),
    type: stringValue(json['type'], '正常'),
    restSeconds: intValue(json['restSeconds'], 90),
    durationSec: intValue(json['durationSec'], 45),
  );
}

class TrainingExercise {
  String exerciseName;
  String bodyPart;
  List<SetRecord> sets;

  TrainingExercise({
    required this.exerciseName,
    required this.bodyPart,
    required this.sets,
  });

  double get totalVolume => sets.fold(0, (sum, set) => sum + set.setVolume);

  Map<String, dynamic> toJson() => {
    'exerciseName': exerciseName,
    'bodyPart': bodyPart,
    'sets': sets.map((e) => e.toJson()).toList(),
  };

  factory TrainingExercise.fromJson(Map<String, dynamic> json) =>
      TrainingExercise(
        exerciseName: stringValue(json['exerciseName'], '未命名动作'),
        bodyPart: stringValue(json['bodyPart'], '全身'),
        sets: (json['sets'] as List<dynamic>? ?? const [])
            .whereType<Map<String, dynamic>>()
            .map(SetRecord.fromJson)
            .toList(),
      );
}

class TrainingSession {
  String id;
  String name;
  String date;
  List<TrainingExercise> exercises;

  TrainingSession({
    required this.id,
    required this.name,
    required this.date,
    required this.exercises,
  });

  double get sessionVolume =>
      exercises.fold(0, (sum, ex) => sum + ex.totalVolume);

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'date': date,
    'exercises': exercises.map((e) => e.toJson()).toList(),
  };

  factory TrainingSession.fromJson(Map<String, dynamic> json) =>
      TrainingSession(
        id: stringValue(json['id']),
        name: stringValue(json['name'], '训练'),
        date: stringValue(json['date']),
        exercises: (json['exercises'] as List<dynamic>? ?? const [])
            .whereType<Map<String, dynamic>>()
            .map(TrainingExercise.fromJson)
            .toList(),
      );
}
