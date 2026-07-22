import 'exercise_metadata.dart';

final Map<String, ExerciseMetadata> exerciseMetadataCatalog = Map.unmodifiable(
  _buildExerciseMetadataCatalog(),
);

ExerciseMetadata? exerciseMetadataById(String exerciseId) =>
    exerciseMetadataCatalog[exerciseId.trim()];

Map<String, ExerciseMetadata> _buildExerciseMetadataCatalog() {
  final result = <String, ExerciseMetadata>{};

  void reviewed(
    List<String> ids, {
    required String bodyPart,
    required List<MuscleGroup> primary,
    List<MuscleGroup> secondary = const [],
    required List<MuscleRegion> regions,
    required ExerciseMovementPattern pattern,
  }) {
    for (final id in ids) {
      result[id] = ExerciseMetadata(
        exerciseId: id,
        status: ExerciseMetadataStatus.reviewed,
        primaryMuscles: primary,
        secondaryMuscles: secondary,
        muscleRegions: regions,
        movementPattern: pattern,
        fallbackBodyPart: bodyPart,
      );
    }
  }

  void unresolved(List<String> ids, {required String bodyPart}) {
    for (final id in ids) {
      result[id] = ExerciseMetadata(
        exerciseId: id,
        status: ExerciseMetadataStatus.unresolved,
        primaryMuscles: const [],
        secondaryMuscles: const [],
        muscleRegions: const [],
        movementPattern: ExerciseMovementPattern.other,
        fallbackBodyPart: bodyPart,
      );
    }
  }

  reviewed(
    [
      'barbell_flat_bench_press',
      'dumbbell_flat_bench_press',
      'smith_flat_bench_press',
      'machine_chest_press',
      'standard_push_up',
      'wide_push_up',
      'cable_chest_press',
    ],
    bodyPart: '胸部',
    primary: const [MuscleGroup.chest],
    secondary: const [MuscleGroup.shoulders, MuscleGroup.arms],
    regions: const [
      MuscleRegion.midChest,
      MuscleRegion.frontDelts,
      MuscleRegion.triceps,
    ],
    pattern: ExerciseMovementPattern.horizontalPush,
  );
  reviewed(
    [
      'barbell_incline_bench_press',
      'dumbbell_incline_bench_press',
      'smith_incline_bench_press',
      'decline_push_up',
    ],
    bodyPart: '胸部',
    primary: const [MuscleGroup.chest],
    secondary: const [MuscleGroup.shoulders, MuscleGroup.arms],
    regions: const [
      MuscleRegion.upperChest,
      MuscleRegion.frontDelts,
      MuscleRegion.triceps,
    ],
    pattern: ExerciseMovementPattern.horizontalPush,
  );
  reviewed(
    [
      'barbell_decline_bench_press',
      'dumbbell_decline_bench_press',
      'incline_push_up',
    ],
    bodyPart: '胸部',
    primary: const [MuscleGroup.chest],
    secondary: const [MuscleGroup.shoulders, MuscleGroup.arms],
    regions: const [
      MuscleRegion.lowerChest,
      MuscleRegion.frontDelts,
      MuscleRegion.triceps,
    ],
    pattern: ExerciseMovementPattern.horizontalPush,
  );
  reviewed(
    ['dumbbell_fly', 'pec_deck_fly', 'cable_fly'],
    bodyPart: '胸部',
    primary: const [MuscleGroup.chest],
    regions: const [MuscleRegion.midChest],
    pattern: ExerciseMovementPattern.horizontalPush,
  );
  reviewed(
    ['incline_dumbbell_fly', 'low_cable_fly'],
    bodyPart: '胸部',
    primary: const [MuscleGroup.chest],
    regions: const [MuscleRegion.upperChest],
    pattern: ExerciseMovementPattern.horizontalPush,
  );
  reviewed(
    ['parallel_bar_dip'],
    bodyPart: '胸部',
    primary: const [MuscleGroup.chest],
    secondary: const [MuscleGroup.arms],
    regions: const [MuscleRegion.lowerChest, MuscleRegion.triceps],
    pattern: ExerciseMovementPattern.horizontalPush,
  );

  reviewed(
    ['conventional_deadlift', 'sumo_deadlift'],
    bodyPart: '背部',
    primary: const [MuscleGroup.back, MuscleGroup.glutes],
    secondary: const [MuscleGroup.legs, MuscleGroup.core],
    regions: const [
      MuscleRegion.lowerBack,
      MuscleRegion.glutes,
      MuscleRegion.hamstrings,
      MuscleRegion.spinalErectors,
    ],
    pattern: ExerciseMovementPattern.hinge,
  );
  reviewed(
    [
      'barbell_bent_over_row',
      'pendlay_row',
      'dumbbell_one_arm_row',
      'dumbbell_chest_supported_row',
      't_bar_row',
      'seated_cable_row',
      'single_arm_machine_row',
      'machine_chest_supported_row',
      'cable_one_arm_row',
    ],
    bodyPart: '背部',
    primary: const [MuscleGroup.back],
    secondary: const [MuscleGroup.arms],
    regions: const [
      MuscleRegion.lats,
      MuscleRegion.midBack,
      MuscleRegion.biceps,
    ],
    pattern: ExerciseMovementPattern.horizontalPull,
  );
  reviewed(
    [
      'lat_pulldown',
      'wide_grip_lat_pulldown',
      'reverse_grip_lat_pulldown',
      'pull_up',
      'chin_up',
      'assisted_pull_up',
    ],
    bodyPart: '背部',
    primary: const [MuscleGroup.back],
    secondary: const [MuscleGroup.arms],
    regions: const [MuscleRegion.lats, MuscleRegion.biceps],
    pattern: ExerciseMovementPattern.verticalPull,
  );
  reviewed(
    ['scapular_pull_up', 'straight_arm_pulldown'],
    bodyPart: '背部',
    primary: const [MuscleGroup.back],
    regions: const [MuscleRegion.lats, MuscleRegion.upperBack],
    pattern: ExerciseMovementPattern.verticalPull,
  );
  reviewed(
    ['face_pull'],
    bodyPart: '背部',
    primary: const [MuscleGroup.back, MuscleGroup.shoulders],
    regions: const [MuscleRegion.upperBack, MuscleRegion.rearDelts],
    pattern: ExerciseMovementPattern.horizontalPull,
  );
  reviewed(
    ['back_extension'],
    bodyPart: '背部',
    primary: const [MuscleGroup.back, MuscleGroup.core],
    secondary: const [MuscleGroup.glutes],
    regions: const [
      MuscleRegion.lowerBack,
      MuscleRegion.spinalErectors,
      MuscleRegion.glutes,
    ],
    pattern: ExerciseMovementPattern.hinge,
  );

  reviewed(
    [
      'barbell_back_squat',
      'high_bar_squat',
      'front_squat',
      'pause_squat',
      'goblet_squat',
      'leg_press',
      'hack_squat',
      'smith_squat',
      'bodyweight_squat',
      'jump_squat',
      'single_leg_box_squat',
    ],
    bodyPart: '腿部',
    primary: const [MuscleGroup.legs, MuscleGroup.glutes],
    regions: const [MuscleRegion.quads, MuscleRegion.glutes],
    pattern: ExerciseMovementPattern.squat,
  );
  reviewed(
    [
      'romanian_deadlift',
      'stiff_leg_deadlift',
      'good_morning',
      'single_leg_romanian_deadlift',
    ],
    bodyPart: '腿部',
    primary: const [MuscleGroup.legs, MuscleGroup.glutes],
    secondary: const [MuscleGroup.back, MuscleGroup.core],
    regions: const [
      MuscleRegion.hamstrings,
      MuscleRegion.glutes,
      MuscleRegion.lowerBack,
      MuscleRegion.spinalErectors,
    ],
    pattern: ExerciseMovementPattern.hinge,
  );
  reviewed(
    [
      'bulgarian_split_squat',
      'dumbbell_lunge',
      'walking_lunge',
      'smith_lunge',
      'reverse_lunge',
    ],
    bodyPart: '腿部',
    primary: const [MuscleGroup.legs, MuscleGroup.glutes],
    regions: const [
      MuscleRegion.quads,
      MuscleRegion.hamstrings,
      MuscleRegion.glutes,
    ],
    pattern: ExerciseMovementPattern.lunge,
  );
  reviewed(
    ['seated_leg_extension'],
    bodyPart: '腿部',
    primary: const [MuscleGroup.legs],
    regions: const [MuscleRegion.quads],
    pattern: ExerciseMovementPattern.squat,
  );
  reviewed(
    ['lying_leg_curl', 'seated_leg_curl', 'standing_leg_curl'],
    bodyPart: '腿部',
    primary: const [MuscleGroup.legs],
    regions: const [MuscleRegion.hamstrings],
    pattern: ExerciseMovementPattern.hinge,
  );
  reviewed(
    ['hip_adduction_machine'],
    bodyPart: '腿部',
    primary: const [MuscleGroup.legs],
    regions: const [MuscleRegion.adductors],
    pattern: ExerciseMovementPattern.hipAdduction,
  );
  reviewed(
    ['hip_abduction_machine'],
    bodyPart: '腿部',
    primary: const [MuscleGroup.glutes],
    regions: const [MuscleRegion.glutes],
    pattern: ExerciseMovementPattern.hipAbduction,
  );
  reviewed(
    ['standing_calf_raise', 'seated_calf_raise', 'single_leg_calf_raise'],
    bodyPart: '腿部',
    primary: const [MuscleGroup.legs],
    regions: const [MuscleRegion.calves],
    pattern: ExerciseMovementPattern.calfRaise,
  );

  reviewed(
    [
      'barbell_standing_press',
      'barbell_seated_press',
      'dumbbell_seated_press',
      'arnold_press',
      'smith_shoulder_press',
      'machine_shoulder_press',
      'handstand_push_up',
      'pike_push_up',
    ],
    bodyPart: '肩部',
    primary: const [MuscleGroup.shoulders],
    secondary: const [MuscleGroup.arms],
    regions: const [
      MuscleRegion.frontDelts,
      MuscleRegion.sideDelts,
      MuscleRegion.triceps,
    ],
    pattern: ExerciseMovementPattern.verticalPush,
  );
  reviewed(
    ['dumbbell_lateral_raise', 'cable_lateral_raise'],
    bodyPart: '肩部',
    primary: const [MuscleGroup.shoulders],
    regions: const [MuscleRegion.sideDelts],
    pattern: ExerciseMovementPattern.shoulderIsolation,
  );
  reviewed(
    ['dumbbell_front_raise', 'cable_front_raise'],
    bodyPart: '肩部',
    primary: const [MuscleGroup.shoulders],
    regions: const [MuscleRegion.frontDelts],
    pattern: ExerciseMovementPattern.shoulderIsolation,
  );
  reviewed(
    ['dumbbell_rear_delt_fly', 'reverse_pec_deck', 'cable_rear_delt_fly'],
    bodyPart: '肩部',
    primary: const [MuscleGroup.shoulders],
    secondary: const [MuscleGroup.back],
    regions: const [MuscleRegion.rearDelts, MuscleRegion.upperBack],
    pattern: ExerciseMovementPattern.shoulderIsolation,
  );

  reviewed(
    [
      'barbell_curl',
      'ez_bar_curl',
      'dumbbell_alternating_curl',
      'incline_dumbbell_curl',
      'concentration_curl',
      'preacher_curl',
      'cable_curl',
    ],
    bodyPart: '手臂',
    primary: const [MuscleGroup.arms],
    regions: const [MuscleRegion.biceps],
    pattern: ExerciseMovementPattern.elbowFlexion,
  );
  reviewed(
    ['hammer_curl', 'cable_hammer_curl'],
    bodyPart: '手臂',
    primary: const [MuscleGroup.arms],
    regions: const [MuscleRegion.biceps, MuscleRegion.forearms],
    pattern: ExerciseMovementPattern.elbowFlexion,
  );
  reviewed(
    ['close_grip_bench_press', 'diamond_push_up'],
    bodyPart: '手臂',
    primary: const [MuscleGroup.arms],
    secondary: const [MuscleGroup.chest, MuscleGroup.shoulders],
    regions: const [
      MuscleRegion.triceps,
      MuscleRegion.midChest,
      MuscleRegion.frontDelts,
    ],
    pattern: ExerciseMovementPattern.elbowExtension,
  );
  reviewed(
    [
      'barbell_skull_crusher',
      'dumbbell_overhead_extension',
      'lying_triceps_extension',
      'cable_triceps_pushdown',
      'reverse_grip_pushdown',
      'cable_overhead_extension',
    ],
    bodyPart: '手臂',
    primary: const [MuscleGroup.arms],
    regions: const [MuscleRegion.triceps],
    pattern: ExerciseMovementPattern.elbowExtension,
  );
  reviewed(
    ['parallel_bar_dip_triceps'],
    bodyPart: '手臂',
    primary: const [MuscleGroup.arms],
    secondary: const [MuscleGroup.chest],
    regions: const [MuscleRegion.triceps, MuscleRegion.lowerChest],
    pattern: ExerciseMovementPattern.elbowExtension,
  );

  reviewed(
    ['plank', 'dead_bug', 'ab_wheel_rollout'],
    bodyPart: '核心',
    primary: const [MuscleGroup.core],
    regions: const [MuscleRegion.abs],
    pattern: ExerciseMovementPattern.core,
  );
  reviewed(
    ['side_plank', 'pallof_press'],
    bodyPart: '核心',
    primary: const [MuscleGroup.core],
    regions: const [MuscleRegion.obliques, MuscleRegion.abs],
    pattern: ExerciseMovementPattern.core,
  );
  reviewed(
    [
      'crunch',
      'reverse_crunch',
      'hanging_leg_raise',
      'hanging_knee_raise',
      'cable_crunch',
      'lying_leg_raise',
    ],
    bodyPart: '核心',
    primary: const [MuscleGroup.core],
    regions: const [MuscleRegion.abs],
    pattern: ExerciseMovementPattern.core,
  );
  reviewed(
    ['bicycle_crunch', 'russian_twist'],
    bodyPart: '核心',
    primary: const [MuscleGroup.core],
    regions: const [MuscleRegion.abs, MuscleRegion.obliques],
    pattern: ExerciseMovementPattern.core,
  );
  reviewed(
    ['bird_dog'],
    bodyPart: '核心',
    primary: const [MuscleGroup.core],
    secondary: const [MuscleGroup.glutes],
    regions: const [
      MuscleRegion.abs,
      MuscleRegion.spinalErectors,
      MuscleRegion.glutes,
    ],
    pattern: ExerciseMovementPattern.core,
  );

  reviewed(
    [
      'barbell_hip_thrust',
      'single_leg_hip_thrust',
      'dumbbell_hip_thrust',
      'glute_bridge',
      'single_leg_glute_bridge',
    ],
    bodyPart: '臀部',
    primary: const [MuscleGroup.glutes],
    secondary: const [MuscleGroup.legs],
    regions: const [MuscleRegion.glutes, MuscleRegion.hamstrings],
    pattern: ExerciseMovementPattern.hinge,
  );
  reviewed(
    ['cable_kickback'],
    bodyPart: '臀部',
    primary: const [MuscleGroup.glutes],
    regions: const [MuscleRegion.glutes],
    pattern: ExerciseMovementPattern.hinge,
  );
  reviewed(
    ['hip_abduction_machine_glute', 'clamshell'],
    bodyPart: '臀部',
    primary: const [MuscleGroup.glutes],
    regions: const [MuscleRegion.glutes],
    pattern: ExerciseMovementPattern.hipAbduction,
  );
  reviewed(
    ['forty_five_degree_back_extension'],
    bodyPart: '臀部',
    primary: const [MuscleGroup.glutes],
    secondary: const [MuscleGroup.legs, MuscleGroup.back, MuscleGroup.core],
    regions: const [
      MuscleRegion.glutes,
      MuscleRegion.hamstrings,
      MuscleRegion.lowerBack,
      MuscleRegion.spinalErectors,
    ],
    pattern: ExerciseMovementPattern.hinge,
  );
  reviewed(
    ['step_up'],
    bodyPart: '臀部',
    primary: const [MuscleGroup.glutes, MuscleGroup.legs],
    regions: const [MuscleRegion.glutes, MuscleRegion.quads],
    pattern: ExerciseMovementPattern.lunge,
  );

  unresolved([
    'clean',
    'snatch',
    'clean_and_jerk',
    'turkish_get_up',
  ], bodyPart: '全身/体能');
  reviewed(
    ['push_press'],
    bodyPart: '全身/体能',
    primary: const [MuscleGroup.shoulders],
    secondary: const [MuscleGroup.legs, MuscleGroup.arms],
    regions: const [
      MuscleRegion.frontDelts,
      MuscleRegion.quads,
      MuscleRegion.triceps,
    ],
    pattern: ExerciseMovementPattern.verticalPush,
  );
  reviewed(
    ['kettlebell_swing'],
    bodyPart: '全身/体能',
    primary: const [MuscleGroup.glutes, MuscleGroup.legs],
    secondary: const [MuscleGroup.back, MuscleGroup.core],
    regions: const [
      MuscleRegion.glutes,
      MuscleRegion.hamstrings,
      MuscleRegion.lowerBack,
      MuscleRegion.spinalErectors,
    ],
    pattern: ExerciseMovementPattern.hinge,
  );
  reviewed(
    ['kettlebell_goblet_squat'],
    bodyPart: '全身/体能',
    primary: const [MuscleGroup.legs, MuscleGroup.glutes],
    regions: const [MuscleRegion.quads, MuscleRegion.glutes],
    pattern: ExerciseMovementPattern.squat,
  );
  reviewed(
    ['farmer_carry'],
    bodyPart: '全身/体能',
    primary: const [MuscleGroup.arms, MuscleGroup.core],
    regions: const [
      MuscleRegion.forearms,
      MuscleRegion.abs,
      MuscleRegion.spinalErectors,
    ],
    pattern: ExerciseMovementPattern.carry,
  );
  reviewed(
    ['sled_push'],
    bodyPart: '全身/体能',
    primary: const [MuscleGroup.legs, MuscleGroup.glutes],
    regions: const [MuscleRegion.quads, MuscleRegion.glutes],
    pattern: ExerciseMovementPattern.conditioning,
  );
  reviewed(
    ['battle_rope'],
    bodyPart: '全身/体能',
    primary: const [MuscleGroup.shoulders, MuscleGroup.arms],
    secondary: const [MuscleGroup.core],
    regions: const [
      MuscleRegion.frontDelts,
      MuscleRegion.biceps,
      MuscleRegion.triceps,
      MuscleRegion.abs,
    ],
    pattern: ExerciseMovementPattern.conditioning,
  );
  reviewed(
    ['rowing_machine'],
    bodyPart: '全身/体能',
    primary: const [MuscleGroup.back, MuscleGroup.legs],
    secondary: const [MuscleGroup.arms],
    regions: const [
      MuscleRegion.lats,
      MuscleRegion.midBack,
      MuscleRegion.quads,
      MuscleRegion.biceps,
    ],
    pattern: ExerciseMovementPattern.horizontalPull,
  );
  reviewed(
    ['air_bike'],
    bodyPart: '全身/体能',
    primary: const [MuscleGroup.legs, MuscleGroup.arms],
    regions: const [
      MuscleRegion.quads,
      MuscleRegion.hamstrings,
      MuscleRegion.biceps,
      MuscleRegion.triceps,
    ],
    pattern: ExerciseMovementPattern.conditioning,
  );
  reviewed(
    ['burpee'],
    bodyPart: '全身/体能',
    primary: const [MuscleGroup.chest, MuscleGroup.legs, MuscleGroup.core],
    secondary: const [MuscleGroup.shoulders, MuscleGroup.arms],
    regions: const [
      MuscleRegion.midChest,
      MuscleRegion.quads,
      MuscleRegion.abs,
      MuscleRegion.frontDelts,
      MuscleRegion.triceps,
    ],
    pattern: ExerciseMovementPattern.conditioning,
  );
  reviewed(
    ['mountain_climber'],
    bodyPart: '全身/体能',
    primary: const [MuscleGroup.core, MuscleGroup.legs],
    regions: const [MuscleRegion.abs, MuscleRegion.quads],
    pattern: ExerciseMovementPattern.core,
  );
  reviewed(
    ['jumping_jack'],
    bodyPart: '全身/体能',
    primary: const [MuscleGroup.legs, MuscleGroup.shoulders],
    regions: const [MuscleRegion.calves, MuscleRegion.sideDelts],
    pattern: ExerciseMovementPattern.conditioning,
  );
  reviewed(
    ['bear_crawl'],
    bodyPart: '全身/体能',
    primary: const [MuscleGroup.core, MuscleGroup.shoulders],
    secondary: const [MuscleGroup.arms],
    regions: const [
      MuscleRegion.abs,
      MuscleRegion.frontDelts,
      MuscleRegion.triceps,
    ],
    pattern: ExerciseMovementPattern.conditioning,
  );

  return result;
}
