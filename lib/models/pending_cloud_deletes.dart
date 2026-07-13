class PendingCloudDeletes {
  final Set<String> foodIds;
  final Set<String> dietRecordIds;
  final Set<String> exerciseRecordIds;
  final Set<String> waterRecordIds;
  final Set<String> trackingDates;

  const PendingCloudDeletes({
    this.foodIds = const {},
    this.dietRecordIds = const {},
    this.exerciseRecordIds = const {},
    this.waterRecordIds = const {},
    this.trackingDates = const {},
  });

  const PendingCloudDeletes.empty() : this();

  bool get isEmpty =>
      foodIds.isEmpty &&
      dietRecordIds.isEmpty &&
      exerciseRecordIds.isEmpty &&
      waterRecordIds.isEmpty &&
      trackingDates.isEmpty;

  PendingCloudDeletes copyWith({
    Set<String>? foodIds,
    Set<String>? dietRecordIds,
    Set<String>? exerciseRecordIds,
    Set<String>? waterRecordIds,
    Set<String>? trackingDates,
  }) {
    return PendingCloudDeletes(
      foodIds: foodIds ?? this.foodIds,
      dietRecordIds: dietRecordIds ?? this.dietRecordIds,
      exerciseRecordIds: exerciseRecordIds ?? this.exerciseRecordIds,
      waterRecordIds: waterRecordIds ?? this.waterRecordIds,
      trackingDates: trackingDates ?? this.trackingDates,
    );
  }

  Map<String, dynamic> toJson() => {
    'foodIds': foodIds.toList(),
    'dietRecordIds': dietRecordIds.toList(),
    'exerciseRecordIds': exerciseRecordIds.toList(),
    'waterRecordIds': waterRecordIds.toList(),
    'trackingDates': trackingDates.toList(),
  };

  factory PendingCloudDeletes.fromJson(Object? value) {
    if (value is! Map) return const PendingCloudDeletes.empty();

    Set<String> readSet(Object? raw) {
      if (raw is! List) return <String>{};
      return raw.map((item) => item.toString()).toSet();
    }

    return PendingCloudDeletes(
      foodIds: readSet(value['foodIds']),
      dietRecordIds: readSet(value['dietRecordIds']),
      exerciseRecordIds: readSet(value['exerciseRecordIds']),
      waterRecordIds: readSet(value['waterRecordIds']),
      trackingDates: readSet(value['trackingDates']),
    );
  }

  PendingCloudDeletes without(PendingCloudDeletes processed) {
    return PendingCloudDeletes(
      foodIds: foodIds.difference(processed.foodIds),
      dietRecordIds: dietRecordIds.difference(processed.dietRecordIds),
      exerciseRecordIds: exerciseRecordIds.difference(
        processed.exerciseRecordIds,
      ),
      waterRecordIds: waterRecordIds.difference(processed.waterRecordIds),
      trackingDates: trackingDates.difference(processed.trackingDates),
    );
  }

  PendingCloudDeletes merge(PendingCloudDeletes other) {
    return PendingCloudDeletes(
      foodIds: {...foodIds, ...other.foodIds},
      dietRecordIds: {...dietRecordIds, ...other.dietRecordIds},
      exerciseRecordIds: {...exerciseRecordIds, ...other.exerciseRecordIds},
      waterRecordIds: {...waterRecordIds, ...other.waterRecordIds},
      trackingDates: {...trackingDates, ...other.trackingDates},
    );
  }
}
