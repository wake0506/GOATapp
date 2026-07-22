import 'dart:async';

import 'package:flutter/material.dart';

import '../../../exercise_catalog.dart';
import '../../../models/training.dart';
import '../../../widgets/goat_page_header.dart';
import '../models/exercise_metadata.dart';
import '../models/exercise_recommendation.dart';
import '../models/training_coverage.dart';
import '../painters/muscle_coverage_painter.dart';
import '../painters/muscle_map_3d_painter.dart';
import '../services/exercise_recommendation_engine.dart';
import '../widgets/interactive_muscle_map_3d.dart';

enum TrainingCoverageScope { current, today, sevenDays }

typedef MuscleMap3DInitializer = Future<bool> Function();

Future<bool> initializeProceduralMuscleMap3D() async => true;

class TrainingCoveragePage extends StatefulWidget {
  const TrainingCoveragePage({
    super.key,
    required this.todayCoverage,
    required this.weeklyCoverage,
    required this.catalog,
    this.currentCoverage,
    this.activeSession,
    this.onApplyRecommendation,
    this.initialize3D = initializeProceduralMuscleMap3D,
    this.initialRegion,
  });

  final TrainingCoverageResult? currentCoverage;
  final TrainingCoverageResult todayCoverage;
  final TrainingCoverageResult weeklyCoverage;
  final List<ExerciseDefinition> catalog;
  final TrainingSession? activeSession;
  final Future<void> Function(ExerciseRecommendationResult recommendation)?
  onApplyRecommendation;
  final MuscleMap3DInitializer initialize3D;
  final MuscleRegion? initialRegion;

  @override
  State<TrainingCoveragePage> createState() => _TrainingCoveragePageState();
}

class _TrainingCoveragePageState extends State<TrainingCoveragePage> {
  late TrainingCoverageScope _scope = widget.currentCoverage == null
      ? TrainingCoverageScope.today
      : TrainingCoverageScope.current;
  late final MuscleMap3DController _mapController;
  late MuscleRegion? _selectedRegion = widget.initialRegion ?? _goalRegion();
  List<ExerciseRecommendationResult> _recommendations = const [];
  bool _recommendationsIgnored = false;
  bool _initializing3D = true;
  bool _simplified = false;
  bool _automaticFallback = false;
  MuscleMapView _fallbackView = MuscleMapView.front;

  TrainingCoverageResult get _coverage => switch (_scope) {
    TrainingCoverageScope.current =>
      widget.currentCoverage ?? widget.todayCoverage,
    TrainingCoverageScope.today => widget.todayCoverage,
    TrainingCoverageScope.sevenDays => widget.weeklyCoverage,
  };

  @override
  void initState() {
    super.initState();
    _mapController = MuscleMap3DController();
    _refreshRecommendations();
    unawaited(_initialize3D());
  }

