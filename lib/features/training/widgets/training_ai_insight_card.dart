import 'package:flutter/material.dart';

class TrainingAiInsightCard extends StatefulWidget {
  const TrainingAiInsightCard({super.key, this.insight});

  final String? insight;

  @override
  State<TrainingAiInsightCard> createState() => _TrainingAiInsightCardState();
}

class _TrainingAiInsightCardState extends State<TrainingAiInsightCard> {
  var _dismissed = false;

  @override
  Widget build(BuildContext context) {
    if (_dismissed) return const SizedBox.shrink();

    return Container(
      key: const Key('training-ai-insight-card'),
      decoration: BoxDecoration(
        color: const Color(0xFFEAF6F2),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFCFE9E0)),
      ),
      padding: const EdgeInsets.fromLTRB(18, 15, 10, 16),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Padding(
            padding: EdgeInsets.only(top: 2),
            child: Icon(
              Icons.auto_awesome_rounded,
              color: Color(0xFF006B55),
              size: 24,
            ),
          ),
          const SizedBox(width: 11),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'DeepSeek 训练建议',
                  style: TextStyle(
                    color: Color(0xFF005A45),
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 7),
                Text(
                  widget.insight ?? '完成更多训练记录后，这里会提供更有针对性的训练建议。',
                  style: const TextStyle(
                    color: Color(0xFF52605D),
                    fontSize: 14,
                    height: 1.5,
                    fontWeight: FontWeight.w400,
                  ),
                ),
              ],
            ),
          ),
          IconButton(
            tooltip: '隐藏本次建议',
            onPressed: () => setState(() => _dismissed = true),
            icon: const Icon(Icons.close_rounded, size: 20),
            color: const Color(0xFF58716A),
          ),
        ],
      ),
    );
  }
}
