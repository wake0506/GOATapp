import 'json_value.dart';
import 'progression_target.dart';
import 'rest_prescription.dart';
import '../features/training/domain/training_session_state.dart';

class SetRecord {
  String? id;
  double weight;
  int reps;
  String type;
  int restSeconds;
  int durationSec;
  TrainingSetType? setType;
  int? rir;
  double? rpe;
  bool? reachedFailure;
  DateTime? completedAt;
  bool replacementPlaceholder;
  int? recommendedRestSeconds;
  int? plannedRestSeconds;
  int? actualRestSeconds;
  int? restPolicyVersion;
  RestSource? restSource;

  SetRecord({
    this.id,
    this.weight = 0,
    this.reps = 0,
    this.type = '正常',
    this.restSeconds = 90,
    this.durationSec = 45,
    this.setType,
    this.rir,
    this.rpe,
    this.reachedFailure,
    this.completedAt,
    this.replacementPlaceholder = false,
    this.recommendedRestSeconds,
    this.plannedRestSeconds,
    this.actualRestSeconds,
    this.restPolicyVersion,
    this.restSource,
  });

  SetRecord copy() => SetRecord(
    id: id,
    weight: weight,
    reps: reps,
    type: type,
    restSeconds: restSeconds,
    durationSec: durationSec,
    setType: setType,
    rir: rir,
    rpe: rpe,
    reachedFailure: reachedFailure,
    completedAt: completedAt,
    replacementPlaceholder: replacementPlaceholder,
    recommendedRestSeconds: recommendedRestSeconds,
    plannedRestSeconds: plannedRestSeconds,
    actualRestSeconds: actualRestSeconds,
    restPolicyVersion: restPolicyVersion,
    restSource: restSource,
  );

  double get setVolume => weight * reps;

  TrainingSetType get resolvedSetType => setType ?? legacyTrainingSetType(type);

  bool get isLegacyBreakthrough => setType == null && type == '突破';

  Map<String, dynamic> toJson() => {
    'id': id,
    'weight': weight,
    'reps': reps,
    'type': type,
    'restSeconds': restSeconds,
    'durationSec': durationSec,
    'setType': setType?.storageValue,
    'rir': rir,
    'rpe': rpe,
    'reachedFailure': reachedFailure,
    'completedAt': completedAt?.toUtc().toIso8601String(),
    'replacementPlaceholder': replacementPlaceholder,
    'recommendedRestSeconds': recommendedRestSeconds,
    'plannedRestSeconds': plannedRestSeconds,
    'actualRestSeconds': actualRestSeconds,
    'restPolicyVersion': restPolicyVersion,
    'restSource': restSource?.name,
  };

  factory SetRecord.fromJson(Map<String, dynamic> json) => SetRecord(
    id: _nullableString(json['id']),
    weight: doubleValue(json['weight']),
    reps: intValue(json['reps']),
    type: stringValue(json['type'], '正常'),
    restSeconds: intValue(json['restSeconds'], 90),
    durationSec: intValue(json['durationSec'], 45),
    setType: TrainingSetTypeCodec.fromStorage(json['setType']),
    rir: _validRir(json['rir']),
    rpe: _validRpe(json['rpe']),
    reachedFailure: json['reachedFailure'] is bool
        ? json['reachedFailure'] as bool
        : null,
    completedAt: DateTime.tryParse(stringValue(json['completedAt'])),
    replacementPlaceholder: json['replacementPlaceholder'] == true,
    recommendedRestSeconds: _nullableNonNegativeInt(
      json['recommendedRestSeconds'],
    ),
    plannedRestSeconds: _nullableNonNegativeInt(json['plannedRestSeconds']),
    actualRestSeconds: _nullableNonNegativeInt(json['actualRestSeconds']),
    restPolicyVersion: _nullableNonNegativeInt(json['restPolicyVersion']),
    restSource: RestSource.values
        .where((candidate) => candidate.name == json['restSource'])
        .firstOrNull,
  );
}

TrainingSetType legacyTrainingSetType(String type) => switch (type) {
  '热身' => TrainingSetType.warmup,
  '正常' || '突破' => TrainingSetType.working,
  _ => TrainingSetType.working,
};

class TrainingExercise {
  String? exerciseId;
  String exerciseName;
  String bodyPart;
  List<SetRecord> sets;
  int? orderIndex;
  TrainingExerciseStatus? status;
  String? substitutedFromExerciseId;
  String? supersetGroupId;
  ProgressionTarget? progressionTarget;
  RestPrescription? restPrescription;

  TrainingExercise({
    this.exerciseId,
    required this.exerciseName,
    required this.bodyPart,
    required this.sets,
    this.orderIndex,
    this.status,
    this.substitutedFromExerciseId,
    this.supersetGroupId,
    this.progressionTarget,
    this.restPrescription,
  });

  double get totalVolume => sets.fold(0, (sum, set) => sum + set.setVolume);

  Map<String, dynamic> toJson() => {
    'exerciseId': exerciseId,
    'exerciseName': exerciseName,
    'bodyPart': bodyPart,
    'sets': sets.map((e) => e.toJson()).toList(),
    'orderIndex': orderIndex,
    'status': status?.storageValue,
    'substitutedFromExerciseId': substitutedFromExerciseId,
    'supersetGroupId': supersetGroupId,
    'progressionTarget': progressionTarget?.toJson(),
    'restPrescription': restPrescription?.toJson(),
  };

  factory TrainingExercise.fromJson(
    Map<String, dynamic> json,
  ) => TrainingExercise(
    exerciseId: _nullableString(json['exerciseId']),
    exerciseName: stringValue(json['exerciseName'], '未命名动作'),
    bodyPart: stringValue(json['bodyPart'], '全身'),
    sets: (json['sets'] as List<dynamic>? ?? const [])
        .whereType<Map<String, dynamic>>()
        .map(SetRecord.fromJson)
        .toList(),
    orderIndex: json['orderIndex'] is num ? intValue(json['orderIndex']) : null,
    status: TrainingExerciseStatusCodec.fromStorage(json['status']),
    substitutedFromExerciseId: _nullableString(
      json['substitutedFromExerciseId'],
    ),
    supersetGroupId: _nullableString(json['supersetGroupId']),
    progressionTarget: ProgressionTarget.tryFromJson(json['progressionTarget']),
    restPrescription: RestPrescription.tryFromJson(json['restPrescription']),
  );
}

String? _nullableString(Object? value) {
  if (value is! String || value.trim().isEmpty) return null;
  return value;
}

int? _validRir(Object? value) {
  if (value is! num) return null;
  final rir = value.toInt();
  return rir >= 0 && rir <= 3 ? rir : null;
}

double? _validRpe(Object? value) {
  if (value is! num) return null;
  final rpe = value.toDouble();
  return rpe >= 1 && rpe <= 10 ? rpe : null;
}

int? _nullableNonNegativeInt(Object? value) {
  if (value is! num) return null;
  final parsed = value.toInt();
  return parsed < 0 ? null : parsed;
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

extension _FirstOrNull<T> on Iterable<T> {
  T? get firstOrNull {
    final iterator = this.iterator;
    return iterator.moveNext() ? iterator.current : null;
  }
}
