import '../import_models.dart';

abstract interface class SourceRecord {
  int get rowNumber;

  List<ImportIssue> get issues;
}

/// Normalized facts directly expressed by one source file.
class SourceFileFact {
  SourceFileFact({
    required this.fileIndex,
    required this.fileName,
    required this.fileType,
    Iterable<SourceRecord> records = const [],
    Iterable<ImportSourceEntity> localEntities = const [],
    Iterable<ImportIssue> issues = const [],
  }) : records = List.unmodifiable(records),
       localEntities = List.unmodifiable(localEntities),
       issues = List.unmodifiable(issues);

  final int fileIndex;
  final String fileName;
  final ImportSourceFileType fileType;
  final List<SourceRecord> records;
  final List<ImportSourceEntity> localEntities;
  final List<ImportIssue> issues;
}

class ParseUnitResult {
  ParseUnitResult({
    Iterable<ImportSourceEntity> derivedEntities = const [],
    Iterable<ImportTransactionGroupDraft> groups = const [],
    Iterable<ImportFilteredRecord> filteredRecords = const [],
    Iterable<ImportIssue> issues = const [],
  }) : derivedEntities = List.unmodifiable(derivedEntities),
       groups = List.unmodifiable(groups),
       filteredRecords = List.unmodifiable(filteredRecords),
       issues = List.unmodifiable(issues);

  final List<ImportSourceEntity> derivedEntities;
  final List<ImportTransactionGroupDraft> groups;
  final List<ImportFilteredRecord> filteredRecords;
  final List<ImportIssue> issues;
}

/// One source-semantic parsing step. A unit may require one file type or a
/// complete set of file types, which keeps future joined-file rules local.
abstract interface class ParseUnit {
  String get key;

  Set<ImportSourceFileType> get requiredFileTypes;

  ParseUnitResult parse(Map<ImportSourceFileType, SourceFileFact> facts);
}

class ParseUnitExecution {
  const ParseUnitExecution({required this.unit, required this.result});

  final ParseUnit unit;
  final ParseUnitResult result;
}

/// Executes independent and joined ParseUnits in their declared stable order.
class ParseUnitPlan {
  ParseUnitPlan(Iterable<ParseUnit> units) : _units = List.unmodifiable(units);

  final List<ParseUnit> _units;

  List<ParseUnitExecution> execute(
    Map<ImportSourceFileType, SourceFileFact> facts,
  ) {
    final executions = <ParseUnitExecution>[];
    for (final unit in _units) {
      final fileIssues = [
        for (final fileType in unit.requiredFileTypes)
          ...?facts[fileType]?.issues.where((issue) => issue.rowNumber == null),
      ];
      final present = unit.requiredFileTypes.where(facts.containsKey).toSet();
      if (present.isEmpty) continue;
      if (present.length != unit.requiredFileTypes.length) {
        final missing = unit.requiredFileTypes.difference(present);
        executions.add(
          ParseUnitExecution(
            unit: unit,
            result: ParseUnitResult(
              issues: [
                ImportIssue(
                  code: 'parse_unit_companion_file_missing',
                  message:
                      '${unit.key} 缺少联合解析所需文件：'
                      '${missing.map((type) => type.label).join('、')}。',
                  severity: ImportIssueSeverity.blocking,
                ),
                ...fileIssues,
              ],
            ),
          ),
        );
        continue;
      }
      final parsed = unit.parse(facts);
      executions.add(
        ParseUnitExecution(
          unit: unit,
          result: ParseUnitResult(
            derivedEntities: parsed.derivedEntities,
            groups: parsed.groups,
            filteredRecords: parsed.filteredRecords,
            issues: [...parsed.issues, ...fileIssues],
          ),
        ),
      );
    }
    return executions;
  }
}

/// Source-neutral assembler for normalized file facts and ParseUnit results.
///
/// It centralizes ordering, source-entity constraint merging, parse issues and
/// duplicate operation-key detection so individual source parsers only need to
/// orchestrate file recognition and declare their ParseUnits.
class ImportPlanAssembler {
  const ImportPlanAssembler();

