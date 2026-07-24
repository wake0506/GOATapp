import '../../../models/json_value.dart';

enum AiSuggestionType {
  training,
  progression,
  rest,
  exercise,
  nutrition,
  profile,
  memory,
}

enum AiSuggestionStatus {
  proposed,
  accepted,
  modified,
  rejected,
  dismissed,
  applied,
  applyFailed,
}

enum AiSuggestionDataQuality { high, medium, low, insufficient }

enum AiProposedActionType {
  updateTrainingPlan,
  updateProgressionTarget,
  updateRestPrescription,
  suggestExercise,
  updateCalorieGoal,
  updateProfile,
  createMemory,
}

enum SuggestionDecision { accepted, modified, rejected, dismissed }

enum SuggestionRejectionReason {
  notSuitable,
  inaccurateData,
  dislikeSuggestion,
  other,
}

class AiProposedAction {
  const AiProposedAction({
    required this.type,
    required this.payload,
    this.domainEntityId,
  });

  final AiProposedActionType type;
  final Map<String, dynamic> payload;
  final String? domainEntityId;

  Map<String, dynamic> toJson() => {
    'type': type.name,
    'payload': payload,
    'domainEntityId': domainEntityId,
  };

  factory AiProposedAction.fromJson(Map<String, dynamic> json) =>
      AiProposedAction(
        type:
            AiProposedActionType.values
                .where((item) => item.name == json['type'])
                .firstOrNull ??
            AiProposedActionType.createMemory,
        payload: json['payload'] is Map
            ? Map<String, dynamic>.from(json['payload'] as Map)
            : const {},
        domainEntityId: _optionalString(json['domainEntityId']),
      );
}

class AiSuggestion {
  const AiSuggestion({
    required this.id,
    required this.type,
    required this.title,
    required this.summary,
    required this.reasonCodes,
    required this.evidenceRefs,
    required this.knowledgeRefs,
    required this.dataQuality,
    required this.status,
    required this.createdAt,
    this.proposedAction,
    this.failureMessage,
  });

  final String id;
  final AiSuggestionType type;
  final String title;
  final String summary;
  final List<String> reasonCodes;
  final List<String> evidenceRefs;
  final List<String> knowledgeRefs;
  final AiProposedAction? proposedAction;
  final AiSuggestionDataQuality dataQuality;
  final AiSuggestionStatus status;
  final DateTime createdAt;
  final String? failureMessage;

  AiSuggestion copyWith({
    String? title,
    String? summary,
    AiProposedAction? proposedAction,
    AiSuggestionStatus? status,
    String? failureMessage,
    bool clearFailure = false,
  }) => AiSuggestion(
    id: id,
    type: type,
    title: title ?? this.title,
    summary: summary ?? this.summary,
    reasonCodes: reasonCodes,
    evidenceRefs: evidenceRefs,
    knowledgeRefs: knowledgeRefs,
    proposedAction: proposedAction ?? this.proposedAction,
    dataQuality: dataQuality,
    status: status ?? this.status,
    createdAt: createdAt,
    failureMessage: clearFailure ? null : failureMessage ?? this.failureMessage,
  );

  Map<String, dynamic> toJson() => {
    'id': id,
    'type': type.name,
    'title': title,
    'summary': summary,
    'reasonCodes': reasonCodes,
    'evidenceRefs': evidenceRefs,
    'knowledgeRefs': knowledgeRefs,
    'proposedAction': proposedAction?.toJson(),
    'dataQuality': dataQuality.name,
    'status': status.name,
    'createdAt': createdAt.toUtc().toIso8601String(),
    'failureMessage': failureMessage,
  };

  factory AiSuggestion.fromJson(Map<String, dynamic> json) => AiSuggestion(
    id: stringValue(json['id']),
    type:
        AiSuggestionType.values
            .where((item) => item.name == json['type'])
            .firstOrNull ??
        AiSuggestionType.training,
    title: stringValue(json['title'], 'GOAT 建议'),
    summary: stringValue(json['summary']),
    reasonCodes: _strings(json['reasonCodes']),
    evidenceRefs: _strings(json['evidenceRefs']),
    knowledgeRefs: _strings(json['knowledgeRefs']),
    proposedAction: json['proposedAction'] is Map
        ? AiProposedAction.fromJson(
            Map<String, dynamic>.from(json['proposedAction'] as Map),
          )
        : null,
    dataQuality:
        AiSuggestionDataQuality.values
            .where((item) => item.name == json['dataQuality'])
            .firstOrNull ??
        AiSuggestionDataQuality.insufficient,
    status:
        AiSuggestionStatus.values
            .where((item) => item.name == json['status'])
            .firstOrNull ??
        AiSuggestionStatus.proposed,
    createdAt:
        DateTime.tryParse(stringValue(json['createdAt'])) ?? DateTime.now(),
    failureMessage: _optionalString(json['failureMessage']),
  );
}

class SuggestionFeedback {
  const SuggestionFeedback({
    required this.suggestionId,
    required this.decision,
    required this.createdAt,
    this.modifiedAction,
    this.reasonCode,
  });

  final String suggestionId;
  final SuggestionDecision decision;
  final AiProposedAction? modifiedAction;
  final SuggestionRejectionReason? reasonCode;
  final DateTime createdAt;

  Map<String, dynamic> toJson() => {
    'suggestionId': suggestionId,
    'decision': decision.name,
    'modifiedAction': modifiedAction?.toJson(),
    'reasonCode': reasonCode?.name,
    'createdAt': createdAt.toUtc().toIso8601String(),
  };

  factory SuggestionFeedback.fromJson(Map<String, dynamic> json) =>
      SuggestionFeedback(
        suggestionId: stringValue(json['suggestionId']),
        decision:
            SuggestionDecision.values
                .where((item) => item.name == json['decision'])
                .firstOrNull ??
            SuggestionDecision.dismissed,
        modifiedAction: json['modifiedAction'] is Map
            ? AiProposedAction.fromJson(
                Map<String, dynamic>.from(json['modifiedAction'] as Map),
              )
            : null,
        reasonCode: SuggestionRejectionReason.values
            .where((item) => item.name == json['reasonCode'])
            .firstOrNull,
        createdAt:
            DateTime.tryParse(stringValue(json['createdAt'])) ?? DateTime.now(),
      );
}

List<String> _strings(Object? value) =>
    (value as List<dynamic>? ?? const []).map((item) => '$item').toList();

String? _optionalString(Object? value) {
  if (value is! String || value.trim().isEmpty) return null;
  return value.trim();
}

extension _FirstOrNull<T> on Iterable<T> {
  T? get firstOrNull {
    final iterator = this.iterator;
    return iterator.moveNext() ? iterator.current : null;
  }
}
