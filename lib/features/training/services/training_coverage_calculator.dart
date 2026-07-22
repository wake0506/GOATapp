import '../../../exercise_catalog.dart';
import '../../../models/training.dart';
import '../../analytics/models/analytics_date_range.dart';
import '../../analytics/services/effective_set_calculator.dart';
import '../domain/training_session_state.dart';
import '../models/exercise_metadata.dart';
import '../models/exercise_metadata_catalog.dart';
import '../models/training_coverage.dart';

class TrainingCoverageCalculator {
  const TrainingCoverageCalculator({
    this.effectiveSetCalculator = const EffectiveSetCalculator(),
  });

  final EffectiveSetCalculator effectiveSetCalculator;

  TrainingCoverageResult calculateSession({
    required TrainingSession session,
    required bool isActiveSession,
    List<ExerciseDefinition> catalog = exerciseCatalog,
    Map<String, ExerciseMetadata>? metadataCatalog,
  }) => calculateSessions(
    sessions: [session],
    activeSessionIds: isActiveSession ? {session.id} : const {},
    catalog: catalog,
    metadataCatalog: metadataCatalog,
  );

  TrainingCoverageResult calculateHistory({
    required Iterable<TrainingSession> completedSessions,
    required AnalyticsDateRange dateRange,
    List<ExerciseDefinition> catalog = exerciseCatalog,
    Map<String, ExerciseMetadata>? metadataCatalog,
  }) => calculateSessions(
    sessions: completedSessions.where((session) {
      final date = DateTime.tryParse(session.date);
      return date != null && dateRange.contains(date);
    }),
    catalog: catalog,
    metadataCatalog: metadataCatalog,
  );

  TrainingCoverageResult calculateSessions({
    required Iterable<TrainingSession> sessions,
    Set<String> activeSessionIds = const {},
    List<ExerciseDefinition> catalog = exerciseCatalog,
    Map<String, ExerciseMetadata>? metadataCatalog,
  }) {
    final resolvedMetadata = metadataCatalog ?? exerciseMetadataCatalog;
    final sessionList = sessions.toList(growable: false);
    final muscles = {
      for (final group in MuscleGroup.values) group: _MuscleCounter(),
    };
    final regions = {
      for (final region in MuscleRegion.values) region: _RegionCounter(),
    };
    final movements = {
      for (final pattern in ExerciseMovementPattern.values)
        pattern: _MovementCounter(),
    };
    final targetBodyParts = <String>{};
    final targetMuscles = <MuscleGroup>{};
    final unresolvedIds = <String>{};
    final seenLegacyExercises = <String>{};
    var completedEffectiveSets = 0;
    var contributingExercises = 0;

    for (final session in sessionList) {
      final isActive = activeSessionIds.contains(session.id);
      for (final exercise in session.exercises) {
        if (exercise.status == TrainingExerciseStatus.replaced) continue;
        targetBodyParts.add(exercise.bodyPart);
        final resolved = _resolveExercise(
          exercise,
          catalog: catalog,
          metadataCatalog: resolvedMetadata,
        );
        final metadata = resolved.metadata;
        final fallbackGroup = muscleGroupForBodyPart(exercise.bodyPart);
        if (metadata != null) {
          targetMuscles.addAll(metadata.primaryMuscles);
          if (metadata.status == ExerciseMetadataStatus.unresolved) {
            unresolvedIds.add(resolved.exerciseId);
          }
        } else if (fallbackGroup != null) {
          targetMuscles.add(fallbackGroup);
          unresolvedIds.add(resolved.exerciseId);
        }
        if (resolved.usedLegacyName) {
          seenLegacyExercises.add(resolved.exerciseId);
        }

        final effectiveSets = exercise.sets.where((set) {
          if (!effectiveSetCalculator.isEffectiveSet(set)) return false;
          return !isActive || set.completedAt != null;
        }).length;
        if (effectiveSets == 0) continue;
        completedEffectiveSets += effectiveSets;
        contributingExercises++;

        if (metadata == null ||
            metadata.status == ExerciseMetadataStatus.unresolved) {
          if (fallbackGroup != null) {
            final counter = muscles[fallbackGroup]!;
            counter.primary += effectiveSets * 2;
            counter.effectiveSets += effectiveSets;
            counter.exerciseIds.add(resolved.exerciseId);
          }
          continue;
        }

        for (final group in metadata.primaryMuscles) {
          final counter = muscles[group]!;
          counter.primary += effectiveSets * 2;
          counter.effectiveSets += effectiveSets;
          counter.exerciseIds.add(resolved.exerciseId);
        }
        for (final group in metadata.secondaryMuscles) {
          final counter = muscles[group]!;
          counter.secondary += effectiveSets;
          counter.effectiveSets += effectiveSets;
          counter.exerciseIds.add(resolved.exerciseId);
        }
        for (final region in metadata.muscleRegions) {
          final group = muscleGroupForRegion(region);
          final units = metadata.primaryMuscles.contains(group) ? 2 : 1;
          final counter = regions[region]!;
          counter.units += effectiveSets * units;
          counter.exerciseIds.add(resolved.exerciseId);
        }
        final movement = movements[metadata.movementPattern]!;
        movement.effectiveSets += effectiveSets;
        movement.exerciseIds.add(resolved.exerciseId);
      }
    }

    return TrainingCoverageResult(
      sessionIds: sessionList.map((session) => session.id).toList(),
      targetBodyParts: targetBodyParts.toList()..sort(),
      targetMuscleGroups: targetMuscles.toList()
        ..sort((left, right) => left.index.compareTo(right.index)),
      muscleCoverage: [
        for (final group in MuscleGroup.values)
          MuscleCoverageItem(
            muscle: group,
            level: coverageLevelForUnits(muscles[group]!.units),
            primaryContribution: muscles[group]!.primary,
            secondaryContribution: muscles[group]!.secondary,
            effectiveSetCount: muscles[group]!.effectiveSets,
            contributingExerciseIds: muscles[group]!.exerciseIds.toList()
              ..sort(),
          ),
      ],
      regionCoverage: [
        for (final region in MuscleRegion.values)
          RegionCoverageItem(
            region: region,
            level: coverageLevelForUnits(regions[region]!.units),
            contributionUnits: regions[region]!.units,
            contributingExerciseIds: regions[region]!.exerciseIds.toList()
              ..sort(),
          ),
      ],
      movementPatternCoverage: [
        for (final pattern in ExerciseMovementPattern.values)
          MovementCoverageItem(
            pattern: pattern,
            effectiveSetCount: movements[pattern]!.effectiveSets,
            level: movementCoverageLevel(movements[pattern]!.effectiveSets),
            contributingExerciseIds: movements[pattern]!.exerciseIds.toList()
              ..sort(),
          ),
      ],
      completedEffectiveSets: completedEffectiveSets,
      dataQuality: _dataQuality(
        effectiveSets: completedEffectiveSets,
        contributingExercises: contributingExercises,
        unresolvedExercises: unresolvedIds.length,
        legacyExercises: seenLegacyExercises.length,
      ),
      legacyResolvedExercises: seenLegacyExercises.length,
      unresolvedExerciseIds: unresolvedIds.toList()..sort(),
    );
  }

