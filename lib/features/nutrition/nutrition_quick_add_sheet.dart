import 'package:flutter/material.dart';

import '../../models/parsed_diet_item.dart';
import '../../models/recent_food_suggestion.dart';
import '../../repositories/nutrition_repository.dart';
import '../../services/nutrition_ai_service.dart';
import '../../services/speech_recognition_service.dart';
import '../voice_entry/voice_entry_sheet.dart';

Future<void> showNutritionQuickAddSheet({
  required BuildContext context,
  required String mealType,
  required List<RecentFoodSuggestion> recentFoods,
  required NutritionRepository repository,
  required NutritionAiService nutritionService,
  required SpeechRecognitionService speechService,
  required bool enableSystemSpeech,
  required Future<void> Function(
    RecentFoodSuggestion suggestion,
    double amount,
    String mealType,
  )
  onAddRecent,
  required VoidCallback onCopyYesterday,
  required VoidCallback onCustomFood,
}) async {
  await showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.white,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
    ),
    builder: (_) => NutritionQuickAddSheet(
      mealType: mealType,
      recentFoods: recentFoods,
      repository: repository,
      nutritionService: nutritionService,
      speechService: speechService,
      enableSystemSpeech: enableSystemSpeech,
      onAddRecent: onAddRecent,
      onCopyYesterday: onCopyYesterday,
      onCustomFood: onCustomFood,
    ),
  );
}

class NutritionQuickAddSheet extends StatefulWidget {
  final String mealType;
  final List<RecentFoodSuggestion> recentFoods;
  final NutritionRepository repository;
  final NutritionAiService nutritionService;
  final SpeechRecognitionService speechService;
  final bool enableSystemSpeech;
  final Future<void> Function(
    RecentFoodSuggestion suggestion,
    double amount,
    String mealType,
  )
  onAddRecent;
  final VoidCallback onCopyYesterday;
  final VoidCallback onCustomFood;

  const NutritionQuickAddSheet({
    super.key,
    required this.mealType,
    required this.recentFoods,
    required this.repository,
    required this.nutritionService,
    required this.speechService,
    required this.enableSystemSpeech,
    required this.onAddRecent,
    required this.onCopyYesterday,
    required this.onCustomFood,
  });

  @override
  State<NutritionQuickAddSheet> createState() => _NutritionQuickAddSheetState();
}

class _NutritionQuickAddSheetState extends State<NutritionQuickAddSheet> {
  final _textController = TextEditingController();
  List<ParsedDietItem> _preview = [];
  String? _error;
  bool _loading = false;
  bool _saving = false;
  late String _mealType = widget.mealType;

  static const _mealTypes = ['早餐', '午餐', '晚餐', '加餐'];

  @override
  void dispose() {
    _textController.dispose();
    super.dispose();
  }

  Future<void> _parseText() async {
    final text = _textController.text.trim();
    if (text.isEmpty || _loading || _saving) return;
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final items = await widget.nutritionService.parseDietText(
        text,
        defaultMealType: _mealType,
      );
      if (!mounted) return;
      setState(() {
        _preview = items;
        if (_preview.map((item) => item.mealType).toSet().length == 1) {
          _mealType = _preview.first.mealType;
        }
      });
    } catch (_) {
      if (mounted) setState(() => _error = 'AI 暂时不可用，请检查文本后重试');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _savePreview() async {
    if (_preview.isEmpty || _saving) return;
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      await widget.repository.addRecords(List.unmodifiable(_preview));
      if (mounted) Navigator.of(context).pop();
    } catch (_) {
      if (mounted) {
        setState(() {
          _saving = false;
          _error = '保存失败，本地数据未丢失，请重试';
        });
      }
    }
  }

