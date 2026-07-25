import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../models/ai_coach_state.dart';
import '../models/ai_memory.dart';
import '../models/ai_suggestion.dart';

class AiCoachLocalRepository {
  AiCoachLocalRepository({
    required SharedPreferences preferences,
    required String namespace,
  }) : _preferences = preferences,
       _namespace = namespace;

  final SharedPreferences _preferences;
  final String _namespace;

  String get _key => 'goat_${_namespace}_ai_coach_v1';

  AiCoachState load() {
    final raw = _preferences.getString(_key);
    if (raw == null || raw.trim().isEmpty) return const AiCoachState();
    try {
      final decoded = jsonDecode(raw);
      return decoded is Map
          ? AiCoachState.fromJson(Map<String, dynamic>.from(decoded))
          : const AiCoachState();
    } catch (_) {
      return const AiCoachState();
    }
  }

  Future<void> save(AiCoachState state) async {
    final saved = await _preferences.setString(
      _key,
      jsonEncode(state.toJson()),
    );
    if (!saved) throw StateError('AI 教练本地数据写入失败');
  }

  Future<void> clear() async {
    final removed = await _preferences.remove(_key);
    if (!removed && _preferences.containsKey(_key)) {
      throw StateError('AI 教练本地命名空间清理失败');
    }
  }

  Future<AiCoachState> addUserProvided({
    required AiProfileCategory category,
    required String value,
    DateTime? now,
  }) async {
    final trimmed = value.trim();
    if (trimmed.isEmpty) throw ArgumentError.value(value, 'value', '不能为空');
    final timestamp = now ?? DateTime.now();
    final id =
        'user_${timestamp.microsecondsSinceEpoch}_${category.name.hashCode.abs()}';
    final item = AiMemoryItem(
      id: id,
      category: category,
      value: trimmed,
      sourceType: AiMemorySourceType.userProvided,
      status: AiMemoryStatus.active,
      createdAt: timestamp,
      updatedAt: timestamp,
      sourceRefs: const [
        AiMemorySourceRef(
          type: 'user_input',
          id: 'profile_editor',
          label: '你在 GOAT 中主动填写',
        ),
      ],
      confidenceLevel: AiMemoryConfidence.high,
      userConfirmed: true,
    );
    final state = load();
    final next = state.copyWith(memories: [...state.memories, item]);
    await save(next);
    return next;
  }

  Future<AiCoachState> setUserProfileValue({
    required AiProfileCategory category,
    String? value,
    DateTime? now,
  }) async {
    final state = load();
    final stableKey = 'user_profile_${category.name}';
    final existing = state.memories
        .where(
          (item) =>
              item.stableKey == stableKey &&
              item.sourceType == AiMemorySourceType.userProvided,
        )
        .firstOrNull;
    final trimmed = value?.trim() ?? '';
    if (trimmed.isEmpty) {
      if (existing == null) return state;
      final next = state.copyWith(
        memories: _upsert(
          state.memories,
          existing.copyWith(
            status: AiMemoryStatus.archived,
            updatedAt: now ?? DateTime.now(),
          ),
        ),
      );
      await save(next);
      return next;
    }

    final timestamp = now ?? DateTime.now();
    final item = AiMemoryItem(
      id: existing?.id ?? stableKey,
      stableKey: stableKey,
      category: category,
      value: trimmed,
      sourceType: AiMemorySourceType.userProvided,
      status: AiMemoryStatus.active,
      createdAt: existing?.createdAt ?? timestamp,
      updatedAt: timestamp,
      sourceRefs: const [
        AiMemorySourceRef(
          type: 'user_input',
          id: 'profile_account_center',
          label: '你在个人主页中主动设置',
        ),
      ],
      confidenceLevel: AiMemoryConfidence.high,
      userConfirmed: true,
    );
    final next = state.copyWith(memories: _upsert(state.memories, item));
    await save(next);
    return next;
  }

  Future<AiCoachState> addInference(AiMemoryItem inference) async {
    if (inference.sourceType != AiMemorySourceType.aiInferred) {
      throw ArgumentError('Only AI-inferred memories can be added here.');
    }
    final state = load();
    if (_isSuppressed(state.memories, inference.stableKey)) return state;
    final item = inference.copyWith(
      status: AiMemoryStatus.pendingConfirmation,
      userConfirmed: false,
    );
    final next = state.copyWith(memories: _upsert(state.memories, item));
    await save(next);
    return next;
  }

