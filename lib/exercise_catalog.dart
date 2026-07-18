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
  core,
  other,
}

class ExerciseDefinition {
  final String? _configuredId;
  final String name;
  final String bodyPart;
  final String equipment;
  final List<String> _configuredPrimaryMuscles;
  final List<String> _configuredSecondaryMuscles;
  final ExerciseMovementPattern? _configuredMovementPattern;
  final List<String> muscleRegions;

  const ExerciseDefinition({
    String? id,
    required this.name,
    required this.bodyPart,
    required this.equipment,
    List<String> primaryMuscles = const [],
    List<String> secondaryMuscles = const [],
    ExerciseMovementPattern? movementPattern,
    this.muscleRegions = const [],
  }) : _configuredId = id,
       _configuredPrimaryMuscles = primaryMuscles,
       _configuredSecondaryMuscles = secondaryMuscles,
       _configuredMovementPattern = movementPattern;

  String get id => _configuredId?.trim().isNotEmpty == true
      ? _configuredId!
      : _legacyCatalogId(name);

  bool get hasStableId => id.isNotEmpty;

  List<String> get primaryMuscles => _configuredPrimaryMuscles.isNotEmpty
      ? _configuredPrimaryMuscles
      : _primaryMusclesFor(bodyPart);

  List<String> get secondaryMuscles => _configuredSecondaryMuscles;

  ExerciseMovementPattern get movementPattern =>
      _configuredMovementPattern ?? _movementPatternFor(id);
}

const List<String> exerciseBodyParts = [
  '胸部',
  '背部',
  '腿部',
  '肩部',
  '手臂',
  '核心',
  '臀部',
  '全身/体能',
];

