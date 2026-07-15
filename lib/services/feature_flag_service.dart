import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class FeatureFlagService {
  static const _cacheKey = 'goat_feature_flags_v1';
  final SupabaseClient client;
  final SharedPreferences preferences;

  FeatureFlagService({required this.client, required this.preferences});

  Map<String, bool> cached() => _decode(preferences.getString(_cacheKey));

  Future<Map<String, bool>> refresh() async {
    final rows = await client.from('app_feature_flags').select('key, enabled');
    final flags = <String, bool>{
      for (final row in rows) row['key'].toString(): row['enabled'] == true,
    };
    await preferences.setString(_cacheKey, jsonEncode(flags));
    return flags;
  }

  bool isEnabled(
    String key, {
    required bool localCapability,
    bool defaultValue = false,
  }) {
    if (!localCapability) return false;
    return cached()[key] ?? defaultValue;
  }

  static Map<String, bool> _decode(String? raw) {
    if (raw == null) return const {};
    try {
      final value = jsonDecode(raw);
      if (value is Map)
        return value.map(
          (key, value) => MapEntry(key.toString(), value == true),
        );
    } catch (_) {}
    return const {};
  }
}
