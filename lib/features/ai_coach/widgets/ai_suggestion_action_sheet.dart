import 'package:flutter/material.dart';

import '../models/ai_suggestion.dart';

class AiSuggestionActionDecision {
  const AiSuggestionActionDecision({
    required this.confirmed,
    this.modifiedAction,
    this.feedbackType,
  });

  final bool confirmed;
  final AiProposedAction? modifiedAction;
  final SuggestionFeedbackType? feedbackType;
}

class AiSuggestionActionSheet extends StatefulWidget {
  const AiSuggestionActionSheet({
    super.key,
    required this.suggestion,
    required this.currentLabel,
    required this.updatedLabel,
    required this.impactLabel,
  });

  final AiSuggestion suggestion;
  final String currentLabel;
  final String updatedLabel;
  final String impactLabel;

  static Future<AiSuggestionActionDecision?> show(
    BuildContext context, {
    required AiSuggestion suggestion,
    required String currentLabel,
    required String updatedLabel,
    required String impactLabel,
  }) => showModalBottomSheet<AiSuggestionActionDecision>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.white,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(26)),
    ),
    builder: (_) => AiSuggestionActionSheet(
      suggestion: suggestion,
      currentLabel: currentLabel,
      updatedLabel: updatedLabel,
      impactLabel: impactLabel,
    ),
  );

  @override
  State<AiSuggestionActionSheet> createState() =>
      _AiSuggestionActionSheetState();
}

class _AiSuggestionActionSheetState extends State<AiSuggestionActionSheet> {
  SuggestionFeedbackType _feedbackType = SuggestionFeedbackType.dismissed;

  late final TextEditingController _secondsController = TextEditingController(
    text:
        (widget.suggestion.proposedAction?.payload['fixedSeconds'] as num?)
            ?.toInt()
            .toString() ??
        '',
  );

  @override
  void dispose() {
    _secondsController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final action = widget.suggestion.proposedAction;
    final editable =
        action?.type == AiProposedActionType.updateRestPrescription;
    return SafeArea(
      child: SingleChildScrollView(
        padding: EdgeInsets.fromLTRB(
          20,
          18,
          20,
          24 + MediaQuery.viewInsetsOf(context).bottom,
        ),
        child: Column(
          key: const Key('ai-suggestion-action-sheet'),
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              '应用建议前确认',
              style: TextStyle(fontSize: 22, fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 18),
            _PreviewRow(label: '当前', value: widget.currentLabel),
            _PreviewRow(label: '修改后', value: widget.updatedLabel),
            _PreviewRow(label: '影响', value: widget.impactLabel),
            if (editable) ...[
              const SizedBox(height: 12),
              TextField(
                key: const Key('ai-suggestion-rest-seconds'),
                controller: _secondsController,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  labelText: '固定休息秒数',
                  helperText: '允许 15–600 秒',
                  border: OutlineInputBorder(),
                ),
              ),
            ],
            const SizedBox(height: 14),
            const Text(
              '如果暂不采用',
              style: TextStyle(
                color: Color(0xFF596360),
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 6,
              children: [
                _FeedbackChip(
                  label: '不适合我',
                  value: SuggestionFeedbackType.notForMe,
                  selected: _feedbackType,
                  onSelected: _selectFeedback,
                ),
                _FeedbackChip(
                  label: '数据不准确',
                  value: SuggestionFeedbackType.inaccurateData,
                  selected: _feedbackType,
                  onSelected: _selectFeedback,
                ),
                _FeedbackChip(
                  label: '不喜欢',
                  value: SuggestionFeedbackType.disliked,
                  selected: _feedbackType,
                  onSelected: _selectFeedback,
                ),
                _FeedbackChip(
                  label: '忽略',
                  value: SuggestionFeedbackType.dismissed,
                  selected: _feedbackType,
                  onSelected: _selectFeedback,
                ),
              ],
            ),
            const SizedBox(height: 20),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => Navigator.pop(
                      context,
                      AiSuggestionActionDecision(
                        confirmed: false,
                        feedbackType: _feedbackType,
                      ),
                    ),
                    child: const Text('暂不采用'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: FilledButton(
                    key: const Key('ai-suggestion-confirm-apply'),
                    onPressed: () {
                      AiProposedAction? modified;
                      if (editable && action != null) {
                        final seconds = int.tryParse(
                          _secondsController.text.trim(),
                        );
                        if (seconds == null || seconds < 15 || seconds > 600) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('请输入 15–600 秒')),
                          );
                          return;
                        }
                        if (seconds != action.payload['fixedSeconds']) {
                          modified = AiProposedAction(
                            type: action.type,
                            domainEntityId: action.domainEntityId,
                            payload: {
                              ...action.payload,
                              'fixedSeconds': seconds,
                            },
                          );
                        }
                      }
                      Navigator.pop(
                        context,
                        AiSuggestionActionDecision(
                          confirmed: true,
                          modifiedAction: modified,
                        ),
                      );
                    },
                    child: const Text('确认应用'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  void _selectFeedback(SuggestionFeedbackType value) {
    setState(() => _feedbackType = value);
  }
}

class _FeedbackChip extends StatelessWidget {
  const _FeedbackChip({
    required this.label,
    required this.value,
    required this.selected,
    required this.onSelected,
  });

  final String label;
  final SuggestionFeedbackType value;
  final SuggestionFeedbackType selected;
  final ValueChanged<SuggestionFeedbackType> onSelected;

  @override
  Widget build(BuildContext context) => ChoiceChip(
    label: Text(label),
    selected: selected == value,
    onSelected: (_) => onSelected(value),
    visualDensity: VisualDensity.compact,
  );
}

class _PreviewRow extends StatelessWidget {
  const _PreviewRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 12),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 64,
          child: Text(
            label,
            style: const TextStyle(color: Color(0xFF7D8583), fontSize: 12),
          ),
        ),
        Expanded(
          child: Text(
            value,
            style: const TextStyle(fontWeight: FontWeight.w600),
          ),
        ),
      ],
    ),
  );
}
