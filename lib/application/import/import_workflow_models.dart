import '../../domain/import/import_models.dart';
import '../../domain/import/import_persistence_models.dart';

enum ImportMappingAction { map, create, unresolved }

String importSourceDescription(ImportSourceEntity entity) {
  if (entity.kind == ImportEntityKind.category) {
    return switch (entity.categoryKind) {
      ImportCategoryKind.income => '收入分类',
      ImportCategoryKind.expense => '支出分类',
      null => '分类',
    };
  }
  return '账户';
}

String importTargetDescription(ImportTargetDescriptor descriptor) {
  return switch (descriptor) {
    ImportTargetDescriptor.incomeCategory => '收入分类',
    ImportTargetDescriptor.expenseCategory => '支出分类',
    ImportTargetDescriptor.fundAccount => '资金账户',
    ImportTargetDescriptor.reimbursementAccount => '报销账户',
    ImportTargetDescriptor.creditAccount => '信用账户',
    ImportTargetDescriptor.loanAccount => '贷款账户',
    ImportTargetDescriptor.ghostAccount => '无账户',
    ImportTargetDescriptor.unsupported => '不支持',
  };
}

sealed class ImportMappingDecision {
  const ImportMappingDecision();
}

class ExistingTargetDecision extends ImportMappingDecision {
  const ExistingTargetDecision(this.targetId);

  final String targetId;
}

class PlannedCreationDecision extends ImportMappingDecision {
  const PlannedCreationDecision(this.creation);

  final ImportMappingCreation creation;
}

class UnresolvedDecision extends ImportMappingDecision {
  const UnresolvedDecision(this.reason);

  final String reason;
}

class ImportMappingReviewItem {
  ImportMappingReviewItem({
    required this.key,
    required this.sourceName,
    required this.sourceDescription,
    required this.action,
    this.targetName,
    this.targetId,
    this.targetPath,
    this.targetDescription,
    this.existingTargetOptions = const [],
    this.creationOptions = const [],
    this.issues = const [],
    this.decision,
  });

  final ImportMappingKey key;
  final String sourceName;
  final String sourceDescription;
  final ImportMappingAction action;
  final String? targetName;
  final String? targetId;
  final String? targetPath;
  final String? targetDescription;
  final List<ImportMappingTarget> existingTargetOptions;
  final List<ImportMappingCreation> creationOptions;
  final List<ImportIssue> issues;
  final ImportMappingDecision? decision;

  ImportMappingDecision get effectiveDecision {
    final current = decision;
    if (current != null) return current;
    return switch (action) {
      ImportMappingAction.map when targetId != null => ExistingTargetDecision(
        targetId!,
      ),
      ImportMappingAction.create when creationOptions.isNotEmpty =>
        PlannedCreationDecision(creationOptions.first),
      _ => const UnresolvedDecision('当前映射尚未完成。'),
    };
  }

  ImportMappingReviewItem copyWith({
    String? sourceName,
    String? sourceDescription,
    ImportMappingAction? action,
    Object? targetName = _mappingItemSentinel,
    Object? targetId = _mappingItemSentinel,
    Object? targetPath = _mappingItemSentinel,
    Object? targetDescription = _mappingItemSentinel,
    List<ImportMappingTarget>? existingTargetOptions,
    List<ImportMappingCreation>? creationOptions,
    List<ImportIssue>? issues,
    Object? decision = _mappingItemSentinel,
  }) {
    return ImportMappingReviewItem(
      key: key,
      sourceName: sourceName ?? this.sourceName,
      sourceDescription: sourceDescription ?? this.sourceDescription,
      action: action ?? this.action,
      targetName:
          targetName == _mappingItemSentinel
              ? this.targetName
              : targetName as String?,
      targetId:
          targetId == _mappingItemSentinel
              ? this.targetId
              : targetId as String?,
      targetPath:
          targetPath == _mappingItemSentinel
              ? this.targetPath
              : targetPath as String?,
      targetDescription:
          targetDescription == _mappingItemSentinel
              ? this.targetDescription
              : targetDescription as String?,
      existingTargetOptions:
          existingTargetOptions ?? this.existingTargetOptions,
      creationOptions: creationOptions ?? this.creationOptions,
      issues: issues ?? this.issues,
      decision:
          decision == _mappingItemSentinel
              ? this.decision
              : decision as ImportMappingDecision?,
    );
  }
}

const Object _mappingItemSentinel = Object();

/// Mapping targets exposed to the feature layer.
///
/// The import workflow deliberately does not expose its ledger port.  This
/// small read model keeps target role information available to the UI without
/// leaking an infrastructure/domain adapter across the application seam.
enum ImportMappingTargetKind {
  asset,
  liability,
  reimbursement,
  incomeCategory,
  expenseCategory,
  ghost,
  unsupported,
}

