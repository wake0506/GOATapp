import 'package:flutter/material.dart';

import '../domain/training_session_state.dart';

class SetTypeSelectorSheet {
  const SetTypeSelectorSheet._();

  static const labels = <TrainingSetType, String>{
    TrainingSetType.working: '正式组',
    TrainingSetType.warmup: '热身组',
    TrainingSetType.drop: '递减组',
    TrainingSetType.amrap: 'AMRAP',
    TrainingSetType.failure: '力竭组',
    TrainingSetType.superset: '超级组',
  };

  static Future<TrainingSetType?> show(
    BuildContext context, {
    required TrainingSetType current,
  }) => showModalBottomSheet<TrainingSetType>(
    context: context,
    backgroundColor: Colors.white,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
    ),
    builder: (context) => SafeArea(
      child: ListView(
        shrinkWrap: true,
        padding: const EdgeInsets.fromLTRB(16, 14, 16, 18),
        children: [
          const Padding(
            padding: EdgeInsets.fromLTRB(8, 4, 8, 8),
            child: Text(
              '组类型',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700),
            ),
          ),
          for (final type in TrainingSetType.values)
            ListTile(
              title: Text(labels[type]!),
              trailing: type == current
                  ? const Icon(Icons.check, color: Color(0xFF008C8C))
                  : null,
              textColor: type == current
                  ? const Color(0xFF008C8C)
                  : const Color(0xFF515957),
              onTap: () => Navigator.pop(context, type),
            ),
        ],
      ),
    ),
  );
}
