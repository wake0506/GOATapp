import 'dart:convert';

import '../../../models/json_value.dart';
import 'ai_suggestion.dart';

enum AiCoachUncertainty {
  insufficientEvidence,
  missingUserContext,
  needsConfirmation,
}

class AiCoachResponse {
  const AiCoachResponse({
    required this.answer,
    required this.summary,
    this.evidenceRefs = const [],
    this.knowledgeRefs = const [],
    this.suggestions = const [],
    this.uncertainties = const [],
    this.usedFallback = false,
  });

  final String answer;
  final String summary;
  final List<String> evidenceRefs;
  final List<String> knowledgeRefs;
  final List<AiSuggestion> suggestions;
  final List<AiCoachUncertainty> uncertainties;
  final bool usedFallback;

  AiCoachResponse copyWith({
    List<String>? evidenceRefs,
    List<String>? knowledgeRefs,
    List<AiSuggestion>? suggestions,
    List<AiCoachUncertainty>? uncertainties,
    bool? usedFallback,
  }) => AiCoachResponse(
    answer: answer,
    summary: summary,
    evidenceRefs: evidenceRefs ?? this.evidenceRefs,
    knowledgeRefs: knowledgeRefs ?? this.knowledgeRefs,
    suggestions: suggestions ?? this.suggestions,
    uncertainties: uncertainties ?? this.uncertainties,
    usedFallback: usedFallback ?? this.usedFallback,
  );
}

class AiCoachResponseParser {
  const AiCoachResponseParser();

  AiCoachResponse parse(Object? payload) {
    final decoded = payload is String ? _decode(payload) : payload;
    if (decoded is! Map) {
      throw const FormatException('AI response must be a JSON object.');
    }
    final json = Map<String, dynamic>.from(decoded);
    final answer = stringValue(json['answer']).trim();
    if (answer.isEmpty) {
      throw const FormatException('AI response answer is empty.');
    }
    return AiCoachResponse(
      answer: answer,
      summary: stringValue(json['summary'], answer).trim(),
      evidenceRefs: _strings(json['evidenceRefs']),
      knowledgeRefs: _strings(json['knowledgeRefs']),
      suggestions: (json['suggestions'] as List<dynamic>? ?? const [])
          .whereType<Map>()
          .map((item) => AiSuggestion.fromJson(Map<String, dynamic>.from(item)))
          .toList(),
      uncertainties: _strings(json['uncertainties'])
          .map(
            (name) => AiCoachUncertainty.values
                .where((item) => item.name == name)
                .firstOrNull,
          )
          .whereType<AiCoachUncertainty>()
          .toList(),
    );
  }

  Object? _decode(String payload) {
    var normalized = payload.trim();
    if (normalized.startsWith('```')) {
      normalized = normalized
          .replaceFirst(RegExp(r'^```(?:json)?\s*'), '')
          .replaceFirst(RegExp(r'\s*```$'), '');
    }
    return jsonDecode(normalized);
  }

  List<String> _strings(Object? value) => (value as List<dynamic>? ?? const [])
      .map((item) => '$item'.trim())
      .where((item) => item.isNotEmpty)
      .toList();
}

extension _FirstOrNull<T> on Iterable<T> {
  T? get firstOrNull {
    final iterator = this.iterator;
    return iterator.moveNext() ? iterator.current : null;
  }
}
