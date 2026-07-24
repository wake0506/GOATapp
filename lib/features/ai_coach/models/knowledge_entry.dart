enum KnowledgeCategory {
  trainingPrinciples,
  progression,
  restAndRecovery,
  exerciseSelection,
  trainingCoverage,
  nutritionGeneral,
  weightTrend,
  goatRuleExplanations,
}

enum KnowledgeSourceType {
  goatProductRule,
  engineeringRule,
  curatedGeneralPrinciple,
  userProvided,
}

enum KnowledgeReviewStatus { approved, draft, deprecated }

class KnowledgeEntry {
  const KnowledgeEntry({
    required this.id,
    required this.category,
    required this.title,
    required this.content,
    required this.tags,
    required this.applicableContexts,
    this.source = 'GOAT 已冻结产品规则',
    this.sourceType = KnowledgeSourceType.goatProductRule,
    this.version = 1,
    this.reviewStatus = KnowledgeReviewStatus.approved,
    this.stablePriority = 0,
  });

  final String id;
  final KnowledgeCategory category;
  final String title;
  final String content;
  final List<String> tags;
  final List<String> applicableContexts;
  final String source;
  final KnowledgeSourceType sourceType;
  final int version;
  final KnowledgeReviewStatus reviewStatus;
  final int stablePriority;

  Map<String, dynamic> toContextJson() => {
    'id': id,
    'category': category.name,
    'title': title,
    'content': content,
    'version': version,
    'source': source,
  };
}

class KnowledgeIntegrityReport {
  const KnowledgeIntegrityReport({
    required this.total,
    required this.approved,
    required this.draft,
    required this.deprecated,
    required this.duplicateIds,
    required this.invalidEntries,
  });

  final int total;
  final int approved;
  final int draft;
  final int deprecated;
  final Set<String> duplicateIds;
  final Set<String> invalidEntries;

  bool get isValid => duplicateIds.isEmpty && invalidEntries.isEmpty;
}
