import 'package:flutter/material.dart';

import '../models/ai_scenario_explanation.dart';
import 'ai_evidence_sheet.dart';

class AiFollowUpSheet extends StatefulWidget {
  const AiFollowUpSheet({super.key, required this.explanation});

  final AiCoachScenarioExplanation explanation;

  static Future<void> show(
    BuildContext context,
    AiCoachScenarioExplanation explanation,
  ) => showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.white,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(26)),
    ),
    builder: (_) => AiFollowUpSheet(explanation: explanation),
  );

  @override
  State<AiFollowUpSheet> createState() => _AiFollowUpSheetState();
}

class _AiFollowUpSheetState extends State<AiFollowUpSheet> {
  String? _selected;

  @override
  Widget build(BuildContext context) => SafeArea(
    child: SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(20, 18, 20, 28),
      child: Column(
        key: const Key('ai-follow-up-sheet'),
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          const Text(
            '问 GOAT',
            style: TextStyle(fontSize: 22, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 5),
          const Text(
            '选择一个与当前结构化结果相关的问题',
            style: TextStyle(color: Color(0xFF7D8583), fontSize: 12),
          ),
          const SizedBox(height: 16),
          for (final question in widget.explanation.followUps)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: OutlinedButton(
                key: Key('ai-follow-up-${question.hashCode}'),
                onPressed: () => setState(() => _selected = question),
                style: OutlinedButton.styleFrom(
                  alignment: Alignment.centerLeft,
                  minimumSize: const Size.fromHeight(46),
                  side: const BorderSide(color: Color(0xFFDCE6E3)),
                  foregroundColor: const Color(0xFF27302E),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
                child: Text(question),
              ),
            ),
          if (_selected != null) ...[
            const SizedBox(height: 8),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: const Color(0xFFF0F7F5),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    _selected!,
                    style: const TextStyle(fontWeight: FontWeight.w700),
                  ),
                  const SizedBox(height: 7),
                  Text(
                    widget.explanation.explanation,
                    style: const TextStyle(
                      color: Color(0xFF53605D),
                      height: 1.45,
                    ),
                  ),
                  const SizedBox(height: 6),
                  TextButton(
                    onPressed: () =>
                        AiEvidenceSheet.show(context, widget.explanation),
                    child: const Text('查看依据 ›'),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    ),
  );
}
