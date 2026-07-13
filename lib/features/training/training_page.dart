import 'package:flutter/material.dart';

import '../../models/training.dart';
import 'recent_training_section.dart';
import 'training_dashboard_card.dart';
import 'training_dashboard_data.dart';
import 'training_empty_state.dart';
import 'training_plan_section.dart';
import 'training_quick_actions.dart';
import 'training_stats_row.dart';
import 'training_template_section.dart';

class TrainingPage extends StatelessWidget {
  final List<TrainingSession> sessions;
  final String businessDate;
  final VoidCallback onStartTraining;
  final VoidCallback onAddRecord;
  final VoidCallback onAddTemplate;
  final VoidCallback onViewHistory;
  final ValueChanged<TrainingTemplate> onSelectTemplate;
  final ValueChanged<TrainingSession> onOpenSession;

  const TrainingPage({
    super.key,
    required this.sessions,
    required this.businessDate,
    required this.onStartTraining,
    required this.onAddRecord,
    required this.onAddTemplate,
    required this.onViewHistory,
    required this.onSelectTemplate,
    required this.onOpenSession,
  });

  @override
  Widget build(BuildContext context) {
    final data = TrainingDashboardData.fromSessions(
      sessions: sessions,
      businessDate: businessDate,
    );
    return Scaffold(
      backgroundColor: const Color(0xFFF4F5F7),
      appBar: AppBar(
        backgroundColor: const Color(0xFFF4F5F7),
        elevation: 0,
        centerTitle: false,
        title: const Text(
          '训练',
          style: TextStyle(fontWeight: FontWeight.w700, color: Colors.black),
        ),
        actions: [
          IconButton(
            onPressed: onAddRecord,
            icon: const Icon(
              Icons.add_circle_outline,
              color: Color(0xFF008C8C),
            ),
            tooltip: '添加训练记录',
          ),
          const SizedBox(width: 6),
        ],
      ),
      body: SafeArea(
        top: false,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 10, 20, 28),
          children: [
            TrainingDashboardCard(data: data),
            const SizedBox(height: 18),
            TrainingQuickActions(
              onStartTraining: onStartTraining,
              onAddRecord: onAddRecord,
              onAddTemplate: onAddTemplate,
              onViewHistory: onViewHistory,
            ),
            const SizedBox(height: 22),
            TrainingTemplateSection(onSelect: onSelectTemplate),
            const SizedBox(height: 22),
            if (!data.hasSessions) ...[
              const TrainingEmptyState(),
              const SizedBox(height: 22),
            ],
            RecentTrainingSection(
              sessions: data.recentSessions,
              onOpenSession: onOpenSession,
            ),
            const SizedBox(height: 22),
            TrainingPlanSection(data: data, onCreatePlan: onAddTemplate),
            const SizedBox(height: 22),
            TrainingStatsRow(data: data),
          ],
        ),
      ),
    );
  }
}
