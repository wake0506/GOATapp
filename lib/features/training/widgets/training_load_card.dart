import 'package:flutter/material.dart';

import '../models/training_page_view_model.dart';
import '../painters/muscle_load_chart_painter.dart';

class TrainingLoadCard extends StatelessWidget {
  const TrainingLoadCard({super.key, required this.loads});

  final List<MuscleLoad> loads;

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
          const Row(
            children: [
              Expanded(
                child: Text(
                  '肌群训练负荷',
                  style: TextStyle(
                    color: Color(0xFF1F2725),
                    fontSize: 19,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              Icon(
                Icons.info_outline_rounded,
                color: Color(0xFF416F64),
                size: 21,
              ),
            ],
          ),
          const SizedBox(height: 3),
          const Text(
            '近 7 天',
            style: TextStyle(
              color: Color(0xFF899092),
              fontSize: 13,
              fontWeight: FontWeight.w400,
            ),
          ),
          const SizedBox(height: 14),
          LayoutBuilder(
            builder: (context, constraints) => SizedBox(
              width: constraints.maxWidth,
              height: 160,
              child: CustomPaint(painter: MuscleLoadChartPainter(loads)),
            ),
          ),
          if (!hasLoad)
            const Padding(
              padding: EdgeInsets.only(top: 5),
              child: Text(
                '最近 7 天暂无足够训练数据',
                style: TextStyle(
                  color: Color(0xFF91999B),
                  fontSize: 13,
                  fontWeight: FontWeight.w400,
                ),
              ),
            ),
        ],
      ),
    );
  }

  static const _cardDecoration = BoxDecoration(
    color: Colors.white,
    borderRadius: BorderRadius.all(Radius.circular(20)),
    boxShadow: [
      BoxShadow(color: Color(0x0D17211E), blurRadius: 14, offset: Offset(0, 5)),
    ],
  );
}
