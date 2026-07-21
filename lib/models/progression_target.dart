class ProgressionTarget {
  const ProgressionTarget({
    required this.targetSets,
    required this.targetRepMin,
    required this.targetRepMax,
    this.weightStepKg,
  });

  final int targetSets;
  final int targetRepMin;
  final int targetRepMax;
  final double? weightStepKg;

  Map<String, dynamic> toJson() => {
    'targetSets': targetSets,
    'targetRepMin': targetRepMin,
    'targetRepMax': targetRepMax,
    'weightStepKg': weightStepKg,
  };

  static ProgressionTarget? tryFromJson(Object? value) {
    if (value is! Map) return null;
    final targetSets = _positiveInt(value['targetSets']);
    final targetRepMin = _positiveInt(value['targetRepMin']);
    final targetRepMax = _positiveInt(value['targetRepMax']);
    if (targetSets == null ||
        targetRepMin == null ||
        targetRepMax == null ||
        targetRepMin > targetRepMax) {
      return null;
    }
    final rawStep = value['weightStepKg'];
    double? weightStepKg;
    if (rawStep != null) {
      if (rawStep is! num || !rawStep.toDouble().isFinite || rawStep <= 0) {
        return null;
      }
      weightStepKg = rawStep.toDouble();
    }
    return ProgressionTarget(
      targetSets: targetSets,
      targetRepMin: targetRepMin,
      targetRepMax: targetRepMax,
      weightStepKg: weightStepKg,
    );
  }
}

int? _positiveInt(Object? value) {
  if (value is! num || value % 1 != 0 || value <= 0) return null;
  return value.toInt();
}
