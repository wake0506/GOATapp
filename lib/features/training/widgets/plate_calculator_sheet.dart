import 'package:flutter/material.dart';

import '../services/plate_calculator_service.dart';

class PlateCalculatorSheet extends StatefulWidget {
  const PlateCalculatorSheet({super.key, required this.initialTarget});

  final double initialTarget;

  static Future<double?> show(
    BuildContext context, {
    required double initialTarget,
  }) => showModalBottomSheet<double>(
    context: context,
    backgroundColor: Colors.white,
    isScrollControlled: true,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
    ),
    builder: (_) => PlateCalculatorSheet(initialTarget: initialTarget),
  );

  @override
  State<PlateCalculatorSheet> createState() => _PlateCalculatorSheetState();
}

class _PlateCalculatorSheetState extends State<PlateCalculatorSheet> {
  static const _service = PlateCalculatorService();
  late final TextEditingController _targetController = TextEditingController(
    text: widget.initialTarget > 0
        ? widget.initialTarget.toStringAsFixed(1)
        : '100.0',
  );
  double _barWeight = 20;
  Set<double> _plates = {...PlateCalculatorService.defaultPlateSizes};
  double? _selectedTotal;

  PlateCalculationResult get _result => _service.calculate(
    targetTotalWeight: double.tryParse(_targetController.text) ?? 0,
    barWeight: _barWeight,
    availablePlateSizes: _plates.toList(),
  );

  @override
  void dispose() {
    _targetController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final result = _result;
    final selectedTotal =
        _selectedTotal ?? (result.isValid ? result.actualTotalWeight : null);
    return SafeArea(
      child: Padding(
        padding: EdgeInsets.fromLTRB(
          20,
          20,
          20,
          18 + MediaQuery.viewInsetsOf(context).bottom,
        ),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text(
                '杠铃片计算器',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 16),
              TextField(
                key: const Key('plate-target-input'),
                controller: _targetController,
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
                decoration: const InputDecoration(
                  labelText: '目标总重量 (kg)',
                  border: OutlineInputBorder(),
                ),
                onChanged: (_) => setState(() => _selectedTotal = null),
              ),
              const SizedBox(height: 8),
              ListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('杠铃重量'),
                trailing: Text('${_barWeight.toStringAsFixed(1)} kg  ›'),
                onTap: _chooseBarWeight,
              ),
              ListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('可用杠铃片'),
                trailing: Text('${_plates.length} 种  ›'),
                onTap: _choosePlates,
              ),
              const Divider(),
              if (!result.isValid)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  child: Text(
                    result.errorMessage!,
                    style: const TextStyle(color: Color(0xFF7D8583)),
                  ),
                )
              else ...[
                const SizedBox(height: 8),
                Text(
                  result.exact ? '每侧加装' : '当前片型无法精确配重',
                  style: const TextStyle(
                    fontSize: 14,
                    color: Color(0xFF6E7775),
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  result.platesPerSide.isEmpty
                      ? '无需加片'
                      : result.platesPerSide
                            .map((plate) => '${plate.toStringAsFixed(2)} kg')
                            .join(' + '),
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  '实际总重量 ${result.actualTotalWeight.toStringAsFixed(1)} kg',
                  style: const TextStyle(color: Color(0xFF008C8C)),
                ),
                if (!result.exact) ...[
                  const SizedBox(height: 12),
                  if (result.lowerAlternative != null)
                    _AlternativeTile(
                      label: '最近较低',
                      alternative: result.lowerAlternative!,
                      selected:
                          selectedTotal == result.lowerAlternative!.totalWeight,
                      onTap: () => setState(
                        () => _selectedTotal =
                            result.lowerAlternative!.totalWeight,
                      ),
                    ),
                  if (result.upperAlternative != null)
                    _AlternativeTile(
                      label: '最近较高',
                      alternative: result.upperAlternative!,
                      selected:
                          selectedTotal == result.upperAlternative!.totalWeight,
                      onTap: () => setState(
                        () => _selectedTotal =
                            result.upperAlternative!.totalWeight,
                      ),
                    ),
                ],
              ],
              const SizedBox(height: 18),
              FilledButton(
                key: const Key('plate-apply-button'),
                onPressed: selectedTotal == null
                    ? null
                    : () => Navigator.pop(context, selectedTotal),
                style: FilledButton.styleFrom(
                  backgroundColor: const Color(0xFF008C8C),
                  minimumSize: const Size.fromHeight(52),
                ),
                child: const Text('应用到当前组'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _chooseBarWeight() async {
    final selected = await showModalBottomSheet<double>(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              title: const Text('20 kg'),
              onTap: () => Navigator.pop(context, 20),
            ),
            ListTile(
              title: const Text('15 kg'),
              onTap: () => Navigator.pop(context, 15),
            ),
            ListTile(
              title: const Text('自定义'),
              onTap: () async {
                final navigator = Navigator.of(context);
                navigator.pop();
                final custom = await _customBarWeight();
                if (custom != null && mounted) {
                  setState(() {
                    _barWeight = custom;
                    _selectedTotal = null;
                  });
                }
              },
            ),
          ],
        ),
      ),
    );
    if (selected != null && mounted) {
      setState(() {
        _barWeight = selected;
        _selectedTotal = null;
      });
    }
  }

  Future<double?> _customBarWeight() async {
    final controller = TextEditingController(text: _barWeight.toString());
    final value = await showDialog<double>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('自定义杠铃重量'),
        content: TextField(
          controller: controller,
          autofocus: true,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          decoration: const InputDecoration(suffixText: 'kg'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () =>
                Navigator.pop(context, double.tryParse(controller.text)),
            child: const Text('确定'),
          ),
        ],
      ),
    );
    controller.dispose();
    return value != null && value > 0 ? value : null;
  }

  Future<void> _choosePlates() async {
    final selected = {..._plates};
    final result = await showModalBottomSheet<Set<double>>(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) => StatefulBuilder(
        builder: (context, setSheetState) => SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 18),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    '可用杠铃片',
                    style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700),
                  ),
                ),
                for (final plate in PlateCalculatorService.defaultPlateSizes)
                  CheckboxListTile(
                    value: selected.contains(plate),
                    activeColor: const Color(0xFF008C8C),
                    title: Text('${plate.toStringAsFixed(2)} kg'),
                    onChanged: (checked) => setSheetState(() {
                      checked == true
                          ? selected.add(plate)
                          : selected.remove(plate);
                    }),
                  ),
                FilledButton(
                  onPressed: () => Navigator.pop(context, selected),
                  style: FilledButton.styleFrom(
                    backgroundColor: const Color(0xFF008C8C),
                    minimumSize: const Size.fromHeight(48),
                  ),
                  child: const Text('完成'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
    if (result != null && mounted) {
      setState(() {
        _plates = result;
        _selectedTotal = null;
      });
    }
  }
}

class _AlternativeTile extends StatelessWidget {
  const _AlternativeTile({
    required this.label,
    required this.alternative,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final PlateLoadAlternative alternative;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => ListTile(
    contentPadding: EdgeInsets.zero,
    title: Text('$label ${alternative.totalWeight.toStringAsFixed(1)} kg'),
    subtitle: Text(
      alternative.platesPerSide.isEmpty
          ? '每侧无需加片'
          : '每侧 ${alternative.platesPerSide.map((plate) => plate.toStringAsFixed(2)).join(' + ')} kg',
    ),
    trailing: selected
        ? const Icon(Icons.check_circle, color: Color(0xFF008C8C))
        : const Icon(Icons.circle_outlined, color: Color(0xFF9AA19F)),
    onTap: onTap,
  );
}
