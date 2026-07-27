import 'package:flutter/material.dart';

import '../../ai_coach/models/ai_scenario_explanation.dart';
import '../../ai_coach/widgets/ai_evidence_sheet.dart';
import '../../ai_coach/widgets/ai_follow_up_sheet.dart';

class HomeAiCard extends StatefulWidget {
  const HomeAiCard({
    super.key,
    required this.content,
    required this.isLoading,
    required this.onRefresh,
    required this.onClose,
    this.explanation,
  });

  final String content;
  final bool isLoading;
  final VoidCallback onRefresh;
  final VoidCallback onClose;
  final AiCoachScenarioExplanation? explanation;

  @override
  State<HomeAiCard> createState() => _HomeAiCardState();
}

class _HomeAiCardState extends State<HomeAiCard> {
  var _expanded = false;

  @override
  Widget build(BuildContext context) {
    final explanation = widget.explanation;
    final content =
        explanation?.explanation ??
        (widget.content.trim().isEmpty
            ? '完成更多饮食记录后，这里会提供更有针对性的建议。'
            : widget.content.trim());
    return Container(
      key: const Key('home-ai-card'),
      padding: const EdgeInsets.fromLTRB(20, 14, 12, 14),
      decoration: BoxDecoration(
        color: const Color(0xFFEAF6F2),
        border: Border.all(color: const Color(0xFFCFE9E0)),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Padding(
            padding: EdgeInsets.only(top: 2),
            child: Icon(
              Icons.auto_awesome_rounded,
              color: Color(0xFF008C8C),
              size: 23,
            ),
          ),
          const SizedBox(width: 11),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'GOAT 营养建议',
                  style: TextStyle(
                    color: Color(0xFF008C8C),
                    fontSize: 17,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 4),
                if (widget.isLoading)
                  const SizedBox(
                    height: 20,
                    width: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Color(0xFF008C8C),
                    ),
                  )
                else ...[
                  if (explanation != null) ...[
                    Text(
                      explanation.headline,
                      style: const TextStyle(
                        color: Color(0xFF24302D),
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 3),
                  ],
                  Text(
                    content,
                    maxLines: _expanded ? 5 : 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: Color(0xFF52605D),
                      fontSize: 13,
                      height: 1.45,
                    ),
                  ),
                  const SizedBox(height: 4),
                  GestureDetector(
                    onTap: explanation != null
                        ? () => AiEvidenceSheet.show(context, explanation)
                        : widget.content.trim().isEmpty
                        ? widget.onRefresh
                        : () => setState(() => _expanded = !_expanded),
                    child: Text(
                      explanation != null
                          ? '为什么这么说  ›'
                          : widget.content.trim().isEmpty
                          ? '查看建议  ›'
                          : _expanded
                          ? '收起  ›'
                          : '查看建议  ›',
                      style: const TextStyle(
                        color: Color(0xFF287A6B),
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                  if (explanation != null && explanation.followUps.isNotEmpty)
                    GestureDetector(
                      onTap: () => AiFollowUpSheet.show(context, explanation),
                      child: const Padding(
                        padding: EdgeInsets.only(top: 5),
                        child: Text(
                          '问 GOAT',
                          style: TextStyle(
                            color: Color(0xFF287A6B),
                            fontSize: 12,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                    ),
                ],
              ],
            ),
          ),
          IconButton(
            tooltip: '隐藏本次建议',
            onPressed: widget.onClose,
            icon: const Icon(Icons.close_rounded, size: 19),
            color: const Color(0xFF61726E),
          ),
        ],
      ),
    );
  }
}
