class PlateLoadAlternative {
  const PlateLoadAlternative({
    required this.platesPerSide,
    required this.totalWeight,
  });

  final List<double> platesPerSide;
  final double totalWeight;
}

class PlateCalculationResult {
  const PlateCalculationResult({
    required this.isValid,
    required this.exact,
    required this.platesPerSide,
    required this.actualTotalWeight,
    this.lowerAlternative,
    this.upperAlternative,
    this.errorMessage,
  });

  final bool isValid;
  final bool exact;
  final List<double> platesPerSide;
  final double actualTotalWeight;
  final PlateLoadAlternative? lowerAlternative;
  final PlateLoadAlternative? upperAlternative;
  final String? errorMessage;
}

class PlateCalculatorService {
  const PlateCalculatorService();

  static const defaultPlateSizes = <double>[1.25, 2.5, 5, 10, 15, 20, 25];

  PlateCalculationResult calculate({
    required double targetTotalWeight,
    required double barWeight,
    List<double> availablePlateSizes = defaultPlateSizes,
  }) {
    if (targetTotalWeight <= 0 || barWeight <= 0) {
      return _invalid('目标重量和杠铃重量必须大于 0。');
    }
    if (targetTotalWeight < barWeight) {
      return _invalid('目标重量不能低于杠铃重量。');
    }
    final plateUnits =
        availablePlateSizes
            .where((plate) => plate > 0)
            .map(_toUnits)
            .where((units) => units > 0)
            .toSet()
            .toList()
          ..sort((a, b) => b.compareTo(a));
    if (plateUnits.isEmpty) return _invalid('请选择可用杠铃片。');

    final targetUnits = _toUnits(targetTotalWeight);
    final barUnits = _toUnits(barWeight);
    final targetAddedUnits = targetUnits - barUnits;
    final pairUnits = plateUnits.map((units) => units * 2).toList();
    final maxSum = targetAddedUnits + pairUnits.reduce((a, b) => a > b ? a : b);
    final best = <int, List<int>>{0: const []};
    for (var sum = 1; sum <= maxSum; sum++) {
      List<int>? selected;
      for (var index = 0; index < pairUnits.length; index++) {
        final previous = best[sum - pairUnits[index]];
        if (previous == null) continue;
        final candidate = [...previous, plateUnits[index]]
          ..sort((a, b) => b.compareTo(a));
        if (_isBetter(candidate, selected)) selected = candidate;
      }
      if (selected != null) best[sum] = selected;
    }

    final exactPlates = best[targetAddedUnits];
    final lowerSum = best.keys
        .where((sum) => sum <= targetAddedUnits)
        .reduce((a, b) => a > b ? a : b);
    final upperSums = best.keys.where((sum) => sum >= targetAddedUnits);
    final upperSum = upperSums.isEmpty
        ? null
        : upperSums.reduce((a, b) => a < b ? a : b);
    final lower = _alternative(
      barUnits: barUnits,
      addedUnits: lowerSum,
      plateUnits: best[lowerSum]!,
    );
    final upper = upperSum == null
        ? null
        : _alternative(
            barUnits: barUnits,
            addedUnits: upperSum,
            plateUnits: best[upperSum]!,
          );
    final selected = exactPlates == null
        ? lower
        : _alternative(
            barUnits: barUnits,
            addedUnits: targetAddedUnits,
            plateUnits: exactPlates,
          );
    return PlateCalculationResult(
      isValid: true,
      exact: exactPlates != null,
      platesPerSide: selected.platesPerSide,
      actualTotalWeight: selected.totalWeight,
      lowerAlternative: exactPlates == null ? lower : null,
      upperAlternative: exactPlates == null ? upper : null,
    );
  }

  PlateCalculationResult _invalid(String message) => PlateCalculationResult(
    isValid: false,
    exact: false,
    platesPerSide: const [],
    actualTotalWeight: 0,
    errorMessage: message,
  );

  PlateLoadAlternative _alternative({
    required int barUnits,
    required int addedUnits,
    required List<int> plateUnits,
  }) => PlateLoadAlternative(
    platesPerSide: plateUnits.map(_fromUnits).toList(growable: false),
    totalWeight: _fromUnits(barUnits + addedUnits),
  );

  bool _isBetter(List<int> candidate, List<int>? current) {
    if (current == null || candidate.length != current.length) {
      return current == null || candidate.length < current.length;
    }
    for (var index = 0; index < candidate.length; index++) {
      if (candidate[index] != current[index]) {
        return candidate[index] > current[index];
      }
    }
    return false;
  }

  int _toUnits(double weight) => (weight * 4).round();

  double _fromUnits(int units) => units / 4;
}
