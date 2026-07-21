import 'package:flutter/material.dart';

import '../../models/daily_macro_stats.dart';
import '../../models/consumed_record.dart';
import '../../widgets/goat_page_header.dart';
import 'models/home_dashboard_view_model.dart';
import 'widgets/home_ai_card.dart';
import 'widgets/home_exercise_card.dart';
import 'widgets/home_hero_card.dart';
import 'widgets/home_meals_grid.dart';
import 'widgets/home_metrics_row.dart';

class HomePage extends StatelessWidget {
  const HomePage({
    super.key,
    required this.businessDate,
    required this.isToday,
    required this.stats,
    required this.targetKcal,
    required this.targetProtein,
    required this.targetCarbs,
    required this.targetFat,
    required this.waterMl,
    required this.weight,
    required this.previousWeight,
    required this.consumed,
    required this.aiContent,
    required this.isAiLoading,
    required this.showAiCard,
    required this.onEditTarget,
    required this.onRequestAiAdvice,
    required this.onDismissAi,
    required this.onQuickAddWater,
    required this.onOpenWater,
    required this.onOpenWeight,
    required this.onOpenMeal,
    required this.onAddMeal,
    required this.onVoiceMeal,
    required this.onOpenTraining,
    required this.onAddExercise,
  });

  final String businessDate;
  final bool isToday;
  final DailyMacroStats stats;
  final double targetKcal;
  final double targetProtein;
  final double targetCarbs;
  final double targetFat;
  final int waterMl;
  final double weight;
  final double? previousWeight;
  final List<ConsumedRecord> consumed;
  final String aiContent;
  final bool isAiLoading;
  final bool showAiCard;
  final VoidCallback onEditTarget;
  final VoidCallback onRequestAiAdvice;
  final VoidCallback onDismissAi;
  final VoidCallback onQuickAddWater;
  final VoidCallback onOpenWater;
  final VoidCallback onOpenWeight;
  final ValueChanged<String> onOpenMeal;
  final ValueChanged<String> onAddMeal;
  final ValueChanged<String> onVoiceMeal;
  final VoidCallback onOpenTraining;
  final VoidCallback onAddExercise;

  @override
  Widget build(BuildContext context) {
    final viewModel = HomeDashboardViewModel.fromData(
      stats: stats,
      targetKcal: targetKcal,
      targetProtein: targetProtein,
      targetCarbs: targetCarbs,
      targetFat: targetFat,
      waterMl: waterMl,
      waterGoalMl: 2000,
      weight: weight,
      previousWeight: previousWeight,
      consumed: consumed,
    );
    return Scaffold(
      backgroundColor: const Color(0xFFF4F5F7),
      appBar: AppBar(
        backgroundColor: const Color(0xFFF4F5F7),
        elevation: 0,
        title: GoatPageHeader(title: isToday ? 'G O A T' : 'HISTORY'),
        actions: [
          IconButton(
            tooltip: '编辑今日目标',
            onPressed: onEditTarget,
            icon: const Icon(Icons.tune_rounded, color: Color(0xFF008C8C)),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: CustomScrollView(
        slivers: [
          SliverToBoxAdapter(
            child: KeyedSubtree(
              key: const Key('home-first-viewport-section'),
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 4, 16, 0),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    HomeHeroCard(viewModel: viewModel),
                    const SizedBox(height: 12),
                    if (showAiCard) ...[
                      HomeAiCard(
                        content: aiContent,
                        isLoading: isAiLoading,
                        onRefresh: onRequestAiAdvice,
                        onClose: onDismissAi,
                      ),
                      const SizedBox(height: 12),
                    ],
                    HomeMetricsRow(
                      viewModel: viewModel,
                      onOpenWater: onOpenWater,
                      onQuickAddWater: onQuickAddWater,
                      onOpenWeight: onOpenWeight,
                    ),
                    const SizedBox(height: 12),
                    HomeMealsGrid(
                      key: const Key('home-meals-first-row'),
                      meals: viewModel.meals.take(2).toList(growable: false),
                      onOpenMeal: onOpenMeal,
                      onAddMeal: onAddMeal,
                      onVoiceMeal: onVoiceMeal,
                    ),
                  ],
                ),
              ),
            ),
          ),
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
            sliver: SliverToBoxAdapter(
              child: HomeMealsGrid(
                key: const Key('home-meals-second-row'),
                meals: viewModel.meals.skip(2).toList(growable: false),
                onOpenMeal: onOpenMeal,
                onAddMeal: onAddMeal,
                onVoiceMeal: onVoiceMeal,
              ),
            ),
          ),
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
            sliver: SliverToBoxAdapter(
              child: HomeExerciseCard(
                totalBurn: stats.burn,
                hasExercise: stats.burn > 0,
                onOpenTraining: onOpenTraining,
                onAddExercise: onAddExercise,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
