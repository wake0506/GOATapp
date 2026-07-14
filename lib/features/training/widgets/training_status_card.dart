import 'package:flutter/material.dart';

import '../models/training_page_view_model.dart';

class TrainingStatusCard extends StatelessWidget {
  const TrainingStatusCard({super.key, required this.status});

  final TrainingStatusSummary status;

  @override
  Widget build(BuildContext context) => Container(
    key: const Key('training-status-card'),
    padding: const EdgeInsets.all(20),
    decoration: BoxDecoration(
      gradient: const LinearGradient(
        begin: Alignment.centerLeft,
        end: Alignment.centerRight,
        colors: [Color(0xFF008C8C), Color(0xFF007777), Color(0xFF006363)],
      ),
      borderRadius: BorderRadius.circular(20),
      boxShadow: const [
        BoxShadow(
          color: Color(0x26008C8C),
          blurRadius: 18,
          offset: Offset(0, 8),
        ),
      ],
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'TRAINING STATUS  /  今日训练看板',
          style: TextStyle(
            color: Color(0xD9FFFFFF),
            fontSize: 11,
            fontWeight: FontWeight.w600,
            letterSpacing: 1.3,
          ),
        ),
        const SizedBox(height: 22),
        Row(
          children: [
            Expanded(flex: 13, child: _MainMetric(volume: status.volume)),
            const _Divider(),
            Expanded(
              flex: 9,
              child: _SmallMetric(
                label: '训练时长',
                value: '${status.durationMinutes}',
                unit: 'min',
              ),
            ),
            const _Divider(),
            Expanded(
              flex: 8,
              child: _SmallMetric(
                label: '完成组数',
                value: '${status.completedSets}',
                unit: '组',
              ),
            ),
          ],
        ),
      ],
    ),
  );
}

class _MainMetric extends StatelessWidget {
  const _MainMetric({required this.volume});

  final double volume;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      const Text(
        '总容量',
        style: TextStyle(color: Color(0xBFFFFFFF), fontSize: 12),
      ),
      const SizedBox(height: 7),
      FittedBox(
        fit: BoxFit.scaleDown,
        alignment: Alignment.centerLeft,
        child: RichText(
          text: TextSpan(
            children: [
              TextSpan(
                text: volume.round().toString(),
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 46,
                  height: 0.9,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const TextSpan(
                text: ' kg',
                style: TextStyle(
                  color: Color(0xD9FFFFFF),
                  fontSize: 17,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ),
    ],
  );
}

class _SmallMetric extends StatelessWidget {
  const _SmallMetric({
    required this.label,
    required this.value,
    required this.unit,
  });

  final String label;
  final String value;
  final String unit;

  @override
  Widget build(BuildContext context) => Column(
    children: [
      Text(
        label,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: const TextStyle(color: Color(0xBFFFFFFF), fontSize: 11),
      ),
      const SizedBox(height: 9),
      FittedBox(
        child: RichText(
          text: TextSpan(
            children: [
              TextSpan(
                text: value,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 31,
                  fontWeight: FontWeight.w700,
                ),
              ),
              TextSpan(
                text: ' $unit',
                style: const TextStyle(color: Color(0xD9FFFFFF), fontSize: 12),
              ),
            ],
          ),
        ),
      ),
    ],
  );
}

class _Divider extends StatelessWidget {
  const _Divider();

  @override
  Widget build(BuildContext context) => Container(
    width: 1,
    height: 56,
    margin: const EdgeInsets.symmetric(horizontal: 9),
    color: const Color(0x3DFFFFFF),
  );
}