  @override
  void didUpdateWidget(covariant TrainingCoveragePage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.activeSession != widget.activeSession ||
        oldWidget.currentCoverage != widget.currentCoverage) {
      _refreshRecommendations();
    }
  }

  @override
  void dispose() {
    _mapController.dispose();
    super.dispose();
  }

  Future<void> _initialize3D() async {
    try {
      final supported = await widget.initialize3D().timeout(
        const Duration(seconds: 2),
      );
      if (!mounted) return;
      setState(() {
        _initializing3D = false;
        _simplified = !supported;
        _automaticFallback = !supported;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _initializing3D = false;
        _simplified = true;
        _automaticFallback = true;
      });
    }
  }

  void _refreshRecommendations() {
    final activeSession = widget.activeSession;
    final currentCoverage = widget.currentCoverage;
    if (activeSession == null || currentCoverage == null) {
      _recommendations = const [];
      return;
    }
    _recommendations = const ExerciseRecommendationEngine()
        .complementary(
          currentSession: activeSession,
          coverageResult: currentCoverage,
          catalog: widget.catalog,
        )
        .take(5)
        .toList(growable: false);
  }

  MuscleRegion? _goalRegion() {
    final targets =
        (widget.currentCoverage ?? widget.todayCoverage).targetMuscleGroups;
    for (final group in targets) {
      return switch (group) {
        MuscleGroup.back => MuscleRegion.lats,
        MuscleGroup.chest => MuscleRegion.midChest,
        MuscleGroup.shoulders => MuscleRegion.sideDelts,
        MuscleGroup.arms => MuscleRegion.biceps,
        MuscleGroup.legs => MuscleRegion.quads,
        MuscleGroup.glutes => MuscleRegion.glutes,
        MuscleGroup.core => MuscleRegion.abs,
      };
    }
    return null;
  }

  void _selectRegion(MuscleRegion region, {bool focus = false}) {
    setState(() => _selectedRegion = region);
    if (focus) _mapController.focusRegion(region);
    _showRegionDetail(region);
  }

  Future<void> _showRegionDetail(MuscleRegion region) async {
    final regionCoverage = _coverage.region(region);
    final movementPatterns = _coverage.movementPatternCoverage.where(
      (item) => item.contributingExerciseIds.any(
        regionCoverage.contributingExerciseIds.contains,
      ),
    );
    final contributions =
        [
          for (final entry in regionCoverage.contributingEffectiveSets.entries)
            (name: _exerciseName(entry.key), sets: entry.value, id: entry.key),
        ]..sort((left, right) {
          final bySets = right.sets.compareTo(left.sets);
          return bySets != 0 ? bySets : left.id.compareTo(right.id);
        });
    final recommendation = _recommendations
        .where((item) => item.targetRegions.contains(region))
        .firstOrNull;
    final apply = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(26)),
      ),
      builder: (sheetContext) => SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
          child: Column(
            key: const Key('muscle-region-detail-sheet'),
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Center(
                child: Container(
                  width: 42,
                  height: 4,
                  decoration: BoxDecoration(
                    color: const Color(0xFFD9DEDC),
                    borderRadius: BorderRadius.circular(99),
                  ),
                ),
              ),
              const SizedBox(height: 18),
              Row(
                children: [
                  Expanded(
                    child: Text(
                      muscleRegionLabel(region),
                      style: const TextStyle(
                        fontSize: 23,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  _LevelBadge(level: regionCoverage.level),
                ],
              ),
              const SizedBox(height: 6),
              Text(
                '当前覆盖：${coverageLevelLabel(regionCoverage.level)}',
                style: const TextStyle(color: Color(0xFF68716F)),
              ),
              const SizedBox(height: 20),
              const _SheetLabel('贡献动作'),
              const SizedBox(height: 8),
              if (contributions.isEmpty)
                const Text(
                  '当前窗口暂无有效组贡献',
                  style: TextStyle(color: Color(0xFF7D8583)),
                )
              else
                for (final contribution in contributions)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: Row(
                      children: [
                        const Icon(
                          Icons.fitness_center,
                          size: 16,
                          color: Color(0xFF008C7A),
                        ),
                        const SizedBox(width: 9),
                        Expanded(child: Text(contribution.name)),
                        Text(
                          '${contribution.sets} 组',
                          style: const TextStyle(
                            color: Color(0xFF68716F),
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
              const SizedBox(height: 14),
              const _SheetLabel('动作模式'),
              const SizedBox(height: 8),
              Text(
                movementPatterns.isEmpty
                    ? '暂无已完成的动作模式'
                    : movementPatterns
                          .map(
                            (item) =>
                                '${movementPatternLabel(item.pattern)} ${item.effectiveSetCount} 组',
                          )
                          .join(' · '),
                style: const TextStyle(color: Color(0xFF68716F)),
              ),
              if (recommendation != null) ...[
                const SizedBox(height: 20),
                const _SheetLabel('下一步可考虑'),
                const SizedBox(height: 8),
                _RecommendationPreview(recommendation: recommendation),
                if (widget.onApplyRecommendation != null) ...[
                  const SizedBox(height: 14),
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton(
                      key: const Key('coverage-region-recommendation-apply'),
                      onPressed: () => Navigator.pop(sheetContext, true),
                      style: FilledButton.styleFrom(
                        backgroundColor: const Color(0xFF008C7A),
                        minimumSize: const Size.fromHeight(48),
                      ),
                      child: const Text('采用这条建议'),
                    ),
                  ),
                ],
              ],
              const SizedBox(height: 12),
              const Text(
                '颜色仅表示当前时间窗口内的训练覆盖，不代表损伤、恢复或肌肉增长。',
                style: TextStyle(color: Color(0xFF8A9290), fontSize: 11),
              ),
            ],
          ),
        ),
      ),
    );
    if (apply == true && recommendation != null && mounted) {
      await _confirmRecommendation(recommendation);
    }
  }

  Future<void> _showRecommendationDetail(
    ExerciseRecommendationResult recommendation,
  ) async {
    if (recommendation.targetRegions.isNotEmpty) {
      final target = recommendation.targetRegions.first;
      setState(() => _selectedRegion = target);
      _mapController.focusRegion(target);
    }
    final apply = await showModalBottomSheet<bool>(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(26)),
      ),
      builder: (sheetContext) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 18, 20, 24),
          child: Column(
            key: const Key('coverage-recommendation-detail'),
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                '下一步可考虑',
                style: TextStyle(color: Color(0xFF008C7A), fontSize: 12),
              ),
              const SizedBox(height: 5),
              Text(
                recommendation.exercise.name,
                style: const TextStyle(
                  fontSize: 23,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 16),
              _RecommendationPreview(recommendation: recommendation),
              const SizedBox(height: 16),
              Text(
                recommendation.reasonCodes
                    .map(exerciseRecommendationReasonLabel)
                    .join(' · '),
                style: const TextStyle(color: Color(0xFF68716F)),
              ),
              if (widget.onApplyRecommendation != null) ...[
                const SizedBox(height: 20),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton(
                    key: const Key('coverage-recommendation-detail-apply'),
                    onPressed: () => Navigator.pop(sheetContext, true),
                    style: FilledButton.styleFrom(
                      backgroundColor: const Color(0xFF008C7A),
                      minimumSize: const Size.fromHeight(48),
                    ),
                    child: const Text('采用建议'),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
    if (apply == true && mounted) await _confirmRecommendation(recommendation);
  }

  Future<void> _confirmRecommendation(
    ExerciseRecommendationResult recommendation,
  ) async {
    final callback = widget.onApplyRecommendation;
    if (callback == null) return;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('采用这条动作建议？'),
        content: Text(
          '将 ${recommendation.exercise.name} 加入或切换为下一动作。当前训练方案不会改变。',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('取消'),
          ),
          FilledButton(
            key: const Key('coverage-recommendation-confirm'),
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('确认采用'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    await callback(recommendation);
    if (!mounted) return;
    setState(() {
      _recommendationsIgnored = true;
      _recommendations = const [];
    });
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('已采用 ${recommendation.exercise.name}')),
    );
  }

  String _exerciseName(String id) =>
      widget.catalog
          .where((exercise) => exercise.id == id)
          .map((exercise) => exercise.name)
          .firstOrNull ??
      id;

  @override
  Widget build(BuildContext context) {
    final media = MediaQuery.of(context);
    final reducedMotion = media.disableAnimations || media.accessibleNavigation;
    final visibleRecommendations = _recommendationsIgnored
        ? const <ExerciseRecommendationResult>[]
        : _recommendations;
    return Scaffold(
      key: const Key('training-coverage-page'),
      backgroundColor: const Color(0xFFF4F5F7),
      appBar: AppBar(
        backgroundColor: const Color(0xFFF4F5F7),
        elevation: 0,
        title: const GoatPageHeader(title: '训 练 覆 盖'),
        actions: [
          IconButton(
            key: const Key('coverage-view-mode-toggle'),
            tooltip: _simplified ? '切换 3D 视图' : '切换简化视图',
            onPressed: _initializing3D
                ? null
                : () => setState(() {
                    _simplified = !_simplified;
                    _automaticFallback = false;
                  }),
            icon: Icon(
              _simplified ? Icons.view_in_ar_outlined : Icons.accessibility_new,
              color: const Color(0xFF52605D),
            ),
          ),
        ],
      ),
      body: Align(
        alignment: Alignment.topCenter,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 780),
          child: ListView(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
            children: [
              _ScopeSelector(
                scope: _scope,
                hasCurrent: widget.currentCoverage != null,
                onChanged: (scope) => setState(() => _scope = scope),
              ),
              const SizedBox(height: 14),
              if (_automaticFallback) ...[
                const _FallbackNotice(),
                const SizedBox(height: 12),
              ],
              _CoverageCard(
                padding: const EdgeInsets.fromLTRB(14, 16, 14, 12),
                child: Column(
                  children: [
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 6),
                      child: Row(
                        children: [
                          const Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  '肌群分布',
                                  style: TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                                SizedBox(height: 2),
                                Text(
                                  '训练覆盖可视化 · 非医学状态',
                                  style: TextStyle(
                                    color: Color(0xFF8A9290),
                                    fontSize: 11,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          _ViewShortcut(
                            label: '正面',
                            onTap: () {
                              if (_simplified) {
                                setState(
                                  () => _fallbackView = MuscleMapView.front,
                                );
                              } else {
                                _mapController.showFront();
                              }
                            },
                          ),
                          const SizedBox(width: 6),
                          _ViewShortcut(
                            label: '背面',
                            onTap: () {
                              if (_simplified) {
                                setState(
                                  () => _fallbackView = MuscleMapView.back,
                                );
                              } else {
                                _mapController.showBack();
                              }
                            },
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 8),
                    SizedBox(
                      height: media.size.width >= 700 ? 450 : 398,
                      child: _initializing3D
                          ? const _MuscleMapLoading()
                          : _simplified
                          ? Center(
                              child: SizedBox(
                                width: 220,
                                height: 360,
                                child: CustomPaint(
                                  key: const Key('muscle-coverage-map'),
                                  painter: MuscleCoveragePainter(
                                    coverage: _coverage,
                                    view: _fallbackView,
                                  ),
                                  child: const SizedBox.expand(),
                                ),
                              ),
                            )
                          : InteractiveMuscleMap3D(
                              coverage: _coverage,
                              controller: _mapController,
                              initialRegion: _selectedRegion,
                              reducedMotion: reducedMotion,
                              onRegionSelected: _selectRegion,
                            ),
                    ),
                    const SizedBox(height: 8),
                    _CoverageLegend(),
                    const SizedBox(height: 9),
                    Text(
                      coverageQualityLabel(_coverage.dataQuality),
                      style: const TextStyle(
                        color: Color(0xFF7D8583),
                        fontSize: 11,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 14),
              _RegionCoverageSummary(
                coverage: _coverage,
                onSelected: (region) => _selectRegion(region, focus: true),
              ),
              if (visibleRecommendations.isNotEmpty) ...[
                const SizedBox(height: 14),
                _CoverageRecommendationCard(
                  recommendation: visibleRecommendations.first,
                  onOpen: () =>
                      _showRecommendationDetail(visibleRecommendations.first),
                  onIgnore: () =>
                      setState(() => _recommendationsIgnored = true),
                ),
              ],
              const SizedBox(height: 14),
              _MovementSummary(coverage: _coverage),
            ],
          ),
        ),
      ),
    );
  }
}

class _ScopeSelector extends StatelessWidget {
  const _ScopeSelector({
    required this.scope,
    required this.hasCurrent,
    required this.onChanged,
  });

  final TrainingCoverageScope scope;
  final bool hasCurrent;
  final ValueChanged<TrainingCoverageScope> onChanged;

  @override
  Widget build(BuildContext context) => SegmentedButton<TrainingCoverageScope>(
    key: const Key('coverage-scope-toggle'),
    showSelectedIcon: false,
    segments: [
      if (hasCurrent)
        const ButtonSegment(
          value: TrainingCoverageScope.current,
          label: Text('本次'),
        ),
      const ButtonSegment(
        value: TrainingCoverageScope.today,
        label: Text('今日'),
      ),
      const ButtonSegment(
        value: TrainingCoverageScope.sevenDays,
        label: Text('近 7 天'),
      ),
    ],
    selected: {scope},
    onSelectionChanged: (value) => onChanged(value.first),
    style: ButtonStyle(
      visualDensity: VisualDensity.compact,
      backgroundColor: WidgetStateProperty.resolveWith(
        (states) => states.contains(WidgetState.selected)
            ? const Color(0xFFDDF0EB)
            : Colors.white,
      ),
    ),
  );
}

class _RegionCoverageSummary extends StatelessWidget {
  const _RegionCoverageSummary({
    required this.coverage,
    required this.onSelected,
  });

  final TrainingCoverageResult coverage;
  final ValueChanged<MuscleRegion> onSelected;

  @override
  Widget build(BuildContext context) {
    final items =
        coverage.regionCoverage.where((item) {
          final target = coverage.targetMuscleGroups.contains(
            muscleGroupForRegion(item.region),
          );
          return target || item.level != CoverageLevel.untrained;
        }).toList()..sort((left, right) {
          final byLevel = right.level.index.compareTo(left.level.index);
          return byLevel != 0
              ? byLevel
              : left.region.index.compareTo(right.region.index);
        });
    final visible = items.isEmpty
        ? coverage.regionCoverage.take(5)
        : items.take(8);
    final more = coverage.muscleCoverage
        .where(
          (item) =>
              item.level == CoverageLevel.sufficient ||
              item.level == CoverageLevel.high,
        )
        .toList();
    final less = coverage.muscleCoverage
        .where(
          (item) =>
              coverage.targetMuscleGroups.contains(item.muscle) &&
              (item.level == CoverageLevel.untrained ||
                  item.level == CoverageLevel.light),
        )
        .toList();
    return _CoverageCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            '覆盖摘要',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 10),
          Text(
            more.isEmpty
                ? '当前还没有覆盖较多的区域'
                : '覆盖较多：${more.map((item) => muscleGroupLabel(item.muscle)).join('、')}',
          ),
          const SizedBox(height: 6),
          Text(
            less.isEmpty
                ? '当前计划下暂无明显的相对低覆盖区域'
                : '当前计划下可进一步补充：${less.map((item) => muscleGroupLabel(item.muscle)).join('、')}',
            style: const TextStyle(color: Color(0xFF68716F)),
          ),
          const SizedBox(height: 15),
          for (final item in visible)
            Semantics(
              button: true,
              label:
                  '${muscleRegionLabel(item.region)}，当前覆盖${coverageLevelLabel(item.level)}，点击查看详情',
              child: InkWell(
                key: Key('coverage-region-${item.region.name}'),
                borderRadius: BorderRadius.circular(12),
                onTap: () => onSelected(item.region),
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 9),
                  child: Row(
                    children: [
                      Container(
                        width: 9,
                        height: 9,
                        decoration: BoxDecoration(
                          color: muscleCoverage3DColor(item.level),
                          shape: BoxShape.circle,
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(child: Text(muscleRegionLabel(item.region))),
                      Text(
                        coverageLevelLabel(item.level),
                        style: const TextStyle(
                          color: Color(0xFF68716F),
                          fontSize: 12,
                        ),
                      ),
                      const SizedBox(width: 4),
                      const Icon(
                        Icons.chevron_right,
                        size: 18,
                        color: Color(0xFF99A09E),
                      ),
                    ],
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _MovementSummary extends StatelessWidget {
  const _MovementSummary({required this.coverage});

  final TrainingCoverageResult coverage;

  @override
  Widget build(BuildContext context) {
    final movements =
        coverage.movementPatternCoverage
            .where((item) => item.effectiveSetCount > 0)
            .toList()
          ..sort(
            (left, right) =>
                right.effectiveSetCount.compareTo(left.effectiveSetCount),
          );
    return _CoverageCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            '动作模式',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 12),
          if (movements.isEmpty)
            const Text('暂无已完成的动作模式记录')
          else
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final item in movements)
                  _Pill(
                    text:
                        '${movementPatternLabel(item.pattern)} ${item.effectiveSetCount} 组',
                  ),
              ],
            ),
        ],
      ),
    );
  }
}

class _CoverageRecommendationCard extends StatelessWidget {
  const _CoverageRecommendationCard({
    required this.recommendation,
    required this.onOpen,
    required this.onIgnore,
  });

  final ExerciseRecommendationResult recommendation;
  final VoidCallback onOpen;
  final VoidCallback onIgnore;

  @override
  Widget build(BuildContext context) => _CoverageCard(
    child: Column(
      key: const Key('coverage-recommendation-card'),
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Icon(Icons.auto_awesome, size: 18, color: Color(0xFF008C7A)),
            const SizedBox(width: 8),
            const Expanded(
              child: Text(
                '下一步可考虑',
                style: TextStyle(
                  color: Color(0xFF008C7A),
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
            IconButton(
              key: const Key('coverage-recommendation-ignore'),
              tooltip: '忽略建议',
              visualDensity: VisualDensity.compact,
              onPressed: onIgnore,
              icon: const Icon(Icons.close, size: 18),
            ),
          ],
        ),
        Text(
          recommendation.exercise.name,
          style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: 7),
        Text(
          [
            ...recommendation.targetRegions.take(2).map(muscleRegionLabel),
            movementPatternLabel(recommendation.movementPattern),
          ].join(' · '),
          style: const TextStyle(color: Color(0xFF68716F), fontSize: 12),
        ),
        const SizedBox(height: 12),
        Align(
          alignment: Alignment.centerRight,
          child: TextButton(
            key: const Key('coverage-recommendation-open'),
            onPressed: onOpen,
            child: const Text('查看原因'),
          ),
        ),
      ],
    ),
  );
}

class _RecommendationPreview extends StatelessWidget {
  const _RecommendationPreview({required this.recommendation});

  final ExerciseRecommendationResult recommendation;

  @override
  Widget build(BuildContext context) => Container(
    width: double.infinity,
    padding: const EdgeInsets.all(14),
    decoration: BoxDecoration(
      color: const Color(0xFFF0F6F4),
      borderRadius: BorderRadius.circular(16),
    ),
    child: Text(
      '${recommendation.exercise.name}\n目标区域：${recommendation.targetRegions.map(muscleRegionLabel).join('、')}\n动作模式：${movementPatternLabel(recommendation.movementPattern)}',
      style: const TextStyle(height: 1.65),
    ),
  );
}

class _CoverageLegend extends StatelessWidget {
  @override
  Widget build(BuildContext context) => Wrap(
    alignment: WrapAlignment.center,
    spacing: 10,
    runSpacing: 7,
    children: [
      for (final level in CoverageLevel.values)
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 8,
              height: 8,
              decoration: BoxDecoration(
                color: muscleCoverage3DColor(level),
                shape: BoxShape.circle,
              ),
            ),
            const SizedBox(width: 4),
            Text(
              coverageLevelLabel(level),
              style: const TextStyle(color: Color(0xFF68716F), fontSize: 10),
            ),
          ],
        ),
    ],
  );
}

class _ViewShortcut extends StatelessWidget {
  const _ViewShortcut({required this.label, required this.onTap});

  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => InkWell(
    borderRadius: BorderRadius.circular(99),
    onTap: onTap,
    child: Container(
      padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 7),
      decoration: BoxDecoration(
        color: const Color(0xFFF0F5F3),
        borderRadius: BorderRadius.circular(99),
      ),
      child: Text(
        label,
        style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600),
      ),
    ),
  );
}

