import 'package:flutter/material.dart';

import '../services/warmup_suggestion_service.dart';

class WarmupSuggestionSheet extends StatefulWidget {
  const WarmupSuggestionSheet({
    super.key,
    required this.targetWeight,
    required this.suggestions,
    required this.viewOnly,
  });

  final double targetWeight;
  final List<WarmupSuggestion> suggestions;
  final bool viewOnly;

  static Future<List<WarmupSuggestion>?> show(
    BuildContext context, {
    required double targetWeight,
    required List<WarmupSuggestion> suggestions,
    required bool viewOnly,
  }) => showModalBottomSheet<List<WarmupSuggestion>>(
    context: context,
    backgroundColor: Colors.white,
    isScrollControlled: true,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
    ),
    builder: (_) => WarmupSuggestionSheet(
      targetWeight: targetWeight,
      suggestions: suggestions,
      viewOnly: viewOnly,
    ),
  );

  @override
  State<WarmupSuggestionSheet> createState() => _WarmupSuggestionSheetState();
}

class _WarmupSuggestionSheetState extends State<WarmupSuggestionSheet> {
  late final List<WarmupSuggestion> _items = [...widget.suggestions];
  bool _adjusting = false;

  @override
  Widget build(BuildContext context) => SafeArea(
    child: Padding(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 18),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text(
            '热身建议',
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 6),
          Text(
            '目标工作组 ${widget.targetWeight.toStringAsFixed(1)} kg',
            style: const TextStyle(color: Color(0xFF6E7775)),
          ),
          const SizedBox(height: 16),
          for (var index = 0; index < _items.length; index++)
            _WarmupRow(
              item: _items[index],
              adjusting: _adjusting && !widget.viewOnly,
              onWeightChanged: (delta) => setState(() {
                _items[index] = _items[index].copyWith(
                  weight: (_items[index].weight + delta).clamp(0, 9999),
                );
              }),
              onRepsChanged: (delta) => setState(() {
                _items[index] = _items[index].copyWith(
                  reps: (_items[index].reps + delta).clamp(1, 99),
                );
              }),
              onRemove: () => setState(() => _items.removeAt(index)),
            ),
          if (widget.viewOnly)
            const Padding(
              padding: EdgeInsets.only(top: 10),
              child: Text(
                '当前动作已经开始，热身建议仅供参考，不会回写过去的训练记录。',
                style: TextStyle(color: Color(0xFF7D8583), fontSize: 13),
              ),
            ),
          const SizedBox(height: 18),
          if (!widget.viewOnly)
            FilledButton(
              onPressed: _items.isEmpty
                  ? null
                  : () => Navigator.pop(context, _items),
              style: FilledButton.styleFrom(
                backgroundColor: const Color(0xFF008C8C),
                minimumSize: const Size.fromHeight(52),
              ),
              child: const Text('加入本次训练'),
            ),
          TextButton(
            onPressed: widget.viewOnly
                ? () => Navigator.pop(context)
                : () => setState(() => _adjusting = !_adjusting),
            child: Text(widget.viewOnly ? '关闭' : (_adjusting ? '完成调整' : '调整')),
          ),
        ],
      ),
    ),
  );
}

class _WarmupRow extends StatelessWidget {
  const _WarmupRow({
    required this.item,
    required this.adjusting,
    required this.onWeightChanged,
    required this.onRepsChanged,
    required this.onRemove,
  });

  final WarmupSuggestion item;
  final bool adjusting;
  final ValueChanged<double> onWeightChanged;
  final ValueChanged<int> onRepsChanged;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 5),
    child: Row(
      children: [
        Expanded(
          child: Text(
            '${item.weight.toStringAsFixed(1)} kg × ${item.reps}',
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
          ),
        ),
        if (adjusting) ...[
          IconButton(
            visualDensity: VisualDensity.compact,
            onPressed: () => onWeightChanged(-2.5),
            icon: const Icon(Icons.remove),
          ),
          IconButton(
            visualDensity: VisualDensity.compact,
            onPressed: () => onWeightChanged(2.5),
            icon: const Icon(Icons.add),
          ),
          IconButton(
            visualDensity: VisualDensity.compact,
            onPressed: onRemove,
            icon: const Icon(Icons.close),
          ),
        ],
      ],
    ),
  );
}
