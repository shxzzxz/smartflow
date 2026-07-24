import '../../domain/import/import_models.dart';
import '../../domain/import/import_persistence_models.dart';

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

class ImportMappingTarget {
  const ImportMappingTarget({
    required this.id,
    required this.name,
    required this.displayPath,
    required this.kind,
    required this.isArchived,
  });

  final String id;
  final String name;
  final String displayPath;
  final ImportMappingTargetKind kind;
  final bool isArchived;
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
  const ImportMappingCreation({required this.name, required this.kind});

  final String name;
  final ImportMappingTargetKind kind;
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
  }) : issues = List.unmodifiable(issues),
       effectiveMappings = Map.unmodifiable(effectiveMappings),
       compatibleTargetKinds = Map.unmodifiable({
         for (final entry in compatibleTargetKinds.entries)
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
    Map<int, Map<ImportMappingKey, String>> groupMappingOverrides = const {},
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
       groupMappingOverrides =
           Map<int, Map<ImportMappingKey, String>>.unmodifiable({
             for (final entry in groupMappingOverrides.entries)
               entry.key: Map<ImportMappingKey, String>.unmodifiable(
                 entry.value,
               ),
           }),
       groups = List.unmodifiable(groups);

  final ImportParseResult plan;
  final Map<ImportMappingKey, String> defaultMappings;
  final Map<ImportMappingKey, String> effectiveMappings;
  final List<ImportMappingSuggestion> suggestions;
  final Map<ImportMappingKey, ImportMappingCreation> plannedCreations;
  final List<ImportMappingTarget> targets;
  final Map<ImportMappingKey, Set<ImportMappingTargetKind>>
  compatibleTargetKinds;
  final Map<int, Map<ImportMappingKey, String>> groupMappingOverrides;
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
