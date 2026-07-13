import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../models/water_intake_record.dart';

class WaterIntakeDraft {
  final int amountMl;
  final DateTime recordedAt;

  const WaterIntakeDraft({required this.amountMl, required this.recordedAt});
}

Future<WaterIntakeDraft?> showAddWaterSheet({
  required BuildContext context,
  required String date,
  WaterIntakeRecord? initialRecord,
}) {
  return showModalBottomSheet<WaterIntakeDraft>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.white,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
    ),
    builder: (_) => AddWaterSheet(date: date, initialRecord: initialRecord),
  );
}

class AddWaterSheet extends StatefulWidget {
  final String date;
  final WaterIntakeRecord? initialRecord;

  const AddWaterSheet({super.key, required this.date, this.initialRecord});

  @override
  State<AddWaterSheet> createState() => _AddWaterSheetState();
}

class _AddWaterSheetState extends State<AddWaterSheet> {
  late final TextEditingController _amountController;
  late final TextEditingController _timeController;
  late DateTime _recordedAt;

  @override
  void initState() {
    super.initState();
    final selectedDate = DateTime.tryParse(widget.date) ?? DateTime.now();
    final now = DateTime.now();
    _recordedAt =
        widget.initialRecord?.recordedAt ??
        DateTime(
          selectedDate.year,
          selectedDate.month,
          selectedDate.day,
          now.hour,
          now.minute,
        );
    _amountController = TextEditingController(
      text: widget.initialRecord?.amountMl.toString() ?? '',
    );
    _timeController = TextEditingController(text: _formatTime(_recordedAt));
  }

  @override
  void dispose() {
    _amountController.dispose();
    _timeController.dispose();
    super.dispose();
  }

  String _formatTime(DateTime value) =>
      '${value.hour.toString().padLeft(2, '0')}:${value.minute.toString().padLeft(2, '0')}';

  void _submit() {
    final amount = int.tryParse(_amountController.text.trim());
    final match = RegExp(r'^(\d{2}):(\d{2})$').firstMatch(_timeController.text);
    final hour = match == null ? -1 : int.parse(match.group(1)!);
    final minute = match == null ? -1 : int.parse(match.group(2)!);
    if (amount == null || amount <= 0 || hour > 23 || minute > 59) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('请输入有效的饮水量和时间')));
      return;
    }
    final recordedAt = DateTime(
      _recordedAt.year,
      _recordedAt.month,
      _recordedAt.day,
      hour,
      minute,
    );
    Navigator.pop(
      context,
      WaterIntakeDraft(amountMl: amount, recordedAt: recordedAt),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isEditing = widget.initialRecord != null;
    return Padding(
      padding: EdgeInsets.fromLTRB(
        20,
        20,
        20,
        20 + MediaQuery.of(context).viewInsets.bottom,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            isEditing ? '编辑饮水记录' : '记录饮水',
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 16),
          Wrap(
            spacing: 8,
            children: [200, 250, 300, 500]
                .map(
                  (amount) => ActionChip(
                    label: Text('$amount ml'),
                    onPressed: () => setState(
                      () => _amountController.text = amount.toString(),
                    ),
                  ),
                )
                .toList(),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _amountController,
                  keyboardType: TextInputType.number,
                  inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                  decoration: const InputDecoration(
                    labelText: '水量 (ml)',
                    filled: true,
                    fillColor: Color(0xFFF4F5F7),
                    border: OutlineInputBorder(borderSide: BorderSide.none),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              SizedBox(
                width: 110,
                child: TextField(
                  controller: _timeController,
                  keyboardType: TextInputType.number,
                  inputFormatters: [
                    FilteringTextInputFormatter.allow(RegExp(r'[0-9:]')),
                    LengthLimitingTextInputFormatter(5),
                  ],
                  decoration: const InputDecoration(
                    labelText: '时间',
                    hintText: '08:20',
                    filled: true,
                    fillColor: Color(0xFFF4F5F7),
                    border: OutlineInputBorder(borderSide: BorderSide.none),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          FilledButton(
            onPressed: _submit,
            style: FilledButton.styleFrom(
              backgroundColor: const Color(0xFF008C8C),
              foregroundColor: Colors.white,
            ),
            child: Text(isEditing ? '保存修改' : '添加记录'),
          ),
        ],
      ),
    );
  }
}