  CoverageLevel coverageLevelForUnits(int units) {
    if (units <= 0) return CoverageLevel.untrained;
    if (units <= 2) return CoverageLevel.light;
    if (units <= 5) return CoverageLevel.moderate;
    if (units <= 8) return CoverageLevel.sufficient;
    return CoverageLevel.high;
  }

  CoverageLevel movementCoverageLevel(int effectiveSets) {
    if (effectiveSets <= 0) return CoverageLevel.untrained;
    if (effectiveSets == 1) return CoverageLevel.light;
    if (effectiveSets == 2) return CoverageLevel.moderate;
    if (effectiveSets <= 4) return CoverageLevel.sufficient;
    return CoverageLevel.high;
  }

  _ResolvedExercise _resolveExercise(
    TrainingExercise exercise, {
    required List<ExerciseDefinition> catalog,
    required Map<String, ExerciseMetadata> metadataCatalog,
  }) {
    final id = exercise.exerciseId?.trim();
    if (id != null && id.isNotEmpty) {
      return _ResolvedExercise(
        exerciseId: id,
        metadata: metadataCatalog[id],
        usedLegacyName: false,
      );
    }
    final normalizedName = _normalizeName(exercise.exerciseName);
    final definition = catalog
        .where((item) => _normalizeName(item.name) == normalizedName)
        .firstOrNull;
    if (definition != null) {
      return _ResolvedExercise(
        exerciseId: definition.id,
        metadata: metadataCatalog[definition.id],
        usedLegacyName: true,
      );
    }
    return _ResolvedExercise(
      exerciseId: 'legacy:$normalizedName',
      metadata: null,
      usedLegacyName: true,
    );
  }

  CoverageDataQuality _dataQuality({
    required int effectiveSets,
    required int contributingExercises,
    required int unresolvedExercises,
    required int legacyExercises,
  }) {
    if (effectiveSets == 0) return CoverageDataQuality.insufficient;
    final gaps = unresolvedExercises + legacyExercises;
    if (gaps == 0) return CoverageDataQuality.high;
    if (contributingExercises > 0 && gaps * 2 < contributingExercises) {
      return CoverageDataQuality.medium;
    }
    return CoverageDataQuality.low;
  }

  String _normalizeName(String value) =>
      value.trim().toLowerCase().replaceAll(RegExp(r'[\s·・_-]+'), '');
}

class _ResolvedExercise {
  const _ResolvedExercise({
    required this.exerciseId,
    required this.metadata,
    required this.usedLegacyName,
  });

  final String exerciseId;
  final ExerciseMetadata? metadata;
  final bool usedLegacyName;
}

class _MuscleCounter {
  int primary = 0;
  int secondary = 0;
  int effectiveSets = 0;
  final Set<String> exerciseIds = {};

  int get units => primary + secondary;
}

class _RegionCounter {
  int units = 0;
  final Set<String> exerciseIds = {};
}

class _MovementCounter {
  int effectiveSets = 0;
  final Set<String> exerciseIds = {};
}

extension _FirstOrNull<T> on Iterable<T> {
  T? get firstOrNull {
    final iterator = this.iterator;
    return iterator.moveNext() ? iterator.current : null;
  }
}
