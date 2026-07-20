import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../models/training_template.dart';

class TrainingTemplateStore {
  TrainingTemplateStore({
    required SharedPreferences preferences,
    required String namespace,
  }) : _preferences = preferences,
       _key = 'goat_${namespace}_training_templates_v1';

  final SharedPreferences _preferences;
  final String _key;

  List<TrainingTemplate> load() {
    final raw = _preferences.getString(_key);
    if (raw == null || raw.trim().isEmpty) return const [];
    try {
      final decoded = jsonDecode(raw);
      if (decoded is! List) return const [];
      return decoded
          .whereType<Map>()
          .map(
            (value) =>
                TrainingTemplate.fromJson(Map<String, dynamic>.from(value)),
          )
          .where(
            (template) =>
                template.id.isNotEmpty &&
                template.name.trim().isNotEmpty &&
                template.exerciseIds.isNotEmpty,
          )
          .toList(growable: false);
    } catch (_) {
      return const [];
    }
  }

  Future<void> save(TrainingTemplate template) async {
    final templates = [...load()];
    final index = templates.indexWhere((item) => item.id == template.id);
    if (index == -1) {
      templates.add(template);
    } else {
      templates[index] = template;
    }
    await _write(templates);
  }

  Future<void> delete(String templateId) async {
    await _write(load().where((item) => item.id != templateId).toList());
  }

  Future<void> _write(List<TrainingTemplate> templates) async {
    final saved = await _preferences.setString(
      _key,
      jsonEncode(templates.map((item) => item.toJson()).toList()),
    );
    if (!saved) throw StateError('训练方案保存失败');
  }
}
