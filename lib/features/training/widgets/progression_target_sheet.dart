import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../models/progression_target.dart';

class ProgressionTargetEditResult {
  const ProgressionTargetEditResult._({this.target, required this.cleared});

  const ProgressionTargetEditResult.saved(ProgressionTarget target)
    : this._(target: target, cleared: false);

  const ProgressionTargetEditResult.cleared()
    : this._(target: null, cleared: true);

  final ProgressionTarget? target;
  final bool cleared;
}

class ProgressionTargetSheet extends StatefulWidget {
  const ProgressionTargetSheet({super.key, this.initialTarget});

  final ProgressionTarget? initialTarget;

  static Future<ProgressionTargetEditResult?> show(
    BuildContext context, {
    ProgressionTarget? initialTarget,
  }) => showModalBottomSheet<ProgressionTargetEditResult>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.white,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
    ),
    builder: (_) => ProgressionTargetSheet(initialTarget: initialTarget),
  );

  @override
  State<ProgressionTargetSheet> createState() => _ProgressionTargetSheetState();
}

class _ProgressionTargetSheetState extends State<ProgressionTargetSheet> {
  late final TextEditingController _setsController;
  late final TextEditingController _minController;
  late final TextEditingController _maxController;
  late final TextEditingController _stepController;

  @override
  void initState() {
    super.initState();
    final target = widget.initialTarget;
    _setsController = TextEditingController(
      text: target?.targetSets.toString() ?? '',
    );
    _minController = TextEditingController(
      text: target?.targetRepMin.toString() ?? '',
    );
    _maxController = TextEditingController(
      text: target?.targetRepMax.toString() ?? '',
    );
    _stepController = TextEditingController(
      text: target?.weightStepKg?.toString() ?? '',
    );
  }

  @override
  void dispose() {
    _setsController.dispose();
    _minController.dispose();
    _maxController.dispose();
    _stepController.dispose();
    super.dispose();
  }

  ProgressionTarget? get _target => ProgressionTarget.tryFromJson({
    'targetSets': int.tryParse(_setsController.text),
    'targetRepMin': int.tryParse(_minController.text),
    'targetRepMax': int.tryParse(_maxController.text),
    'weightStepKg': _stepController.text.trim().isEmpty
        ? null
        : double.tryParse(_stepController.text),
  });

  @override
  Widget build(BuildContext context) {
    final target = _target;
    return SafeArea(
      child: SingleChildScrollView(
        padding: EdgeInsets.fromLTRB(
          20,
          18,
          20,
          20 + MediaQuery.viewInsetsOf(context).bottom,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text(
              '训练目标',
              style: TextStyle(fontSize: 22, fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 4),
            const Text(
              '用于生成确定性的下次训练建议，不会自动修改方案。',
              style: TextStyle(color: Color(0xFF737B79), fontSize: 13),
            ),
            const SizedBox(height: 18),
            _NumberField(
              key: const Key('progression-target-sets'),
              controller: _setsController,
              label: '目标组数',
              suffix: '组',
              onChanged: (_) => setState(() {}),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: _NumberField(
                    key: const Key('progression-target-min'),
                    controller: _minController,
                    label: '最低次数',
                    suffix: '次',
                    onChanged: (_) => setState(() {}),
                  ),
                ),
                const Padding(
                  padding: EdgeInsets.fromLTRB(10, 24, 10, 0),
                  child: Text('–', style: TextStyle(fontSize: 20)),
                ),
                Expanded(
                  child: _NumberField(
                    key: const Key('progression-target-max'),
                    controller: _maxController,
                    label: '最高次数',
                    suffix: '次',
                    onChanged: (_) => setState(() {}),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            _NumberField(
              key: const Key('progression-target-step'),
              controller: _stepController,
              label: '加重步长（可不填）',
              suffix: 'kg',
              decimal: true,
              onChanged: (_) => setState(() {}),
            ),
            if (target == null) ...[
              const SizedBox(height: 8),
              const Text(
                '请输入正数组数和次数，并确保最高次数不小于最低次数。',
                style: TextStyle(color: Color(0xFF8A6A55), fontSize: 12),
              ),
            ],
            const SizedBox(height: 18),
            FilledButton(
              key: const Key('progression-target-save'),
              onPressed: target == null
                  ? null
                  : () => Navigator.pop(
                      context,
                      ProgressionTargetEditResult.saved(target),
                    ),
              style: FilledButton.styleFrom(
                backgroundColor: const Color(0xFF008C8C),
                minimumSize: const Size.fromHeight(52),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
              ),
              child: const Text('保存'),
            ),
            if (widget.initialTarget != null) ...[
              const SizedBox(height: 8),
              TextButton(
                key: const Key('progression-target-clear'),
                onPressed: () => Navigator.pop(
                  context,
                  const ProgressionTargetEditResult.cleared(),
                ),
                child: const Text('清除递进目标'),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _NumberField extends StatelessWidget {
  const _NumberField({
    super.key,
    required this.controller,
    required this.label,
    required this.suffix,
    required this.onChanged,
    this.decimal = false,
  });

  final TextEditingController controller;
  final String label;
  final String suffix;
  final ValueChanged<String> onChanged;
  final bool decimal;

  @override
  Widget build(BuildContext context) => TextField(
    controller: controller,
    onChanged: onChanged,
    keyboardType: TextInputType.numberWithOptions(decimal: decimal),
    inputFormatters: [
      if (decimal)
        FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d{0,2}'))
      else
        FilteringTextInputFormatter.digitsOnly,
    ],
    decoration: InputDecoration(
      labelText: label,
      suffixText: suffix,
      filled: true,
      fillColor: const Color(0xFFF4F5F7),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: BorderSide.none,
      ),
    ),
  );
}