  Future<AiCoachState> upsertDerived(
    Iterable<AiMemoryItem> derivedItems,
  ) async {
    final state = load();
    var memories = [...state.memories];
    for (final item in derivedItems) {
      if (item.sourceType != AiMemorySourceType.behaviorDerived ||
          item.stableKey == null ||
          _isSuppressed(memories, item.stableKey)) {
        continue;
      }
      memories = _upsert(memories, item);
    }
    final next = state.copyWith(memories: memories);
    await save(next);
    return next;
  }

  Future<AiCoachState> editMemory(String id, String value) async {
    final trimmed = value.trim();
    if (trimmed.isEmpty) throw ArgumentError.value(value, 'value', '不能为空');
    final state = load();
    final target = state.memories.where((item) => item.id == id).firstOrNull;
    if (target == null ||
        target.sourceType != AiMemorySourceType.userProvided) {
      throw StateError('只有你主动提供的信息可以直接编辑');
    }
    final updated = target.copyWith(value: trimmed, updatedAt: DateTime.now());
    final next = state.copyWith(memories: _upsert(state.memories, updated));
    await save(next);
    return next;
  }

  Future<AiCoachState> setMemoryStatus(String id, AiMemoryStatus status) async {
    final state = load();
    final target = state.memories.where((item) => item.id == id).firstOrNull;
    if (target == null) return state;
    final confirmed = status == AiMemoryStatus.active
        ? true
        : target.userConfirmed;
    final updated = target.copyWith(
      status: status,
      userConfirmed: confirmed,
      updatedAt: DateTime.now(),
    );
    final next = state.copyWith(memories: _upsert(state.memories, updated));
    await save(next);
    return next;
  }

  Future<AiCoachState> archiveMemory(String id) =>
      setMemoryStatus(id, AiMemoryStatus.archived);

  Future<AiCoachState> saveSuggestion(AiSuggestion suggestion) async {
    final state = load();
    final next = state.copyWith(
      suggestions: _upsertSuggestion(state.suggestions, suggestion),
    );
    await save(next);
    return next;
  }

  Future<AiCoachState> recordFeedback(SuggestionFeedback feedback) async {
    final state = load();
    final next = state.copyWith(feedback: [...state.feedback, feedback]);
    await save(next);
    return next;
  }

  Future<AiCoachState> mergeFrom(AiCoachState source) async {
    var target = load();
    var memories = [...target.memories];
    for (final memory in source.memories) {
      final key = memory.stableKey;
      if (key != null && _isSuppressed(memories, key)) continue;
      memories = _upsert(memories, memory);
    }
    var suggestions = [...target.suggestions];
    for (final suggestion in source.suggestions) {
      suggestions = _upsertSuggestion(suggestions, suggestion);
    }
    final feedbackIds = target.feedback
        .map(
          (item) => '${item.suggestionId}:${item.createdAt.toIso8601String()}',
        )
        .toSet();
    final feedback = [
      ...target.feedback,
      ...source.feedback.where(
        (item) => feedbackIds.add(
          '${item.suggestionId}:${item.createdAt.toIso8601String()}',
        ),
      ),
    ];
    target = target.copyWith(
      memories: memories,
      suggestions: suggestions,
      feedback: feedback,
    );
    await save(target);
    return target;
  }

  bool _isSuppressed(List<AiMemoryItem> items, String? stableKey) {
    if (stableKey == null) return false;
    return items.any(
      (item) => item.stableKey == stableKey && item.isSuppressed,
    );
  }

  List<AiMemoryItem> _upsert(List<AiMemoryItem> items, AiMemoryItem incoming) {
    final index = incoming.stableKey == null
        ? items.indexWhere((item) => item.id == incoming.id)
        : items.indexWhere(
            (item) =>
                item.stableKey == incoming.stableKey &&
                item.sourceType == incoming.sourceType,
          );
    if (index < 0) return [...items, incoming];
    final next = [...items];
    next[index] = incoming.copyWith(createdAt: items[index].createdAt);
    return next;
  }

  List<AiSuggestion> _upsertSuggestion(
    List<AiSuggestion> items,
    AiSuggestion incoming,
  ) {
    final index = items.indexWhere((item) => item.id == incoming.id);
    if (index < 0) return [...items, incoming];
    final next = [...items];
    next[index] = incoming;
    return next;
  }
}

extension _FirstOrNull<T> on Iterable<T> {
  T? get firstOrNull {
    final iterator = this.iterator;
    return iterator.moveNext() ? iterator.current : null;
  }
}