const List<ExerciseDefinition> exerciseCatalog = [
  // Chest
  ExerciseDefinition(name: '杠铃平板卧推', bodyPart: '胸部', equipment: '自由重量'),
  ExerciseDefinition(name: '杠铃上斜卧推', bodyPart: '胸部', equipment: '自由重量'),
  ExerciseDefinition(name: '杠铃下斜卧推', bodyPart: '胸部', equipment: '自由重量'),
  ExerciseDefinition(name: '哑铃平板卧推', bodyPart: '胸部', equipment: '自由重量'),
  ExerciseDefinition(name: '哑铃上斜卧推', bodyPart: '胸部', equipment: '自由重量'),
  ExerciseDefinition(name: '哑铃下斜卧推', bodyPart: '胸部', equipment: '自由重量'),
  ExerciseDefinition(name: '哑铃飞鸟', bodyPart: '胸部', equipment: '自由重量'),
  ExerciseDefinition(name: '上斜哑铃飞鸟', bodyPart: '胸部', equipment: '自由重量'),
  ExerciseDefinition(name: '史密斯平板卧推', bodyPart: '胸部', equipment: '器械'),
  ExerciseDefinition(name: '史密斯上斜卧推', bodyPart: '胸部', equipment: '器械'),
  ExerciseDefinition(name: '器械推胸', bodyPart: '胸部', equipment: '器械'),
  ExerciseDefinition(name: '蝴蝶机夹胸', bodyPart: '胸部', equipment: '器械'),
  ExerciseDefinition(name: '双杠臂屈伸', bodyPart: '胸部', equipment: '徒手'),
  ExerciseDefinition(name: '标准俯卧撑', bodyPart: '胸部', equipment: '徒手'),
  ExerciseDefinition(name: '宽距俯卧撑', bodyPart: '胸部', equipment: '徒手'),
  ExerciseDefinition(name: '上斜俯卧撑', bodyPart: '胸部', equipment: '徒手'),
  ExerciseDefinition(name: '下斜俯卧撑', bodyPart: '胸部', equipment: '徒手'),
  ExerciseDefinition(name: '绳索夹胸', bodyPart: '胸部', equipment: '绳索'),
  ExerciseDefinition(name: '低位绳索夹胸', bodyPart: '胸部', equipment: '绳索'),
  ExerciseDefinition(name: '绳索推胸', bodyPart: '胸部', equipment: '绳索'),

  // Back
  ExerciseDefinition(name: '传统硬拉', bodyPart: '背部', equipment: '自由重量'),
  ExerciseDefinition(name: '相扑硬拉', bodyPart: '背部', equipment: '自由重量'),
  ExerciseDefinition(name: '杠铃俯身划船', bodyPart: '背部', equipment: '自由重量'),
  ExerciseDefinition(name: '潘德雷划船', bodyPart: '背部', equipment: '自由重量'),
  ExerciseDefinition(name: '哑铃单臂划船', bodyPart: '背部', equipment: '自由重量'),
  ExerciseDefinition(name: '哑铃胸托划船', bodyPart: '背部', equipment: '自由重量'),
  ExerciseDefinition(name: 'T 杆划船', bodyPart: '背部', equipment: '器械'),
  ExerciseDefinition(name: '高位下拉', bodyPart: '背部', equipment: '器械'),
  ExerciseDefinition(name: '宽握高位下拉', bodyPart: '背部', equipment: '器械'),
  ExerciseDefinition(name: '反握高位下拉', bodyPart: '背部', equipment: '器械'),
  ExerciseDefinition(name: '坐姿划船', bodyPart: '背部', equipment: '器械'),
  ExerciseDefinition(name: '单臂器械划船', bodyPart: '背部', equipment: '器械'),
  ExerciseDefinition(name: '胸托划船机', bodyPart: '背部', equipment: '器械'),
  ExerciseDefinition(name: '引体向上', bodyPart: '背部', equipment: '徒手'),
  ExerciseDefinition(name: '反手引体向上', bodyPart: '背部', equipment: '徒手'),
  ExerciseDefinition(name: '辅助引体向上', bodyPart: '背部', equipment: '器械'),
  ExerciseDefinition(name: '悬垂肩胛上拉', bodyPart: '背部', equipment: '徒手'),
  ExerciseDefinition(name: '直臂下拉', bodyPart: '背部', equipment: '绳索'),
  ExerciseDefinition(name: '面拉', bodyPart: '背部', equipment: '绳索'),
  ExerciseDefinition(name: '绳索单臂划船', bodyPart: '背部', equipment: '绳索'),
  ExerciseDefinition(name: '山羊挺身', bodyPart: '背部', equipment: '徒手'),

  // Legs
  ExerciseDefinition(name: '杠铃深蹲', bodyPart: '腿部', equipment: '自由重量'),
  ExerciseDefinition(name: '高杠深蹲', bodyPart: '腿部', equipment: '自由重量'),
  ExerciseDefinition(name: '前蹲', bodyPart: '腿部', equipment: '自由重量'),
  ExerciseDefinition(name: '暂停深蹲', bodyPart: '腿部', equipment: '自由重量'),
  ExerciseDefinition(name: '罗马尼亚硬拉', bodyPart: '腿部', equipment: '自由重量'),
  ExerciseDefinition(name: '直腿硬拉', bodyPart: '腿部', equipment: '自由重量'),
  ExerciseDefinition(name: '早安式', bodyPart: '腿部', equipment: '自由重量'),
  ExerciseDefinition(name: '保加利亚分腿蹲', bodyPart: '腿部', equipment: '自由重量'),
  ExerciseDefinition(name: '哑铃箭步蹲', bodyPart: '腿部', equipment: '自由重量'),
  ExerciseDefinition(name: '行走箭步蹲', bodyPart: '腿部', equipment: '自由重量'),
  ExerciseDefinition(name: '高脚杯深蹲', bodyPart: '腿部', equipment: '自由重量'),
  ExerciseDefinition(name: '单腿罗马尼亚硬拉', bodyPart: '腿部', equipment: '自由重量'),
  ExerciseDefinition(name: '腿举机', bodyPart: '腿部', equipment: '器械'),
  ExerciseDefinition(name: '哈克深蹲', bodyPart: '腿部', equipment: '器械'),
  ExerciseDefinition(name: '史密斯深蹲', bodyPart: '腿部', equipment: '器械'),
  ExerciseDefinition(name: '史密斯箭步蹲', bodyPart: '腿部', equipment: '器械'),
  ExerciseDefinition(name: '坐姿腿屈伸', bodyPart: '腿部', equipment: '器械'),
  ExerciseDefinition(name: '俯卧腿弯举', bodyPart: '腿部', equipment: '器械'),
  ExerciseDefinition(name: '坐姿腿弯举', bodyPart: '腿部', equipment: '器械'),
  ExerciseDefinition(name: '站姿腿弯举', bodyPart: '腿部', equipment: '器械'),
  ExerciseDefinition(name: '内收肌训练机', bodyPart: '腿部', equipment: '器械'),
  ExerciseDefinition(name: '外展肌训练机', bodyPart: '腿部', equipment: '器械'),
  ExerciseDefinition(name: '站姿提踵', bodyPart: '腿部', equipment: '器械'),
  ExerciseDefinition(name: '坐姿提踵', bodyPart: '腿部', equipment: '器械'),
  ExerciseDefinition(name: '自重深蹲', bodyPart: '腿部', equipment: '徒手'),
  ExerciseDefinition(name: '跳深蹲', bodyPart: '腿部', equipment: '徒手'),
  ExerciseDefinition(name: '反向箭步蹲', bodyPart: '腿部', equipment: '徒手'),
  ExerciseDefinition(name: '单腿箱式深蹲', bodyPart: '腿部', equipment: '徒手'),
  ExerciseDefinition(name: '单腿提踵', bodyPart: '腿部', equipment: '徒手'),

  // Shoulders
  ExerciseDefinition(name: '杠铃站姿推举', bodyPart: '肩部', equipment: '自由重量'),
  ExerciseDefinition(name: '杠铃坐姿推举', bodyPart: '肩部', equipment: '自由重量'),
  ExerciseDefinition(name: '哑铃坐姿推举', bodyPart: '肩部', equipment: '自由重量'),
  ExerciseDefinition(name: '阿诺德推举', bodyPart: '肩部', equipment: '自由重量'),
  ExerciseDefinition(name: '哑铃侧平举', bodyPart: '肩部', equipment: '自由重量'),
  ExerciseDefinition(name: '哑铃前平举', bodyPart: '肩部', equipment: '自由重量'),
  ExerciseDefinition(name: '哑铃俯身飞鸟', bodyPart: '肩部', equipment: '自由重量'),
  ExerciseDefinition(name: '史密斯推举', bodyPart: '肩部', equipment: '器械'),
  ExerciseDefinition(name: '器械肩推', bodyPart: '肩部', equipment: '器械'),
  ExerciseDefinition(name: '反向蝴蝶机', bodyPart: '肩部', equipment: '器械'),
  ExerciseDefinition(name: '绳索侧平举', bodyPart: '肩部', equipment: '绳索'),
  ExerciseDefinition(name: '绳索前平举', bodyPart: '肩部', equipment: '绳索'),
  ExerciseDefinition(name: '绳索反向飞鸟', bodyPart: '肩部', equipment: '绳索'),
  ExerciseDefinition(name: '倒立撑', bodyPart: '肩部', equipment: '徒手'),
  ExerciseDefinition(name: '派克俯卧撑', bodyPart: '肩部', equipment: '徒手'),

  // Arms
  ExerciseDefinition(name: '杠铃弯举', bodyPart: '手臂', equipment: '自由重量'),
  ExerciseDefinition(name: 'EZ 杠弯举', bodyPart: '手臂', equipment: '自由重量'),
  ExerciseDefinition(name: '哑铃交替弯举', bodyPart: '手臂', equipment: '自由重量'),
  ExerciseDefinition(name: '锤式弯举', bodyPart: '手臂', equipment: '自由重量'),
  ExerciseDefinition(name: '上斜哑铃弯举', bodyPart: '手臂', equipment: '自由重量'),
  ExerciseDefinition(name: '集中弯举', bodyPart: '手臂', equipment: '自由重量'),
  ExerciseDefinition(name: '牧师凳弯举', bodyPart: '手臂', equipment: '器械'),
  ExerciseDefinition(name: '绳索弯举', bodyPart: '手臂', equipment: '绳索'),
  ExerciseDefinition(name: '绳索锤式弯举', bodyPart: '手臂', equipment: '绳索'),
  ExerciseDefinition(name: '窄距卧推', bodyPart: '手臂', equipment: '自由重量'),
  ExerciseDefinition(name: '杠铃颈前臂屈伸', bodyPart: '手臂', equipment: '自由重量'),
  ExerciseDefinition(name: '哑铃颈后臂屈伸', bodyPart: '手臂', equipment: '自由重量'),
  ExerciseDefinition(name: '仰卧臂屈伸', bodyPart: '手臂', equipment: '自由重量'),
  ExerciseDefinition(name: '绳索下压', bodyPart: '手臂', equipment: '绳索'),
  ExerciseDefinition(name: '反握绳索下压', bodyPart: '手臂', equipment: '绳索'),
  ExerciseDefinition(name: '绳索过顶臂屈伸', bodyPart: '手臂', equipment: '绳索'),
  ExerciseDefinition(name: '双杠臂屈伸', bodyPart: '手臂', equipment: '徒手'),
  ExerciseDefinition(name: '钻石俯卧撑', bodyPart: '手臂', equipment: '徒手'),

  // Core
  ExerciseDefinition(name: '平板支撑', bodyPart: '核心', equipment: '徒手'),
  ExerciseDefinition(name: '侧平板支撑', bodyPart: '核心', equipment: '徒手'),
  ExerciseDefinition(name: '卷腹', bodyPart: '核心', equipment: '徒手'),
  ExerciseDefinition(name: '反向卷腹', bodyPart: '核心', equipment: '徒手'),
  ExerciseDefinition(name: '仰卧单车', bodyPart: '核心', equipment: '徒手'),
  ExerciseDefinition(name: '死虫式', bodyPart: '核心', equipment: '徒手'),
  ExerciseDefinition(name: '鸟狗式', bodyPart: '核心', equipment: '徒手'),
  ExerciseDefinition(name: '悬垂举腿', bodyPart: '核心', equipment: '徒手'),
  ExerciseDefinition(name: '悬垂屈膝举腿', bodyPart: '核心', equipment: '徒手'),
  ExerciseDefinition(name: '健腹轮', bodyPart: '核心', equipment: '自由重量'),
  ExerciseDefinition(name: '俄罗斯转体', bodyPart: '核心', equipment: '自由重量'),
  ExerciseDefinition(name: '绳索卷腹', bodyPart: '核心', equipment: '绳索'),
  ExerciseDefinition(name: 'Pallof 抗旋转', bodyPart: '核心', equipment: '绳索'),
  ExerciseDefinition(name: '仰卧举腿', bodyPart: '核心', equipment: '徒手'),

  // Glutes
  ExerciseDefinition(name: '杠铃臀推', bodyPart: '臀部', equipment: '自由重量'),
  ExerciseDefinition(name: '单腿臀推', bodyPart: '臀部', equipment: '自由重量'),
  ExerciseDefinition(name: '哑铃臀推', bodyPart: '臀部', equipment: '自由重量'),
  ExerciseDefinition(name: '臀桥', bodyPart: '臀部', equipment: '徒手'),
  ExerciseDefinition(name: '单腿臀桥', bodyPart: '臀部', equipment: '徒手'),
  ExerciseDefinition(name: '绳索后踢腿', bodyPart: '臀部', equipment: '绳索'),
  ExerciseDefinition(name: '髋外展机', bodyPart: '臀部', equipment: '器械'),
  ExerciseDefinition(name: '45 度臀背挺身', bodyPart: '臀部', equipment: '器械'),
  ExerciseDefinition(name: '台阶上步', bodyPart: '臀部', equipment: '徒手'),
  ExerciseDefinition(name: '蚌式开合', bodyPart: '臀部', equipment: '徒手'),

  // Full body and conditioning
  ExerciseDefinition(name: '高翻', bodyPart: '全身/体能', equipment: '自由重量'),
  ExerciseDefinition(name: '抓举', bodyPart: '全身/体能', equipment: '自由重量'),
  ExerciseDefinition(name: '挺举', bodyPart: '全身/体能', equipment: '自由重量'),
  ExerciseDefinition(name: '推举借力', bodyPart: '全身/体能', equipment: '自由重量'),
  ExerciseDefinition(name: '壶铃摇摆', bodyPart: '全身/体能', equipment: '壶铃'),
  ExerciseDefinition(name: '壶铃高脚杯深蹲', bodyPart: '全身/体能', equipment: '壶铃'),
  ExerciseDefinition(name: '壶铃土耳其起身', bodyPart: '全身/体能', equipment: '壶铃'),
  ExerciseDefinition(name: '农夫行走', bodyPart: '全身/体能', equipment: '自由重量'),
  ExerciseDefinition(name: '雪橇推', bodyPart: '全身/体能', equipment: '器械'),
  ExerciseDefinition(name: '战绳', bodyPart: '全身/体能', equipment: '器械'),
  ExerciseDefinition(name: '划船机', bodyPart: '全身/体能', equipment: '器械'),
  ExerciseDefinition(name: '空中自行车', bodyPart: '全身/体能', equipment: '器械'),
  ExerciseDefinition(name: '波比跳', bodyPart: '全身/体能', equipment: '徒手'),
  ExerciseDefinition(name: '登山跑', bodyPart: '全身/体能', equipment: '徒手'),
  ExerciseDefinition(name: '开合跳', bodyPart: '全身/体能', equipment: '徒手'),
  ExerciseDefinition(name: '熊爬', bodyPart: '全身/体能', equipment: '徒手'),
];

