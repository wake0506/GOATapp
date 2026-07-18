import '../../../exercise_catalog.dart';

class WarmupSuggestion {
  const WarmupSuggestion({
    required this.weight,
    required this.reps,
    required this.order,
    required this.label,
  });

  final double weight;
  final int reps;
  final int order;
  final String label;

  WarmupSuggestion copyWith({double? weight, int? reps}) => WarmupSuggestion(
    weight: weight ?? this.weight,
    reps: reps ?? this.reps,
    order: order,
    label: label,
  );
}

class WarmupSuggestionService {
  const WarmupSuggestionService();

  List<WarmupSuggestion> suggest({
    required ExerciseDefinition exercise,
    required double targetWorkingWeight,
    double barWeight = 20,
    List<double> availablePlateSizes = const [1.25, 2.5, 5, 10, 15, 20, 25],
  }) {
    if (!_isApplicable(exercise) ||
        targetWorkingWeight <= 0 ||
        barWeight < 0 ||
        targetWorkingWeight <= barWeight) {
      return const [];
    }
    final positivePlates = availablePlateSizes.where((plate) => plate > 0);
    final increment = positivePlates.isEmpty
        ? 2.5
        : positivePlates.reduce((a, b) => a < b ? a : b) * 2;
    const scheme = [(0.4, 8, '40%'), (0.6, 5, '60%'), (0.8, 3, '80%')];
    final result = <WarmupSuggestion>[];
    final seenWeights = <int>{};

    // Product default ramp-up scheme, not a universal physiological prescription.
    for (final (ratio, reps, label) in scheme) {
      final desired = targetWorkingWeight * ratio;
      final rounded = _roundLoad(
        desired: desired,
        barWeight: barWeight,
        increment: increment,
      );
      if (rounded >= targetWorkingWeight) continue;
      final key = (rounded * 100).round();
      if (!seenWeights.add(key)) continue;
      result.add(
        WarmupSuggestion(
          weight: rounded,
          reps: reps,
          order: result.length,
          label: label,
        ),
      );
    }
    return result;
  }

  bool _isApplicable(ExerciseDefinition exercise) {
    if (exercise.equipment != '自由重量') return false;
    return switch (exercise.movementPattern) {
      ExerciseMovementPattern.horizontalPush ||
      ExerciseMovementPattern.verticalPush ||
      ExerciseMovementPattern.horizontalPull ||
      ExerciseMovementPattern.verticalPull ||
      ExerciseMovementPattern.squat ||
      ExerciseMovementPattern.hinge => true,
      _ => false,
    };
  }

  double _roundLoad({
    required double desired,
    required double barWeight,
    required double increment,
  }) {
    if (desired <= barWeight || increment <= 0) return barWeight;
    final steps = ((desired - barWeight) / increment).round();
    return barWeight + steps * increment;
  }
}
