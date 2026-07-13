import 'package:flutter/material.dart';

import '../../models/consumed_record.dart';

Future<void> showEditDietRecordSheet({
  required BuildContext context,
  required ConsumedRecord record,
  required Future<void> Function(ConsumedRecord record) onSave,
}) async {
  await showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.white,
    builder: (_) => EditDietRecordSheet(record: record, onSave: onSave),
  );
}

class EditDietRecordSheet extends StatefulWidget {
  final ConsumedRecord record;
  final Future<void> Function(ConsumedRecord record) onSave;

  const EditDietRecordSheet({
    super.key,
    required this.record,
    required this.onSave,
  });

  @override
  State<EditDietRecordSheet> createState() => _EditDietRecordSheetState();
}

class _EditDietRecordSheetState extends State<EditDietRecordSheet> {
  late final _name = TextEditingController(text: widget.record.name);
  late final _amount = TextEditingController(
    text: widget.record.amount.toString(),
  );
  late final _unit = TextEditingController(text: widget.record.unit);
  late final _kcal = TextEditingController(text: widget.record.kcal.toString());
  late final _protein = TextEditingController(text: widget.record.p.toString());
  late final _carbs = TextEditingController(text: widget.record.c.toString());
  late final _fat = TextEditingController(text: widget.record.f.toString());
  bool _saving = false;
  String? _error;

  @override
  void dispose() {
    for (final controller in [
      _name,
      _amount,
      _unit,
      _kcal,
      _protein,
      _carbs,
      _fat,
    ]) {
      controller.dispose();
    }
    super.dispose();
  }

  double? _number(TextEditingController controller) {
    final value = double.tryParse(controller.text.trim());
    if (value == null || !value.isFinite || value < 0) return null;
    return value;
  }

  Future<void> _save() async {
    final name = _name.text.trim();
    final amount = _number(_amount);
    final kcal = _number(_kcal);
    final protein = _number(_protein);
    final carbs = _number(_carbs);
    final fat = _number(_fat);
    if (name.isEmpty ||
        amount == null ||
        kcal == null ||
        protein == null ||
        carbs == null ||
        fat == null) {
      setState(() => _error = '请输入有效的非负数值和食物名称');
      return;
    }
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      await widget.onSave(
        ConsumedRecord(
          id: widget.record.id,
          name: name,
          p: protein,
          c: carbs,
          f: fat,
          kcal: kcal,
          mealType: widget.record.mealType,
          date: widget.record.date,
          amount: amount,
          unit: _unit.text.trim().isEmpty ? 'g' : _unit.text.trim(),
        ),
      );
      if (mounted) Navigator.of(context).pop();
    } catch (_) {
      if (mounted) {
        setState(() {
          _saving = false;
          _error = '保存失败，请重试';
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: EdgeInsets.fromLTRB(
          20,
          18,
          20,
          18 + MediaQuery.of(context).viewInsets.bottom,
        ),
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text(
                '编辑饮食记录',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 14),
              TextField(
                controller: _name,
                decoration: const InputDecoration(labelText: '食物名称'),
              ),
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _amount,
                      keyboardType: const TextInputType.numberWithOptions(
                        decimal: true,
                      ),
                      decoration: const InputDecoration(labelText: '数量'),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: TextField(
                      controller: _unit,
                      decoration: const InputDecoration(labelText: '单位'),
                    ),
                  ),
                ],
              ),
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _kcal,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(labelText: 'kcal'),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: TextField(
                      controller: _protein,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(labelText: '蛋白质'),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: TextField(
                      controller: _carbs,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(labelText: '碳水'),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: TextField(
                      controller: _fat,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(labelText: '脂肪'),
                    ),
                  ),
                ],
              ),
              if (_error != null)
                Padding(
                  padding: const EdgeInsets.only(top: 10),
                  child: Text(
                    _error!,
                    style: const TextStyle(color: Colors.redAccent),
                  ),
                ),
              const SizedBox(height: 16),
              FilledButton(
                onPressed: _saving ? null : _save,
                child: Text(_saving ? '保存中...' : '保存修改'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
