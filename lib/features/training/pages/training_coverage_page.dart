import 'package:flutter/material.dart';

import '../../../exercise_catalog.dart';
import '../../../widgets/goat_page_header.dart';
import '../models/exercise_metadata.dart';
import '../models/training_coverage.dart';
import '../painters/muscle_coverage_painter.dart';

class TrainingCoveragePage extends StatefulWidget {
  const TrainingCoveragePage({
    super.key,
    required this.sessionCoverage,
    required this.weeklyCoverage,
    required this.catalog,
  });

  final TrainingCoverageResult sessionCoverage;
  final TrainingCoverageResult weeklyCoverage;
  final List<ExerciseDefinition> catalog;

  @override
  State<TrainingCoveragePage> createState() => _TrainingCoveragePageState();
}

class _TrainingCoveragePageState extends State<TrainingCoveragePage> {
  bool _weekly = false;
  MuscleMapView _view = MuscleMapView.front;

  TrainingCoverageResult get _coverage =>
      _weekly ? widget.weeklyCoverage : widget.sessionCoverage;

  @override
  Widget build(BuildContext context) => Scaffold(
    key: const Key('training-coverage-page'),
    backgroundColor: const Color(0xFFF4F5F7),
    appBar: AppBar(
      backgroundColor: const Color(0xFFF4F5F7),
      elevation: 0,
      title: const GoatPageHeader(title: '训 练 覆 盖'),
    ),
    body: ListView(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
      children: [
        SegmentedButton<bool>(
          key: const Key('coverage-scope-toggle'),
          segments: const [
            ButtonSegment(value: false, label: Text('本次 / 今日')),
            ButtonSegment(value: true, label: Text('近 7 天')),
          ],
          selected: {_weekly},
          onSelectionChanged: (value) => setState(() => _weekly = value.first),
          style: ButtonStyle(
            backgroundColor: WidgetStateProperty.resolveWith(
              (states) => states.contains(WidgetState.selected)
                  ? const Color(0xFFDDF0EB)
                  : Colors.white,
            ),
          ),
        ),
        const SizedBox(height: 14),
        _CoverageCard(
          child: Column(
            children: [
              Row(
                children: [
                  const Expanded(
                    child: Text(
                      '肌群分布',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  SegmentedButton<MuscleMapView>(
                    key: const Key('coverage-map-view-toggle'),
                    showSelectedIcon: false,
                    segments: const [
                      ButtonSegment(
                        value: MuscleMapView.front,
                        label: Text('正面'),
                      ),
                      ButtonSegment(
                        value: MuscleMapView.back,
                        label: Text('背面'),
                      ),
                    ],
                    selected: {_view},
                    onSelectionChanged: (value) =>
                        setState(() => _view = value.first),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Center(
                child: SizedBox(
                  width: 220,
                  height: 360,
                  child: CustomPaint(
                    key: const Key('muscle-coverage-map'),
                    painter: MuscleCoveragePainter(
                      coverage: _coverage,
                      view: _view,
                    ),
                    child: const SizedBox.expand(),
                  ),
                ),
              ),
              const SizedBox(height: 8),
              Text(
                coverageQualityLabel(_coverage.dataQuality),
                style: const TextStyle(color: Color(0xFF7D8583), fontSize: 11),
              ),
            ],
          ),
        ),
        const SizedBox(height: 14),
        _CoverageSummary(coverage: _coverage),
        const SizedBox(height: 14),
        _MovementSummary(coverage: _coverage),
        const SizedBox(height: 14),
        _ContributingExercises(
          coverage: _coverage,
          catalog: widget.catalog,
          view: _view,
        ),
      ],
    ),
  );
}

class _CoverageSummary extends StatelessWidget {
  const _CoverageSummary({required this.coverage});

  final TrainingCoverageResult coverage;

  @override
  Widget build(BuildContext context) {
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
          const SizedBox(height: 12),
          Text(
            more.isEmpty
                ? '当前还没有覆盖较多的区域'
                : '覆盖较多：${more.map((item) => muscleGroupLabel(item.muscle)).join('、')}',
          ),
          const SizedBox(height: 7),
          Text(
            less.isEmpty
                ? '当前计划下暂无明显的相对低覆盖区域'
                : '当前计划下可进一步补充：${less.map((item) => muscleGroupLabel(item.muscle)).join('、')}',
            style: const TextStyle(color: Color(0xFF68716F)),
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

class _ContributingExercises extends StatelessWidget {
  const _ContributingExercises({
    required this.coverage,
    required this.catalog,
    required this.view,
  });

  final TrainingCoverageResult coverage;
  final List<ExerciseDefinition> catalog;
  final MuscleMapView view;

  @override
  Widget build(BuildContext context) {
    final visibleRegions = view == MuscleMapView.front
        ? const {
            MuscleRegion.upperChest,
            MuscleRegion.midChest,
            MuscleRegion.lowerChest,
            MuscleRegion.frontDelts,
            MuscleRegion.sideDelts,
            MuscleRegion.biceps,
            MuscleRegion.forearms,
            MuscleRegion.abs,
            MuscleRegion.obliques,
            MuscleRegion.quads,
            MuscleRegion.adductors,
            MuscleRegion.calves,
          }
        : const {
            MuscleRegion.rearDelts,
            MuscleRegion.upperBack,
            MuscleRegion.midBack,
            MuscleRegion.lowerBack,
            MuscleRegion.lats,
            MuscleRegion.triceps,
            MuscleRegion.forearms,
            MuscleRegion.glutes,
            MuscleRegion.hamstrings,
            MuscleRegion.calves,
            MuscleRegion.spinalErectors,
          };
    final ids = coverage.regionCoverage
        .where((item) => visibleRegions.contains(item.region))
        .expand((item) => item.contributingExerciseIds)
        .toSet();
    final names = catalog
        .where((exercise) => ids.contains(exercise.id))
        .map((exercise) => exercise.name)
        .toList();
    return _CoverageCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            '贡献动作',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 10),
          Text(
            names.isEmpty ? '当前视图暂无贡献动作' : names.take(8).join(' · '),
            style: const TextStyle(color: Color(0xFF68716F)),
          ),
        ],
      ),
    );
  }
}

class _CoverageCard extends StatelessWidget {
  const _CoverageCard({required this.child});

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
