import 'package:flutter/material.dart';

import '../models/ai_suggestion.dart';

class AiSuggestionCard extends StatelessWidget {
  const AiSuggestionCard({
    super.key,
    required this.suggestion,
    required this.onStatusChanged,
  });

  final AiSuggestion suggestion;
  final ValueChanged<AiSuggestionStatus> onStatusChanged;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      key: Key('ai-suggestion-${suggestion.id}'),
      onTap: () => showAiSuggestionDetailSheet(
        context,
        suggestion: suggestion,
        onStatusChanged: onStatusChanged,
      ),
      borderRadius: BorderRadius.circular(18),
      child: Ink(
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: const Color(0xFFE5E9E8)),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.all(9),
              decoration: BoxDecoration(
                color: const Color(0xFFEAF3F1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Icon(
                Icons.auto_awesome_rounded,
                color: Color(0xFF008C8C),
                size: 19,
              ),
            ),
            const SizedBox(width: 13),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    suggestion.title,
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                      color: Color(0xFF202725),
                    ),
                  ),
                  const SizedBox(height: 5),
                  Text(
                    suggestion.summary,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 13,
                      height: 1.45,
                      color: Color(0xFF69716F),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    _statusLabel(suggestion.status),
                    style: TextStyle(
                      fontSize: 11,
                      color: suggestion.status == AiSuggestionStatus.applyFailed
                          ? const Color(0xFFC65353)
                          : const Color(0xFF008C8C),
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
            const Icon(Icons.chevron_right_rounded, color: Color(0xFFB6BDBB)),
          ],
        ),
      ),
    );
  }
}

Future<void> showAiSuggestionDetailSheet(
  BuildContext context, {
  required AiSuggestion suggestion,
  required ValueChanged<AiSuggestionStatus> onStatusChanged,
}) => showModalBottomSheet<void>(
  context: context,
  isScrollControlled: true,
  backgroundColor: Colors.white,
  shape: const RoundedRectangleBorder(
    borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
  ),
  builder: (context) => SafeArea(
    child: SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(20, 18, 20, 24),
      child: Column(
        key: const Key('ai-suggestion-detail-sheet'),
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 36,
            height: 4,
            margin: const EdgeInsets.only(bottom: 20),
            decoration: BoxDecoration(
              color: const Color(0xFFDDE2E1),
              borderRadius: BorderRadius.circular(99),
            ),
          ),
          const Text(
            'GOAT 建议',
            style: TextStyle(
              color: Color(0xFF008C8C),
              fontSize: 13,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            suggestion.title,
            style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 12),
          Text(
            suggestion.summary,
            style: const TextStyle(fontSize: 15, height: 1.55),
          ),
          if (suggestion.reasonCodes.isNotEmpty) ...[
            const SizedBox(height: 22),
            const _SheetTitle('原因'),
            for (final reason in suggestion.reasonCodes)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Text('• ${_humanize(reason)}'),
              ),
          ],
          if (suggestion.evidenceRefs.isNotEmpty ||
              suggestion.knowledgeRefs.isNotEmpty) ...[
            const SizedBox(height: 22),
            const _SheetTitle('为什么这么说'),
            for (final ref in suggestion.evidenceRefs)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Text('• 数据依据：${_humanize(ref)}'),
              ),
            for (final ref in suggestion.knowledgeRefs)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Text('• GOAT 规则：${_humanize(ref)}'),
              ),
          ],
          if (suggestion.status == AiSuggestionStatus.proposed) ...[
            const SizedBox(height: 26),
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                key: const Key('ai-suggestion-accept'),
                onPressed: () {
                  Navigator.pop(context);
                  onStatusChanged(AiSuggestionStatus.accepted);
                },
                style: FilledButton.styleFrom(
                  backgroundColor: const Color(0xFF008C8C),
                  padding: const EdgeInsets.symmetric(vertical: 14),
                ),
                child: const Text('采用建议'),
              ),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: TextButton(
                    key: const Key('ai-suggestion-modify'),
                    onPressed: () {
                      Navigator.pop(context);
                      onStatusChanged(AiSuggestionStatus.modified);
                    },
                    child: const Text('调整后接受'),
                  ),
                ),
                Expanded(
                  child: TextButton(
                    key: const Key('ai-suggestion-dismiss'),
                    onPressed: () {
                      Navigator.pop(context);
                      onStatusChanged(AiSuggestionStatus.dismissed);
                    },
                    child: const Text('忽略'),
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    ),
  ),
);

class _SheetTitle extends StatelessWidget {
  const _SheetTitle(this.text);

  final String text;

  @override
  Widget build(BuildContext context) => Text(
    text,
    style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
  );
}

String _statusLabel(AiSuggestionStatus status) => switch (status) {
  AiSuggestionStatus.proposed => '待你决定',
  AiSuggestionStatus.accepted => '已接受，尚未应用',
  AiSuggestionStatus.modified => '已调整，尚未应用',
  AiSuggestionStatus.rejected => '已拒绝',
  AiSuggestionStatus.dismissed => '已忽略',
  AiSuggestionStatus.applied => '已应用',
  AiSuggestionStatus.applyFailed => '应用失败，原数据未改变',
};

String _humanize(String value) =>
    value.replaceAll('kb_', '').replaceAll('_', ' ').trim();
