import 'dart:math';

import 'package:package_info_plus/package_info_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class SyncDiagnosticsService {
  static const _deviceKey = 'goat_sync_diagnostics_device_id_v1';
  final SupabaseClient client;
  final SharedPreferences preferences;
  final Duration minInterval;
  DateTime? _lastSentAt;
  String? _lastFingerprint;

  SyncDiagnosticsService({
    required this.client,
    required this.preferences,
    this.minInterval = const Duration(seconds: 30),
  });

  Future<void> report({
    required bool syncEnabled,
    required int pendingOperations,
    DateTime? lastSuccessAt,
    String? errorCode,
    DateTime? errorAt,
    bool force = false,
  }) async {
    final user = client.auth.currentUser;
    if (user == null || user.isAnonymous || pendingOperations < 0) return;
    final fingerprint =
        '$syncEnabled:$pendingOperations:${lastSuccessAt?.toIso8601String()}:${errorCode ?? ''}:${errorAt?.toIso8601String()}';
    final now = DateTime.now().toUtc();
    if (!force &&
        fingerprint == _lastFingerprint &&
        _lastSentAt != null &&
        now.difference(_lastSentAt!) < minInterval)
      return;
    final info = await PackageInfo.fromPlatform();
    await client.from('sync_diagnostics').upsert({
      'user_id': user.id,
      'device_id': _deviceId(),
      'app_version': info.version,
      'sync_enabled': syncEnabled,
      'pending_operations': pendingOperations,
      'last_success_at': lastSuccessAt?.toUtc().toIso8601String(),
      'last_error_code': errorCode,
      'last_error_at': errorAt?.toUtc().toIso8601String(),
    }, onConflict: 'user_id,device_id');
    _lastSentAt = now;
    _lastFingerprint = fingerprint;
  }

  String _deviceId() {
    final existing = preferences.getString(_deviceKey);
    if (existing != null && existing.isNotEmpty) return existing;
    final random = Random.secure();
    final value = List.generate(
      4,
      (_) => random.nextInt(0x100000000).toRadixString(16).padLeft(8, '0'),
    ).join();
    preferences.setString(_deviceKey, value);
    return value;
  }
}
