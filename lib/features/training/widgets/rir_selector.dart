import 'package:flutter/material.dart';

class RirSelector extends StatelessWidget {
  const RirSelector({
    super.key,
    required this.value,
    required this.onChanged,
    required this.onHelp,
  });

  final int? value;
  final ValueChanged<int> onChanged;
  final VoidCallback onHelp;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Expanded(
              child: Text(
                '剩余次数 RIR',
                style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
              ),
            ),
            IconButton(
              onPressed: onHelp,
              icon: const Icon(Icons.help_outline, size: 19),
              visualDensity: VisualDensity.compact,
            ),
          ],
        ),
        const SizedBox(height: 8),
        Container(
          padding: const EdgeInsets.all(4),
          decoration: BoxDecoration(
            color: const Color(0xFFE9ECEB),
            borderRadius: BorderRadius.circular(14),
          ),
          child: Row(
            children: [
              for (final rir in const [3, 2, 1, 0])
                Expanded(
                  child: InkWell(
                    key: Key('training-rir-$rir'),
                    onTap: () => onChanged(rir),
                    borderRadius: BorderRadius.circular(11),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 150),
                      padding: const EdgeInsets.symmetric(vertical: 11),
                      decoration: BoxDecoration(
                        color: value == rir
                            ? const Color(0xFF008C8C)
                            : Colors.transparent,
                        borderRadius: BorderRadius.circular(11),
                      ),
                      child: Text(
                        rir == 3 ? '3+' : '$rir',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: value == rir
                              ? Colors.white
                              : const Color(0xFF737B79),
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }
}
