import 'package:flutter/material.dart';

import '../models/ai_scenario_explanation.dart';
import 'ai_evidence_sheet.dart';
import 'ai_follow_up_sheet.dart';

class AiCoachExplanationCard extends StatelessWidget {
  const AiCoachExplanationCard({
    super.key,
    required this.explanation,
    this.compact = false,
    this.onSuggestion,
  });

  final AiCoachScenarioExplanation explanation;
  final bool compact;
  final ValueChanged<int>? onSuggestion;

  @override
  Widget build(BuildContext context) => Container(
    key: key == null ? const Key('ai-coach-explanation-card') : null,
    width: double.infinity,
    padding: EdgeInsets.fromLTRB(18, compact ? 14 : 18, 18, 14),
    decoration: BoxDecoration(
      color: const Color(0xFFF0F7F5),
      borderRadius: BorderRadius.circular(20),
      border: Border.all(color: const Color(0xFFD9EBE6)),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Icon(
              Icons.auto_awesome_rounded,
              size: 18,
              color: Color(0xFF4467D9),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                explanation.title,
                style: const TextStyle(
                  color: Color(0xFF008C7A),
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
            if (explanation.partialData)
              const Text(
                '数据不完整',
                style: TextStyle(color: Color(0xFF8A7650), fontSize: 10),
              ),
          ],
        ),
        const SizedBox(height: 8),
        Text(
          explanation.headline,
          style: TextStyle(
            color: const Color(0xFF202826),
            fontSize: compact ? 15 : 17,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 5),
        Text(
          explanation.explanation,
          maxLines: compact ? 2 : 4,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(
            color: Color(0xFF596360),
            fontSize: 12,
            height: 1.45,
          ),
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 4,
          runSpacing: 2,
          children: [
            TextButton(
              key: const Key('ai-explanation-evidence'),
              onPressed: () => AiEvidenceSheet.show(context, explanation),
              child: const Text('为什么这么说 ›'),
            ),
            if (explanation.followUps.isNotEmpty)
              TextButton(
                key: const Key('ai-explanation-follow-up'),
                onPressed: () => AiFollowUpSheet.show(context, explanation),
                child: const Text('问 GOAT'),
              ),
          ],
        ),
        if (explanation.suggestions.isNotEmpty && onSuggestion != null) ...[
          const Divider(height: 18),
          for (var index = 0; index < explanation.suggestions.length; index++)
            ListTile(
              key: Key('ai-suggestion-$index'),
              contentPadding: EdgeInsets.zero,
              dense: true,
              title: Text(
                explanation.suggestions[index].title,
                style: const TextStyle(fontWeight: FontWeight.w600),
              ),
              subtitle: Text(
                explanation.suggestions[index].summary,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
              trailing: const Icon(Icons.chevron_right_rounded),
              onTap: () => onSuggestion!(index),
            ),
        ],
      ],
    ),
  );
}

class AiCoachLoadingState extends StatelessWidget {
  const AiCoachLoadingState({super.key});

  @override
  Widget build(BuildContext context) => const SizedBox(
    height: 44,
    child: Center(
      child: SizedBox(
        width: 20,
        height: 20,
        child: CircularProgressIndicator(strokeWidth: 2),
      ),
    ),
  );
}

class AiCoachFallbackState extends StatelessWidget {
  const AiCoachFallbackState({super.key, this.message});

  final String? message;

  @override
  Widget build(BuildContext context) => Text(
    message ?? '当前无法生成进一步解释。你仍可以查看 GOAT 的确定性建议和数据依据。',
    style: const TextStyle(
      color: Color(0xFF68716F),
      fontSize: 12,
      height: 1.45,
    ),
  );
}
