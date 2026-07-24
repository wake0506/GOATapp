import '../../../exercise_catalog.dart';
import '../../../models/rest_prescription.dart';

class ExerciseRestProfileCatalog {
  ExerciseRestProfileCatalog._();

  static const List<ExerciseRestProfile> profiles = [
    ExerciseRestProfile(
      exerciseId: 'clean',
      restClass: ExerciseRestClass.olympicPower,
    ),
    ExerciseRestProfile(
      exerciseId: 'snatch',
      restClass: ExerciseRestClass.olympicPower,
    ),
    ExerciseRestProfile(
      exerciseId: 'clean_and_jerk',
      restClass: ExerciseRestClass.olympicPower,
    ),

    ExerciseRestProfile(
      exerciseId: 'conventional_deadlift',
      restClass: ExerciseRestClass.heavyCompound,
    ),
    ExerciseRestProfile(
      exerciseId: 'sumo_deadlift',
      restClass: ExerciseRestClass.heavyCompound,
    ),
    ExerciseRestProfile(
      exerciseId: 'barbell_bent_over_row',
      restClass: ExerciseRestClass.heavyCompound,
    ),
    ExerciseRestProfile(
      exerciseId: 'pendlay_row',
      restClass: ExerciseRestClass.heavyCompound,
    ),
    ExerciseRestProfile(
      exerciseId: 'barbell_back_squat',
      restClass: ExerciseRestClass.heavyCompound,
    ),
    ExerciseRestProfile(
      exerciseId: 'high_bar_squat',
      restClass: ExerciseRestClass.heavyCompound,
    ),
    ExerciseRestProfile(
      exerciseId: 'front_squat',
      restClass: ExerciseRestClass.heavyCompound,
    ),
    ExerciseRestProfile(
      exerciseId: 'pause_squat',
      restClass: ExerciseRestClass.heavyCompound,
    ),
    ExerciseRestProfile(
      exerciseId: 'romanian_deadlift',
      restClass: ExerciseRestClass.heavyCompound,
    ),
    ExerciseRestProfile(
      exerciseId: 'stiff_leg_deadlift',
      restClass: ExerciseRestClass.heavyCompound,
    ),
    ExerciseRestProfile(
      exerciseId: 'good_morning',
      restClass: ExerciseRestClass.heavyCompound,
    ),
    ExerciseRestProfile(
      exerciseId: 'turkish_get_up',
      restClass: ExerciseRestClass.heavyCompound,
    ),

    ExerciseRestProfile(
      exerciseId: 'barbell_flat_bench_press',
      restClass: ExerciseRestClass.standardCompound,
    ),
    ExerciseRestProfile(
      exerciseId: 'barbell_incline_bench_press',
      restClass: ExerciseRestClass.standardCompound,
    ),
    ExerciseRestProfile(
      exerciseId: 'barbell_decline_bench_press',
      restClass: ExerciseRestClass.standardCompound,
    ),
    ExerciseRestProfile(
      exerciseId: 'dumbbell_flat_bench_press',
      restClass: ExerciseRestClass.standardCompound,
    ),
    ExerciseRestProfile(
      exerciseId: 'dumbbell_incline_bench_press',
      restClass: ExerciseRestClass.standardCompound,
    ),
    ExerciseRestProfile(
      exerciseId: 'dumbbell_decline_bench_press',
      restClass: ExerciseRestClass.standardCompound,
    ),
    ExerciseRestProfile(
      exerciseId: 'parallel_bar_dip',
      restClass: ExerciseRestClass.standardCompound,
    ),
    ExerciseRestProfile(
      exerciseId: 'standard_push_up',
      restClass: ExerciseRestClass.standardCompound,
    ),
    ExerciseRestProfile(
      exerciseId: 'wide_push_up',
      restClass: ExerciseRestClass.standardCompound,
    ),
    ExerciseRestProfile(
      exerciseId: 'incline_push_up',
      restClass: ExerciseRestClass.standardCompound,
    ),
    ExerciseRestProfile(
      exerciseId: 'decline_push_up',
      restClass: ExerciseRestClass.standardCompound,
    ),
    ExerciseRestProfile(
      exerciseId: 'cable_chest_press',
      restClass: ExerciseRestClass.standardCompound,
    ),
    ExerciseRestProfile(
      exerciseId: 'dumbbell_one_arm_row',
      restClass: ExerciseRestClass.standardCompound,
    ),
    ExerciseRestProfile(
      exerciseId: 'dumbbell_chest_supported_row',
      restClass: ExerciseRestClass.standardCompound,
    ),
    ExerciseRestProfile(
      exerciseId: 'pull_up',
      restClass: ExerciseRestClass.standardCompound,
    ),
    ExerciseRestProfile(
      exerciseId: 'chin_up',
      restClass: ExerciseRestClass.standardCompound,
    ),
    ExerciseRestProfile(
      exerciseId: 'cable_one_arm_row',
      restClass: ExerciseRestClass.standardCompound,
    ),
    ExerciseRestProfile(
      exerciseId: 'bulgarian_split_squat',
      restClass: ExerciseRestClass.standardCompound,
    ),
    ExerciseRestProfile(
      exerciseId: 'dumbbell_lunge',
      restClass: ExerciseRestClass.standardCompound,
    ),
    ExerciseRestProfile(
      exerciseId: 'walking_lunge',
      restClass: ExerciseRestClass.standardCompound,
    ),
    ExerciseRestProfile(
      exerciseId: 'goblet_squat',
      restClass: ExerciseRestClass.standardCompound,
    ),
    ExerciseRestProfile(
      exerciseId: 'single_leg_romanian_deadlift',
      restClass: ExerciseRestClass.standardCompound,
    ),
    ExerciseRestProfile(
      exerciseId: 'reverse_lunge',
      restClass: ExerciseRestClass.standardCompound,
    ),
    ExerciseRestProfile(
      exerciseId: 'single_leg_box_squat',
      restClass: ExerciseRestClass.standardCompound,
    ),
    ExerciseRestProfile(
      exerciseId: 'barbell_standing_press',
      restClass: ExerciseRestClass.standardCompound,
    ),
    ExerciseRestProfile(
      exerciseId: 'barbell_seated_press',
      restClass: ExerciseRestClass.standardCompound,
    ),
    ExerciseRestProfile(
      exerciseId: 'dumbbell_seated_press',
      restClass: ExerciseRestClass.standardCompound,
    ),
    ExerciseRestProfile(
      exerciseId: 'arnold_press',
      restClass: ExerciseRestClass.standardCompound,
    ),
    ExerciseRestProfile(
      exerciseId: 'handstand_push_up',
      restClass: ExerciseRestClass.standardCompound,
    ),
    ExerciseRestProfile(
      exerciseId: 'pike_push_up',
      restClass: ExerciseRestClass.standardCompound,
    ),
    ExerciseRestProfile(
      exerciseId: 'close_grip_bench_press',
      restClass: ExerciseRestClass.standardCompound,
    ),
    ExerciseRestProfile(
      exerciseId: 'parallel_bar_dip_triceps',
      restClass: ExerciseRestClass.standardCompound,
    ),
    ExerciseRestProfile(
      exerciseId: 'diamond_push_up',
      restClass: ExerciseRestClass.standardCompound,
    ),
    ExerciseRestProfile(
      exerciseId: 'barbell_hip_thrust',
      restClass: ExerciseRestClass.standardCompound,
    ),
    ExerciseRestProfile(
      exerciseId: 'single_leg_hip_thrust',
      restClass: ExerciseRestClass.standardCompound,
    ),
    ExerciseRestProfile(
      exerciseId: 'dumbbell_hip_thrust',
      restClass: ExerciseRestClass.standardCompound,
    ),
    ExerciseRestProfile(
      exerciseId: 'step_up',
      restClass: ExerciseRestClass.standardCompound,
    ),
    ExerciseRestProfile(
      exerciseId: 'push_press',
      restClass: ExerciseRestClass.standardCompound,
    ),
    ExerciseRestProfile(
      exerciseId: 'kettlebell_swing',
      restClass: ExerciseRestClass.standardCompound,
    ),
    ExerciseRestProfile(
      exerciseId: 'kettlebell_goblet_squat',
      restClass: ExerciseRestClass.standardCompound,
    ),
    ExerciseRestProfile(
      exerciseId: 'farmer_carry',
      restClass: ExerciseRestClass.standardCompound,
    ),

    ExerciseRestProfile(
      exerciseId: 'smith_flat_bench_press',
      restClass: ExerciseRestClass.machineCompound,
    ),
    ExerciseRestProfile(
      exerciseId: 'smith_incline_bench_press',
      restClass: ExerciseRestClass.machineCompound,
    ),
    ExerciseRestProfile(
      exerciseId: 'machine_chest_press',
      restClass: ExerciseRestClass.machineCompound,
    ),
    ExerciseRestProfile(
      exerciseId: 't_bar_row',
      restClass: ExerciseRestClass.machineCompound,
    ),
    ExerciseRestProfile(
      exerciseId: 'lat_pulldown',
      restClass: ExerciseRestClass.machineCompound,
    ),
    ExerciseRestProfile(
      exerciseId: 'wide_grip_lat_pulldown',
      restClass: ExerciseRestClass.machineCompound,
    ),
    ExerciseRestProfile(
      exerciseId: 'reverse_grip_lat_pulldown',
      restClass: ExerciseRestClass.machineCompound,
    ),
    ExerciseRestProfile(
      exerciseId: 'seated_cable_row',
      restClass: ExerciseRestClass.machineCompound,
    ),
    ExerciseRestProfile(
      exerciseId: 'single_arm_machine_row',
      restClass: ExerciseRestClass.machineCompound,
    ),
    ExerciseRestProfile(
      exerciseId: 'machine_chest_supported_row',
      restClass: ExerciseRestClass.machineCompound,
    ),
    ExerciseRestProfile(
      exerciseId: 'assisted_pull_up',
      restClass: ExerciseRestClass.machineCompound,
    ),
    ExerciseRestProfile(
      exerciseId: 'leg_press',
      restClass: ExerciseRestClass.machineCompound,
    ),
    ExerciseRestProfile(
      exerciseId: 'hack_squat',
      restClass: ExerciseRestClass.machineCompound,
    ),
    ExerciseRestProfile(
      exerciseId: 'smith_squat',
      restClass: ExerciseRestClass.machineCompound,
    ),
    ExerciseRestProfile(
      exerciseId: 'smith_lunge',
      restClass: ExerciseRestClass.machineCompound,
    ),
    ExerciseRestProfile(
      exerciseId: 'smith_shoulder_press',
      restClass: ExerciseRestClass.machineCompound,
    ),
    ExerciseRestProfile(
      exerciseId: 'machine_shoulder_press',
      restClass: ExerciseRestClass.machineCompound,
    ),
    ExerciseRestProfile(
      exerciseId: 'sled_push',
      restClass: ExerciseRestClass.machineCompound,
    ),

    ExerciseRestProfile(
      exerciseId: 'dumbbell_fly',
      restClass: ExerciseRestClass.isolation,
    ),
    ExerciseRestProfile(
      exerciseId: 'incline_dumbbell_fly',
      restClass: ExerciseRestClass.isolation,
    ),
    ExerciseRestProfile(
      exerciseId: 'pec_deck_fly',
      restClass: ExerciseRestClass.isolation,
    ),
    ExerciseRestProfile(
      exerciseId: 'cable_fly',
      restClass: ExerciseRestClass.isolation,
    ),
    ExerciseRestProfile(
      exerciseId: 'low_cable_fly',
      restClass: ExerciseRestClass.isolation,
    ),
    ExerciseRestProfile(
      exerciseId: 'scapular_pull_up',
      restClass: ExerciseRestClass.isolation,
    ),
    ExerciseRestProfile(
      exerciseId: 'straight_arm_pulldown',
      restClass: ExerciseRestClass.isolation,
    ),
    ExerciseRestProfile(
      exerciseId: 'face_pull',
      restClass: ExerciseRestClass.isolation,
    ),
    ExerciseRestProfile(
      exerciseId: 'back_extension',
      restClass: ExerciseRestClass.isolation,
    ),
    ExerciseRestProfile(
      exerciseId: 'seated_leg_extension',
      restClass: ExerciseRestClass.isolation,
    ),
    ExerciseRestProfile(
      exerciseId: 'lying_leg_curl',
      restClass: ExerciseRestClass.isolation,
    ),
    ExerciseRestProfile(
      exerciseId: 'seated_leg_curl',
      restClass: ExerciseRestClass.isolation,
    ),
    ExerciseRestProfile(
      exerciseId: 'standing_leg_curl',
      restClass: ExerciseRestClass.isolation,
    ),
    ExerciseRestProfile(
      exerciseId: 'hip_adduction_machine',
      restClass: ExerciseRestClass.isolation,
    ),
    ExerciseRestProfile(
      exerciseId: 'hip_abduction_machine',
      restClass: ExerciseRestClass.isolation,
    ),
    ExerciseRestProfile(
      exerciseId: 'bodyweight_squat',
      restClass: ExerciseRestClass.isolation,
    ),
    ExerciseRestProfile(
      exerciseId: 'jump_squat',
      restClass: ExerciseRestClass.isolation,
    ),
    ExerciseRestProfile(
      exerciseId: 'dumbbell_lateral_raise',
      restClass: ExerciseRestClass.isolation,
    ),
    ExerciseRestProfile(
      exerciseId: 'dumbbell_front_raise',
      restClass: ExerciseRestClass.isolation,
    ),
    ExerciseRestProfile(
      exerciseId: 'dumbbell_rear_delt_fly',
      restClass: ExerciseRestClass.isolation,
    ),
    ExerciseRestProfile(
      exerciseId: 'reverse_pec_deck',
      restClass: ExerciseRestClass.isolation,
    ),
    ExerciseRestProfile(
      exerciseId: 'cable_lateral_raise',
      restClass: ExerciseRestClass.isolation,
    ),
    ExerciseRestProfile(
      exerciseId: 'cable_front_raise',
      restClass: ExerciseRestClass.isolation,
    ),
    ExerciseRestProfile(
      exerciseId: 'cable_rear_delt_fly',
      restClass: ExerciseRestClass.isolation,
    ),
    ExerciseRestProfile(
      exerciseId: 'plank',
      restClass: ExerciseRestClass.isolation,
    ),
    ExerciseRestProfile(
      exerciseId: 'side_plank',
      restClass: ExerciseRestClass.isolation,
    ),
    ExerciseRestProfile(
      exerciseId: 'crunch',
      restClass: ExerciseRestClass.isolation,
    ),
    ExerciseRestProfile(
      exerciseId: 'reverse_crunch',
      restClass: ExerciseRestClass.isolation,
    ),
    ExerciseRestProfile(
      exerciseId: 'bicycle_crunch',
      restClass: ExerciseRestClass.isolation,
    ),
    ExerciseRestProfile(
      exerciseId: 'dead_bug',
      restClass: ExerciseRestClass.isolation,
    ),
    ExerciseRestProfile(
      exerciseId: 'bird_dog',
      restClass: ExerciseRestClass.isolation,
    ),
    ExerciseRestProfile(
      exerciseId: 'hanging_leg_raise',
      restClass: ExerciseRestClass.isolation,
    ),
    ExerciseRestProfile(
      exerciseId: 'hanging_knee_raise',
      restClass: ExerciseRestClass.isolation,
    ),
    ExerciseRestProfile(
      exerciseId: 'ab_wheel_rollout',
      restClass: ExerciseRestClass.isolation,
    ),
    ExerciseRestProfile(
      exerciseId: 'russian_twist',
      restClass: ExerciseRestClass.isolation,
    ),
    ExerciseRestProfile(
      exerciseId: 'cable_crunch',
      restClass: ExerciseRestClass.isolation,
    ),
    ExerciseRestProfile(
      exerciseId: 'pallof_press',
      restClass: ExerciseRestClass.isolation,
    ),
    ExerciseRestProfile(
      exerciseId: 'lying_leg_raise',
      restClass: ExerciseRestClass.isolation,
    ),
    ExerciseRestProfile(
      exerciseId: 'glute_bridge',
      restClass: ExerciseRestClass.isolation,
    ),
    ExerciseRestProfile(
      exerciseId: 'single_leg_glute_bridge',
      restClass: ExerciseRestClass.isolation,
    ),
    ExerciseRestProfile(
      exerciseId: 'cable_kickback',
      restClass: ExerciseRestClass.isolation,
    ),
    ExerciseRestProfile(
      exerciseId: 'hip_abduction_machine_glute',
      restClass: ExerciseRestClass.isolation,
    ),
    ExerciseRestProfile(
      exerciseId: 'forty_five_degree_back_extension',
      restClass: ExerciseRestClass.isolation,
    ),
    ExerciseRestProfile(
      exerciseId: 'clamshell',
      restClass: ExerciseRestClass.isolation,
    ),

    ExerciseRestProfile(
      exerciseId: 'standing_calf_raise',
      restClass: ExerciseRestClass.smallMuscleIsolation,
    ),
    ExerciseRestProfile(
      exerciseId: 'seated_calf_raise',
      restClass: ExerciseRestClass.smallMuscleIsolation,
    ),
    ExerciseRestProfile(
      exerciseId: 'single_leg_calf_raise',
      restClass: ExerciseRestClass.smallMuscleIsolation,
    ),
    ExerciseRestProfile(
      exerciseId: 'barbell_curl',
      restClass: ExerciseRestClass.smallMuscleIsolation,
    ),
    ExerciseRestProfile(
      exerciseId: 'ez_bar_curl',
      restClass: ExerciseRestClass.smallMuscleIsolation,
    ),
    ExerciseRestProfile(
      exerciseId: 'dumbbell_alternating_curl',
      restClass: ExerciseRestClass.smallMuscleIsolation,
    ),
    ExerciseRestProfile(
      exerciseId: 'hammer_curl',
      restClass: ExerciseRestClass.smallMuscleIsolation,
    ),
    ExerciseRestProfile(
      exerciseId: 'incline_dumbbell_curl',
      restClass: ExerciseRestClass.smallMuscleIsolation,
    ),
    ExerciseRestProfile(
      exerciseId: 'concentration_curl',
      restClass: ExerciseRestClass.smallMuscleIsolation,
    ),
    ExerciseRestProfile(
      exerciseId: 'preacher_curl',
      restClass: ExerciseRestClass.smallMuscleIsolation,
    ),
    ExerciseRestProfile(
      exerciseId: 'cable_curl',
      restClass: ExerciseRestClass.smallMuscleIsolation,
    ),
    ExerciseRestProfile(
      exerciseId: 'cable_hammer_curl',
      restClass: ExerciseRestClass.smallMuscleIsolation,
    ),
    ExerciseRestProfile(
      exerciseId: 'barbell_skull_crusher',
      restClass: ExerciseRestClass.smallMuscleIsolation,
    ),
    ExerciseRestProfile(
      exerciseId: 'dumbbell_overhead_extension',
      restClass: ExerciseRestClass.smallMuscleIsolation,
    ),
    ExerciseRestProfile(
      exerciseId: 'lying_triceps_extension',
      restClass: ExerciseRestClass.smallMuscleIsolation,
    ),
    ExerciseRestProfile(
      exerciseId: 'cable_triceps_pushdown',
      restClass: ExerciseRestClass.smallMuscleIsolation,
    ),
    ExerciseRestProfile(
      exerciseId: 'reverse_grip_pushdown',
      restClass: ExerciseRestClass.smallMuscleIsolation,
    ),
    ExerciseRestProfile(
      exerciseId: 'cable_overhead_extension',
      restClass: ExerciseRestClass.smallMuscleIsolation,
    ),

    ExerciseRestProfile(
      exerciseId: 'rowing_machine',
      restClass: ExerciseRestClass.other,
    ),
    ExerciseRestProfile(
      exerciseId: 'air_bike',
      restClass: ExerciseRestClass.other,
    ),
    ExerciseRestProfile(
      exerciseId: 'battle_rope',
      restClass: ExerciseRestClass.other,
    ),
    ExerciseRestProfile(
      exerciseId: 'burpee',
      restClass: ExerciseRestClass.other,
    ),
    ExerciseRestProfile(
      exerciseId: 'mountain_climber',
      restClass: ExerciseRestClass.other,
    ),
    ExerciseRestProfile(
      exerciseId: 'jumping_jack',
      restClass: ExerciseRestClass.other,
    ),
    ExerciseRestProfile(
      exerciseId: 'bear_crawl',
      restClass: ExerciseRestClass.other,
    ),
  ];

