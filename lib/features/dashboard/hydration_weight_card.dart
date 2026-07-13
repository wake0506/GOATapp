import 'package:flutter/material.dart';

class HydrationWeightCard extends StatelessWidget {
  final int waterMl;
  final int waterGoalMl;
  final double weightKg;
  final VoidCallback onOpenWater;
  final VoidCallback onOpenWeight;

  const HydrationWeightCard({
    super.key,
    required this.waterMl,
    required this.waterGoalMl,
    required this.weightKg,
    required this.onOpenWater,
    required this.onOpenWeight,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: _DataTile(
            label: '饮水',
            value: '$waterMl / $waterGoalMl ml',
            icon: Icons.water_drop_outlined,
            color: Colors.blueAccent,
            onTap: onOpenWater,
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: _DataTile(
            label: '体重',
            value: '${weightKg.toStringAsFixed(2)} kg',
            icon: Icons.monitor_weight_outlined,
            color: Colors.orangeAccent,
            onTap: onOpenWeight,
          ),
        ),
      ],
    );
  }
}

class _DataTile extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;
  final Color color;
  final VoidCallback onTap;

  const _DataTile({
    required this.label,
    required this.value,
    required this.icon,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: '$label$value',
      child: Material(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(16),
          child: Padding(
            padding: const EdgeInsets.all(13),
            child: Row(
              children: [
                Icon(icon, color: color, size: 20),
                const SizedBox(width: 9),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        label,
                        style: const TextStyle(
                          fontSize: 11,
                          color: Colors.black45,
                        ),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        value,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
