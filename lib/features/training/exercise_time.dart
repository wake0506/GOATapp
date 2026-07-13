import 'package:flutter/services.dart';

class ExerciseEndTime {
  final String value;
  final bool isNextDay;

  const ExerciseEndTime({required this.value, required this.isNextDay});
}

int? parse24HourTime(String text) {
  final match = RegExp(r'^(\d{2}):(\d{2})$').firstMatch(text.trim());
  if (match == null) return null;
  final hour = int.parse(match.group(1)!);
  final minute = int.parse(match.group(2)!);
  if (hour > 23 || minute > 59) return null;
  return hour * 60 + minute;
}

String format24HourTime(int totalMinutes) {
  final minutes = totalMinutes % (24 * 60);
  final hour = minutes ~/ 60;
  final minute = minutes % 60;
  return '${hour.toString().padLeft(2, '0')}:${minute.toString().padLeft(2, '0')}';
}

ExerciseEndTime calculateExerciseEndTime({
  required String startTime,
  required int hours,
  required int minutes,
}) {
  final start = parse24HourTime(startTime);
  if (start == null || hours < 0 || hours > 6 || minutes < 0 || minutes > 59) {
    throw const FormatException('Invalid exercise time');
  }
  final duration = hours * 60 + minutes;
  if (duration == 0) throw const FormatException('Duration must be positive');
  final end = start + duration;
  return ExerciseEndTime(
    value: format24HourTime(end),
    isNextDay: end >= 24 * 60,
  );
}

class TimeTextInputFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    final digits = newValue.text
        .replaceAll(RegExp(r'\D'), '')
        .substring(
          0,
          newValue.text.replaceAll(RegExp(r'\D'), '').length.clamp(0, 4),
        );
    final formatted = digits.length <= 2
        ? digits
        : '${digits.substring(0, 2)}:${digits.substring(2)}';
    return TextEditingValue(
      text: formatted,
      selection: TextSelection.collapsed(offset: formatted.length),
    );
  }
}