  ImportParseResult assemble({
    required ImportSource source,
    required Iterable<ImportFileParseResult> fileResults,
    required Iterable<SourceFileFact> facts,
    required Iterable<ParseUnitExecution> executions,
    Iterable<ImportIssue> fatalIssues = const [],
  }) {
    final entities = <String, ImportSourceEntity>{};
    final issues = <ImportIssue>[];
    final orderedFacts = facts.toList(growable: false)..sort((left, right) {
      final byType = left.fileType.key.compareTo(right.fileType.key);
      return byType != 0 ? byType : left.fileIndex.compareTo(right.fileIndex);
    });
    for (final fact in orderedFacts) {
      _addIssues(issues, fact.issues.where((issue) => issue.rowNumber == null));
      for (final entity in fact.localEntities) {
        _mergeEntity(entities, entity);
      }
    }

    final groups = <ImportTransactionGroupDraft>[];
    final filteredRecords = <ImportFilteredRecord>[];
    for (final execution in executions) {
      final executionIssues = execution.result.issues;
      _addIssues(issues, executionIssues);
      for (final entity in execution.result.derivedEntities) {
        _mergeEntity(entities, entity);
      }
      for (final group in execution.result.groups) {
        final groupIssues = [
          ...group.issues,
          for (final issue in executionIssues)
            if (!_containsEquivalentIssue(group.issues, issue)) issue,
        ];
        groups.add(
          groupIssues.length == group.issues.length
              ? group
              : group.copyWith(issues: groupIssues),
        );
      }
      filteredRecords.addAll(execution.result.filteredRecords);
    }
    _markDuplicateOperationKeys(groups);

    return ImportParseResult(
      source: source,
      fileResults: fileResults,
      sourceEntities: entities.values,
      groups: groups,
      filteredRecords: filteredRecords,
      issues: issues,
      fatalIssues: fatalIssues,
    );
  }

  void _mergeEntity(
    Map<String, ImportSourceEntity> entities,
    ImportSourceEntity incoming,
  ) {
    final current = entities[incoming.sourceEntityKey];
    if (current == null) {
      entities[incoming.sourceEntityKey] = incoming;
      return;
    }
    if (current.source != incoming.source ||
        current.kind != incoming.kind ||
        current.categoryKind != incoming.categoryKind) {
      entities[incoming.sourceEntityKey] = current.copyWith(
        hasTargetDescriptorConflict: true,
      );
      return;
    }
    final allowed = switch ((
      current.allowedTargetDescriptors.isEmpty,
      incoming.allowedTargetDescriptors.isEmpty,
    )) {
      (true, true) => const <ImportTargetDescriptor>{},
      (true, false) => incoming.allowedTargetDescriptors,
      (false, true) => current.allowedTargetDescriptors,
      (false, false) => current.allowedTargetDescriptors.intersection(
        incoming.allowedTargetDescriptors,
      ),
    };
    final constraintConflict =
        current.hasTargetDescriptorConflict ||
        incoming.hasTargetDescriptorConflict ||
        (current.allowedTargetDescriptors.isNotEmpty &&
            incoming.allowedTargetDescriptors.isNotEmpty &&
            allowed.isEmpty);
    final preferred =
        current.preferredTargetDescriptor ?? incoming.preferredTargetDescriptor;
    entities[incoming.sourceEntityKey] = current.copyWith(
      isReviewPlaceholder:
          current.isReviewPlaceholder || incoming.isReviewPlaceholder,
      allowedTargetDescriptors: allowed,
      preferredTargetDescriptor: preferred,
      hasTargetDescriptorConflict: constraintConflict,
    );
  }

  void _markDuplicateOperationKeys(List<ImportTransactionGroupDraft> groups) {
    final firstByKey = <String, int>{};
    for (var index = 0; index < groups.length; index++) {
      final key = groups[index].sourceOperationKey;
      if (key == null) continue;
      final first = firstByKey[key];
      if (first == null) {
        firstByKey[key] = index;
        continue;
      }
      final issue = ImportIssue(
        code: 'duplicate_source_operation_key',
        message: '资料包内重复的来源操作键：$key',
        severity: ImportIssueSeverity.blocking,
      );
      groups[index] = _appendGroupIssue(groups[index], issue);
      groups[first] = _appendGroupIssue(groups[first], issue);
    }
  }

  bool _containsEquivalentIssue(
    Iterable<ImportIssue> existing,
    ImportIssue incoming,
  ) {
    return existing.any(
      (issue) =>
          issue.code == incoming.code &&
          issue.rowNumber == incoming.rowNumber &&
          issue.message == incoming.message &&
          issue.severity == incoming.severity &&
          issue.fileType == incoming.fileType,
    );
  }

  void _addIssues(List<ImportIssue> target, Iterable<ImportIssue> incoming) {
    for (final issue in incoming) {
      if (!_containsEquivalentIssue(target, issue)) target.add(issue);
    }
  }

  ImportTransactionGroupDraft _appendGroupIssue(
    ImportTransactionGroupDraft group,
    ImportIssue issue,
  ) {
    if (_containsEquivalentIssue(group.issues, issue)) return group;
    return group.copyWith(issues: [...group.issues, issue]);
  }
}