String _legacyCatalogId(String name) => switch (name) {
  '杠铃平板卧推' => 'barbell_flat_bench_press',
  '杠铃上斜卧推' => 'barbell_incline_bench_press',
  '杠铃下斜卧推' => 'barbell_decline_bench_press',
  '哑铃平板卧推' => 'dumbbell_flat_bench_press',
  '哑铃上斜卧推' => 'dumbbell_incline_bench_press',
  '哑铃下斜卧推' => 'dumbbell_decline_bench_press',
  '哑铃飞鸟' => 'dumbbell_fly',
  '上斜哑铃飞鸟' => 'incline_dumbbell_fly',
  '史密斯平板卧推' => 'smith_flat_bench_press',
  '史密斯上斜卧推' => 'smith_incline_bench_press',
  '器械推胸' => 'machine_chest_press',
  '蝴蝶机夹胸' => 'pec_deck_fly',
  '双杠臂屈伸' => 'parallel_bar_dip',
  '标准俯卧撑' => 'standard_push_up',
  '宽距俯卧撑' => 'wide_push_up',
  '上斜俯卧撑' => 'incline_push_up',
  '下斜俯卧撑' => 'decline_push_up',
  '绳索夹胸' => 'cable_fly',
  '低位绳索夹胸' => 'low_cable_fly',
  '绳索推胸' => 'cable_chest_press',
  '传统硬拉' => 'conventional_deadlift',
  '相扑硬拉' => 'sumo_deadlift',
  '杠铃俯身划船' => 'barbell_bent_over_row',
  '潘德雷划船' => 'pendlay_row',
  '哑铃单臂划船' => 'dumbbell_one_arm_row',
  '哑铃胸托划船' => 'dumbbell_chest_supported_row',
  'T 杆划船' => 't_bar_row',
  '高位下拉' => 'lat_pulldown',
  '宽握高位下拉' => 'wide_grip_lat_pulldown',
  '反握高位下拉' => 'reverse_grip_lat_pulldown',
  '坐姿划船' => 'seated_cable_row',
  '单臂器械划船' => 'single_arm_machine_row',
  '胸托划船机' => 'machine_chest_supported_row',
  '引体向上' => 'pull_up',
  '反手引体向上' => 'chin_up',
  '辅助引体向上' => 'assisted_pull_up',
  '悬垂肩胛上拉' => 'scapular_pull_up',
  '直臂下拉' => 'straight_arm_pulldown',
  '面拉' => 'face_pull',
  '绳索单臂划船' => 'cable_one_arm_row',
  '山羊挺身' => 'back_extension',
  '杠铃深蹲' => 'barbell_back_squat',
  '高杠深蹲' => 'high_bar_squat',
  '前蹲' => 'front_squat',
  '暂停深蹲' => 'pause_squat',
  '罗马尼亚硬拉' => 'romanian_deadlift',
  '直腿硬拉' => 'stiff_leg_deadlift',
  '早安式' => 'good_morning',
  '保加利亚分腿蹲' => 'bulgarian_split_squat',
  '哑铃箭步蹲' => 'dumbbell_lunge',
  '行走箭步蹲' => 'walking_lunge',
  '高脚杯深蹲' => 'goblet_squat',
  '单腿罗马尼亚硬拉' => 'single_leg_romanian_deadlift',
  '腿举机' => 'leg_press',
  '哈克深蹲' => 'hack_squat',
  '史密斯深蹲' => 'smith_squat',
  '史密斯箭步蹲' => 'smith_lunge',
  '坐姿腿屈伸' => 'seated_leg_extension',
  '俯卧腿弯举' => 'lying_leg_curl',
  '坐姿腿弯举' => 'seated_leg_curl',
  '站姿腿弯举' => 'standing_leg_curl',
  '内收肌训练机' => 'hip_adduction_machine',
  '外展肌训练机' => 'hip_abduction_machine',
  '站姿提踵' => 'standing_calf_raise',
  '坐姿提踵' => 'seated_calf_raise',
  '自重深蹲' => 'bodyweight_squat',
  '跳深蹲' => 'jump_squat',
  '反向箭步蹲' => 'reverse_lunge',
  '单腿箱式深蹲' => 'single_leg_box_squat',
  '单腿提踵' => 'single_leg_calf_raise',
  '杠铃站姿推举' => 'barbell_standing_press',
  '杠铃坐姿推举' => 'barbell_seated_press',
  '哑铃坐姿推举' => 'dumbbell_seated_press',
  '阿诺德推举' => 'arnold_press',
  '哑铃侧平举' => 'dumbbell_lateral_raise',
  '哑铃前平举' => 'dumbbell_front_raise',
  '哑铃俯身飞鸟' => 'dumbbell_rear_delt_fly',
  '史密斯推举' => 'smith_shoulder_press',
  '器械肩推' => 'machine_shoulder_press',
  '反向蝴蝶机' => 'reverse_pec_deck',
  '绳索侧平举' => 'cable_lateral_raise',
  '绳索前平举' => 'cable_front_raise',
  '绳索反向飞鸟' => 'cable_rear_delt_fly',
  '倒立撑' => 'handstand_push_up',
  '派克俯卧撑' => 'pike_push_up',
  '杠铃弯举' => 'barbell_curl',
  'EZ 杠弯举' => 'ez_bar_curl',
  '哑铃交替弯举' => 'dumbbell_alternating_curl',
  '锤式弯举' => 'hammer_curl',
  '上斜哑铃弯举' => 'incline_dumbbell_curl',
  '集中弯举' => 'concentration_curl',
  '牧师凳弯举' => 'preacher_curl',
  '绳索弯举' => 'cable_curl',
  '绳索锤式弯举' => 'cable_hammer_curl',
  '窄距卧推' => 'close_grip_bench_press',
  '杠铃颈前臂屈伸' => 'barbell_skull_crusher',
  '哑铃颈后臂屈伸' => 'dumbbell_overhead_extension',
  '仰卧臂屈伸' => 'lying_triceps_extension',
  '绳索下压' => 'cable_triceps_pushdown',
  '反握绳索下压' => 'reverse_grip_pushdown',
  '绳索过顶臂屈伸' => 'cable_overhead_extension',
  '钻石俯卧撑' => 'diamond_push_up',
  '平板支撑' => 'plank',
  '侧平板支撑' => 'side_plank',
  '卷腹' => 'crunch',
  '反向卷腹' => 'reverse_crunch',
  '仰卧单车' => 'bicycle_crunch',
  '死虫式' => 'dead_bug',
  '鸟狗式' => 'bird_dog',
  '悬垂举腿' => 'hanging_leg_raise',
  '悬垂屈膝举腿' => 'hanging_knee_raise',
  '健腹轮' => 'ab_wheel_rollout',
  '俄罗斯转体' => 'russian_twist',
  '绳索卷腹' => 'cable_crunch',
  'Pallof 抗旋转' => 'pallof_press',
  '仰卧举腿' => 'lying_leg_raise',
  '杠铃臀推' => 'barbell_hip_thrust',
  '单腿臀推' => 'single_leg_hip_thrust',
  '哑铃臀推' => 'dumbbell_hip_thrust',
  '臀桥' => 'glute_bridge',
  '单腿臀桥' => 'single_leg_glute_bridge',
  '绳索后踢腿' => 'cable_kickback',
  '髋外展机' => 'hip_abduction_machine_glute',
  '45 度臀背挺身' => 'forty_five_degree_back_extension',
  '台阶上步' => 'step_up',
  '蚌式开合' => 'clamshell',
  '高翻' => 'clean',
  '抓举' => 'snatch',
  '挺举' => 'clean_and_jerk',
  '推举借力' => 'push_press',
  '壶铃摇摆' => 'kettlebell_swing',
  '壶铃高脚杯深蹲' => 'kettlebell_goblet_squat',
  '壶铃土耳其起身' => 'turkish_get_up',
  '农夫行走' => 'farmer_carry',
  '雪橇推' => 'sled_push',
  '战绳' => 'battle_rope',
  '划船机' => 'rowing_machine',
  '空中自行车' => 'air_bike',
  '波比跳' => 'burpee',
  '登山跑' => 'mountain_climber',
  '开合跳' => 'jumping_jack',
  '熊爬' => 'bear_crawl',
  _ => throw StateError('Missing stable exercise catalog ID for $name.'),
};

