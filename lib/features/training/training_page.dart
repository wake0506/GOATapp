import 'package:flutter/material.dart';

import '../../models/training.dart';
import 'domain/active_training_session.dart';
import 'models/training_page_view_model.dart';
import 'widgets/personal_best_card.dart';
import 'widgets/training_ai_insight_card.dart';
import 'widgets/training_coverage_entry.dart';
import 'widgets/active_training_session_card.dart';
import 'widgets/training_load_card.dart';
import 'widgets/training_page_header.dart';
import 'widgets/training_quick_start_card.dart';
import 'widgets/training_status_card.dart';
import 'widgets/weekly_review_entry.dart';

class TrainingPage extends StatelessWidget {
  const TrainingPage({
    super.key,
    required this.sessions,
    required this.businessDate,
    required this.onStartTraining,
    required this.onUsePplTemplate,
    required this.onUseFullBodyTemplate,
    required this.onViewHistory,
    required this.onManageTemplates,
    this.activeSession,
    this.onResumeTraining,
    this.onOpenWeeklyReview,
    this.onOpenCoverage,
  });

  final List<TrainingSession> sessions;
  final String businessDate;
  final VoidCallback onStartTraining;
  final VoidCallback onUsePplTemplate;
  final VoidCallback onUseFullBodyTemplate;
  final VoidCallback onViewHistory;
  final VoidCallback onManageTemplates;
  final ActiveTrainingSession? activeSession;
  final VoidCallback? onResumeTraining;
  final VoidCallback? onOpenWeeklyReview;
  final VoidCallback? onOpenCoverage;

  @override
  Widget build(BuildContext context) {
    final viewModel = TrainingPageViewModel.fromSessions(
      sessions: sessions,
      businessDate: businessDate,
    );
    return Scaffold(
      backgroundColor: const Color(0xFFF4F5F7),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 28),
          children: [
            const TrainingPageHeader(),
            const SizedBox(height: 18),
            TrainingStatusCard(status: viewModel.status),
            if (activeSession != null && onResumeTraining != null) ...[
              const SizedBox(height: 14),
              ActiveTrainingSessionCard(
                session: activeSession!,
                onTap: onResumeTraining!,
              ),
            ],
            const SizedBox(height: 14),
            const TrainingAiInsightCard(),
            if (onOpenWeeklyReview != null) ...[
              const SizedBox(height: 10),
              WeeklyReviewEntry(onTap: onOpenWeeklyReview!),
            ],
            const SizedBox(height: 14),
            TrainingQuickStartCard(
              onStartTraining: onStartTraining,
              onUsePplTemplate: onUsePplTemplate,
              onUseFullBodyTemplate: onUseFullBodyTemplate,
              onViewHistory: onViewHistory,
              onManageTemplates: onManageTemplates,
            ),
            const SizedBox(height: 14),
            TrainingLoadCard(
              loads: viewModel.muscleLoads,
              legacyInferredSets: viewModel.legacyInferredSets,
            ),
            if (onOpenCoverage != null) ...[
              const SizedBox(height: 10),
              TrainingCoverageEntry(onTap: onOpenCoverage!),
            ],
            const SizedBox(height: 14),
            PersonalBestCard(personalBests: viewModel.personalBests),
          ],
        ),
      ),
    );
  }
}
