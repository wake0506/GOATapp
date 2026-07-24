import 'ai_memory.dart';
import 'ai_suggestion.dart';

class AiCoachState {
  const AiCoachState({
    this.memories = const [],
    this.suggestions = const [],
    this.feedback = const [],
    this.schemaVersion = 1,
  });

  final List<AiMemoryItem> memories;
  final List<AiSuggestion> suggestions;
  final List<SuggestionFeedback> feedback;
  final int schemaVersion;

  AiCoachState copyWith({
    List<AiMemoryItem>? memories,
    List<AiSuggestion>? suggestions,
    List<SuggestionFeedback>? feedback,
  }) => AiCoachState(
    memories: memories ?? this.memories,
    suggestions: suggestions ?? this.suggestions,
    feedback: feedback ?? this.feedback,
    schemaVersion: schemaVersion,
  );

  Map<String, dynamic> toJson() => {
    'schemaVersion': schemaVersion,
    'memories': memories.map((item) => item.toJson()).toList(),
    'suggestions': suggestions.map((item) => item.toJson()).toList(),
    'feedback': feedback.map((item) => item.toJson()).toList(),
  };

  factory AiCoachState.fromJson(Map<String, dynamic> json) => AiCoachState(
    schemaVersion: json['schemaVersion'] is num
        ? (json['schemaVersion'] as num).toInt()
        : 1,
    memories: (json['memories'] as List<dynamic>? ?? const [])
        .whereType<Map>()
        .map((item) => AiMemoryItem.fromJson(Map<String, dynamic>.from(item)))
        .toList(),
    suggestions: (json['suggestions'] as List<dynamic>? ?? const [])
        .whereType<Map>()
        .map((item) => AiSuggestion.fromJson(Map<String, dynamic>.from(item)))
        .toList(),
    feedback: (json['feedback'] as List<dynamic>? ?? const [])
        .whereType<Map>()
        .map(
          (item) =>
              SuggestionFeedback.fromJson(Map<String, dynamic>.from(item)),
        )
        .toList(),
  );
}
