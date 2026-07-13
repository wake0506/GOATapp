import 'package:flutter/material.dart';

class DashboardQuickActions extends StatelessWidget {
  final VoidCallback onDiet;
  final VoidCallback onWater;
  final VoidCallback onExercise;
  final VoidCallback onWeight;

  const DashboardQuickActions({
    super.key,
    required this.onDiet,
    required this.onWater,
    required this.onExercise,
    required this.onWeight,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          '快捷记录',
          style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: 10),
        LayoutBuilder(
          builder: (context, constraints) {
            final width = (constraints.maxWidth - 10) / 2;
            return Wrap(
              spacing: 10,
              runSpacing: 10,
              children: [
                _Action(
                  label: '记录饮食',
                  icon: Icons.restaurant_outlined,
                  onTap: onDiet,
                  width: width,
                ),
                _Action(
                  label: '记录饮水',
                  icon: Icons.water_drop_outlined,
                  onTap: onWater,
                  width: width,
                ),
                _Action(
                  label: '记录运动',
                  icon: Icons.directions_run_outlined,
                  onTap: onExercise,
                  width: width,
                ),
                _Action(
                  label: '记录体重',
                  icon: Icons.monitor_weight_outlined,
                  onTap: onWeight,
                  width: width,
                ),
              ],
            );
          },
        ),
      ],
    );
  }
}

class _Action extends StatelessWidget {
  final String label;
  final IconData icon;
  final VoidCallback onTap;
  final double width;

  const _Action({
    required this.label,
    required this.icon,
    required this.onTap,
    required this.width,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: width,
      child: Semantics(
        button: true,
        label: label,
        child: Material(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
          child: InkWell(
            onTap: onTap,
            borderRadius: BorderRadius.circular(14),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
              child: Row(
                children: [
                  Icon(icon, size: 19, color: const Color(0xFF008C8C)),
                  const SizedBox(width: 8),
                  Flexible(
                    child: Text(
                      label,
                      style: const TextStyle(
                        fontSize: 13,
                        color: Colors.black87,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
