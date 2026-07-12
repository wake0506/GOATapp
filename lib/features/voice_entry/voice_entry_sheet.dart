import 'dart:async';

import 'package:flutter/material.dart';

import '../../models/parsed_diet_item.dart';
import '../../repositories/nutrition_repository.dart';
import '../../services/nutrition_ai_service.dart';
import '../../services/speech_recognition_service.dart';

Future<void> showVoiceEntrySheet({
  required BuildContext context,
  required String mealType,
  required SpeechRecognitionService speechService,
  required NutritionAiService nutritionService,
  required NutritionRepository repository,
}) async {
  await showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.white,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(32)),
    ),
    builder: (_) => VoiceEntrySheet(
      initialMealType: mealType,
      speechService: speechService,
      nutritionService: nutritionService,
      repository: repository,
    ),
  );
}

class VoiceEntrySheet extends StatefulWidget {
  final String initialMealType;
  final SpeechRecognitionService speechService;
  final NutritionAiService nutritionService;
  final NutritionRepository repository;

  const VoiceEntrySheet({
    super.key,
    required this.initialMealType,
    required this.speechService,
    required this.nutritionService,
    required this.repository,
  });

  @override
  State<VoiceEntrySheet> createState() => _VoiceEntrySheetState();
}

class _VoiceEntrySheetState extends State<VoiceEntrySheet> {
  final _textController = TextEditingController();
  StreamSubscription<SpeechState>? _speechSubscription;
  SpeechState _speechState = SpeechState.idle;
  List<ParsedDietItem> _items = [];
  String? _error;
  bool _isSaving = false;

  bool get _isListening => _speechState == SpeechState.listening;
  bool get _isBusy => _isSaving || _speechState == SpeechState.parsing;

  @override
  void initState() {
    super.initState();
    _speechSubscription = widget.speechService.stateStream.listen((state) {
      if (mounted) {
        setState(() {
          _speechState = state;
          if (state == SpeechState.recognized &&
              _textController.text.trim().isEmpty) {
            _error = '没有识别到语音，请靠近麦克风再试一次，或直接输入文字';
          }
        });
      }
    });
  }

  @override
  void dispose() {
    unawaited(widget.speechService.cancel());
    _speechSubscription?.cancel();
    _textController.dispose();
    super.dispose();
  }

  Future<void> _toggleListening() async {
    if (_isBusy) return;
    setState(() => _error = null);
    if (_isListening) {
      final result = await widget.speechService.stopListening();
      if (!mounted) return;
      if (result.text.trim().isEmpty) {
        setState(() => _error = '没有识别到内容，可以直接输入文字');
      } else {
        setState(() {
          _textController.text = result.text;
          _textController.selection = TextSelection.collapsed(
            offset: result.text.length,
          );
          _speechState = SpeechState.recognized;
        });
      }
      return;
    }

    final permission = await widget.speechService.requestPermission();
    if (!mounted) return;
    if (permission != PermissionResult.granted) {
      setState(
        () => _error = permission == PermissionResult.permanentlyDenied
            ? '麦克风权限已关闭，请在系统设置中开启'
            : '需要麦克风权限才能使用语音录入',
      );
      return;
    }
    final initialized = await widget.speechService.initialize();
    if (!mounted) return;
    if (!initialized.available) {
      setState(() => _error = '当前设备语音服务不可用，请直接输入文字');
      return;
    }
    await widget.speechService.startListening(
      onPartial: (text) {
        if (!mounted) return;
        _textController.value = TextEditingValue(
          text: text,
          selection: TextSelection.collapsed(offset: text.length),
        );
      },
    );
  }

  Future<void> _parse() async {
    if (_textController.text.trim().isEmpty || _isBusy) return;
    setState(() {
      _error = null;
      _speechState = SpeechState.parsing;
    });
    try {
      final items = await widget.nutritionService.parseDietText(
        _textController.text,
        defaultMealType: widget.initialMealType,
      );
      if (!mounted) return;
      setState(() {
        _items = items;
        _speechState = SpeechState.preview;
      });
    } catch (error) {
      if (mounted) {
        setState(() {
          _speechState = SpeechState.error;
          _error = error.toString();
        });
      }
    }
  }

  Future<void> _confirm() async {
    if (_items.isEmpty || _isSaving) return;
    setState(() {
      _isSaving = true;
      _speechState = SpeechState.saving;
      _error = null;
    });
    try {
      await widget.repository.addRecords(List.unmodifiable(_items));
      if (mounted) Navigator.of(context).pop();
    } catch (error) {
      if (mounted) {
        setState(() {
          _isSaving = false;
          _speechState = SpeechState.error;
          _error = '保存失败：$error';
        });
      }
    }
  }

