import 'package:flutter/material.dart';

import 'dashboard_data.dart';

class MacroProgressSection extends StatelessWidget {
  final List<DashboardMacro> macros;

  const MacroProgressSection({super.key, required this.macros});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(18, 16, 18, 18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
      ),
      child: LayoutBuilder(
        builder: (context, constraints) => Row(
          children: macros
              .map(
                (macro) => Expanded(
                  child: Padding(
                    padding: EdgeInsets.only(
                      right: macro == macros.last
                          ? 0
                          : constraints.maxWidth * 0.035,
                    ),
                    child: _MacroTile(macro: macro),
                  ),
                ),
              )
              .toList(),
        ),
      ),
    );
  }
}

class _MacroTile extends StatelessWidget {
  final DashboardMacro macro;

  const _MacroTile({required this.macro});

  @override
  Widget build(BuildContext context) {
    final progress = macro.target > 0
        ? (macro.current / macro.target).clamp(0.0, 1.0)
        : 0.0;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          macro.label,
          style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: 5),
        Text(
          '${macro.current.toStringAsFixed(0)} / ${macro.target.toStringAsFixed(0)} g',
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(fontSize: 11, color: Colors.black54),
        ),
        const SizedBox(height: 8),
        ClipRRect(
          borderRadius: BorderRadius.circular(4),
          child: LinearProgressIndicator(
            value: progress,
            minHeight: 6,
            backgroundColor: const Color(0xFFE9EEED),
            valueColor: const AlwaysStoppedAnimation<Color>(Color(0xFF008C8C)),
          ),
        ),
      ],
    );
  }
}