extension ImportMappingTargetKindDescriptor on ImportMappingTargetKind {
  ImportTargetDescriptor get defaultDescriptor => switch (this) {
    ImportMappingTargetKind.asset => ImportTargetDescriptor.fundAccount,
    // A legacy liability kind does not identify a credit card versus a loan.
    ImportMappingTargetKind.liability => ImportTargetDescriptor.unsupported,
    ImportMappingTargetKind.reimbursement =>
      ImportTargetDescriptor.reimbursementAccount,
    ImportMappingTargetKind.incomeCategory =>
      ImportTargetDescriptor.incomeCategory,
    ImportMappingTargetKind.expenseCategory =>
      ImportTargetDescriptor.expenseCategory,
    ImportMappingTargetKind.ghost => ImportTargetDescriptor.ghostAccount,
    ImportMappingTargetKind.unsupported => ImportTargetDescriptor.unsupported,
  };
}

extension ImportTargetDescriptorMappingProjection on ImportTargetDescriptor {
  ImportMappingTargetKind get legacyMappingKind => switch (this) {
    ImportTargetDescriptor.fundAccount => ImportMappingTargetKind.asset,
    ImportTargetDescriptor.reimbursementAccount =>
      ImportMappingTargetKind.reimbursement,
    ImportTargetDescriptor.creditAccount ||
    ImportTargetDescriptor.loanAccount => ImportMappingTargetKind.liability,
    ImportTargetDescriptor.incomeCategory =>
      ImportMappingTargetKind.incomeCategory,
    ImportTargetDescriptor.expenseCategory =>
      ImportMappingTargetKind.expenseCategory,
    ImportTargetDescriptor.ghostAccount => ImportMappingTargetKind.ghost,
    ImportTargetDescriptor.unsupported => ImportMappingTargetKind.unsupported,
  };
}

class ImportMappingTarget {
  const ImportMappingTarget({
    required this.id,
    required this.name,
    required this.displayPath,
    required this.kind,
    required this.isArchived,
    this.descriptor,
  });

  final String id;
  final String name;
  final String displayPath;
  final ImportMappingTargetKind kind;
  final bool isArchived;
  final ImportTargetDescriptor? descriptor;

  ImportTargetDescriptor get effectiveDescriptor =>
      descriptor ?? kind.defaultDescriptor;
}

class ImportMappingKey {
  const ImportMappingKey({
    required this.source,
    required this.entityKind,
    required this.sourceEntityKey,
  });

  factory ImportMappingKey.fromEntity(ImportSourceEntity entity) {
    return ImportMappingKey(
      source: entity.source,
      entityKind: entity.kind,
      sourceEntityKey: entity.sourceEntityKey,
    );
  }

  final ImportSource source;
  final ImportEntityKind entityKind;
  final String sourceEntityKey;

  @override
  bool operator ==(Object other) {
    return other is ImportMappingKey &&
        other.source == source &&
        other.entityKind == entityKind &&
        other.sourceEntityKey == sourceEntityKey;
  }

  @override
  int get hashCode => Object.hash(source, entityKind, sourceEntityKey);
}

class ImportMappingSuggestion {
  const ImportMappingSuggestion({
    required this.key,
    required this.targetAccountId,
  });

  final ImportMappingKey key;
  final String targetAccountId;
}

/// A mapping target that will be created inside the eventual import commit.
///
/// Keeping this as a plan rather than creating ledger data during review lets
/// users cancel or revise an import without leaving unused accounts behind.
class ImportMappingCreation {
  const ImportMappingCreation({
    required this.name,
    required this.kind,
    this.descriptor,
    this.pathSegments = const [],
    this.defaultParametersHint,
  });

  final String name;
  final ImportMappingTargetKind kind;
  final ImportTargetDescriptor? descriptor;
  final List<String> pathSegments;
  final String? defaultParametersHint;

  ImportTargetDescriptor get effectiveDescriptor =>
      descriptor ?? kind.defaultDescriptor;
}

class ImportGroupReview {
  ImportGroupReview({
    required this.index,
    required this.group,
    required List<ImportIssue> issues,
    required this.isExactDuplicate,
    required this.isSuspectedDuplicate,
    Map<ImportMappingKey, String> effectiveMappings = const {},
    Map<ImportMappingKey, Set<ImportMappingTargetKind>> compatibleTargetKinds =
        const {},
    Map<ImportMappingKey, Set<ImportTargetDescriptor>>
        compatibleTargetDescriptors =
        const {},
  }) : issues = List.unmodifiable(issues),
       effectiveMappings = Map.unmodifiable(effectiveMappings),
       compatibleTargetKinds = Map.unmodifiable({
         for (final entry in compatibleTargetKinds.entries)
           entry.key: Set.unmodifiable(entry.value),
       }),
       compatibleTargetDescriptors = Map.unmodifiable({
         for (final entry in compatibleTargetDescriptors.entries)
           entry.key: Set.unmodifiable(entry.value),
       });

  final int index;
  final ImportTransactionGroupDraft group;
  final List<ImportIssue> issues;
  final bool isExactDuplicate;
  final bool isSuspectedDuplicate;
  final Map<ImportMappingKey, String> effectiveMappings;
  final Map<ImportMappingKey, Set<ImportMappingTargetKind>>
  compatibleTargetKinds;
  final Map<ImportMappingKey, Set<ImportTargetDescriptor>>
  compatibleTargetDescriptors;

