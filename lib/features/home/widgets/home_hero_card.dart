import 'package:flutter/material.dart';

import '../models/home_dashboard_view_model.dart';
import 'macro_half_ring.dart';

class HomeHeroCard extends StatelessWidget {
  const HomeHeroCard({
    super.key,
    required this.viewModel,
    required this.onEditTarget,
  });

  final HomeDashboardViewModel viewModel;
  final VoidCallback onEditTarget;

  @override
  Widget build(BuildContext context) {
    return Container(
      key: const Key('home-hero-card'),
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
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: _Metric(
                  label: '摄入',
                  value: viewModel.stats.kcalIn.toInt(),
                ),
              ),
              const Padding(
                padding: EdgeInsets.only(top: 29),
                child: Text(
                  '−',
                  style: TextStyle(color: Color(0xFF8B9291), fontSize: 23),
                ),
              ),
              Expanded(
                child: _Metric(
                  label: '消耗',
                  value: viewModel.stats.burn.toInt(),
                ),
              ),
              const Padding(
                padding: EdgeInsets.only(top: 29),
                child: Text(
                  '=',
                  style: TextStyle(color: Color(0xFF8B9291), fontSize: 21),
                ),
              ),
              Expanded(flex: 2, child: _NetMetric(value: viewModel.netKcal)),
              IconButton(
                tooltip: '编辑今日目标',
                onPressed: onEditTarget,
                visualDensity: VisualDensity.compact,
                icon: const Icon(
                  Icons.tune_rounded,
                  color: Color(0xFF008C8C),
                  size: 20,
                ),
              ),
            ],
          ),
          Align(
            alignment: Alignment.centerRight,
            child: Text(
              '目标 ${viewModel.targetKcal.toInt()} kcal',
              style: const TextStyle(
                color: Color(0xFF9AA1A3),
                fontSize: 11,
                fontWeight: FontWeight.w400,
              ),
            ),
          ),
          const SizedBox(height: 12),
          const Divider(height: 1, color: Color(0xFFECF0F0)),
          const SizedBox(height: 17),
          Row(
            children: [
              Expanded(
                child: MacroHalfRing(
                  label: 'PRO',
                  current: viewModel.stats.p,
                  target: viewModel.targetProtein,
                  color: const Color(0xFF278764),
                ),
              ),
              Expanded(
                child: MacroHalfRing(
                  label: 'CHO',
                  current: viewModel.stats.c,
                  target: viewModel.targetCarbs,
                  color: const Color(0xFF2584D8),
                ),
              ),
              Expanded(
                child: MacroHalfRing(
                  label: 'FAT',
                  current: viewModel.stats.f,
                  target: viewModel.targetFat,
                  color: const Color(0xFFF2A13F),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _Metric extends StatelessWidget {
  const _Metric({required this.label, required this.value});

  final String label;
  final int value;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.center,
    children: [
      Text(
        label,
        style: const TextStyle(
          color: Color(0xFF69706F),
          fontSize: 11,
          fontWeight: FontWeight.w400,
        ),
      ),
      const SizedBox(height: 6),
      Text(
        value.toString(),
        style: const TextStyle(
          color: Color(0xFF1F2725),
          fontSize: 25,
          fontWeight: FontWeight.w600,
        ),
      ),
      const Text(
        'kcal',
        style: TextStyle(color: Color(0xFF8C9493), fontSize: 10),
      ),
    ],
  );
}

class _NetMetric extends StatelessWidget {
  const _NetMetric({required this.value});

  final double value;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.center,
    children: [
      const Text(
        '净摄入',
        style: TextStyle(
          color: Color(0xFF246C5D),
          fontSize: 11,
          fontWeight: FontWeight.w500,
        ),
      ),
      const SizedBox(height: 3),
      FittedBox(
        child: Text(
          value.toInt().toString(),
          style: const TextStyle(
            color: Color(0xFF006B59),
            fontSize: 37,
            height: 1,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
      const Text(
        'kcal',
        style: TextStyle(color: Color(0xFF4E8585), fontSize: 11),
      ),
    ],
  );
}
