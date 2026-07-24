import 'package:flutter_test/flutter_test.dart';
import 'package:goat_app/features/ai_coach/models/ai_coach_response.dart';
import 'package:goat_app/features/ai_coach/models/ai_suggestion.dart';
import 'package:goat_app/features/ai_coach/services/ai_coach_response_validator.dart';
import 'package:goat_app/features/ai_coach/services/ai_context_assembler.dart';
import 'package:goat_app/features/ai_coach/services/ai_suggestion_service.dart';
import 'package:goat_app/features/ai_coach/services/knowledge_retrieval_service.dart';
import 'package:goat_app/features/ai_coach/services/training_ai_action_service.dart';
import 'package:goat_app/features/training/models/training_template.dart';
import 'package:goat_app/features/training/services/training_template_store.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  const transitions = AiSuggestionTransitionService();

  test('suggestion status supports proposed feedback decisions', () {
    final suggestion = _suggestion();

    expect(
      transitions.transition(suggestion, AiSuggestionStatus.accepted).status,
      AiSuggestionStatus.accepted,
    );
    expect(
      transitions.transition(suggestion, AiSuggestionStatus.modified).status,
      AiSuggestionStatus.modified,
    );
    expect(
      transitions.transition(suggestion, AiSuggestionStatus.rejected).status,
      AiSuggestionStatus.rejected,
    );
    expect(
      transitions.transition(suggestion, AiSuggestionStatus.dismissed).status,
      AiSuggestionStatus.dismissed,
    );
  });

  test('illegal terminal transition is safely rejected', () {
    final applied = _suggestion().copyWith(status: AiSuggestionStatus.applied);

    expect(
      () => transitions.transition(applied, AiSuggestionStatus.accepted),
      throwsStateError,
    );
  });

  test('unconfirmed action leaves domain and suggestion unchanged', () async {
    var persisted = false;
    final result = await const AiSuggestionApplicationService().apply(
      suggestion: _suggestion(),
      userConfirmed: false,
      validate: (_) async => true,
      persist: (_) async => persisted = true,
    );

    expect(result.status, AiSuggestionStatus.proposed);
    expect(persisted, isFalse);
  });

  test(
    'confirmed valid action applies only after persistence succeeds',
    () async {
      var fixedSeconds = 150;
      final result = await const AiSuggestionApplicationService().apply(
        suggestion: _suggestion(),
        userConfirmed: true,
        validate: (action) async =>
            action.type == AiProposedActionType.updateRestPrescription &&
            action.payload['fixedSeconds'] == 180,
        persist: (action) async {
          fixedSeconds = action.payload['fixedSeconds'] as int;
        },
      );

      expect(fixedSeconds, 180);
      expect(result.status, AiSuggestionStatus.applied);
    },
  );

  test('validation failure never marks suggestion applied', () async {
    final result = await const AiSuggestionApplicationService().apply(
      suggestion: _suggestion(),
      userConfirmed: true,
      validate: (_) async => false,
      persist: (_) async => fail('persist must not run'),
    );

    expect(result.status, AiSuggestionStatus.applyFailed);
    expect(result.failureMessage, isNotEmpty);
  });

  test(
    'persistence failure keeps accepted boundary and reports apply failure',
    () async {
      final result = await const AiSuggestionApplicationService().apply(
        suggestion: _suggestion(),
        userConfirmed: true,
        validate: (_) async => true,
        persist: (_) async => throw StateError('disk full'),
      );

      expect(result.status, AiSuggestionStatus.applyFailed);
      expect(result.status, isNot(AiSuggestionStatus.applied));
    },
  );

  test(
    'confirmed rest action validates and persists the real template',
    () async {
      SharedPreferences.setMockInitialValues({});
      final preferences = await SharedPreferences.getInstance();
      final store = TrainingTemplateStore(
        preferences: preferences,
        namespace: 'user_a',
      );
      await store.save(
        const TrainingTemplate(
          id: 'push_day',
          name: '推日',
          exerciseIds: ['barbell_flat_bench_press'],
        ),
      );
      final domain = TrainingAiActionService(templateStore: store);
      final suggestion = _suggestion().copyWith(
        proposedAction: const AiProposedAction(
          type: AiProposedActionType.updateRestPrescription,
          payload: {
            'templateId': 'push_day',
            'exerciseId': 'barbell_flat_bench_press',
            'fixedSeconds': 180,
          },
        ),
      );

      final result = await const AiSuggestionApplicationService().apply(
        suggestion: suggestion,
        userConfirmed: true,
        validate: domain.validate,
        persist: domain.apply,
      );

      expect(result.status, AiSuggestionStatus.applied);
      expect(
        store
            .load()
            .single
            .restFor('barbell_flat_bench_press')
            .validFixedSeconds,
        180,
      );
    },
  );

  test('unconfirmed rest action cannot mutate the real template', () async {
    SharedPreferences.setMockInitialValues({});
    final preferences = await SharedPreferences.getInstance();
    final store = TrainingTemplateStore(
      preferences: preferences,
      namespace: 'user_a',
    );
    await store.save(
      const TrainingTemplate(
        id: 'push_day',
        name: '推日',
        exerciseIds: ['barbell_flat_bench_press'],
      ),
    );
    final domain = TrainingAiActionService(templateStore: store);
    final suggestion = _suggestion().copyWith(
      proposedAction: const AiProposedAction(
        type: AiProposedActionType.updateRestPrescription,
        payload: {
          'templateId': 'push_day',
          'exerciseId': 'barbell_flat_bench_press',
          'fixedSeconds': 180,
        },
      ),
    );

    final result = await const AiSuggestionApplicationService().apply(
      suggestion: suggestion,
      userConfirmed: false,
      validate: domain.validate,
      persist: domain.apply,
    );

    expect(result.status, AiSuggestionStatus.proposed);
    expect(
      store.load().single.restFor('barbell_flat_bench_press').validFixedSeconds,
      isNull,
    );
  });

  test('structured response parser accepts fenced JSON', () {
    final response = const AiCoachResponseParser().parse('''
```json
{
  "answer": "保持当前重量。",
  "summary": "目标次数尚未完成。",
  "evidenceRefs": ["progression_recommendation"],
  "knowledgeRefs": ["kb_progression_keep_target_incomplete"],
  "suggestions": [],
  "uncertainties": []
}
```
''');

    expect(response.answer, '保持当前重量。');
    expect(response.knowledgeRefs, hasLength(1));
  });

  test('citation validator removes fake evidence and knowledge ids', () {
    const response = AiCoachResponse(
      answer: '解释',
      summary: '摘要',
      evidenceRefs: ['progression_recommendation', 'fake_data'],
      knowledgeRefs: ['kb_valid', 'kb_fake'],
    );
    const context = AssembledAiContext(
      taskType: AiCoachTaskType.progressionExplanation,
      payload: {},
      allowedEvidenceRefs: {'progression_recommendation'},
      allowedKnowledgeRefs: {'kb_valid', 'kb_other'},
    );

    final validated = const AiCoachResponseValidator().validate(
      response,
      context,
    );

    expect(validated.evidenceRefs, ['progression_recommendation']);
    expect(validated.knowledgeRefs, ['kb_valid']);
  });

  test(
    'explanation task removes actions that override deterministic engines',
    () {
      final response = AiCoachResponse(
        answer: '保持',
        summary: '保持',
        suggestions: [_suggestion()],
      );
      const context = AssembledAiContext(
        taskType: AiCoachTaskType.restExplanation,
        payload: {},
        allowedEvidenceRefs: {},
        allowedKnowledgeRefs: {},
      );

      final validated = const AiCoachResponseValidator().validate(
        response,
        context,
      );

      expect(validated.suggestions, isEmpty);
      expect(
        validated.uncertainties,
        contains(AiCoachUncertainty.insufficientEvidence),
      );
    },
  );
}

AiSuggestion _suggestion() => AiSuggestion(
  id: 'rest_suggestion',
  type: AiSuggestionType.rest,
  title: '固定卧推休息时间',
  summary: '你经常把卧推休息延长到约 3 分钟。',
  reasonCodes: const ['planned_actual_rest'],
  evidenceRefs: const ['training_session'],
  knowledgeRefs: const ['kb_rest_user_override'],
  proposedAction: const AiProposedAction(
    type: AiProposedActionType.updateRestPrescription,
    domainEntityId: 'barbell_flat_bench_press',
    payload: {'fixedSeconds': 180},
  ),
  dataQuality: AiSuggestionDataQuality.high,
  status: AiSuggestionStatus.proposed,
  createdAt: DateTime.utc(2026, 7, 24),
);
