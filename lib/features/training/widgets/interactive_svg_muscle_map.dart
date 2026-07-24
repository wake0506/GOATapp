import 'package:flutter/material.dart';

import '../models/exercise_metadata.dart';
import '../models/muscle_region_svg_mapping.dart';
import '../models/training_coverage.dart';
import '../painters/svg_muscle_map_painter.dart';

class SvgMuscleMapController extends ChangeNotifier {
  MuscleBodyView _view = MuscleBodyView.front;
  MuscleRegion? _selectedRegion;

  MuscleBodyView get view => _view;
  MuscleRegion? get selectedRegion => _selectedRegion;

  void showFront() => _moveTo(MuscleBodyView.front, null);

  void showBack() => _moveTo(MuscleBodyView.back, null);

  void focusRegion(MuscleRegion region) {
    final view =
        muscleRegionSvgMapping[region]?.preferredView ?? MuscleBodyView.front;
    _moveTo(view, region);
  }

  void _moveTo(MuscleBodyView view, MuscleRegion? region) {
    _view = view;
    _selectedRegion = region;
    notifyListeners();
  }
}

class InteractiveSvgMuscleMap extends StatefulWidget {
  const InteractiveSvgMuscleMap({
    super.key,
    required this.coverage,
    required this.onRegionSelected,
    this.controller,
    this.initialRegion,
    this.reducedMotion = false,
  });

  final TrainingCoverageResult coverage;
  final ValueChanged<MuscleRegion> onRegionSelected;
  final SvgMuscleMapController? controller;
  final MuscleRegion? initialRegion;
  final bool reducedMotion;

  @override
  State<InteractiveSvgMuscleMap> createState() =>
      _InteractiveSvgMuscleMapState();
}

class _InteractiveSvgMuscleMapState extends State<InteractiveSvgMuscleMap>
    with TickerProviderStateMixin {
  late final AnimationController _coverageController;
  late TrainingCoverageResult _previousCoverage;
  late MuscleBodyView _view;
  MuscleRegion? _selectedRegion;
  double _dragDistance = 0;

  @override
  void initState() {
    super.initState();
    _previousCoverage = widget.coverage;
    _selectedRegion = widget.controller?.selectedRegion ?? widget.initialRegion;
    _view =
        widget.controller?.view ??
        (widget.initialRegion == null
            ? MuscleBodyView.front
            : muscleRegionSvgMapping[widget.initialRegion]?.preferredView ??
                  MuscleBodyView.front);
    _coverageController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 280),
      value: 1,
    )..addListener(_repaint);
    widget.controller?.addListener(_handleController);
  }

  @override
  void didUpdateWidget(covariant InteractiveSvgMuscleMap oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.controller != widget.controller) {
      oldWidget.controller?.removeListener(_handleController);
      widget.controller?.addListener(_handleController);
    }
    if (oldWidget.coverage != widget.coverage) {
      _previousCoverage = oldWidget.coverage;
      if (widget.reducedMotion) {
        _coverageController.value = 1;
      } else {
        _coverageController.forward(from: 0);
      }
    }
    if (widget.initialRegion != null &&
        widget.initialRegion != oldWidget.initialRegion) {
      _focusRegion(widget.initialRegion!);
    }
  }

  @override
  void dispose() {
    widget.controller?.removeListener(_handleController);
    _coverageController
      ..removeListener(_repaint)
      ..dispose();
    super.dispose();
  }

  void _repaint() {
    if (mounted) setState(() {});
  }

  void _handleController() {
    final controller = widget.controller;
    if (controller == null) return;
    setState(() {
      _view = controller.view;
      _selectedRegion = controller.selectedRegion;
    });
  }

  void _focusRegion(MuscleRegion region) {
    setState(() {
      _selectedRegion = region;
      _view =
          muscleRegionSvgMapping[region]?.preferredView ?? MuscleBodyView.front;
    });
  }

  void _showView(MuscleBodyView view) {
    if (_view == view) return;
    final controller = widget.controller;
    if (controller != null) {
      if (view == MuscleBodyView.front) {
        controller.showFront();
      } else {
        controller.showBack();
      }
      return;
    }
    setState(() {
      _view = view;
      _selectedRegion = null;
    });
  }

  void _handleDragStart(DragStartDetails details) {
    _dragDistance = 0;
  }

  void _handleDragUpdate(DragUpdateDetails details) {
    _dragDistance += details.delta.dx;
  }

  void _handleDragEnd(DragEndDetails details) {
    if (_dragDistance.abs() < 36) return;
    _showView(
      _view == MuscleBodyView.front
          ? MuscleBodyView.back
          : MuscleBodyView.front,
    );
  }

  void _handleTapUp(TapUpDetails details, Size size) {
    final region = SvgMuscleScene.layout(
      size,
      _view,
    ).hitTest(details.localPosition);
    if (region == null) return;
    setState(() => _selectedRegion = region);
    widget.onRegionSelected(region);
  }

  @override
  Widget build(BuildContext context) {
    final primaryColor = Theme.of(context).colorScheme.primary;
    final selected = _selectedRegion;
    final viewLabel = _view == MuscleBodyView.front ? '正面' : '背面';
    return Semantics(
      label: selected == null
          ? '训练覆盖人体图，当前$viewLabel，左右滑动切换正背面，点击肌群查看详情'
          : '${muscleRegionLabel(selected)}，'
                '${coverageLevelLabel(widget.coverage.region(selected).level)}，'
                '点击查看详情',
      child: RepaintBoundary(
        child: Column(
          children: [
            Expanded(
              child: LayoutBuilder(
                builder: (context, constraints) {
                  final size = Size(
                    constraints.maxWidth,
                    constraints.maxHeight,
                  );
                  return GestureDetector(
                    key: const Key('interactive-svg-muscle-map'),
                    behavior: HitTestBehavior.opaque,
                    onHorizontalDragStart: _handleDragStart,
                    onHorizontalDragUpdate: _handleDragUpdate,
                    onHorizontalDragEnd: _handleDragEnd,
                    onTapUp: (details) => _handleTapUp(details, size),
                    child: AnimatedSwitcher(
                      duration: widget.reducedMotion
                          ? Duration.zero
                          : const Duration(milliseconds: 240),
                      switchInCurve: Curves.easeOutCubic,
                      switchOutCurve: Curves.easeInCubic,
                      transitionBuilder: (child, animation) => FadeTransition(
                        opacity: animation,
                        child: ScaleTransition(
                          scale: Tween<double>(
                            begin: 0.965,
                            end: 1,
                          ).animate(animation),
                          child: child,
                        ),
                      ),
                      child: CustomPaint(
                        key: Key('svg-muscle-map-${_view.name}'),
                        painter: SvgMuscleMapPainter(
                          coverage: widget.coverage,
                          previousCoverage: _previousCoverage,
                          coverageProgress: _coverageController.value,
                          view: _view,
                          primaryColor: primaryColor,
                          selectedRegion: _selectedRegion,
                        ),
                        child: const SizedBox.expand(),
                      ),
                    ),
                  );
                },
              ),
            ),
            const SizedBox(height: 6),
            const Text(
              '左右滑动切换视角 · 点击肌群查看详情',
              textAlign: TextAlign.center,
              style: TextStyle(color: Color(0xFF7D8583), fontSize: 11),
            ),
          ],
        ),
      ),
    );
  }
}
