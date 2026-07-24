import 'package:flutter/material.dart';

import '../../../models/rest_prescription.dart';
import '../models/exercise_rest_profile_catalog.dart';

class RestPrescriptionSheet extends StatefulWidget {
  const RestPrescriptionSheet({
    super.key,
    required this.exerciseId,
    this.initial = const RestPrescription.recommended(),
  });

  final String exerciseId;
  final RestPrescription initial;

  static Future<RestPrescription?> show(
    BuildContext context, {
    required String exerciseId,
    RestPrescription initial = const RestPrescription.recommended(),
  }) => showModalBottomSheet<RestPrescription>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.white,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
    ),
    builder: (_) =>
        RestPrescriptionSheet(exerciseId: exerciseId, initial: initial),
  );

  @override
  State<RestPrescriptionSheet> createState() => _RestPrescriptionSheetState();
}

class _RestPrescriptionSheetState extends State<RestPrescriptionSheet> {
  late RestPrescriptionMode _mode = widget.initial.mode;
  late final TextEditingController _secondsController = TextEditingController(
    text: '${widget.initial.validFixedSeconds ?? 180}',
  );

  int get _baseSeconds =>
      ExerciseRestProfileCatalog.find(widget.exerciseId)?.baseRestSeconds ?? 90;

  @override
  void dispose() {
    _secondsController.dispose();
    super.dispose();
  }

  String _format(int seconds) =>
      '${seconds ~/ 60}:${(seconds % 60).toString().padLeft(2, '0')}';

  void _save() {
    if (_mode == RestPrescriptionMode.recommended) {
      Navigator.pop(context, const RestPrescription.recommended());
      return;
    }
    final seconds = int.tryParse(_secondsController.text.trim());
    if (seconds == null || seconds < 15 || seconds > 600) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('请输入 15–600 秒')));
      return;
    }
    Navigator.pop(context, RestPrescription.fixed(seconds));
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: SingleChildScrollView(
        padding: EdgeInsets.fromLTRB(
          20,
          18,
          20,
          18 + MediaQuery.viewInsetsOf(context).bottom,
        ),
        child: Column(
          key: const Key('rest-prescription-sheet'),
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text(
              '组间休息',
              style: TextStyle(fontSize: 22, fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 10),
            RadioGroup<RestPrescriptionMode>(
              groupValue: _mode,
              onChanged: (value) => setState(() => _mode = value!),
              child: Column(
                children: [
                  RadioListTile<RestPrescriptionMode>(
                    key: const Key('rest-mode-recommended'),
                    value: RestPrescriptionMode.recommended,
                    activeColor: const Color(0xFF008C8C),
                    contentPadding: EdgeInsets.zero,
                    title: const Text('使用 GOAT 推荐'),
                    subtitle: Text(
                      '当前基础建议 ${_format(_baseSeconds)}\n训练中会根据组类型、RIR 与力竭情况动态调整',
                    ),
                  ),
                  const Divider(height: 1),
                  const RadioListTile<RestPrescriptionMode>(
                    key: Key('rest-mode-fixed'),
                    value: RestPrescriptionMode.fixed,
                    activeColor: Color(0xFF008C8C),
                    contentPadding: EdgeInsets.zero,
                    title: Text('固定时间'),
                    subtitle: Text('普通工作组保持固定；热身仍使用 GOAT 热身逻辑'),
                  ),
                ],
              ),
            ),
            if (_mode == RestPrescriptionMode.fixed) ...[
              const SizedBox(height: 8),
              TextField(
                key: const Key('rest-fixed-seconds'),
                controller: _secondsController,
                keyboardType: TextInputType.number,
                decoration: InputDecoration(
                  labelText: '固定秒数（15–600）',
                  suffixText: '秒',
                  filled: true,
                  fillColor: const Color(0xFFF4F5F7),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                    borderSide: BorderSide.none,
                  ),
                ),
              ),
            ],
            const SizedBox(height: 18),
            FilledButton(
              key: const Key('rest-prescription-save'),
              onPressed: _save,
              style: FilledButton.styleFrom(
                minimumSize: const Size.fromHeight(52),
                backgroundColor: const Color(0xFF008C8C),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(15),
                ),
              ),
              child: const Text(
                '保存',
                style: TextStyle(fontWeight: FontWeight.w700),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
