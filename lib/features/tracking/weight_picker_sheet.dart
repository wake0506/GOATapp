import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

double weightFromParts(int integerPart, int decimalPart) =>
    integerPart + decimalPart / 100;

String formatWeightValue(double value) => '${value.toStringAsFixed(2)} kg';

class WeightChange {
  final double currentWeight;
  final Map<String, double> dailyWeight;

  const WeightChange({required this.currentWeight, required this.dailyWeight});
}

WeightChange applyWeightChange({
  required Map<String, double> dailyWeight,
  required String date,
  required String today,
  required double currentWeight,
  required double value,
}) {
  final nextDailyWeight = {...dailyWeight, date: value};
  return WeightChange(
    currentWeight: date == today ? value : currentWeight,
    dailyWeight: nextDailyWeight,
  );
}

Future<void> showWeightPickerSheet({
  required BuildContext context,
  required double initialWeight,
  required ValueChanged<double> onSaved,
}) async {
  final value = await showModalBottomSheet<double>(
    context: context,
    backgroundColor: Colors.white,
    builder: (_) => WeightPickerSheet(initialWeight: initialWeight),
  );
  if (value != null) onSaved(value);
}

class WeightPickerSheet extends StatefulWidget {
  final double initialWeight;

  const WeightPickerSheet({super.key, required this.initialWeight});

  @override
  State<WeightPickerSheet> createState() => _WeightPickerSheetState();
}

class _WeightPickerSheetState extends State<WeightPickerSheet> {
  late int _integerPart;
  late int _decimalPart;

  @override
  void initState() {
    super.initState();
    final normalized = widget.initialWeight.clamp(20.0, 300.99);
    final hundredths = (normalized * 100).round().clamp(2000, 30099);
    _integerPart = hundredths ~/ 100;
    _decimalPart = hundredths % 100;
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 300,
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text(
                    '取消',
                    style: TextStyle(color: Colors.black38),
                  ),
                ),
                Text(
                  '${_integerPart.toString().padLeft(2, '0')} | ${_decimalPart.toString().padLeft(2, '0')} kg',
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 17,
                  ),
                ),
                TextButton(
                  onPressed: () => Navigator.pop(
                    context,
                    weightFromParts(_integerPart, _decimalPart),
                  ),
                  child: const Text(
                    '确定',
                    style: TextStyle(
                      color: Color(0xFF008C8C),
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: Row(
              children: [
                Expanded(
                  child: CupertinoPicker(
                    scrollController: FixedExtentScrollController(
                      initialItem: _integerPart - 20,
                    ),
                    itemExtent: 40,
                    onSelectedItemChanged: (index) =>
                        setState(() => _integerPart = 20 + index),
                    children: List.generate(
                      281,
                      (index) => Center(child: Text('${20 + index}')),
                    ),
                  ),
                ),
                const Text('.', style: TextStyle(fontSize: 24)),
                Expanded(
                  child: CupertinoPicker(
                    scrollController: FixedExtentScrollController(
                      initialItem: _decimalPart,
                    ),
                    itemExtent: 40,
                    onSelectedItemChanged: (index) =>
                        setState(() => _decimalPart = index),
                    children: List.generate(
                      100,
                      (index) =>
                          Center(child: Text(index.toString().padLeft(2, '0'))),
                    ),
                  ),
                ),
                const Padding(
                  padding: EdgeInsets.only(right: 24),
                  child: Text('kg'),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
