import 'package:flutter/material.dart';

import '../models/weight_trend.dart';

class WeightTrendSummary extends StatelessWidget {
  const WeightTrendSummary({super.key, required this.trend});

  final WeightTrend trend;

  @override
  Widget build(BuildContext context) => Container(
    key: const Key('weight-trend-summary'),
    padding: const EdgeInsets.all(14),
    decoration: BoxDecoration(
      color: const Color(0xFFF4F7F6),
      borderRadius: BorderRadius.circular(14),
    ),
    child: Column(
      children: [
        Row(
          children: [
            _TrendMetric(
              label: '当前',
              value: _weight(trend.latestMeasuredWeightKg),
            ),
            _TrendMetric(label: '趋势', value: _weight(trend.sevenDayAverageKg)),
            _TrendMetric(label: '7天变化', value: _change(trend.change7dKg)),
            _TrendMetric(label: '14天变化', value: _change(trend.change14dKg)),
          ],
        ),
        const SizedBox(height: 8),
        Align(
          alignment: Alignment.centerLeft,
          child: Text(
            _qualityLabel(trend.dataQuality),
            key: const Key('weight-trend-quality'),
            style: const TextStyle(color: Color(0xFF858D8B), fontSize: 10),
          ),
        ),
      ],
    ),
  );

  String _weight(double? value) =>
      value == null ? '--' : '${value.toStringAsFixed(2)} kg';

  String _change(double? value) => value == null
      ? '--'
      : '${value > 0 ? '+' : ''}${value.toStringAsFixed(2)} kg';

  String _qualityLabel(WeightTrendDataQuality quality) => switch (quality) {
    WeightTrendDataQuality.unavailable => '暂无趋势数据',
    WeightTrendDataQuality.singleReading => '单次记录，数据仍不足',
    WeightTrendDataQuality.partial => '数据积累中',
    WeightTrendDataQuality.complete => '基于完整 7 日记录',
  };
}

class _TrendMetric extends StatelessWidget {
  const _TrendMetric({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) => Expanded(
    child: Column(
      children: [
        Text(
          value,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: 3),
        Text(
          label,
          style: const TextStyle(color: Color(0xFF7D8583), fontSize: 9),
        ),
      ],
    ),
  );
}
