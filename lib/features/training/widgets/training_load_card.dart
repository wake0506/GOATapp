import 'package:flutter/material.dart';

import '../models/training_page_view_model.dart';
import '../painters/muscle_load_chart_painter.dart';

class TrainingLoadCard extends StatelessWidget {
  const TrainingLoadCard({
    super.key,
    required this.loads,
    this.legacyInferredSets = 0,
  });

  final List<MuscleLoad> loads;
  final int legacyInferredSets;

  @override
  Widget build(BuildContext context) {
    final hasLoad = loads.any((load) => load.value > 0);
    return Container(
      key: const Key('training-load-card'),
      decoration: _cardDecoration,
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Expanded(
                child: Text(
                  '近 7 天有效训练',
                  style: TextStyle(
                    color: Color(0xFF1F2725),
                    fontSize: 19,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              IconButton(
                key: const Key('effective-sets-info'),
                tooltip: '什么是有效组',
                onPressed: () => _showExplanation(context),
                visualDensity: VisualDensity.compact,
                icon: const Icon(
                  Icons.info_outline_rounded,
                  color: Color(0xFF008C8C),
                  size: 21,
                ),
              ),
            ],
          ),
          const Text(
            '已完成的非热身训练组',
            style: TextStyle(
              color: Color(0xFF899092),
              fontSize: 13,
              fontWeight: FontWeight.w400,
            ),
          ),
          const SizedBox(height: 14),
          if (hasLoad)
            LayoutBuilder(
              builder: (context, constraints) => SizedBox(
                width: constraints.maxWidth,
                height: loads.length * 31.0,
                child: CustomPaint(painter: MuscleLoadChartPainter(loads)),
              ),
            )
          else
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 14),
              child: Text(
                '最近 7 天暂无足够训练数据',
                style: TextStyle(
                  color: Color(0xFF91999B),
                  fontSize: 13,
                  fontWeight: FontWeight.w400,
                ),
              ),
            ),
          if (legacyInferredSets > 0)
            const Padding(
              padding: EdgeInsets.only(top: 7),
              child: Text(
                '包含部分历史训练记录',
                style: TextStyle(color: Color(0xFF91999B), fontSize: 11),
              ),
            ),
        ],
      ),
    );
  }

  Future<void> _showExplanation(
    BuildContext context,
  ) => showModalBottomSheet<void>(
    context: context,
    backgroundColor: Colors.white,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
    ),
    builder: (_) => const SafeArea(
      child: Padding(
        padding: EdgeInsets.fromLTRB(20, 18, 20, 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '有效训练组',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700),
            ),
            SizedBox(height: 10),
            Text(
              '有效组不包含热身组。目前 GOAT V1 将已完成且次数大于 0 的非热身训练组计为有效组。超级组、递减组、AMRAP 和力竭组均按实际完成的单组计数。',
              style: TextStyle(fontSize: 14, height: 1.45),
            ),
          ],
        ),
      ),
    ),
  );

  static const _cardDecoration = BoxDecoration(
    color: Colors.white,
    borderRadius: BorderRadius.all(Radius.circular(20)),
    boxShadow: [
      BoxShadow(color: Color(0x0D17211E), blurRadius: 14, offset: Offset(0, 5)),
    ],
  );
}