  Future<void> _showAmount(RecentFoodSuggestion suggestion) async {
    final controller = TextEditingController(
      text: suggestion.amount.toStringAsFixed(0),
    );
    final amount = await showDialog<double>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text('再次记录 ${suggestion.displayName}'),
        content: TextField(
          controller: controller,
          autofocus: true,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          decoration: InputDecoration(labelText: '数量 (${suggestion.unit})'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () {
              final value = double.tryParse(controller.text);
              if (value != null && value > 0 && value.isFinite) {
                Navigator.pop(dialogContext, value);
              }
            },
            child: const Text('确认'),
          ),
        ],
      ),
    );
    controller.dispose();
    if (amount == null || !mounted) return;
    await widget.onAddRecent(suggestion, amount, _mealType);
    if (mounted) Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;
    return SafeArea(
      child: Padding(
        padding: EdgeInsets.fromLTRB(20, 16, 20, 16 + bottomInset),
        child: ConstrainedBox(
          constraints: BoxConstraints(
            maxHeight: MediaQuery.of(context).size.height * 0.86,
          ),
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Text(
                  '快速记录饮食',
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 4),
                Text('当前餐次', style: const TextStyle(color: Colors.black45)),
                const SizedBox(height: 16),
                SegmentedButton<String>(
                  segments: _mealTypes
                      .map(
                        (meal) => ButtonSegment(value: meal, label: Text(meal)),
                      )
                      .toList(),
                  selected: {_mealType},
                  onSelectionChanged: _saving
                      ? null
                      : (selection) {
                          final meal = selection.first;
                          setState(() {
                            _mealType = meal;
                            for (final item in _preview) {
                              item.mealType = meal;
                            }
                          });
                        },
                  style: ButtonStyle(
                    visualDensity: VisualDensity.compact,
                    backgroundColor: WidgetStateProperty.resolveWith(
                      (states) => states.contains(WidgetState.selected)
                          ? const Color(0xFF008C8C)
                          : const Color(0xFFF4F5F7),
                    ),
                    foregroundColor: WidgetStateProperty.resolveWith(
                      (states) => states.contains(WidgetState.selected)
                          ? Colors.white
                          : Colors.black54,
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                if (widget.recentFoods.isNotEmpty) ...[
                  const Text(
                    '最近吃过',
                    style: TextStyle(fontWeight: FontWeight.w700),
                  ),
                  const SizedBox(height: 8),
                  SizedBox(
                    height: 92,
                    child: ListView.separated(
                      scrollDirection: Axis.horizontal,
                      itemCount: widget.recentFoods.length,
                      separatorBuilder: (_, _) => const SizedBox(width: 8),
                      itemBuilder: (_, index) {
                        final food = widget.recentFoods[index];
                        return InkWell(
                          onTap: _saving ? null : () => _showAmount(food),
                          borderRadius: BorderRadius.circular(12),
                          child: Container(
                            width: 132,
                            padding: const EdgeInsets.all(10),
                            decoration: BoxDecoration(
                              color: const Color(0xFFF4F5F7),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  food.displayName,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                                const SizedBox(height: 6),
                                Text(
                                  '${food.amount.toStringAsFixed(0)}${food.unit} · ${food.kcal.toInt()} kcal',
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                                Text(
                                  '已记录 ${food.usageCount} 次',
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                    color: Colors.black45,
                                    fontSize: 11,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                  const SizedBox(height: 16),
                ] else ...[
                  const Text(
                    '最近吃过',
                    style: TextStyle(fontWeight: FontWeight.w700),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    '完成一次饮食记录后，常用食物会显示在这里',
                    style: TextStyle(color: Colors.black45),
                  ),
                  const SizedBox(height: 16),
                ],
                TextField(
                  controller: _textController,
                  minLines: 2,
                  maxLines: 4,
                  enabled: !_saving,
                  decoration: const InputDecoration(
                    labelText: '搜索或输入饮食',
                    hintText: '例如：早餐吃了两个鸡蛋和一杯牛奶',
                    filled: true,
                    fillColor: Color(0xFFF4F5F7),
                    border: OutlineInputBorder(borderSide: BorderSide.none),
                  ),
                ),
                const SizedBox(height: 10),
                FilledButton.icon(
                  onPressed: _loading || _saving ? null : _parseText,
                  icon: const Icon(Icons.auto_awesome),
                  label: Text(_loading ? '正在分析...' : 'AI 分析并预览'),
                ),
                if (widget.enableSystemSpeech) ...[
                  const SizedBox(height: 8),
                  OutlinedButton.icon(
                    onPressed: _saving
                        ? null
                        : () {
                            Navigator.pop(context);
                            showVoiceEntrySheet(
                              context: context,
                              mealType: widget.mealType,
                              speechService: widget.speechService,
                              nutritionService: widget.nutritionService,
                              repository: widget.repository,
                            );
                          },
                    icon: const Icon(Icons.mic_none_rounded),
                    label: const Text('使用系统语音'),
                  ),
                ],
                const SizedBox(height: 8),
                OutlinedButton.icon(
                  onPressed: _saving
                      ? null
                      : () {
                          Navigator.of(context).pop();
                          widget.onCopyYesterday();
                        },
                  icon: const Icon(Icons.content_copy_rounded),
                  label: const Text('复制昨日'),
                ),
                OutlinedButton.icon(
                  onPressed: _saving
                      ? null
                      : () {
                          Navigator.of(context).pop();
                          widget.onCustomFood();
                        },
                  icon: const Icon(Icons.edit_note_rounded),
                  label: const Text('自定义食物'),
                ),
                if (_preview.isNotEmpty) ...[
                  const SizedBox(height: 18),
                  const Text(
                    '分析预览',
                    style: TextStyle(fontWeight: FontWeight.w700),
                  ),
                  ..._preview.map(
                    (item) => ListTile(
                      contentPadding: EdgeInsets.zero,
                      title: Text(item.name),
                      subtitle: Text(
                        '${item.amount.toStringAsFixed(0)}${item.unit} · ${item.kcal.toInt()} kcal',
                      ),
                    ),
                  ),
                  FilledButton(
                    onPressed: _saving ? null : _savePreview,
                    child: Text(_saving ? '保存中...' : '确认记录'),
                  ),
                ],
                if (_error != null) ...[
                  const SizedBox(height: 8),
                  Text(
                    _error!,
                    style: const TextStyle(color: Colors.redAccent),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}