  static final Map<String, ExerciseRestProfile> byId = Map.unmodifiable({
    for (final profile in profiles) profile.exerciseId: profile,
  });

  static ExerciseRestProfile? find(String? exerciseId) =>
      exerciseId == null ? null : byId[exerciseId];

  static RestProfileIntegrityReport validate({
    Iterable<ExerciseDefinition> catalog = exerciseCatalog,
  }) {
    final counts = <String, int>{};
    for (final profile in profiles) {
      counts.update(
        profile.exerciseId,
        (value) => value + 1,
        ifAbsent: () => 1,
      );
    }
    final catalogIds = catalog.map((exercise) => exercise.id).toSet();
    return RestProfileIntegrityReport(
      catalogCount: catalogIds.length,
      mappedCount: profiles.length,
      missingExerciseIds: catalogIds.difference(counts.keys.toSet()).toList()
        ..sort(),
      unknownExerciseIds: counts.keys.toSet().difference(catalogIds).toList()
        ..sort(),
      duplicateExerciseIds:
          counts.entries
              .where((entry) => entry.value > 1)
              .map((entry) => entry.key)
              .toList()
            ..sort(),
    );
  }
}

class RestProfileIntegrityReport {
  const RestProfileIntegrityReport({
    required this.catalogCount,
    required this.mappedCount,
    required this.missingExerciseIds,
    required this.unknownExerciseIds,
    required this.duplicateExerciseIds,
  });

  final int catalogCount;
  final int mappedCount;
  final List<String> missingExerciseIds;
  final List<String> unknownExerciseIds;
  final List<String> duplicateExerciseIds;

  bool get isValid =>
      catalogCount == mappedCount &&
      missingExerciseIds.isEmpty &&
      unknownExerciseIds.isEmpty &&
      duplicateExerciseIds.isEmpty;
}
