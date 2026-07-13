import '../../models/consumed_record.dart';
import '../../models/exercise_record.dart';
import '../../models/training.dart';

class DashboardMacro {
  final String label;
  final double current;
  final double target;

  const DashboardMacro({
    required this.label,
    required this.current,
    required this.target,
  });
}

class DashboardMealSummary {
  final String mealType;
  final String title;
  final double calories;
  final List<String> foodNames;
  final int moreCount;
  final bool isEmpty;

  const DashboardMealSummary({
    required this.mealType,
    required this.title,
    required this.calories,
    required this.foodNames,
    required this.moreCount,
    required this.isEmpty,
  });
}

class DashboardActivitySummary {
  final double exerciseCalories;
  final int exerciseCount;
  final List<String> exerciseNames;
  final int trainingSessionCount;
  final int trainingExerciseCount;
  final List<String> trainingNames;

  const DashboardActivitySummary({
    required this.exerciseCalories,
    required this.exerciseCount,
    required this.exerciseNames,
    required this.trainingSessionCount,
    required this.trainingExerciseCount,
    required this.trainingNames,
  });
}

class DashboardData {
  final String businessDate;
  final bool isToday;
  final double caloriesIn;
  final double caloriesBurn;
  final double caloriesTarget;
  final List<DashboardMacro> macros;
  final List<DashboardMealSummary> meals;
  final DashboardActivitySummary activity;
  final int waterMl;
  final int waterGoalMl;
  final double weightKg;
  final bool showAiTip;
  final bool isAiTipLoading;
  final String aiTip;

  const DashboardData({
    required this.businessDate,
    required this.isToday,
    required this.caloriesIn,
    required this.caloriesBurn,
    required this.caloriesTarget,
    required this.macros,
    required this.meals,
    required this.activity,
    required this.waterMl,
    required this.waterGoalMl,
    required this.weightKg,
    required this.showAiTip,
    required this.isAiTipLoading,
    required this.aiTip,
  });

  double get netCalories => caloriesIn - caloriesBurn;

  factory DashboardData.fromState({
    required String date,
    required bool isToday,
    required Iterable<ConsumedRecord> consumedRecords,
    required Iterable<ExerciseRecord> exerciseRecords,
    required Iterable<TrainingSession> trainingSessions,
    required double calorieTarget,
    required double proteinTarget,
    required double carbsTarget,
    required double fatTarget,
    required int waterMl,
    required int waterGoalMl,
    required double weightKg,
    required bool showAiTip,
    required bool isAiTipLoading,
    required String aiTip,
  }) {
    final consumed = consumedRecords.where((record) => record.date == date);
    final exercises = exerciseRecords.where((record) => record.date == date);
    final sessions = trainingSessions.where((session) => session.date == date);
    final consumedList = consumed.toList(growable: false);
    final exerciseList = exercises.toList(growable: false);
    final sessionList = sessions.toList(growable: false);
    final meals = ['早餐', '午餐', '晚餐', '加餐']
        .map((mealType) {
          final records = consumedList
              .where((record) {
                if (mealType == '加餐') {
                  return record.mealType != '早餐' &&
                      record.mealType != '午餐' &&
                      record.mealType != '晚餐';
                }
                return record.mealType == mealType;
              })
              .toList(growable: false);
          return DashboardMealSummary(
            mealType: mealType,
            title: mealType,
            calories: records.fold(0, (sum, record) => sum + record.kcal),
            foodNames: records.take(3).map((record) => record.name).toList(),
            moreCount: records.length > 3 ? records.length - 3 : 0,
            isEmpty: records.isEmpty,
          );
        })
        .toList(growable: false);
    final activity = DashboardActivitySummary(
      exerciseCalories: exerciseList.fold(
        0,
        (sum, record) => sum + record.kcal,
      ),
      exerciseCount: exerciseList.length,
      exerciseNames: exerciseList.take(2).map((record) => record.type).toList(),
      trainingSessionCount: sessionList.length,
      trainingExerciseCount: sessionList.fold(
        0,
        (sum, session) => sum + session.exercises.length,
      ),
      trainingNames: sessionList
          .take(2)
          .map((session) => session.name)
          .toList(),
    );
    return DashboardData(
      businessDate: date,
      isToday: isToday,
      caloriesIn: consumedList.fold(0, (sum, record) => sum + record.kcal),
      caloriesBurn: activity.exerciseCalories,
      caloriesTarget: calorieTarget,
      macros: [
        DashboardMacro(
          label: 'PRO',
          current: consumedList.fold(0, (sum, record) => sum + record.p),
          target: proteinTarget,
        ),
        DashboardMacro(
          label: 'CHO',
          current: consumedList.fold(0, (sum, record) => sum + record.c),
          target: carbsTarget,
        ),
        DashboardMacro(
          label: 'FAT',
          current: consumedList.fold(0, (sum, record) => sum + record.f),
          target: fatTarget,
        ),
      ],
      meals: meals,
      activity: activity,
      waterMl: waterMl,
      waterGoalMl: waterGoalMl,
      weightKg: weightKg,
      showAiTip: showAiTip,
      isAiTipLoading: isAiTipLoading,
      aiTip: aiTip,
    );
  }

  static String defaultMealTypeForHour(int hour) {
    if (hour < 10) return '早餐';
    if (hour < 15) return '午餐';
    if (hour < 19) return '晚餐';
    return '加餐';
  }
}
