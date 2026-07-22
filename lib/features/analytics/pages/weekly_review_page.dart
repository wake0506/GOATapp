import 'package:flutter/material.dart';

import '../../../widgets/goat_page_header.dart';
import '../../training/models/exercise_metadata.dart';
import '../../training/models/training_coverage.dart';
import '../models/effective_set_summary.dart';
import '../models/weight_trend.dart';
import '../models/weekly_review.dart';

class WeeklyReviewPage extends StatelessWidget {
  const WeeklyReviewPage({
    super.key,
    required this.training,
    required this.nutrition,
    this.coverage,
    this.onOpenCoverage,
  });

  final WeeklyTrainingReview training;
  final WeeklyNutritionReview nutrition;
  final TrainingCoverageResult? coverage;
  final VoidCallback? onOpenCoverage;

  @override
  Widget build(BuildContext context) => Scaffold(
    key: const Key('weekly-review-page'),
    backgroundColor: const Color(0xFFF4F5F7),
    appBar: AppBar(
      backgroundColor: const Color(0xFFF4F5F7),
      elevation: 0,
      title: const GoatPageHeader(title: '本 周 复 盘'),
    ),
    body: ListView(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
      children: [
        Text(
          '${_date(training.dateRange.start)} – ${_date(training.dateRange.end)}',
          style: const TextStyle(color: Color(0xFF7D8583), fontSize: 12),
        ),
        const SizedBox(height: 12),
        _TrainingReviewCard(review: training),
        if (coverage != null) ...[
          const SizedBox(height: 14),
          _WeeklyCoverageCard(
            coverage: coverage!,
            onOpenCoverage: onOpenCoverage,
          ),
        ],
        const SizedBox(height: 14),
        _NutritionReviewCard(review: nutrition),
        const SizedBox(height: 14),
        _WeightReviewCard(review: nutrition),
      ],
    ),
  );

  static String _date(DateTime date) => '${date.month}/${date.day}';
}

class _WeeklyCoverageCard extends StatelessWidget {
  const _WeeklyCoverageCard({required this.coverage, this.onOpenCoverage});

  final TrainingCoverageResult coverage;
  final VoidCallback? onOpenCoverage;

  @override
  Widget build(BuildContext context) {
    final more = coverage.muscleCoverage
        .where(
          (item) =>
              item.level == CoverageLevel.sufficient ||
              item.level == CoverageLevel.high,
        )
        .map((item) => muscleGroupLabel(item.muscle))
        .toList();
    final less = coverage.muscleCoverage
        .where(
          (item) =>
              coverage.targetMuscleGroups.contains(item.muscle) &&
              (item.level == CoverageLevel.untrained ||
                  item.level == CoverageLevel.light),
        )
        .map((item) => muscleGroupLabel(item.muscle))
        .toList();
    return _ReviewCard(
      key: const Key('weekly-coverage-review'),
      title: '本周训练覆盖',
      quality: coverageQualityLabel(coverage.dataQuality),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            more.isEmpty ? '本周记录较少' : '覆盖较多：${more.join('、')}',
            style: const TextStyle(fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 7),
          Text(
            less.isEmpty ? '仅展示已有记录，不判断全身是否练满' : '当前记录中相对较少：${less.join('、')}',
            style: const TextStyle(color: Color(0xFF68716F), fontSize: 12),
          ),
          if (onOpenCoverage != null) ...[
            const SizedBox(height: 10),
            Align(
              alignment: Alignment.centerRight,
              child: TextButton.icon(
                key: const Key('weekly-open-3d-coverage'),
                onPressed: onOpenCoverage,
                icon: const Icon(Icons.view_in_ar_outlined, size: 17),
                label: const Text('查看 3D'),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _TrainingReviewCard extends StatelessWidget {
  const _TrainingReviewCard({required this.review});

  final WeeklyTrainingReview review;

  @override
  Widget build(BuildContext context) => _ReviewCard(
    key: const Key('weekly-training-review'),
    title: '本周训练',
    quality: _qualityLabel(review.dataQuality),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            _Metric(label: '训练天数', value: '${review.trainingDays} 天'),
            _Metric(label: '训练次数', value: '${review.sessionCount} 次'),
            _Metric(label: '有效组', value: '${review.effectiveSets} 组'),
          ],
        ),
        const SizedBox(height: 14),
        Text(
          '完成 ${review.completedSets} 组 · 总容量 ${review.totalVolume.toStringAsFixed(0)} kg',
          style: const TextStyle(color: Color(0xFF626B69), fontSize: 12),
        ),
        if (review.topTrainedGroup != null) ...[
          const SizedBox(height: 6),
          Text(
            '训练组最多：${_groupLabel(review.topTrainedGroup!)} · ${_groupSets(review)} 组',
            style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
          ),
        ],
        if (review.muscleGroups.isNotEmpty) ...[
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final group in review.muscleGroups)
                _NeutralPill(
                  text:
                      '${_groupLabel(group.muscleGroup)} ${group.effectiveSets}组',
                ),
            ],
          ),
        ],
        if (review.previousEffectiveSets != null) ...[
          const SizedBox(height: 12),
          Text(
            '上个 7 日周期：${review.previousSessionCount} 次训练 · ${review.previousEffectiveSets} 个有效组',
            style: const TextStyle(color: Color(0xFF7D8583), fontSize: 12),
          ),
        ],
        if (review.reasons.contains(WeeklyReviewReason.legacyTrainingData))
          const Padding(
            padding: EdgeInsets.only(top: 8),
            child: Text(
              '包含部分历史训练记录',
              style: TextStyle(color: Color(0xFF8B9290), fontSize: 11),
            ),
          ),
      ],
    ),
  );

  int _groupSets(WeeklyTrainingReview review) => review.muscleGroups
      .firstWhere((group) => group.muscleGroup == review.topTrainedGroup)
      .effectiveSets;
}

