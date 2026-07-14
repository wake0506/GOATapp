import 'package:flutter/material.dart';

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
    final trend = viewModel.weightDelta;
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
      child: IntrinsicHeight(
        child: Row(
          children: [
            Expanded(
              child: InkWell(
                onTap: onOpenWater,
                borderRadius: const BorderRadius.horizontal(
                  left: Radius.circular(20),
                ),
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 17, 12, 16),
                  child: Column(
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
                      const SizedBox(height: 13),
                      Row(
                        children: [
                          Expanded(
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
                                    text: ' / ${viewModel.waterGoalMl} ml',
                                    style: const TextStyle(
                                      color: Color(0xFF69706F),
                                      fontSize: 11,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                          _QuickWaterButton(onTap: onQuickAddWater),
                        ],
                      ),
                      const SizedBox(height: 6),
                      Text(
                        '达成 ${(viewModel.waterProgress * 100).round()}%',
                        style: const TextStyle(
                          color: Color(0xFF737B7A),
                          fontSize: 11,
                        ),
                      ),
                      const SizedBox(height: 10),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(8),
                        child: LinearProgressIndicator(
                          value: viewModel.waterProgress,
                          minHeight: 5,
                          color: const Color(0xFF008C8C),
                          backgroundColor: const Color(0xFFE8ECEC),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            const VerticalDivider(
              width: 1,
              thickness: 1,
              color: Color(0xFFEDF0F0),
            ),
            Expanded(
              child: InkWell(
                onTap: onOpenWeight,
                borderRadius: const BorderRadius.horizontal(
                  right: Radius.circular(20),
                ),
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 17, 16, 16),
                  child: Column(
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
                      const SizedBox(height: 13),
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
                      ),
                      const SizedBox(height: 10),
                      _WeightTrend(delta: trend),
                    ],
                  ),
                ),
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
  const _WeightTrend({required this.delta});

  final double? delta;

  @override
  Widget build(BuildContext context) {
    final value = delta;
    if (value == null) {
      return const Text(
        '暂无趋势',
        style: TextStyle(color: Color(0xFF899291), fontSize: 11),
      );
    }
    if (value.abs() < 0.005) {
      return const Text(
        '— 持平',
        style: TextStyle(color: Color(0xFF788180), fontSize: 11),
      );
    }
    final down = value < 0;
    return Text(
      '${down ? '↓' : '↑'} ${value.abs().toStringAsFixed(2)} kg',
      style: TextStyle(
        color: down ? const Color(0xFFC96A62) : const Color(0xFF3F8778),
        fontSize: 11,
        fontWeight: FontWeight.w500,
      ),
    );
  }
}