  void _resetRecognition() {
    setState(() {
      _textController.clear();
      _items = [];
      _error = null;
      _speechState = SpeechState.idle;
    });
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;
    return SafeArea(
      child: Padding(
        padding: EdgeInsets.fromLTRB(20, 18, 20, 16 + bottomInset),
        child: ConstrainedBox(
          constraints: BoxConstraints(
            maxHeight: MediaQuery.of(context).size.height * 0.86,
          ),
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Center(
                  child: Container(
                    width: 42,
                    height: 4,
                    decoration: BoxDecoration(
                      color: Colors.black12,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                const SizedBox(height: 18),
                Row(
                  children: [
                    const Expanded(
                      child: Text(
                        '语音饮食录入',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                    Text(
                      widget.initialMealType,
                      style: const TextStyle(
                        color: Color(0xFF008C8C),
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                TextField(
                  controller: _textController,
                  minLines: 3,
                  maxLines: 6,
                  enabled: !_isBusy,
                  decoration: InputDecoration(
                    hintText: '例如：早餐吃了两个鸡蛋、一杯牛奶和一根香蕉',
                    filled: true,
                    fillColor: const Color(0xFFF4F5F7),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(16),
                      borderSide: BorderSide.none,
                    ),
                  ),
                ),
                const SizedBox(height: 14),
                Center(
                  child: InkWell(
                    onTap: _toggleListening,
                    borderRadius: BorderRadius.circular(48),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 180),
                      width: 76,
                      height: 76,
                      decoration: BoxDecoration(
                        color: _isListening
                            ? Colors.redAccent.withValues(alpha: 0.14)
                            : const Color(0xFF008C8C).withValues(alpha: 0.14),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        _isListening ? Icons.stop_rounded : Icons.mic_rounded,
                        size: 36,
                        color: _isListening
                            ? Colors.redAccent
                            : const Color(0xFF008C8C),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                Center(
                  child: Text(
                    _isListening ? '再次点击结束识别' : '点击开始语音识别',
                    style: const TextStyle(color: Colors.black45, fontSize: 12),
                  ),
                ),
                if (_error != null) ...[
                  const SizedBox(height: 10),
                  Text(
                    _error!,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      color: Colors.redAccent,
                      fontSize: 12,
                    ),
                  ),
                ],
                if (_items.isEmpty) ...[
                  const SizedBox(height: 16),
                  FilledButton.icon(
                    onPressed: _isBusy ? null : _parse,
                    icon: const Icon(Icons.auto_awesome),
                    label: const Text('解析饮食'),
                  ),
                ] else ...[
                  const SizedBox(height: 18),
                  const Text(
                    '解析预览',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
                  ),
                  const SizedBox(height: 8),
                  ..._items.asMap().entries.map(
                    (entry) => _ParsedDietItemEditor(
                      key: ValueKey(entry.key),
                      item: entry.value,
                      onChanged: () => setState(() {}),
                      onDelete: () =>
                          setState(() => _items.removeAt(entry.key)),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton(
                          onPressed: _isBusy ? null : _resetRecognition,
                          child: const Text('重新录音'),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: FilledButton(
                          onPressed: _isBusy || _items.isEmpty
                              ? null
                              : _confirm,
                          child: Text(_isSaving ? '保存中...' : '确认记录'),
                        ),
                      ),
                    ],
                  ),
                  TextButton(
                    onPressed: _isBusy ? null : _parse,
                    child: const Text('重新解析'),
                  ),
                ],
                TextButton(
                  onPressed: _isBusy ? null : () => Navigator.of(context).pop(),
                  child: const Text('取消'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _ParsedDietItemEditor extends StatefulWidget {
  final ParsedDietItem item;
  final VoidCallback onChanged;
  final VoidCallback onDelete;

  const _ParsedDietItemEditor({
    super.key,
    required this.item,
    required this.onChanged,
    required this.onDelete,
  });

  @override
  State<_ParsedDietItemEditor> createState() => _ParsedDietItemEditorState();
}

class _ParsedDietItemEditorState extends State<_ParsedDietItemEditor> {
  late final TextEditingController _name;
  late final TextEditingController _amount;
  late final TextEditingController _unit;
  late final TextEditingController _kcal;
  late final TextEditingController _protein;
  late final TextEditingController _carbs;
  late final TextEditingController _fat;

  @override
  void initState() {
    super.initState();
    final item = widget.item;
    _name = TextEditingController(text: item.name);
    _amount = TextEditingController(text: item.amount.toString());
    _unit = TextEditingController(text: item.unit);
    _kcal = TextEditingController(text: item.kcal.toString());
    _protein = TextEditingController(text: item.protein.toString());
    _carbs = TextEditingController(text: item.carbs.toString());
    _fat = TextEditingController(text: item.fat.toString());
  }

  @override
  void dispose() {
    _name.dispose();
    _amount.dispose();
    _unit.dispose();
    _kcal.dispose();
    _protein.dispose();
    _carbs.dispose();
    _fat.dispose();
    super.dispose();
  }

  void _sync() {
    final item = widget.item;
    item.name = _name.text.trim();
    item.amount = double.tryParse(_amount.text) ?? 0;
    item.unit = _unit.text.trim();
    item.kcal = double.tryParse(_kcal.text) ?? 0;
    item.protein = double.tryParse(_protein.text) ?? 0;
    item.carbs = double.tryParse(_carbs.text) ?? 0;
    item.fat = double.tryParse(_fat.text) ?? 0;
    widget.onChanged();
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      elevation: 0,
      color: const Color(0xFFF4F5F7),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          children: [
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _name,
                    onChanged: (_) => _sync(),
                    decoration: const InputDecoration(labelText: '食物名称'),
                  ),
                ),
                IconButton(
                  onPressed: widget.onDelete,
                  icon: const Icon(
                    Icons.delete_outline,
                    color: Colors.redAccent,
                  ),
                ),
              ],
            ),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _amount,
                    onChanged: (_) => _sync(),
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(labelText: '数量'),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: TextField(
                    controller: _unit,
                    onChanged: (_) => _sync(),
                    decoration: const InputDecoration(labelText: '单位'),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: TextField(
                    controller: _kcal,
                    onChanged: (_) => _sync(),
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(labelText: 'kcal'),
                  ),
                ),
              ],
            ),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _protein,
                    onChanged: (_) => _sync(),
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(labelText: '蛋白质'),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: TextField(
                    controller: _carbs,
                    onChanged: (_) => _sync(),
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(labelText: '碳水'),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: TextField(
                    controller: _fat,
                    onChanged: (_) => _sync(),
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(labelText: '脂肪'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