class _NutritionReviewCard extends StatelessWidget {
  const _NutritionReviewCard({required this.review});

  final WeeklyNutritionReview review;

  @override
  Widget build(BuildContext context) => _ReviewCard(
    key: const Key('weekly-nutrition-review'),
    title: '本周营养',
    quality: _qualityLabel(review.dataQuality),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '记录 ${review.recordedDays} / 7 天',
          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: 4),
        const Text(
          '以下平均值仅基于已记录日期',
          style: TextStyle(color: Color(0xFF7D8583), fontSize: 11),
        ),
        const SizedBox(height: 14),
        Row(
          children: [
            _Metric(
              label: '平均摄入',
              value: _number(review.averageCalories, 'kcal'),
            ),
            _Metric(label: '蛋白质', value: _number(review.averageProtein, 'g')),
          ],
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            _Metric(label: '碳水', value: _number(review.averageCarbs, 'g')),
            _Metric(label: '脂肪', value: _number(review.averageFat, 'g')),
          ],
        ),
        if (review.previousAverageCalories != null) ...[
          const SizedBox(height: 12),
          Text(
            '上个 7 日周期平均 ${review.previousAverageCalories!.round()} kcal',
            style: const TextStyle(color: Color(0xFF7D8583), fontSize: 12),
          ),
        ],
      ],
    ),
  );

  String _number(double? value, String unit) =>
      value == null ? '--' : '${value.round()} $unit';
}

class _WeightReviewCard extends StatelessWidget {
  const _WeightReviewCard({required this.review});

  final WeeklyNutritionReview review;

  @override
  Widget build(BuildContext context) {
    final trend = review.weightTrend;
    return _ReviewCard(
      key: const Key('weekly-weight-review'),
      title: '体重趋势',
      quality: switch (trend.dataQuality) {
        WeightTrendDataQuality.unavailable => '暂无数据',
        WeightTrendDataQuality.singleReading => '历史数据有限',
        WeightTrendDataQuality.partial => '数据积累中',
        WeightTrendDataQuality.complete => '数据充分',
      },
      child: Row(
        children: [
          _Metric(
            label: '趋势体重',
            value: trend.sevenDayAverageKg == null
                ? '--'
                : '${trend.sevenDayAverageKg!.toStringAsFixed(2)} kg',
          ),
          _Metric(label: '7天变化', value: _change(trend.change7dKg)),
          _Metric(label: '14天变化', value: _change(trend.change14dKg)),
        ],
      ),
    );
  }

  String _change(double? value) {
    if (value == null) return '--';
    return '${value > 0 ? '+' : ''}${value.toStringAsFixed(2)} kg';
  }
}

class _ReviewCard extends StatelessWidget {
  const _ReviewCard({
    super.key,
    required this.title,
    required this.quality,
    required this.child,
  });

  final String title;
  final String quality;
  final Widget child;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(20),
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(20),
      boxShadow: const [
        BoxShadow(
          color: Color(0x0D17211E),
          blurRadius: 14,
          offset: Offset(0, 5),
        ),
      ],
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                title,
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
            Text(
              quality,
              style: const TextStyle(color: Color(0xFF8A9290), fontSize: 11),
            ),
          ],
        ),
        const SizedBox(height: 16),
        child,
      ],
    ),
  );
}

class _Metric extends StatelessWidget {
  const _Metric({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) => Expanded(
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          value,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: 3),
        Text(
          label,
          style: const TextStyle(color: Color(0xFF7D8583), fontSize: 11),
        ),
      ],
    ),
  );
}

class _NeutralPill extends StatelessWidget {
  const _NeutralPill({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
    decoration: BoxDecoration(
      color: const Color(0xFFF1F4F3),
      borderRadius: BorderRadius.circular(14),
    ),
    child: Text(text, style: const TextStyle(fontSize: 12)),
  );
}

String _qualityLabel(WeeklyReviewDataQuality quality) => switch (quality) {
  WeeklyReviewDataQuality.complete => '数据充分',
  WeeklyReviewDataQuality.partial => '数据不完整',
  WeeklyReviewDataQuality.insufficient => '暂无记录',
};

String _groupLabel(AnalyticsMuscleGroup group) => switch (group) {
  AnalyticsMuscleGroup.chest => '胸部',
  AnalyticsMuscleGroup.back => '背部',
  AnalyticsMuscleGroup.legs => '腿部',
  AnalyticsMuscleGroup.shoulders => '肩部',
  AnalyticsMuscleGroup.arms => '手臂',
  AnalyticsMuscleGroup.core => '核心',
  AnalyticsMuscleGroup.glutes => '臀部',
  AnalyticsMuscleGroup.fullBody => '全身',
};
