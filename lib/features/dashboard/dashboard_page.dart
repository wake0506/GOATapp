import 'package:flutter/material.dart';

import 'activity_summary_card.dart';
import 'ai_tip_card.dart';
import 'calorie_summary_card.dart';
import 'dashboard_data.dart';
import 'dashboard_header.dart';
import 'dashboard_quick_actions.dart';
import 'hydration_weight_card.dart';
import 'macro_progress_section.dart';
import 'meal_summary_section.dart';

class DashboardPage extends StatelessWidget {
  final DashboardData data;
  final VoidCallback onOpenAssistant;
  final VoidCallback onOpenSettings;
  final VoidCallback onRecordDiet;
  final VoidCallback onRecordWater;
  final VoidCallback onRecordExercise;
  final VoidCallback onRecordWeight;
  final ValueChanged<String> onOpenMeal;
  final ValueChanged<String> onAddMeal;
  final VoidCallback onOpenTraining;
  final VoidCallback onRefreshAi;

  const DashboardPage({
    super.key,
    required this.data,
    required this.onOpenAssistant,
    required this.onOpenSettings,
    required this.onRecordDiet,
    required this.onRecordWater,
    required this.onRecordExercise,
    required this.onRecordWeight,
    required this.onOpenMeal,
    required this.onAddMeal,
    required this.onOpenTraining,
    required this.onRefreshAi,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF4F5F7),
      appBar: DashboardHeader(
        businessDate: data.businessDate,
        isToday: data.isToday,
        onOpenAssistant: onOpenAssistant,
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 4, 20, 36),
        children: [
          CalorieSummaryCard(
            caloriesIn: data.caloriesIn,
            caloriesBurn: data.caloriesBurn,
            netCalories: data.netCalories,
            targetCalories: data.caloriesTarget,
            onOpenSettings: onOpenSettings,
          ),
          const SizedBox(height: 12),
          MacroProgressSection(macros: data.macros),
          const SizedBox(height: 18),
          DashboardQuickActions(
            onDiet: onRecordDiet,
            onWater: onRecordWater,
            onExercise: onRecordExercise,
            onWeight: onRecordWeight,
          ),
          const SizedBox(height: 20),
          MealSummarySection(
            meals: data.meals,
            onOpenMeal: onOpenMeal,
            onAddMeal: onAddMeal,
          ),
          const SizedBox(height: 8),
          ActivitySummaryCard(
            activity: data.activity,
            onOpenTraining: onOpenTraining,
            onAddExercise: onRecordExercise,
          ),
          const SizedBox(height: 10),
          HydrationWeightCard(
            waterMl: data.waterMl,
            waterGoalMl: data.waterGoalMl,
            weightKg: data.weightKg,
            onOpenWater: onRecordWater,
            onOpenWeight: onRecordWeight,
          ),
          if (data.showAiTip) ...[
            const SizedBox(height: 10),
            AiTipCard(
              text: data.aiTip,
              isLoading: data.isAiTipLoading,
              onRefresh: onRefreshAi,
            ),
          ],
        ],
      ),
    );
  }
}
