import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../models/exercise_metadata.dart';
import '../models/muscle_region_3d_mapping.dart';
import '../models/training_coverage.dart';
import '../painters/muscle_map_3d_painter.dart';

/// Legacy Stage 2E renderer retained only for rollback safety.
class MuscleMap3DController extends ChangeNotifier {
  double _targetYaw = 0;
  MuscleRegion? _selectedRegion;

  double get targetYaw => _targetYaw;
  MuscleRegion? get selectedRegion => _selectedRegion;

  void showFront() => _moveTo(0, null);

  void showBack() => _moveTo(math.pi, null);

  void showLeftSide() => _moveTo(-math.pi / 2, null);

  void showRightSide() => _moveTo(math.pi / 2, null);

  void focusRegion(MuscleRegion region) =>
      _moveTo(muscleRegion3DMapping[region]?.preferredYaw ?? 0, region);

  void _moveTo(double yaw, MuscleRegion? region) {
    _targetYaw = yaw;
    _selectedRegion = region;
    notifyListeners();
  }
}

/// Legacy Stage 2E renderer retained only for rollback safety.
class InteractiveMuscleMap3D extends StatefulWidget {
  const InteractiveMuscleMap3D({
    super.key,
    required this.coverage,
    required this.onRegionSelected,
    this.controller,
    this.initialRegion,
    this.reducedMotion = false,
  });

  final TrainingCoverageResult coverage;
  final ValueChanged<MuscleRegion> onRegionSelected;
  final MuscleMap3DController? controller;
  final MuscleRegion? initialRegion;
  final bool reducedMotion;

  @override
  State<InteractiveMuscleMap3D> createState() => _InteractiveMuscleMap3DState();
}

class _InteractiveMuscleMap3DState extends State<InteractiveMuscleMap3D>
    with SingleTickerProviderStateMixin {
  late final AnimationController _animationController;
  Animation<double>? _yawAnimation;
  late double _yaw;
  MuscleRegion? _selectedRegion;

  @override
  void initState() {
    super.initState();
    _selectedRegion = widget.initialRegion;
    _yaw = widget.initialRegion == null
        ? 0
        : muscleRegion3DMapping[widget.initialRegion]?.preferredYaw ?? 0;
    _animationController =
        AnimationController(
          vsync: this,
          duration: const Duration(milliseconds: 380),
        )..addListener(() {
          final animation = _yawAnimation;
          if (animation != null && mounted) {
            setState(() => _yaw = animation.value);
          }
        });
    widget.controller?.addListener(_handleController);
  }

  @override
  void didUpdateWidget(covariant InteractiveMuscleMap3D oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.controller != widget.controller) {
      oldWidget.controller?.removeListener(_handleController);
      widget.controller?.addListener(_handleController);
    }
    if (widget.initialRegion != null &&
        widget.initialRegion != oldWidget.initialRegion) {
      _focusRegion(widget.initialRegion!);
    }
  }

  @override
  void dispose() {
    widget.controller?.removeListener(_handleController);
    _animationController.dispose();
    super.dispose();
  }

  void _handleController() {
    final controller = widget.controller;
    if (controller == null) return;
    _selectedRegion = controller.selectedRegion;
    _animateTo(controller.targetYaw);
  }

  void _focusRegion(MuscleRegion region) {
    _selectedRegion = region;
    _animateTo(muscleRegion3DMapping[region]?.preferredYaw ?? 0);
  }

  void _animateTo(double target) {
    final normalizedTarget = _nearestEquivalent(target, _yaw);
    if (widget.reducedMotion) {
      _animationController.stop();
      setState(() => _yaw = normalizedTarget);
      return;
    }
    _yawAnimation = Tween<double>(begin: _yaw, end: normalizedTarget).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeOutCubic),
    );
    _animationController.forward(from: 0);
  }

  void _handleDragStart(DragStartDetails details) {
    _animationController.stop();
    _yawAnimation = null;
  }

  void _handleDragUpdate(DragUpdateDetails details) {
    setState(() {
      _selectedRegion = null;
      _yaw = _normalize(_yaw + details.delta.dx * 0.012);
    });
  }

  void _handleTapUp(TapUpDetails details, Size size) {
    final region = MuscleMap3DScene.layout(
      size,
      _yaw,
    ).hitTest(details.localPosition);
    if (region == null) return;
    setState(() => _selectedRegion = region);
    widget.onRegionSelected(region);
  }

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) {
      final size = Size(constraints.maxWidth, constraints.maxHeight);
      final viewLabel = _viewLabel(_yaw);
      final selected = _selectedRegion;
      return Semantics(
        label: selected == null
            ? '交互式训练覆盖人体模型，当前$viewLabel，左右拖动旋转，点击肌群查看详情'
            : '${muscleRegionLabel(selected)}，${coverageLevelLabel(widget.coverage.region(selected).level)}，点击查看详情',
        child: RepaintBoundary(
          child: GestureDetector(
            key: const Key('interactive-muscle-map-3d'),
            behavior: HitTestBehavior.opaque,
            onHorizontalDragStart: _handleDragStart,
            onHorizontalDragUpdate: _handleDragUpdate,
            onTapUp: (details) => _handleTapUp(details, size),
            child: Stack(
              fit: StackFit.expand,
              children: [
                CustomPaint(
                  key: const Key('muscle-map-3d-painter'),
                  painter: MuscleMap3DPainter(
                    coverage: widget.coverage,
                    yaw: _yaw,
                    selectedRegion: _selectedRegion,
                  ),
                ),
                Positioned(
                  top: 12,
                  left: 12,
                  child: _ViewBadge(label: viewLabel),
                ),
                const Positioned(
                  left: 0,
                  right: 0,
                  bottom: 8,
                  child: Text(
                    '左右拖动旋转 · 点击肌群查看详情',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: Color(0xFF7D8583), fontSize: 11),
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    },
  );
}

class _ViewBadge extends StatelessWidget {
  const _ViewBadge({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
    decoration: BoxDecoration(
      color: Colors.white.withValues(alpha: 0.86),
      borderRadius: BorderRadius.circular(99),
      border: Border.all(color: const Color(0x1F47635D)),
    ),
    child: Text(
      label,
      style: const TextStyle(
        color: Color(0xFF52605D),
        fontSize: 11,
        fontWeight: FontWeight.w600,
      ),
    ),
  );
}

double _normalize(double angle) {
  var value = angle % (math.pi * 2);
  if (value > math.pi) value -= math.pi * 2;
  if (value < -math.pi) value += math.pi * 2;
  return value;
}

double _nearestEquivalent(double target, double current) {
  final normalized = _normalize(target);
  final candidates = [
    normalized - math.pi * 2,
    normalized,
    normalized + math.pi * 2,
  ];
  candidates.sort(
    (left, right) => (left - current).abs().compareTo((right - current).abs()),
  );
  return candidates.first;
}

String _viewLabel(double yaw) {
  final normalized = _normalize(yaw);
  final absolute = normalized.abs();
  if (absolute <= math.pi / 4) return '正面';
  if (absolute >= math.pi * 3 / 4) return '背面';
  return normalized < 0 ? '左侧' : '右侧';
}
