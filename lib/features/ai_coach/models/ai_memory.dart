import '../../../models/json_value.dart';

enum AiMemorySourceType { userProvided, behaviorDerived, aiInferred }

enum AiMemoryStatus {
  active,
  pendingConfirmation,
  rejected,
  incorrect,
  archived,
}

enum AiMemoryConfidence { high, medium, low }

enum AiProfileCategory {
  trainingGoal,
  trainingExperience,
  availableEquipment,
  trainingPreference,
  dislikedExercise,
  nutritionPreference,
  coachingStyle,
  trainingHabit,
  longTermTrend,
  constraint,
}

extension AiProfileCategoryLabel on AiProfileCategory {
  String get label => switch (this) {
    AiProfileCategory.trainingGoal => '训练目标',
    AiProfileCategory.trainingExperience => '训练经验',
    AiProfileCategory.availableEquipment => '可用器械',
    AiProfileCategory.trainingPreference => '训练偏好',
    AiProfileCategory.dislikedExercise => '不喜欢的动作',
    AiProfileCategory.nutritionPreference => '饮食偏好',
    AiProfileCategory.coachingStyle => '指导风格',
    AiProfileCategory.trainingHabit => '训练频率与习惯',
    AiProfileCategory.longTermTrend => '长期行为趋势',
    AiProfileCategory.constraint => '明确限制',
  };
}

class AiMemorySourceRef {
  const AiMemorySourceRef({
    required this.type,
    required this.id,
    required this.label,
    this.dateRangeStart,
    this.dateRangeEnd,
    this.analyticsType,
  });

  final String type;
  final String id;
  final String label;
  final String? dateRangeStart;
  final String? dateRangeEnd;
  final String? analyticsType;

  Map<String, dynamic> toJson() => {
    'type': type,
    'id': id,
    'label': label,
    'dateRangeStart': dateRangeStart,
    'dateRangeEnd': dateRangeEnd,
    'analyticsType': analyticsType,
  };

  factory AiMemorySourceRef.fromJson(Map<String, dynamic> json) =>
      AiMemorySourceRef(
        type: stringValue(json['type'], 'unknown'),
        id: stringValue(json['id']),
        label: stringValue(json['label'], '来源记录'),
        dateRangeStart: _optionalString(json['dateRangeStart']),
        dateRangeEnd: _optionalString(json['dateRangeEnd']),
        analyticsType: _optionalString(json['analyticsType']),
      );
}

class AiMemoryItem {
  const AiMemoryItem({
    required this.id,
    required this.category,
    required this.value,
    required this.sourceType,
    required this.status,
    required this.createdAt,
    required this.updatedAt,
    this.stableKey,
    this.structuredValue = const {},
    this.sourceRefs = const [],
    this.confidenceLevel,
    this.userConfirmed = false,
  });

  final String id;
  final String? stableKey;
  final AiProfileCategory category;
  final String value;
  final Map<String, dynamic> structuredValue;
  final AiMemorySourceType sourceType;
  final AiMemoryStatus status;
  final DateTime createdAt;
  final DateTime updatedAt;
  final List<AiMemorySourceRef> sourceRefs;
  final AiMemoryConfidence? confidenceLevel;
  final bool userConfirmed;

  bool get isSuppressed =>
      status == AiMemoryStatus.rejected ||
      status == AiMemoryStatus.incorrect ||
      status == AiMemoryStatus.archived;

  bool get isUsableInContext =>
      status == AiMemoryStatus.active &&
      (sourceType != AiMemorySourceType.aiInferred || userConfirmed);

  AiMemoryItem copyWith({
    String? value,
    Map<String, dynamic>? structuredValue,
    AiMemoryStatus? status,
    DateTime? createdAt,
    DateTime? updatedAt,
    List<AiMemorySourceRef>? sourceRefs,
    AiMemoryConfidence? confidenceLevel,
    bool? userConfirmed,
  }) => AiMemoryItem(
    id: id,
    stableKey: stableKey,
    category: category,
    value: value ?? this.value,
    structuredValue: structuredValue ?? this.structuredValue,
    sourceType: sourceType,
    status: status ?? this.status,
    createdAt: createdAt ?? this.createdAt,
    updatedAt: updatedAt ?? this.updatedAt,
    sourceRefs: sourceRefs ?? this.sourceRefs,
    confidenceLevel: confidenceLevel ?? this.confidenceLevel,
    userConfirmed: userConfirmed ?? this.userConfirmed,
  );

  Map<String, dynamic> toJson() => {
    'id': id,
    'stableKey': stableKey,
    'category': category.name,
    'value': value,
    'structuredValue': structuredValue,
    'sourceType': sourceType.name,
    'status': status.name,
    'createdAt': createdAt.toUtc().toIso8601String(),
    'updatedAt': updatedAt.toUtc().toIso8601String(),
    'sourceRefs': sourceRefs.map((item) => item.toJson()).toList(),
    'confidenceLevel': confidenceLevel?.name,
    'userConfirmed': userConfirmed,
  };

  factory AiMemoryItem.fromJson(Map<String, dynamic> json) {
    final sourceType = _enumByName(
      AiMemorySourceType.values,
      json['sourceType'],
      AiMemorySourceType.userProvided,
    );
    return AiMemoryItem(
      id: stringValue(json['id']),
      stableKey: _optionalString(json['stableKey']),
      category: _enumByName(
        AiProfileCategory.values,
        json['category'],
        AiProfileCategory.trainingPreference,
      ),
      value: stringValue(json['value']),
      structuredValue: json['structuredValue'] is Map
          ? Map<String, dynamic>.from(json['structuredValue'] as Map)
          : const {},
      sourceType: sourceType,
      status: _enumByName(
        AiMemoryStatus.values,
        json['status'],
        sourceType == AiMemorySourceType.aiInferred
            ? AiMemoryStatus.pendingConfirmation
            : AiMemoryStatus.active,
      ),
      createdAt:
          DateTime.tryParse(stringValue(json['createdAt'])) ?? DateTime.now(),
      updatedAt:
          DateTime.tryParse(stringValue(json['updatedAt'])) ?? DateTime.now(),
      sourceRefs: (json['sourceRefs'] as List<dynamic>? ?? const [])
          .whereType<Map>()
          .map(
            (item) =>
                AiMemorySourceRef.fromJson(Map<String, dynamic>.from(item)),
          )
          .toList(),
      confidenceLevel: _optionalEnumByName(
        AiMemoryConfidence.values,
        json['confidenceLevel'],
      ),
      userConfirmed: json['userConfirmed'] == true,
    );
  }
}

T _enumByName<T extends Enum>(List<T> values, Object? raw, T fallback) =>
    values.where((item) => item.name == raw).firstOrNull ?? fallback;

T? _optionalEnumByName<T extends Enum>(List<T> values, Object? raw) =>
    values.where((item) => item.name == raw).firstOrNull;

String? _optionalString(Object? value) {
  if (value is! String || value.trim().isEmpty) return null;
  return value.trim();
}

extension _FirstOrNull<T> on Iterable<T> {
  T? get firstOrNull {
    final iterator = this.iterator;
    return iterator.moveNext() ? iterator.current : null;
  }
}
