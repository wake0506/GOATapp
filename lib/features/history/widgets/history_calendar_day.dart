import 'package:flutter/material.dart';

class HistoryCalendarDay extends StatelessWidget {
  const HistoryCalendarDay({
    super.key,
    required this.day,
    required this.dateKey,
    required this.isSelected,
    required this.hasRecord,
    required this.hasTraining,
    required this.onTap,
  });

  final int day;
  final String dateKey;
  final bool isSelected;
  final bool hasRecord;
  final bool hasTraining;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => GestureDetector(
    onTap: onTap,
    child: Container(
      margin: const EdgeInsets.all(4),
      alignment: Alignment.center,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            key: Key('history-calendar-date-$dateKey'),
            width: 24,
            height: 24,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: isSelected ? const Color(0xFF008C8C) : Colors.transparent,
              shape: BoxShape.circle,
              border: hasTraining
                  ? Border.all(
                      color: isSelected ? Colors.white : Colors.redAccent,
                      width: 1.5,
                    )
                  : null,
            ),
            child: Text(
              '$day',
              style: TextStyle(
                color: isSelected ? Colors.white : Colors.black87,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                fontSize: 13,
              ),
            ),
          ),
          const SizedBox(height: 1),
          SizedBox(
            height: 10,
            child: hasRecord
                ? Icon(
                    Icons.check,
                    key: Key('history-calendar-check-$dateKey'),
                    size: 10,
                    color: const Color(0xFF008C8C),
                  )
                : null,
          ),
        ],
      ),
    ),
  );
}