List<String> _primaryMusclesFor(String bodyPart) => switch (bodyPart) {
  '胸部' => const ['chest'],
  '背部' => const ['back'],
  '腿部' => const ['quads', 'hamstrings'],
  '肩部' => const ['frontDelts', 'sideDelts', 'rearDelts'],
  '手臂' => const ['biceps', 'triceps'],
  '核心' => const ['core'],
  '臀部' => const ['glutes'],
  _ => const [],
};

ExerciseMovementPattern _movementPatternFor(String id) {
  if (id.contains('bench_press') ||
      id.contains('push_up') ||
      id.contains('chest_press')) {
    return ExerciseMovementPattern.horizontalPush;
  }
  if (id.contains('shoulder_press') ||
      id.contains('standing_press') ||
      id.contains('seated_press') ||
      id == 'arnold_press') {
    return ExerciseMovementPattern.verticalPush;
  }
  if (id.contains('row')) {
    return ExerciseMovementPattern.horizontalPull;
  }
  if (id.contains('pull_up') || id.contains('pulldown')) {
    return ExerciseMovementPattern.verticalPull;
  }
  if (id.contains('squat') || id == 'leg_press' || id == 'hack_squat') {
    return ExerciseMovementPattern.squat;
  }
  if (id.contains('deadlift') ||
      id == 'good_morning' ||
      id == 'kettlebell_swing') {
    return ExerciseMovementPattern.hinge;
  }
  if (id.contains('lunge') || id == 'step_up') {
    return ExerciseMovementPattern.lunge;
  }
  if (id.contains('curl')) {
    return ExerciseMovementPattern.elbowFlexion;
  }
  if (id.contains('extension') ||
      id.contains('pushdown') ||
      id == 'parallel_bar_dip') {
    return ExerciseMovementPattern.elbowExtension;
  }
  if (id.contains('raise') ||
      id.contains('rear_delt') ||
      id == 'reverse_pec_deck') {
    return ExerciseMovementPattern.shoulderIsolation;
  }
  if (id.contains('plank') ||
      id.contains('crunch') ||
      id.contains('leg_raise') ||
      id == 'dead_bug' ||
      id == 'bird_dog' ||
      id == 'ab_wheel_rollout' ||
      id == 'russian_twist' ||
      id == 'pallof_press') {
    return ExerciseMovementPattern.core;
  }
  return ExerciseMovementPattern.other;
}
