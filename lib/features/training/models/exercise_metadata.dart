enum MuscleGroup { chest, back, shoulders, arms, legs, glutes, core }

enum MuscleRegion {
  upperChest,
  midChest,
  lowerChest,
  lats,
  upperBack,
  midBack,
  lowerBack,
  frontDelts,
  sideDelts,
  rearDelts,
  biceps,
  triceps,
  forearms,
  quads,
  hamstrings,
  calves,
  adductors,
  glutes,
  abs,
  obliques,
  spinalErectors,
}

enum ExerciseMovementPattern {
  horizontalPush,
  verticalPush,
  horizontalPull,
  verticalPull,
  squat,
  hinge,
  lunge,
  elbowFlexion,
  elbowExtension,
  shoulderIsolation,
  hipAbduction,
  hipAdduction,
  calfRaise,
  carry,
  conditioning,
  core,
  other,
}

enum ExerciseMetadataStatus { verified, reviewed, unresolved }

class ExerciseMetadata {
  const ExerciseMetadata({
    required this.exerciseId,
    required this.status,
    required this.primaryMuscles,
    required this.secondaryMuscles,
    required this.muscleRegions,
    required this.movementPattern,
    required this.fallbackBodyPart,
  });

  final String exerciseId;
  final ExerciseMetadataStatus status;
  final List<MuscleGroup> primaryMuscles;
  final List<MuscleGroup> secondaryMuscles;
  final List<MuscleRegion> muscleRegions;
  final ExerciseMovementPattern movementPattern;
  final String fallbackBodyPart;

  bool get hasReliableRegions =>
      status != ExerciseMetadataStatus.unresolved && muscleRegions.isNotEmpty;
}

MuscleGroup muscleGroupForRegion(MuscleRegion region) => switch (region) {
  MuscleRegion.upperChest ||
  MuscleRegion.midChest ||
  MuscleRegion.lowerChest => MuscleGroup.chest,
  MuscleRegion.lats ||
  MuscleRegion.upperBack ||
  MuscleRegion.midBack ||
  MuscleRegion.lowerBack => MuscleGroup.back,
  MuscleRegion.frontDelts ||
  MuscleRegion.sideDelts ||
  MuscleRegion.rearDelts => MuscleGroup.shoulders,
  MuscleRegion.biceps ||
  MuscleRegion.triceps ||
  MuscleRegion.forearms => MuscleGroup.arms,
  MuscleRegion.quads ||
  MuscleRegion.hamstrings ||
  MuscleRegion.calves ||
  MuscleRegion.adductors => MuscleGroup.legs,
  MuscleRegion.glutes => MuscleGroup.glutes,
  MuscleRegion.abs ||
  MuscleRegion.obliques ||
  MuscleRegion.spinalErectors => MuscleGroup.core,
};

String muscleGroupStorageValue(MuscleGroup group) => group.name;

String muscleRegionStorageValue(MuscleRegion region) => region.name;

MuscleGroup? muscleGroupForBodyPart(String bodyPart) {
  final value = bodyPart.trim().toLowerCase();
  if (value.contains('胸') || value == 'chest') return MuscleGroup.chest;
  if (value.contains('背') || value == 'back') return MuscleGroup.back;
  if (value.contains('肩') || value.contains('shoulder')) {
    return MuscleGroup.shoulders;
  }
  if (value.contains('手臂') ||
      value.contains('二头') ||
      value.contains('三头') ||
      value == 'arms') {
    return MuscleGroup.arms;
  }
  if (value.contains('腿') || value.contains('leg')) return MuscleGroup.legs;
  if (value.contains('臀') || value.contains('glute')) {
    return MuscleGroup.glutes;
  }
  if (value.contains('核心') || value.contains('腹') || value == 'core') {
    return MuscleGroup.core;
  }
  return null;
}

String muscleGroupLabel(MuscleGroup group) => switch (group) {
  MuscleGroup.chest => '胸部',
  MuscleGroup.back => '背部',
  MuscleGroup.shoulders => '肩部',
  MuscleGroup.arms => '手臂',
  MuscleGroup.legs => '腿部',
  MuscleGroup.glutes => '臀部',
  MuscleGroup.core => '核心',
};

String muscleRegionLabel(MuscleRegion region) => switch (region) {
  MuscleRegion.upperChest => '上胸',
  MuscleRegion.midChest => '中胸',
  MuscleRegion.lowerChest => '下胸',
  MuscleRegion.lats => '背阔肌',
  MuscleRegion.upperBack => '上背',
  MuscleRegion.midBack => '中背',
  MuscleRegion.lowerBack => '下背',
  MuscleRegion.frontDelts => '肩前束',
  MuscleRegion.sideDelts => '肩中束',
  MuscleRegion.rearDelts => '肩后束',
  MuscleRegion.biceps => '肱二头肌',
  MuscleRegion.triceps => '肱三头肌',
  MuscleRegion.forearms => '前臂',
  MuscleRegion.quads => '股四头肌',
  MuscleRegion.hamstrings => '腘绳肌',
  MuscleRegion.calves => '小腿',
  MuscleRegion.adductors => '大腿内侧',
  MuscleRegion.glutes => '臀肌',
  MuscleRegion.abs => '腹肌',
  MuscleRegion.obliques => '腹斜肌',
  MuscleRegion.spinalErectors => '竖脊肌',
};

String movementPatternLabel(ExerciseMovementPattern pattern) =>
    switch (pattern) {
      ExerciseMovementPattern.horizontalPush => '水平推',
      ExerciseMovementPattern.verticalPush => '垂直推',
      ExerciseMovementPattern.horizontalPull => '水平拉',
      ExerciseMovementPattern.verticalPull => '垂直拉',
      ExerciseMovementPattern.squat => '深蹲',
      ExerciseMovementPattern.hinge => '髋铰链',
      ExerciseMovementPattern.lunge => '弓步',
      ExerciseMovementPattern.elbowFlexion => '屈肘',
      ExerciseMovementPattern.elbowExtension => '伸肘',
      ExerciseMovementPattern.shoulderIsolation => '肩部孤立',
      ExerciseMovementPattern.hipAbduction => '髋外展',
      ExerciseMovementPattern.hipAdduction => '髋内收',
      ExerciseMovementPattern.calfRaise => '提踵',
      ExerciseMovementPattern.carry => '负重行走',
      ExerciseMovementPattern.conditioning => '体能复合',
      ExerciseMovementPattern.core => '核心稳定',
      ExerciseMovementPattern.other => '其他',
    };