class _LevelBadge extends StatelessWidget {
  const _LevelBadge({required this.level});

  final CoverageLevel level;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
    decoration: BoxDecoration(
      color: muscleCoverage3DColor(level),
      borderRadius: BorderRadius.circular(99),
    ),
    child: Text(
      coverageLevelLabel(level),
      style: TextStyle(
        color: level.index >= CoverageLevel.sufficient.index
            ? Colors.white
            : const Color(0xFF35514B),
        fontSize: 11,
        fontWeight: FontWeight.w700,
      ),
    ),
  );
}

class _SheetLabel extends StatelessWidget {
  const _SheetLabel(this.text);

  final String text;

  @override
  Widget build(BuildContext context) => Text(
    text,
    style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14),
  );
}

class _FallbackNotice extends StatelessWidget {
  const _FallbackNotice();

  @override
  Widget build(BuildContext context) => Container(
    key: const Key('muscle-map-3d-fallback-notice'),
    padding: const EdgeInsets.all(14),
    decoration: BoxDecoration(
      color: const Color(0xFFEAF4F1),
      borderRadius: BorderRadius.circular(16),
    ),
    child: const Row(
      children: [
        Icon(Icons.info_outline, color: Color(0xFF008C7A), size: 19),
        SizedBox(width: 10),
        Expanded(
          child: Text(
            '当前设备暂无法显示 3D 模型，已切换至简化视图。',
            style: TextStyle(color: Color(0xFF52605D), fontSize: 12),
          ),
        ),
      ],
    ),
  );
}

