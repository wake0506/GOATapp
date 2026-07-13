import 'package:flutter/material.dart';

import '../../models/consumed_record.dart';
import '../../models/diet_copy_plan.dart';

Future<void> showCopyDietSheet({
  required BuildContext context,
  required DietCopyPlan plan,
  required String targetDate,
  required Future<void> Function(List<ConsumedRecord> records) onConfirm,
}) async {
  await showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.white,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
    ),
    builder: (_) =>
        CopyDietSheet(plan: plan, targetDate: targetDate, onConfirm: onConfirm),
  );
}

class CopyDietSheet extends StatefulWidget {
  final DietCopyPlan plan;
  final String targetDate;
  final Future<void> Function(List<ConsumedRecord> records) onConfirm;

  const CopyDietSheet({
    super.key,
    required this.plan,
    required this.targetDate,
    required this.onConfirm,
  });

  @override
  State<CopyDietSheet> createState() => _CopyDietSheetState();
}

class _CopyDietSheetState extends State<CopyDietSheet> {
  late final Set<String> _selectedIds = widget.plan.records
      .map((record) => record.id)
      .toSet();
  bool _saving = false;

  Future<void> _confirm() async {
    if (_saving || _selectedIds.isEmpty) return;
    setState(() => _saving = true);
    final selected = widget.plan.records
        .where((record) => _selectedIds.contains(record.id))
        .toList();
    await widget.onConfirm(selected);
    if (mounted) Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
        child: ConstrainedBox(
          constraints: BoxConstraints(
            maxHeight: MediaQuery.of(context).size.height * 0.75,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                widget.plan.isEmpty ? '昨天没有饮食记录' : '复制昨天饮食',
                style: const TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                '${widget.plan.sourceDate} → ${widget.targetDate}',
                style: const TextStyle(color: Colors.black45),
              ),
              const SizedBox(height: 12),
              if (widget.plan.isEmpty)
                const Expanded(child: Center(child: Text('昨天没有可复制的记录')))
              else
                Expanded(
                  child: ListView.builder(
                    itemCount: widget.plan.records.length,
                    itemBuilder: (_, index) {
                      final record = widget.plan.records[index];
                      final selected = _selectedIds.contains(record.id);
                      return CheckboxListTile(
                        value: selected,
                        onChanged: _saving
                            ? null
                            : (value) => setState(() {
                                if (value == true) {
                                  _selectedIds.add(record.id);
                                } else {
                                  _selectedIds.remove(record.id);
                                }
                              }),
                        title: Text(record.name),
                        subtitle: Text(
                          '${record.mealType} · ${record.amount.toStringAsFixed(0)}${record.unit} · ${record.kcal.toInt()} kcal',
                        ),
                        activeColor: const Color(0xFF008C8C),
                      );
                    },
                  ),
                ),
              const SizedBox(height: 10),
              FilledButton(
                onPressed: _saving || _selectedIds.isEmpty ? null : _confirm,
                child: Text(
                  _saving ? '保存中...' : '确认复制 ${_selectedIds.length} 条',
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
