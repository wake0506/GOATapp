import 'package:flutter/material.dart';

import '../../analytics/models/weight_trend.dart';
import '../models/home_dashboard_view_model.dart';

class HomeMetricsRow extends StatelessWidget {
  const HomeMetricsRow({
    super.key,
    required this.viewModel,
    required this.onOpenWater,
    required this.onQuickAddWater,
    required this.onOpenWeight,
  });

  final HomeDashboardViewModel viewModel;
  final VoidCallback onOpenWater;
  final VoidCallback onQuickAddWater;
  final VoidCallback onOpenWeight;

  @override
  Widget build(BuildContext context) {
    final trend = viewModel.weightTrend;
    return Container(
      key: const Key('home-metrics-row'),
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
      child: LayoutBuilder(
        builder: (context, constraints) => Stack(
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: InkWell(
                    onTap: onOpenWater,
                    borderRadius: const BorderRadius.horizontal(
                      left: Radius.circular(20),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(16, 14, 12, 13),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Row(
                            children: [
                              Icon(
                                Icons.water_drop_outlined,
                                size: 17,
                                color: Color(0xFF2784C7),
                              ),
                              SizedBox(width: 6),
                              Text(
                                '饮水记录',
                                style: TextStyle(
                                  color: Color(0xFF3B4645),
                                  fontSize: 13,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 10),
                          Row(
                            children: [
                              Expanded(
                                child: FittedBox(
                                  fit: BoxFit.scaleDown,
                                  alignment: Alignment.centerLeft,
                                  child: Text.rich(
                                    TextSpan(
                                      text: viewModel.waterMl.toString(),
                                      style: const TextStyle(
                                        color: Color(0xFF1F2725),
                                        fontSize: 22,
                                        fontWeight: FontWeight.w700,
                                      ),
                                      children: [
                                        TextSpan(
                                          text:
                                              ' / ${viewModel.waterGoalMl} ml',
                                          style: const TextStyle(
                                            color: Color(0xFF69706F),
                                            fontSize: 11,
                                            fontWeight: FontWeight.w500,
                                          ),
                                        ),
                                      ],
                                    ),
                                    maxLines: 1,
                                    strutStyle: const StrutStyle(
                                      fontSize: 22,
                                      height: 1.15,
                                      forceStrutHeight: true,
                                    ),
                                  ),
                                ),
                              ),
                              _QuickWaterButton(onTap: onQuickAddWater),
                            ],
                          ),
                          const SizedBox(height: 4),
                          Text(
                            '达成 ${(viewModel.waterProgress * 100).round()}%',
                            style: const TextStyle(
                              color: Color(0xFF737B7A),
                              fontSize: 11,
                            ),
                          ),
                          const SizedBox(height: 8),
                          SizedBox(
                            height: 5,
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(8),
                              child: LinearProgressIndicator(
                                value: viewModel.waterProgress,
                                color: const Color(0xFF008C8C),
                                backgroundColor: const Color(0xFFE8ECEC),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                Expanded(
                  child: InkWell(
                    onTap: onOpenWeight,
                    borderRadius: const BorderRadius.horizontal(
                      right: Radius.circular(20),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(16, 14, 16, 13),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Row(
                            children: [
                              Icon(
                                Icons.monitor_weight_outlined,
                                size: 17,
                                color: Color(0xFFB27A26),
                              ),
                              SizedBox(width: 6),
                              Expanded(
                                child: Text(
                                  '体重记录',
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                    color: Color(0xFF3B4645),
                                    fontSize: 13,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 10),
                          Text.rich(
                            TextSpan(
                              text: viewModel.weight > 0
                                  ? viewModel.weight.toStringAsFixed(2)
                                  : '--',
                              style: const TextStyle(
                                color: Color(0xFF1F2725),
                                fontSize: 25,
                                fontWeight: FontWeight.w700,
                              ),
                              children: const [
                                TextSpan(
                                  text: ' kg',
                                  style: TextStyle(
                                    color: Color(0xFF69706F),
                                    fontSize: 12,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ],
                            ),
                            strutStyle: const StrutStyle(
                              fontSize: 25,
                              height: 1.15,
                              forceStrutHeight: true,
                            ),
                          ),
                          const SizedBox(height: 8),
                          _WeightTrend(
                            trend: trend,
                            fallbackDelta: viewModel.weightDelta,
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
            Positioned(
              left: constraints.maxWidth / 2,
              top: 14,
              bottom: 13,
              child: const ColoredBox(
                color: Color(0xFFEDF0F0),
                child: SizedBox(width: 1),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _QuickWaterButton extends StatelessWidget {
  const _QuickWaterButton({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => InkWell(
    onTap: onTap,
    borderRadius: BorderRadius.circular(16),
    child: Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 7),
      decoration: BoxDecoration(
        color: const Color(0xFFF1F6F5),
        borderRadius: BorderRadius.circular(16),
      ),
      child: const Text(
        '+250ml',
        style: TextStyle(
          color: Color(0xFF287A6B),
          fontSize: 11,
          fontWeight: FontWeight.w600,
        ),
      ),
    ),
  );
}

class _WeightTrend extends StatelessWidget {
  const _WeightTrend({required this.trend, this.fallbackDelta});

  final WeightTrend? trend;
  final double? fallbackDelta;

  @override
  Widget build(BuildContext context) {
    final value = trend;
    if (value == null) {
      final delta = fallbackDelta;
      if (delta != null) {
        if (delta.abs() < 0.005) {
          return const Text(
            '— 持平',
            style: TextStyle(color: Color(0xFF788180), fontSize: 11),
          );
        }
        final down = delta < 0;
        return Text(
          '${down ? '↓' : '↑'} ${delta.abs().toStringAsFixed(2)} kg',
          style: TextStyle(
            color: down ? const Color(0xFFC96A62) : const Color(0xFF3F8778),
            fontSize: 11,
            fontWeight: FontWeight.w500,
          ),
        );
      }
      return const Text(
        '暂无趋势数据',
        style: TextStyle(color: Color(0xFF899291), fontSize: 11),
      );
    }
    if (value.sevenDayAverageKg == null) {
      return const Text(
        '暂无趋势数据',
        style: TextStyle(color: Color(0xFF899291), fontSize: 11),
      );
    }
    final change = value.change7dKg;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '趋势 ${value.sevenDayAverageKg!.toStringAsFixed(2)} kg',
          style: const TextStyle(
            color: Color(0xFF596361),
            fontSize: 11,
            fontWeight: FontWeight.w500,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          change == null
              ? value.readingCount == 1
                    ? '数据仍不足'
                    : '数据积累中'
              : '近7天 ${change > 0 ? '+' : ''}${change.toStringAsFixed(2)} kg',
          style: const TextStyle(color: Color(0xFF899291), fontSize: 10),
        ),
      ],
    );
  }
}
