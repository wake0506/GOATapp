class ProfileIdentity {
  const ProfileIdentity({
    required this.isLoggedIn,
    required this.displayName,
    required this.email,
  });

  final bool isLoggedIn;
  final String displayName;
  final String email;

  String get resolvedName {
    final name = displayName.trim();
    if (name.isNotEmpty) return name;
    return isLoggedIn ? '未设置显示名称' : '本地使用';
  }

  String get avatarLetter {
    final name = displayName.trim();
    if (name.isNotEmpty) return name.substring(0, 1).toUpperCase();
    final address = email.trim();
    if (address.isNotEmpty) return address.substring(0, 1).toUpperCase();
    return 'G';
  }
}

class ProfileBasicData {
  const ProfileBasicData({
    required this.gender,
    required this.birthYear,
    required this.birthMonth,
    required this.birthDay,
    required this.heightCm,
    required this.currentWeightKg,
  });

  final String gender;
  final int birthYear;
  final int birthMonth;
  final int birthDay;
  final double heightCm;
  final double currentWeightKg;
}

class ProfileBasicUpdate {
  const ProfileBasicUpdate({
    required this.displayName,
    required this.gender,
    required this.birthYear,
    required this.heightCm,
  });

  final String displayName;
  final String gender;
  final int birthYear;
  final double heightCm;
}

class ProfileSummary {
  const ProfileSummary({
    required this.identity,
    required this.totalTrainingSessions,
    required this.weeklyTrainingDays,
    required this.weeklyEffectiveSets,
    required this.trendWeightKg,
    required this.latestWeightKg,
    required this.templateCount,
    required this.activeMemoryCount,
    required this.pendingMemoryCount,
    this.trainingGoal,
    this.trainingExperience,
    this.availableEquipment = const [],
    this.trainingPreference,
    this.coachingStyle,
  });

  final ProfileIdentity identity;
  final int totalTrainingSessions;
  final int weeklyTrainingDays;
  final int weeklyEffectiveSets;
  final double? trendWeightKg;
  final double? latestWeightKg;
  final int templateCount;
  final int activeMemoryCount;
  final int pendingMemoryCount;
  final String? trainingGoal;
  final String? trainingExperience;
  final List<String> availableEquipment;
  final String? trainingPreference;
  final String? coachingStyle;

  String get weightLabel {
    final value = trendWeightKg ?? latestWeightKg;
    return value == null ? '--' : '${value.toStringAsFixed(1)} kg';
  }
}