  bool get isBlocked => issues.any((issue) => issue.isBlocking);
  bool get hasWarnings =>
      isSuspectedDuplicate || issues.any((issue) => issue.isWarning);
  bool get requiresWarningConfirmation => hasWarnings;
  bool get canSelect => !isExactDuplicate && !isBlocked;
}

class ImportPlanReview {
  ImportPlanReview({
    required this.plan,
    required Map<ImportMappingKey, String> defaultMappings,
    required Map<ImportMappingKey, String> effectiveMappings,
    required List<ImportMappingSuggestion> suggestions,
    Map<ImportMappingKey, ImportMappingCreation> plannedCreations = const {},
    List<ImportMappingTarget> targets = const [],
    Map<ImportMappingKey, Set<ImportMappingTargetKind>> compatibleTargetKinds =
        const {},
    Map<ImportMappingKey, Set<ImportTargetDescriptor>>
        compatibleTargetDescriptors =
        const {},
    Map<int, Map<ImportMappingKey, String>> groupMappingOverrides = const {},
    List<ImportMappingReviewItem> mappingItems = const [],
    required List<ImportGroupReview> groups,
  }) : defaultMappings = Map.unmodifiable(defaultMappings),
       effectiveMappings = Map.unmodifiable(effectiveMappings),
       suggestions = List.unmodifiable(suggestions),
       plannedCreations = Map.unmodifiable(plannedCreations),
       targets = List.unmodifiable(targets),
       compatibleTargetKinds = Map.unmodifiable({
         for (final entry in compatibleTargetKinds.entries)
           entry.key: Set.unmodifiable(entry.value),
       }),
       compatibleTargetDescriptors = Map.unmodifiable({
         for (final entry in compatibleTargetDescriptors.entries)
           entry.key: Set.unmodifiable(entry.value),
       }),
       groupMappingOverrides =
           Map<int, Map<ImportMappingKey, String>>.unmodifiable({
             for (final entry in groupMappingOverrides.entries)
               entry.key: Map<ImportMappingKey, String>.unmodifiable(
                 entry.value,
               ),
           }),
       mappingItems = List.unmodifiable(mappingItems),
       groups = List.unmodifiable(groups);

  final ImportParseResult plan;
  final Map<ImportMappingKey, String> defaultMappings;
  final Map<ImportMappingKey, String> effectiveMappings;
  final List<ImportMappingSuggestion> suggestions;
  final Map<ImportMappingKey, ImportMappingCreation> plannedCreations;
  final List<ImportMappingTarget> targets;
  final Map<ImportMappingKey, Set<ImportMappingTargetKind>>
  compatibleTargetKinds;
  final Map<ImportMappingKey, Set<ImportTargetDescriptor>>
  compatibleTargetDescriptors;
  final Map<int, Map<ImportMappingKey, String>> groupMappingOverrides;
  final List<ImportMappingReviewItem> mappingItems;
  final List<ImportGroupReview> groups;
}

class ImportCommitCommand {
  ImportCommitCommand({
    required this.plan,
    required Map<ImportMappingKey, String> mappings,
    Map<ImportMappingKey, ImportMappingCreation> plannedCreations = const {},
    required Set<int> selectedGroupIndexes,
    Set<int> confirmedSuspectedDuplicateIndexes = const {},
    Set<int> confirmedWarningIndexes = const {},
    Map<int, Map<ImportMappingKey, String>> groupMappingOverrides = const {},
    this.saveMappingConfiguration = false,
    this.importedAt,
  }) : mappings = Map.unmodifiable(mappings),
       plannedCreations = Map.unmodifiable(plannedCreations),
       selectedGroupIndexes = Set.unmodifiable(selectedGroupIndexes),
       confirmedSuspectedDuplicateIndexes = Set.unmodifiable(
         confirmedSuspectedDuplicateIndexes,
       ),
       confirmedWarningIndexes = Set.unmodifiable(confirmedWarningIndexes),
       groupMappingOverrides =
           Map<int, Map<ImportMappingKey, String>>.unmodifiable({
             for (final entry in groupMappingOverrides.entries)
               entry.key: Map<ImportMappingKey, String>.unmodifiable(
                 entry.value,
               ),
           });

  final ImportParseResult plan;
  final Map<ImportMappingKey, String> mappings;
  final Map<ImportMappingKey, ImportMappingCreation> plannedCreations;
  final Set<int> selectedGroupIndexes;
  final Set<int> confirmedSuspectedDuplicateIndexes;
  final Set<int> confirmedWarningIndexes;
  final Map<int, Map<ImportMappingKey, String>> groupMappingOverrides;
  final bool saveMappingConfiguration;
  final DateTime? importedAt;
}

class ImportCommitResult {
  ImportCommitResult({
    required this.batch,
    required this.skippedGroupCount,
    Map<ImportMappingKey, String> createdMappings = const {},
  }) : createdMappings = Map.unmodifiable(createdMappings);

  final ImportBatch? batch;
  final int skippedGroupCount;
  final Map<ImportMappingKey, String> createdMappings;

  bool get createdBatch => batch != null;
}
