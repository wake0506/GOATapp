import '../../../models/rest_prescription.dart';
import '../../training/models/training_template.dart';
import '../../training/services/training_template_store.dart';
import '../models/ai_suggestion.dart';

class TrainingAiActionService {
  const TrainingAiActionService({required this.templateStore});

  final TrainingTemplateStore templateStore;

  Future<bool> validate(AiProposedAction action) async {
    if (action.type != AiProposedActionType.updateRestPrescription) {
      return false;
    }
    final templateId = action.payload['templateId'];
    final exerciseId = action.payload['exerciseId'];
    final fixedSeconds = action.payload['fixedSeconds'];
    if (templateId is! String ||
        templateId.trim().isEmpty ||
        exerciseId is! String ||
        exerciseId.trim().isEmpty ||
        fixedSeconds is! num ||
        fixedSeconds.toInt() < 15 ||
        fixedSeconds.toInt() > 600) {
      return false;
    }
    final template = templateStore
        .load()
        .where((item) => item.id == templateId)
        .firstOrNull;
    return template != null && template.exerciseIds.contains(exerciseId);
  }

  Future<void> apply(AiProposedAction action) async {
    if (!await validate(action)) {
      throw StateError('休息方案建议不再符合当前训练方案');
    }
    final templateId = action.payload['templateId'] as String;
    final exerciseId = action.payload['exerciseId'] as String;
    final fixedSeconds = (action.payload['fixedSeconds'] as num).toInt();
    final template = templateStore.load().firstWhere(
      (item) => item.id == templateId,
    );
    final updated = TrainingTemplate(
      id: template.id,
      name: template.name,
      exerciseIds: template.exerciseIds,
      progressionTargets: template.progressionTargets,
      restPrescriptions: {
        ...template.restPrescriptions,
        exerciseId: RestPrescription.fixed(fixedSeconds),
      },
    );
    await templateStore.save(updated);
  }
}

extension _FirstOrNull<T> on Iterable<T> {
  T? get firstOrNull {
    final iterator = this.iterator;
    return iterator.moveNext() ? iterator.current : null;
  }
}
