import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../models/app_snapshot.dart';

class LocalStorageService {
  static const String _guestNamespace = 'guest';
  static const String _snapshotSuffix = 'snapshot_v1';
  static const String _migrationKey = 'goat_storage_migrated_v1';
  static const List<String> _legacyKeys = [
    'user_gender',
    'user_birthYear',
    'user_birthMonth',
    'user_birthDay',
    'user_height',
    'user_weight',
    'search_history_v2',
    'targetP',
    'targetC',
    'targetF',
    'targetKcal',
    'resetHour',
    'aiDismissedDate',
    'goat_database',
    'goat_consumed_v2',
    'goat_exercise',
    'goat_water',
    'goat_weight',
    'goat_training',
  ];

  final SharedPreferences prefs;

  LocalStorageService(this.prefs);

  static Future<LocalStorageService> create() async {
    return LocalStorageService(await SharedPreferences.getInstance());
  }

  String namespaceForUser(String? userId) {
    if (userId == null || userId.trim().isEmpty) return _guestNamespace;
    final safeId = userId.replaceAll(RegExp(r'[^a-zA-Z0-9_-]'), '_');
    return 'user_$safeId';
  }

  String _key(String namespace) => 'goat_${namespace}_$_snapshotSuffix';

  AppSnapshot? load(String namespace) {
    final raw = prefs.getString(_key(namespace));
    if (raw == null || raw.trim().isEmpty) return null;
    try {
      final decoded = jsonDecode(raw);
      if (decoded is Map) {
        return AppSnapshot.fromJson(Map<String, dynamic>.from(decoded));
      }
    } catch (_) {
      return null;
    }
    return null;
  }

  Future<void> save(String namespace, AppSnapshot snapshot) async {
    final saved = await prefs.setString(
      _key(namespace),
      jsonEncode(snapshot.toJson()),
    );
    if (!saved) throw StateError('本地数据写入失败');
  }

  Future<void> migrateLegacyGuestData() async {
    if (prefs.getBool(_migrationKey) == true) return;
    if (load(_guestNamespace) == null && _legacyDataExists()) {
      await save(_guestNamespace, _readLegacySnapshot());
    }
    await prefs.setBool(_migrationKey, true);
  }

  bool _legacyDataExists() {
    return _legacyKeys.any((key) => prefs.containsKey(key));
  }

  AppSnapshot _readLegacySnapshot() {
    List<Map<String, dynamic>> decodeList(String key) {
      final raw = prefs.getString(key);
      if (raw == null) return const [];
      try {
        final value = jsonDecode(raw);
        return value is List
            ? value
                  .whereType<Map>()
                  .map((e) => Map<String, dynamic>.from(e))
                  .toList()
            : const [];
      } catch (_) {
        return const [];
      }
    }

    Map<String, dynamic> legacy = {
      'gender': prefs.getString('user_gender') ?? '男',
      'birthYear': prefs.getInt('user_birthYear') ?? 2000,
      'birthMonth': prefs.getInt('user_birthMonth') ?? 1,
      'birthDay': prefs.getInt('user_birthDay') ?? 1,
      'height': prefs.getDouble('user_height') ?? 175,
      'currentWeight': prefs.getDouble('user_weight') ?? 70,
      'searchHistory': prefs.getStringList('search_history_v2') ?? const [],
      'targetP': prefs.getDouble('targetP') ?? 150,
      'targetC': prefs.getDouble('targetC') ?? 200,
      'targetF': prefs.getDouble('targetF') ?? 60,
      'targetKcal': prefs.getDouble('targetKcal') ?? 2000,
      'resetHour': prefs.getInt('resetHour') ?? 0,
      'aiDismissedDate': prefs.getString('aiDismissedDate') ?? '',
      'foods': decodeList('goat_database'),
      'consumed': decodeList('goat_consumed_v2'),
      'exercises': decodeList('goat_exercise'),
      'training': decodeList('goat_training'),
      'water': _decodeMap('goat_water'),
      'weight': _decodeMap('goat_weight'),
    };
    return AppSnapshot.fromJson(legacy);
  }

  Map<String, dynamic> _decodeMap(String key) {
    final raw = prefs.getString(key);
    if (raw == null) return {};
    try {
      final value = jsonDecode(raw);
      return value is Map ? Map<String, dynamic>.from(value) : {};
    } catch (_) {
      return {};
    }
  }

  Future<void> clearNamespace(String namespace) async {
    final removed = await prefs.remove(_key(namespace));
    if (!removed && prefs.containsKey(_key(namespace))) {
      throw StateError('本地命名空间清理失败');
    }
  }
}
