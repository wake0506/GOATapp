import 'package:flutter/material.dart';

class TrainingSetInputCard extends StatelessWidget {
  const TrainingSetInputCard({
    super.key,
    required this.weight,
    required this.reps,
    required this.onWeightDecrease,
    required this.onWeightIncrease,
    required this.onWeightTap,
    required this.onRepsDecrease,
    required this.onRepsIncrease,
    required this.onRepsTap,
  });

  final double weight;
  final int reps;
  final VoidCallback onWeightDecrease;
  final VoidCallback onWeightIncrease;
  final VoidCallback onWeightTap;
  final VoidCallback onRepsDecrease;
  final VoidCallback onRepsIncrease;
  final VoidCallback onRepsTap;

  @override
  Widget build(BuildContext context) {
    return Container(
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
          _ValueStepper(
            label: '重量',
            value: '${weight.toStringAsFixed(1)} kg',
            decreaseKey: const Key('training-weight-decrease'),
            increaseKey: const Key('training-weight-increase'),
            onDecrease: onWeightDecrease,
            onIncrease: onWeightIncrease,
            onValueTap: onWeightTap,
          ),
          const Divider(height: 32, color: Color(0xFFF0F1F2)),
          _ValueStepper(
            label: '次数',
            value: '$reps',
            decreaseKey: const Key('training-reps-decrease'),
            increaseKey: const Key('training-reps-increase'),
            onDecrease: onRepsDecrease,
            onIncrease: onRepsIncrease,
            onValueTap: onRepsTap,
          ),
        ],
      ),
    );
  }
}

class _ValueStepper extends StatelessWidget {
  const _ValueStepper({
    required this.label,
    required this.value,
    required this.decreaseKey,
    required this.increaseKey,
    required this.onDecrease,
    required this.onIncrease,
    required this.onValueTap,
  });

  final String label;
  final String value;
  final Key decreaseKey;
  final Key increaseKey;
  final VoidCallback onDecrease;
  final VoidCallback onIncrease;
  final VoidCallback onValueTap;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        SizedBox(
          width: 48,
          child: Text(
            label,
            style: const TextStyle(color: Color(0xFF737B79), fontSize: 14),
          ),
        ),
        _StepButton(key: decreaseKey, icon: Icons.remove, onTap: onDecrease),
        Expanded(
          child: InkWell(
            onTap: onValueTap,
            borderRadius: BorderRadius.circular(12),
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 10),
              child: Text(
                value,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: Color(0xFF1F2725),
                  fontSize: 24,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ),
        ),
        _StepButton(key: increaseKey, icon: Icons.add, onTap: onIncrease),
      ],
    );
  }
}

class _StepButton extends StatelessWidget {
  const _StepButton({super.key, required this.icon, required this.onTap});

  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Material(
    color: const Color(0xFFF4F5F7),
    borderRadius: BorderRadius.circular(12),
    child: InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: SizedBox(
        width: 46,
        height: 46,
        child: Icon(icon, size: 22, color: const Color(0xFF1F2725)),
      ),
    ),
  );
}
