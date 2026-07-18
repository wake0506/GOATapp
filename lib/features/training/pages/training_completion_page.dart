import 'package:flutter/material.dart';

import '../../../models/training.dart';

class TrainingCompletionPage extends StatelessWidget {
  const TrainingCompletionPage({
    super.key,
    required this.session,
    required this.durationMinutes,
    required this.onDone,
  });

  final TrainingSession session;
  final int durationMinutes;
  final VoidCallback onDone;

  @override
  Widget build(BuildContext context) {
    final sets = session.exercises.fold<int>(
      0,
      (sum, exercise) =>
          sum + exercise.sets.where((set) => set.completedAt != null).length,
    );
    return Scaffold(
      backgroundColor: const Color(0xFFF4F5F7),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 48, 24, 28),
          child: Column(
            children: [
              const Spacer(),
              Container(
                width: 112,
                height: 112,
                alignment: Alignment.center,
                decoration: const BoxDecoration(
                  color: Color(0xFF008C8C),
                  shape: BoxShape.circle,
                ),
                child: const Text(
                  'GOAL',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 26,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 1.5,
                  ),
                ),
              ),
              const SizedBox(height: 30),
              const Text(
                '今日训练已完成',
                style: TextStyle(
                  color: Color(0xFF1F2725),
                  fontSize: 26,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 10),
              Text(
                session.name,
                style: const TextStyle(color: Color(0xFF7D8583), fontSize: 15),
              ),
              const SizedBox(height: 34),
              Container(
                padding: const EdgeInsets.symmetric(vertical: 20),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Row(
                  children: [
                    _Fact(label: '训练时长', value: '$durationMinutes 分钟'),
                    const SizedBox(
                      height: 42,
                      child: VerticalDivider(width: 1),
                    ),
                    _Fact(label: '完成组数', value: '$sets 组'),
                    const SizedBox(
                      height: 42,
                      child: VerticalDivider(width: 1),
                    ),
                    _Fact(
                      label: '训练容量',
                      value: '${session.sessionVolume.toStringAsFixed(0)} kg',
                    ),
                  ],
                ),
              ),
              const Spacer(),
              SizedBox(
                width: double.infinity,
                height: 54,
                child: FilledButton(
                  key: const Key('training-completion-done'),
                  onPressed: onDone,
                  style: FilledButton.styleFrom(
                    backgroundColor: const Color(0xFF008C8C),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),
                  child: const Text(
                    '完成',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Fact extends StatelessWidget {
  const _Fact({required this.label, required this.value});
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) => Expanded(
    child: Column(
      children: [
        Text(
          value,
          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 5),
        Text(
          label,
          style: const TextStyle(color: Color(0xFF8A9290), fontSize: 12),
        ),
      ],
    ),
  );
}
