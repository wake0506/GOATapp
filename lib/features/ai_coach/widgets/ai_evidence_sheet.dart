import 'package:flutter/material.dart';

import '../models/ai_scenario_explanation.dart';

class AiEvidenceSheet extends StatelessWidget {
  const AiEvidenceSheet({super.key, required this.explanation});

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
    builder: (_) => AiEvidenceSheet(explanation: explanation),
  );

  @override
  Widget build(BuildContext context) => SafeArea(
    child: SingleChildScrollView(
      padding: EdgeInsets.fromLTRB(
        20,
        12,
        20,
        24 + MediaQuery.viewPaddingOf(context).bottom,
      ),
      child: Column(
        key: const Key('ai-evidence-sheet'),
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Center(
            child: Container(
              width: 42,
              height: 4,
              decoration: BoxDecoration(
                color: const Color(0xFFD9DEDC),
                borderRadius: BorderRadius.circular(99),
              ),
            ),
          ),
          const SizedBox(height: 18),
          const Text(
            '为什么这么说',
            style: TextStyle(fontSize: 22, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 18),
          const _SectionLabel('你的数据'),
          const SizedBox(height: 8),
          if (explanation.evidence.isEmpty)
            const _EmptyMessage('当前没有足够的数据依据')
          else
            for (final item in explanation.evidence)
              _EvidenceRow(label: item.label, value: item.value),
          const SizedBox(height: 18),
          const _SectionLabel('GOAT 知识'),
          const SizedBox(height: 8),
          if (explanation.knowledge.isEmpty)
            const _EmptyMessage('当前没有可验证的知识引用')
          else
            for (final entry in explanation.knowledge)
              _KnowledgeRow(
                title: entry.title,
                content: entry.content,
                source: '${entry.source} · v${entry.version}',
              ),
          if (explanation.partialData || explanation.insufficientEvidence) ...[
            const SizedBox(height: 14),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(13),
              decoration: BoxDecoration(
                color: const Color(0xFFFFF8E7),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Text(
                explanation.insufficientEvidence
                    ? '当前证据不足，结论保持保守。'
                    : '当前数据不完整，结论仅基于已记录内容。',
                style: const TextStyle(color: Color(0xFF7C6330), fontSize: 12),
              ),
            ),
          ],
        ],
      ),
    ),
  );
}

class _SectionLabel extends StatelessWidget {
  const _SectionLabel(this.text);

  final String text;

  @override
  Widget build(BuildContext context) => Text(
    text,
    style: const TextStyle(
      color: Color(0xFF008C7A),
      fontSize: 13,
      fontWeight: FontWeight.w700,
    ),
  );
}

class _EvidenceRow extends StatelessWidget {
  const _EvidenceRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) => Container(
    width: double.infinity,
    margin: const EdgeInsets.only(bottom: 8),
    padding: const EdgeInsets.all(14),
    decoration: BoxDecoration(
      color: const Color(0xFFF5F7F6),
      borderRadius: BorderRadius.circular(14),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13),
        ),
        const SizedBox(height: 4),
        Text(
          value,
          style: const TextStyle(
            color: Color(0xFF65706D),
            fontSize: 12,
            height: 1.4,
          ),
        ),
      ],
    ),
  );
}

class _KnowledgeRow extends StatelessWidget {
  const _KnowledgeRow({
    required this.title,
    required this.content,
    required this.source,
  });

  final String title;
  final String content;
  final String source;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 12),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title, style: const TextStyle(fontWeight: FontWeight.w700)),
        const SizedBox(height: 3),
        Text(
          content,
          style: const TextStyle(
            color: Color(0xFF596360),
            fontSize: 12,
            height: 1.45,
          ),
        ),
        const SizedBox(height: 3),
        Text(
          source,
          style: const TextStyle(color: Color(0xFF969D9B), fontSize: 10),
        ),
      ],
    ),
  );
}

class _EmptyMessage extends StatelessWidget {
  const _EmptyMessage(this.text);

  final String text;

  @override
  Widget build(BuildContext context) => Text(
    text,
    style: const TextStyle(color: Color(0xFF7D8583), fontSize: 12),
  );
}