class _MuscleMapLoading extends StatelessWidget {
  const _MuscleMapLoading();

  @override
  Widget build(BuildContext context) => Container(
    key: const Key('muscle-map-3d-loading'),
    margin: const EdgeInsets.all(18),
    decoration: BoxDecoration(
      color: const Color(0xFFF2F6F4),
      borderRadius: BorderRadius.circular(28),
    ),
    child: const Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.accessibility_new, color: Color(0xFF8FBDB2), size: 52),
          SizedBox(height: 12),
          Text(
            '正在准备训练覆盖视图',
            style: TextStyle(color: Color(0xFF68716F), fontSize: 12),
          ),
        ],
      ),
    ),
  );
}

class _CoverageCard extends StatelessWidget {
  const _CoverageCard({
    required this.child,
    this.padding = const EdgeInsets.all(20),
  });

  final Widget child;
  final EdgeInsets padding;

  @override
  Widget build(BuildContext context) => Container(
    padding: padding,
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
    child: child,
  );
}

class _Pill extends StatelessWidget {
  const _Pill({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
    decoration: BoxDecoration(
      color: const Color(0xFFF0F5F3),
      borderRadius: BorderRadius.circular(14),
    ),
    child: Text(text, style: const TextStyle(fontSize: 12)),
  );
}
