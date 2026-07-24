import '../../application/shared/transaction_runner.dart';
import '../../core/id/id_generator.dart';
import '../../domain/import/import_error_code.dart';
import '../../domain/import/import_models.dart';
import '../../domain/import/import_persistence_models.dart';
import '../../domain/import/port/import_batch_repository.dart';
import '../../domain/import/port/import_ledger_port.dart';
import '../../domain/import/port/import_mapping_repository.dart';
import 'import_workflow_models.dart';

abstract interface class ImportWorkflowAppService {
  Future<ImportPlanReview> review(
    ImportParseResult plan, {
    Map<ImportMappingKey, String> temporaryMappings = const {},
    Map<ImportMappingKey, ImportMappingCreation> plannedCreations = const {},
    Map<int, Map<ImportMappingKey, String>> groupMappingOverrides = const {},
  });

  Future<ImportCommitResult> commit(ImportCommitCommand command);

  Future<List<ImportBatch>> listBatches({ImportSource? source});

  Future<List<ImportBatchItem>> findBatchItems(String batchId);

  Future<ImportBatch> revertBatch(String batchId, {DateTime? revertedAt});
}

class ImportWorkflowAppServiceImpl implements ImportWorkflowAppService {
  ImportWorkflowAppServiceImpl({
    required ImportMappingRepository mappings,
    required ImportBatchRepository batches,
    required ImportLedgerPort ledger,
    required TransactionRunner transactionRunner,
    required IdGenerator idGenerator,
    DateTime Function()? now,
  }) : _mappings = mappings,
       _batches = batches,
       _ledger = ledger,
       _transactionRunner = transactionRunner,
       _idGenerator = idGenerator,
       _now = now ?? DateTime.now;

  final ImportMappingRepository _mappings;
  final ImportBatchRepository _batches;
  final ImportLedgerPort _ledger;
  final TransactionRunner _transactionRunner;
  final IdGenerator _idGenerator;
  final DateTime Function() _now;

  @override
  Future<ImportPlanReview> review(
    ImportParseResult plan, {
    Map<ImportMappingKey, String> temporaryMappings = const {},
    Map<ImportMappingKey, ImportMappingCreation> plannedCreations = const {},
    Map<int, Map<ImportMappingKey, String>> groupMappingOverrides = const {},
  }) async {
    _ensurePlanCanBeReviewed(plan);
    final stored = await _mappings.findBySource(plan.source);
    final defaults = {
      for (final mapping in stored)
        ImportMappingKey(
              source: mapping.source,
              entityKind: mapping.entityKind,
              sourceEntityKey: mapping.sourceEntityKey,
            ):
            mapping.targetAccountId,
    };
    final compatibleTargetKinds = _compatibleTargetKinds(plan);
    final ghostMappingKeys = _ghostMappingKeys(plan);
    final activeTargets = await _ledger.listTargets();
    final targets = [...activeTargets];
    final loadedTargetIds = {for (final target in targets) target.id};
    for (final targetId in {...defaults.values, ...temporaryMappings.values}) {
      if (loadedTargetIds.contains(targetId)) continue;
      final target = await _ledger.findTarget(targetId);
      if (target != null) {
        targets.add(target);
        loadedTargetIds.add(target.id);
      }
    }
    final effective = <ImportMappingKey, String>{
      ...defaults,
      ...temporaryMappings,
    }..removeWhere((key, _) => plannedCreations.containsKey(key));
    _removeUnavailableMappings(
      plan: plan,
      effectiveMappings: effective,
      targets: targets,
      compatibleTargetKinds: compatibleTargetKinds,
    );
    await _applyGhostPlaceholderMappings(
      plan: plan,
      effectiveMappings: effective,
      targets: targets,
      loadedTargetIds: loadedTargetIds,
      compatibleTargetKinds: compatibleTargetKinds,
    );
    final suggestions = _suggestMappings(
      plan: plan,
      effectiveMappings: effective,
      targets: targets,
      compatibleTargetKinds: compatibleTargetKinds,
      excludedKeys: plannedCreations.keys.toSet(),
    );
    final resolvedCreations = _resolveCreationPlans(
      plan: plan,
      requestedCreations: plannedCreations,
      effectiveMappings: effective,
      compatibleTargetKinds: compatibleTargetKinds,
    );
    effective.removeWhere((key, _) => resolvedCreations.containsKey(key));
    final currentFingerprints = _fingerprintCounts(plan.groups);
    final duplicateKeyIndexes = _duplicateOperationKeyIndexes(plan);
    final reviewPlaceholders = {
      for (final entity in plan.sourceEntities)
        if (entity.isReviewPlaceholder) entity.sourceEntityKey: entity,
    };
    final reviews = <ImportGroupReview>[];
    for (var index = 0; index < plan.groups.length; index++) {
      final group = plan.groups[index];
      final issues = [...group.issues];
      if (duplicateKeyIndexes.contains(index) &&
          !issues.any(
            (issue) => issue.code == 'duplicate_source_operation_key',
          )) {
        issues.add(
          const ImportIssue(
            code: 'duplicate_source_operation_key',
            message: '资料包内存在重复的来源操作键。',
            severity: ImportIssueSeverity.blocking,
          ),
        );
      }
      final groupMappings = <ImportMappingKey, String>{
        ...effective,
        ...?groupMappingOverrides[index],
      };
      issues.removeWhere(
        (issue) => _mappingRepairsParserIssue(
          issue: issue,
          group: group,
          placeholders: reviewPlaceholders,
          mappings: groupMappings,
          plannedCreations: resolvedCreations,
        ),
      );
      try {
        await _validateGroup(
          group,
          index,
          _ResolutionContext(
            source: plan.source,
            mappings: groupMappings,
            plannedCreations: resolvedCreations,
            ghostMappingKeys: ghostMappingKeys,
            ledger: _ledger,
          ),
        );
      } on ImportWorkflowException catch (exception) {
        issues.add(
          ImportIssue(
            code: exception.code,
            message: exception.message,
            severity: ImportIssueSeverity.blocking,
          ),
        );
      }
      final duplicates = await _batches.findDuplicates(
        source: plan.source,
        sourceOperationKey: group.sourceOperationKey,
        sourceOperationFingerprint: group.sourceOperationFingerprint,
        fingerprintVersion: group.fingerprintVersion,
      );
      final exact = duplicates.hasExactMatch;
      final inPlanFingerprintDuplicate =
          currentFingerprints[_fingerprintKey(group)]! > 1;
      reviews.add(
        ImportGroupReview(
          index: index,
          group: group,
          issues: issues,
          isExactDuplicate: exact,
          isSuspectedDuplicate:
              !exact &&
              (duplicates.hasFingerprintMatch || inPlanFingerprintDuplicate),
          effectiveMappings: groupMappings,
          compatibleTargetKinds: _compatibleTargetKindsForGroup(group),
        ),
      );
    }
    return ImportPlanReview(
      plan: plan,
      defaultMappings: defaults,
      effectiveMappings: effective,
      suggestions: suggestions,
      plannedCreations: resolvedCreations,
      targets: targets.map(_mapTarget).toList(growable: false),
      compatibleTargetKinds: compatibleTargetKinds,
      groupMappingOverrides: groupMappingOverrides,
      groups: reviews,
    );
  }

  ImportMappingTarget _mapTarget(ImportLedgerTarget target) {
    return ImportMappingTarget(
      id: target.id,
      name: target.name,
      displayPath: target.displayPath,
      kind: switch (target.kind) {
        ImportLedgerTargetKind.asset => ImportMappingTargetKind.asset,
        ImportLedgerTargetKind.liability => ImportMappingTargetKind.liability,
        ImportLedgerTargetKind.reimbursement =>
          ImportMappingTargetKind.reimbursement,
        ImportLedgerTargetKind.incomeCategory =>
          ImportMappingTargetKind.incomeCategory,
        ImportLedgerTargetKind.expenseCategory =>
          ImportMappingTargetKind.expenseCategory,
        ImportLedgerTargetKind.ghost => ImportMappingTargetKind.ghost,
        ImportLedgerTargetKind.unsupported =>
          ImportMappingTargetKind.unsupported,
      },
      isArchived: target.isArchived,
    );
  }

  @override
  Future<ImportCommitResult> commit(ImportCommitCommand command) async {
    _ensurePlanCanBeReviewed(command.plan);
    try {
      return await _transactionRunner.run(() async {
        final plan = command.plan;
        final currentFingerprints = _fingerprintCounts(plan.groups);
        final duplicateKeyIndexes = _duplicateOperationKeyIndexes(plan);
        final ghostMappingKeys = _ghostMappingKeys(plan);
        final reviewPlaceholders = {
          for (final entity in plan.sourceEntities)
            if (entity.isReviewPlaceholder) entity.sourceEntityKey: entity,
        };
        final importIndexes = <int>[];

        for (var index = 0; index < plan.groups.length; index++) {
          final group = plan.groups[index];
          final selected = command.selectedGroupIndexes.contains(index);
          if (!selected) continue;
          if (duplicateKeyIndexes.contains(index)) {
            throw ImportWorkflowException(
              ImportErrorCode.selectedGroupBlocked,
              message: '资料包内存在重复的来源操作键。',
              groupIndex: index,
            );
          }
          final groupMappings = <ImportMappingKey, String>{
            ...command.mappings,
            ...?command.groupMappingOverrides[index],
          };
          final hasUnresolvedBlockingIssue = group.issues.any(
            (issue) =>
                issue.isBlocking &&
                !_mappingRepairsParserIssue(
                  issue: issue,
                  group: group,
                  placeholders: reviewPlaceholders,
                  mappings: groupMappings,
                  plannedCreations: command.plannedCreations,
                ),
          );
          if (hasUnresolvedBlockingIssue) {
            throw ImportWorkflowException(
              ImportErrorCode.selectedGroupBlocked,
              groupIndex: index,
            );
          }
          final duplicates = await _batches.findDuplicates(
            source: plan.source,
            sourceOperationKey: group.sourceOperationKey,
            sourceOperationFingerprint: group.sourceOperationFingerprint,
            fingerprintVersion: group.fingerprintVersion,
          );
          if (duplicates.hasExactMatch) continue;
          final suspected =
              duplicates.hasFingerprintMatch ||
              currentFingerprints[_fingerprintKey(group)]! > 1;
          final hasWarning = group.issues.any((issue) => issue.isWarning);
          final warningConfirmed =
              command.confirmedWarningIndexes.contains(index) ||
              command.confirmedSuspectedDuplicateIndexes.contains(index);
          if ((suspected || hasWarning) && !warningConfirmed) {
            continue;
          }
          await _validateGroup(
            group,
            index,
            _ResolutionContext(
              source: plan.source,
              mappings: groupMappings,
              plannedCreations: command.plannedCreations,
              ghostMappingKeys: ghostMappingKeys,
              ledger: _ledger,
            ),
          );
          importIndexes.add(index);
        }

        if (importIndexes.isEmpty) {
          return ImportCommitResult(
            batch: null,
            skippedGroupCount: plan.groups.length,
          );
        }

        final resolvedMappings = Map<ImportMappingKey, String>.of(
          command.mappings,
        );
        final createdMappings = <ImportMappingKey, String>{};
        for (final entry in command.plannedCreations.entries) {
          if (!_creationIsUsed(
            key: entry.key,
            importIndexes: importIndexes,
            plan: plan,
            mappings: command.mappings,
            groupMappingOverrides: command.groupMappingOverrides,
          )) {
            continue;
          }
          final targetId = await _ledger.createTarget(
            _mapCreation(entry.value),
          );
          resolvedMappings[entry.key] = targetId;
          createdMappings[entry.key] = targetId;
        }

        final importedAt = command.importedAt ?? _now();
        final batchId = _idGenerator.newId();
        final items = <ImportBatchItem>[];
        var createdTransactionCount = 0;
        for (final index in importIndexes) {
          final group = plan.groups[index];
          try {
            final topLevelId = await _createGroup(
              group,
              index,
              _ResolutionContext(
                source: plan.source,
                mappings: {
                  ...resolvedMappings,
                  ...?command.groupMappingOverrides[index],
                },
                ghostMappingKeys: ghostMappingKeys,
                ledger: _ledger,
              ),
            );
            createdTransactionCount += group.transactions.length;
            items.add(
              ImportBatchItem(
                id: _idGenerator.newId(),
                batchId: batchId,
                sourceOperationKey: group.sourceOperationKey,
                sourceOperationFingerprint: group.sourceOperationFingerprint,
                fingerprintVersion: group.fingerprintVersion,
                topLevelTransactionId: topLevelId,
              ),
            );
          } catch (error, stackTrace) {
            if (error is ImportWorkflowException) rethrow;
            throw ImportWorkflowException(
              ImportErrorCode.commitFailed,
              message: '第 ${index + 1} 个交易组创建失败，所有更改已回滚。',
              cause: error,
              stackTrace: stackTrace,
              groupIndex: index,
            );
          }
        }

        if (command.saveMappingConfiguration) {
          for (final entity in plan.sourceEntities) {
            if (entity.isMissingAccountPlaceholder) continue;
            final targetId =
                resolvedMappings[ImportMappingKey.fromEntity(entity)];
            if (targetId != null) {
              await _saveDefaultMappingRecord(entity, targetId);
            }
          }
        }

        final batch = ImportBatch(
          id: batchId,
          source: plan.source,
          status: ImportBatchStatus.imported,
          importedGroupCount: items.length,
          createdTransactionCount: createdTransactionCount,
          skippedGroupCount: plan.groups.length - items.length,
          importedAt: importedAt,
        );
        try {
          await _batches.saveImportedBatch(batch: batch, items: items);
        } catch (error, stackTrace) {
          throw ImportWorkflowException(
            ImportErrorCode.commitFailed,
            message: '导入批次写入失败，所有账务交易已回滚。',
            cause: error,
            stackTrace: stackTrace,
          );
        }
        return ImportCommitResult(
          batch: batch,
          skippedGroupCount: batch.skippedGroupCount,
          createdMappings: createdMappings,
        );
      });
    } on ImportWorkflowException {
      rethrow;
    } catch (error, stackTrace) {
      throw ImportWorkflowException(
        ImportErrorCode.commitFailed,
        cause: error,
        stackTrace: stackTrace,
      );
    }
  }

  @override
  Future<List<ImportBatch>> listBatches({ImportSource? source}) {
    return _batches.list(source: source);
  }

  @override
  Future<List<ImportBatchItem>> findBatchItems(String batchId) {
    return _batches.findItems(batchId);
  }

  @override
  Future<ImportBatch> revertBatch(
    String batchId, {
    DateTime? revertedAt,
  }) async {
    try {
      return await _transactionRunner.run(() async {
        final batch = await _batches.findById(batchId);
        if (batch == null) {
          throw ImportWorkflowException(ImportErrorCode.batchNotFound);
        }
        if (batch.status == ImportBatchStatus.reverted) return batch;

        final items = await _batches.findItems(batchId);
        for (final item in items) {
          if (await _ledger.transactionExists(item.topLevelTransactionId)) {
            await _ledger.deleteTopLevelTransaction(item.topLevelTransactionId);
          }
        }
        final actualRevertedAt = revertedAt ?? _now();
        await _batches.markReverted(
          batchId: batchId,
          revertedAt: actualRevertedAt,
        );
        return ImportBatch(
          id: batch.id,
          source: batch.source,
          status: ImportBatchStatus.reverted,
          importedGroupCount: batch.importedGroupCount,
          createdTransactionCount: batch.createdTransactionCount,
          skippedGroupCount: batch.skippedGroupCount,
          importedAt: batch.importedAt,
          revertedAt: actualRevertedAt,
        );
      });
    } on ImportWorkflowException {
      rethrow;
    } catch (error, stackTrace) {
      throw ImportWorkflowException(
        ImportErrorCode.revertFailed,
        cause: error,
        stackTrace: stackTrace,
      );
    }
  }

  void _ensurePlanCanBeReviewed(ImportParseResult plan) {
    if (plan.hasFatalIssues) {
      throw ImportWorkflowException(ImportErrorCode.fatalPlan);
    }
  }

  Set<int> _duplicateOperationKeyIndexes(ImportParseResult plan) {
    final indexesByKey = <String, List<int>>{};
    for (var index = 0; index < plan.groups.length; index++) {
      final key = plan.groups[index].sourceOperationKey;
      if (key == null) continue;
      indexesByKey.putIfAbsent(key, () => []).add(index);
    }
    return {
      for (final indexes in indexesByKey.values)
        if (indexes.length > 1) ...indexes,
    };
  }

  Set<ImportMappingKey> _ghostMappingKeys(ImportParseResult plan) {
    return {
      for (final entity in plan.sourceEntities)
        if (entity.isMissingAccountPlaceholder)
          ImportMappingKey.fromEntity(entity),
    };
  }

  List<ImportMappingSuggestion> _suggestMappings({
    required ImportParseResult plan,
    required Map<ImportMappingKey, String> effectiveMappings,
    required List<ImportLedgerTarget> targets,
    required Map<ImportMappingKey, Set<ImportMappingTargetKind>>
    compatibleTargetKinds,
    Set<ImportMappingKey> excludedKeys = const {},
  }) {
    final result = <ImportMappingSuggestion>[];
    for (final entity in plan.sourceEntities) {
      if (entity.isMissingAccountPlaceholder) continue;
      final key = ImportMappingKey.fromEntity(entity);
      if (effectiveMappings.containsKey(key) || excludedKeys.contains(key)) {
        continue;
      }
      final normalized = _normalizeName(entity.displayName);
      final candidates =
          targets.where((target) {
            if (target.isArchived || !_targetSupportsEntity(target, entity)) {
              return false;
            }
            final allowedKinds = compatibleTargetKinds[key];
            if (allowedKinds != null &&
                !allowedKinds.contains(_mapTarget(target).kind)) {
              return false;
            }
            return _normalizeName(target.displayPath) == normalized ||
                _normalizeName(target.name) == normalized;
          }).toList();
      if (candidates.length == 1) {
        final targetId = candidates.single.id;
        effectiveMappings[key] = targetId;
        result.add(
          ImportMappingSuggestion(key: key, targetAccountId: targetId),
        );
      }
    }
    return result;
  }

  void _removeUnavailableMappings({
    required ImportParseResult plan,
    required Map<ImportMappingKey, String> effectiveMappings,
    required List<ImportLedgerTarget> targets,
    required Map<ImportMappingKey, Set<ImportMappingTargetKind>>
    compatibleTargetKinds,
  }) {
    final entities = {
      for (final entity in plan.sourceEntities)
        ImportMappingKey.fromEntity(entity): entity,
    };
    final targetsById = {for (final target in targets) target.id: target};
    effectiveMappings.removeWhere((key, targetId) {
      final entity = entities[key];
      final target = targetsById[targetId];
      if (entity == null || target == null || target.isArchived) return true;
      if (!_targetSupportsEntity(target, entity)) return true;
      final allowedKinds = compatibleTargetKinds[key];
      return allowedKinds != null &&
          !allowedKinds.contains(_mapTarget(target).kind);
    });
  }

  Map<ImportMappingKey, ImportMappingCreation> _resolveCreationPlans({
    required ImportParseResult plan,
    required Map<ImportMappingKey, ImportMappingCreation> requestedCreations,
    required Map<ImportMappingKey, String> effectiveMappings,
    required Map<ImportMappingKey, Set<ImportMappingTargetKind>>
    compatibleTargetKinds,
  }) {
    final result = Map<ImportMappingKey, ImportMappingCreation>.of(
      requestedCreations,
    );
    for (final entity in plan.sourceEntities) {
      if (entity.isMissingAccountPlaceholder) continue;
      final key = ImportMappingKey.fromEntity(entity);
      if (effectiveMappings.containsKey(key) || result.containsKey(key)) {
        continue;
      }
      final allowedKinds = compatibleTargetKinds[key];
      if (allowedKinds != null && allowedKinds.isEmpty) continue;
      final kind = _defaultCreationKind(entity, allowedKinds);
      if (kind == null) continue;
      result[key] = ImportMappingCreation(name: entity.displayName, kind: kind);
    }
    return result;
  }

  ImportMappingTargetKind? _defaultCreationKind(
    ImportSourceEntity entity,
    Set<ImportMappingTargetKind>? allowedKinds,
  ) {
    final effectiveKinds =
        allowedKinds ?? const {ImportMappingTargetKind.asset};
    if (entity.kind == ImportEntityKind.category) {
      final kind = switch (entity.categoryKind) {
        ImportCategoryKind.income => ImportMappingTargetKind.incomeCategory,
        ImportCategoryKind.expense => ImportMappingTargetKind.expenseCategory,
        null => null,
      };
      if (kind == null) return null;
      return allowedKinds == null || allowedKinds.contains(kind) ? kind : null;
    }
    if (effectiveKinds.contains(ImportMappingTargetKind.reimbursement)) {
      return ImportMappingTargetKind.reimbursement;
    }
    if (effectiveKinds.contains(ImportMappingTargetKind.asset)) {
      return ImportMappingTargetKind.asset;
    }
    if (effectiveKinds.contains(ImportMappingTargetKind.liability)) {
      return ImportMappingTargetKind.liability;
    }
    return null;
  }

  Future<void> _applyGhostPlaceholderMappings({
    required ImportParseResult plan,
    required Map<ImportMappingKey, String> effectiveMappings,
    required List<ImportLedgerTarget> targets,
    required Set<String> loadedTargetIds,
    required Map<ImportMappingKey, Set<ImportMappingTargetKind>>
    compatibleTargetKinds,
  }) async {
    String? ghostId;
    for (final entity in plan.sourceEntities) {
      if (!entity.isMissingAccountPlaceholder) {
        continue;
      }
      final key = ImportMappingKey.fromEntity(entity);
      if (effectiveMappings.containsKey(key)) continue;
      final allowedKinds = compatibleTargetKinds[key];
      final supportsGhost =
          allowedKinds != null &&
          allowedKinds.contains(ImportMappingTargetKind.asset) &&
          allowedKinds.contains(ImportMappingTargetKind.liability);
      if (!supportsGhost) continue;
      ghostId ??= await _ledger.resolveGhostAccountId();
      effectiveMappings[key] = ghostId;
      if (loadedTargetIds.add(ghostId)) {
        final ghost = await _ledger.findTarget(ghostId);
        if (ghost != null) targets.add(ghost);
      }
    }
  }

  bool _mappingRepairsParserIssue({
    required ImportIssue issue,
    required ImportTransactionGroupDraft group,
    required Map<String, ImportSourceEntity> placeholders,
    required Map<ImportMappingKey, String> mappings,
    Map<ImportMappingKey, ImportMappingCreation> plannedCreations = const {},
  }) {
    final entityKind = switch (issue.code) {
      'account_missing' ||
      'account_explicit_none_not_allowed' => ImportEntityKind.account,
      'category_missing' => ImportEntityKind.category,
      _ => null,
    };
    if (entityKind == null) return false;
    final groupKeys =
        group.transactions.expand((draft) => draft.sourceEntityKeys).toSet();
    final repairEntities = placeholders.values.where(
      (entity) =>
          entity.kind == entityKind &&
          groupKeys.contains(entity.sourceEntityKey),
    );
    if (repairEntities.isEmpty) return false;
    return repairEntities.every((entity) {
      final key = ImportMappingKey.fromEntity(entity);
      return mappings.containsKey(key) || plannedCreations.containsKey(key);
    });
  }

  Future<void> _saveDefaultMappingRecord(
    ImportSourceEntity entity,
    String targetAccountId,
  ) async {
    final now = _now();
    await _mappings.upsert(
      ImportEntityMapping(
        id: _idGenerator.newId(),
        source: entity.source,
        entityKind: entity.kind,
        sourceEntityKey: entity.sourceEntityKey,
        targetAccountId: targetAccountId,
        createdAt: now,
        updatedAt: now,
      ),
    );
  }

  bool _creationIsUsed({
    required ImportMappingKey key,
    required List<int> importIndexes,
    required ImportParseResult plan,
    required Map<ImportMappingKey, String> mappings,
    required Map<int, Map<ImportMappingKey, String>> groupMappingOverrides,
  }) {
    if (mappings.containsKey(key)) return false;
    return importIndexes.any((index) {
      if (groupMappingOverrides[index]?.containsKey(key) ?? false) {
        return false;
      }
      return _compatibleTargetKindsForGroup(
        plan.groups[index],
      ).containsKey(key);
    });
  }

  ImportLedgerTargetCreation _mapCreation(ImportMappingCreation creation) {
    return ImportLedgerTargetCreation(
      name: creation.name,
      kind: switch (creation.kind) {
        ImportMappingTargetKind.asset => ImportLedgerTargetKind.asset,
        ImportMappingTargetKind.liability => ImportLedgerTargetKind.liability,
        ImportMappingTargetKind.reimbursement =>
          ImportLedgerTargetKind.reimbursement,
        ImportMappingTargetKind.incomeCategory =>
          ImportLedgerTargetKind.incomeCategory,
        ImportMappingTargetKind.expenseCategory =>
          ImportLedgerTargetKind.expenseCategory,
        ImportMappingTargetKind.ghost => ImportLedgerTargetKind.ghost,
        ImportMappingTargetKind.unsupported =>
          ImportLedgerTargetKind.unsupported,
      },
    );
  }

  Map<ImportMappingKey, Set<ImportMappingTargetKind>> _compatibleTargetKinds(
    ImportParseResult plan,
  ) {
    final result = <ImportMappingKey, Set<ImportMappingTargetKind>>{};
    for (final group in plan.groups) {
      final groupKinds = _compatibleTargetKindsForGroup(group);
      for (final entry in groupKinds.entries) {
        final previous = result[entry.key];
        if (previous == null) {
          result[entry.key] = {...entry.value};
        } else {
          previous.retainAll(entry.value);
        }
      }
    }
    return result;
  }

  Map<ImportMappingKey, Set<ImportMappingTargetKind>>
  _compatibleTargetKindsForGroup(ImportTransactionGroupDraft group) {
    final result = <ImportMappingKey, Set<ImportMappingTargetKind>>{};
    for (final draft in group.transactions) {
      for (final usage in _draftUsages(draft)) {
        final previous = result[usage.key];
        if (previous == null) {
          result[usage.key] = {...usage.kinds};
        } else {
          previous.retainAll(usage.kinds);
        }
      }
    }
    return result;
  }

  Iterable<_DraftUsage> _draftUsages(ImportTransactionDraft draft) sync* {
    switch (draft) {
      case ImportExpenseDraft draft:
        yield* _accountUsage(draft.paidFrom.sourceEntityKey, {
          ImportMappingTargetKind.asset,
          ImportMappingTargetKind.liability,
        });
        yield _categoryUsage(
          draft.category.sourceEntityKey,
          ImportMappingTargetKind.expenseCategory,
        );
      case ImportIncomeDraft draft:
        yield* _accountUsage(draft.receiveAccount.sourceEntityKey, {
          ImportMappingTargetKind.asset,
          ImportMappingTargetKind.liability,
        });
        yield _categoryUsage(
          draft.category.sourceEntityKey,
          ImportMappingTargetKind.incomeCategory,
        );
      case ImportRefundDraft draft:
        yield* _accountUsage(draft.refundTo.sourceEntityKey, {
          ImportMappingTargetKind.asset,
          ImportMappingTargetKind.liability,
        });
      case ImportReimbursementAdvanceDraft draft:
        yield* _accountUsage(draft.receivableAccount.sourceEntityKey, {
          ImportMappingTargetKind.reimbursement,
        });
        yield* _accountUsage(draft.paidFrom.sourceEntityKey, {
          ImportMappingTargetKind.asset,
          ImportMappingTargetKind.liability,
        });
        yield _categoryUsage(
          draft.category.sourceEntityKey,
          ImportMappingTargetKind.expenseCategory,
        );
      case ImportReimbursementReceiptDraft draft:
        yield* _accountUsage(draft.receivableAccount.sourceEntityKey, {
          ImportMappingTargetKind.reimbursement,
        });
        yield* _accountUsage(draft.receiveAccount.sourceEntityKey, {
          ImportMappingTargetKind.asset,
          ImportMappingTargetKind.liability,
        });
      case ImportReimbursementCloseDraft draft:
        yield* _accountUsage(draft.receivableAccount.sourceEntityKey, {
          ImportMappingTargetKind.reimbursement,
        });
        yield* _accountUsage(draft.receiveAccount.sourceEntityKey, {
          ImportMappingTargetKind.asset,
          ImportMappingTargetKind.liability,
        });
      case ImportTransferDraft draft:
        yield* _accountUsage(draft.fromAccount.sourceEntityKey, {
          ImportMappingTargetKind.asset,
          ImportMappingTargetKind.liability,
        });
        yield* _accountUsage(draft.toAccount.sourceEntityKey, {
          ImportMappingTargetKind.asset,
          ImportMappingTargetKind.liability,
        });
      case ImportRepaymentDraft draft:
        yield* _accountUsage(draft.liabilityAccount.sourceEntityKey, {
          ImportMappingTargetKind.liability,
        });
        yield* _accountUsage(draft.paidFrom.sourceEntityKey, {
          ImportMappingTargetKind.asset,
          ImportMappingTargetKind.liability,
        });
      case ImportInterestExpenseDraft draft:
        yield* _accountUsage(draft.paidFrom.sourceEntityKey, {
          ImportMappingTargetKind.asset,
          ImportMappingTargetKind.liability,
        });
      case ImportBorrowingDraft draft:
        yield* _accountUsage(draft.liabilityAccount.sourceEntityKey, {
          ImportMappingTargetKind.liability,
        });
        yield* _accountUsage(draft.receiveAccount.sourceEntityKey, {
          ImportMappingTargetKind.asset,
        });
      case ImportOpeningBalanceDraft draft:
        yield* _accountUsage(draft.liabilityAccount.sourceEntityKey, {
          ImportMappingTargetKind.liability,
        });
    }
  }

  Iterable<_DraftUsage> _accountUsage(
    String? sourceEntityKey,
    Set<ImportMappingTargetKind> kinds,
  ) sync* {
    if (sourceEntityKey == null) return;
    yield _DraftUsage(
      ImportMappingKey(
        source: ImportSource.yimu,
        entityKind: ImportEntityKind.account,
        sourceEntityKey: sourceEntityKey,
      ),
      kinds,
    );
  }

  _DraftUsage _categoryUsage(
    String sourceEntityKey,
    ImportMappingTargetKind kind,
  ) {
    return _DraftUsage(
      ImportMappingKey(
        source: ImportSource.yimu,
        entityKind: ImportEntityKind.category,
        sourceEntityKey: sourceEntityKey,
      ),
      {kind},
    );
  }

  bool _targetSupportsEntity(
    ImportLedgerTarget target,
    ImportSourceEntity entity,
  ) {
    if (entity.kind == ImportEntityKind.account) {
      return target.kind == ImportLedgerTargetKind.asset ||
          target.kind == ImportLedgerTargetKind.liability ||
          target.kind == ImportLedgerTargetKind.reimbursement;
    }
    return switch (entity.categoryKind) {
      ImportCategoryKind.income =>
        target.kind == ImportLedgerTargetKind.incomeCategory,
      ImportCategoryKind.expense =>
        target.kind == ImportLedgerTargetKind.expenseCategory,
      null => false,
    };
  }

  String _normalizeName(String value) {
    return value.trim().toLowerCase().replaceAll(RegExp(r'\s+'), ' ');
  }

  Map<String, int> _fingerprintCounts(
    List<ImportTransactionGroupDraft> groups,
  ) {
    final counts = <String, int>{};
    for (final group in groups) {
      final key = _fingerprintKey(group);
      counts[key] = (counts[key] ?? 0) + 1;
    }
    return counts;
  }

  String _fingerprintKey(ImportTransactionGroupDraft group) {
    return '${group.fingerprintVersion}:${group.sourceOperationFingerprint}';
  }

  Future<void> _validateGroup(
    ImportTransactionGroupDraft group,
    int groupIndex,
    _ResolutionContext context,
  ) async {
    await _validateTopLevel(group.topLevel, groupIndex, context);
    for (final child in group.children) {
      await _validateChild(child, groupIndex, context);
    }
  }

  Future<void> _validateTopLevel(
    ImportTransactionDraft draft,
    int groupIndex,
    _ResolutionContext context,
  ) async {
    _validateDraftValues(draft, groupIndex);
    switch (draft) {
      case ImportExpenseDraft draft:
        await context.account(
          draft.paidFrom,
          _TargetUsage.settlement,
          groupIndex: groupIndex,
          allowExplicitNone: true,
        );
        await context.category(draft.category, groupIndex: groupIndex);
      case ImportIncomeDraft draft:
        await context.account(
          draft.receiveAccount,
          _TargetUsage.settlement,
          groupIndex: groupIndex,
          allowExplicitNone: true,
        );
        await context.category(draft.category, groupIndex: groupIndex);
      case ImportTransferDraft draft:
        await context.account(
          draft.fromAccount,
          _TargetUsage.settlement,
          groupIndex: groupIndex,
        );
        await context.account(
          draft.toAccount,
          _TargetUsage.settlement,
          groupIndex: groupIndex,
        );
      case ImportReimbursementAdvanceDraft draft:
        await context.account(
          draft.receivableAccount,
          _TargetUsage.reimbursement,
          groupIndex: groupIndex,
        );
        await context.account(
          draft.paidFrom,
          _TargetUsage.settlement,
          groupIndex: groupIndex,
        );
        await context.category(draft.category, groupIndex: groupIndex);
      case ImportRepaymentDraft draft:
        await context.account(
          draft.liabilityAccount,
          _TargetUsage.liability,
          groupIndex: groupIndex,
        );
        await context.account(
          draft.paidFrom,
          _TargetUsage.settlement,
          groupIndex: groupIndex,
        );
      case ImportInterestExpenseDraft draft:
        await context.account(
          draft.paidFrom,
          _TargetUsage.settlement,
          groupIndex: groupIndex,
        );
      case ImportBorrowingDraft draft:
        await context.account(
          draft.liabilityAccount,
          _TargetUsage.liability,
          groupIndex: groupIndex,
        );
        await context.account(
          draft.receiveAccount,
          _TargetUsage.fund,
          groupIndex: groupIndex,
        );
      case ImportOpeningBalanceDraft draft:
        await context.account(
          draft.liabilityAccount,
          _TargetUsage.liability,
          groupIndex: groupIndex,
        );
      case ImportRefundDraft() ||
          ImportReimbursementReceiptDraft() ||
          ImportReimbursementCloseDraft():
        throw ImportWorkflowException(
          ImportErrorCode.invalidDraftStructure,
          message: '子交易行为不能作为顶层交易。',
          groupIndex: groupIndex,
        );
    }
  }

  Future<void> _validateChild(
    ImportTransactionDraft draft,
    int groupIndex,
    _ResolutionContext context,
  ) async {
    _validateDraftValues(draft, groupIndex);
    switch (draft) {
      case ImportRefundDraft draft:
        await context.account(
          draft.refundTo,
          _TargetUsage.settlement,
          groupIndex: groupIndex,
        );
      case ImportReimbursementReceiptDraft draft:
        await context.account(
          draft.receivableAccount,
          _TargetUsage.reimbursement,
          groupIndex: groupIndex,
        );
        await context.account(
          draft.receiveAccount,
          _TargetUsage.settlement,
          groupIndex: groupIndex,
        );
      case ImportReimbursementCloseDraft draft:
        await context.account(
          draft.receivableAccount,
          _TargetUsage.reimbursement,
          groupIndex: groupIndex,
        );
        if (draft.actualReceivedAmount.minorUnits > 0) {
          await context.account(
            draft.receiveAccount,
            _TargetUsage.settlement,
            groupIndex: groupIndex,
          );
        }
      case ImportExpenseDraft() ||
          ImportIncomeDraft() ||
          ImportTransferDraft() ||
          ImportReimbursementAdvanceDraft() ||
          ImportRepaymentDraft() ||
          ImportInterestExpenseDraft() ||
          ImportBorrowingDraft() ||
          ImportOpeningBalanceDraft():
        throw ImportWorkflowException(
          ImportErrorCode.invalidDraftStructure,
          message: '该账务行为不能作为导入子交易。',
          groupIndex: groupIndex,
        );
    }
  }

  void _validateDraftValues(ImportTransactionDraft draft, int groupIndex) {
    final invalid = switch (draft) {
      ImportReimbursementCloseDraft draft =>
        draft.actualReceivedAmount.minorUnits < 0,
      ImportRepaymentDraft draft =>
        draft.principal.minorUnits <= 0 ||
            (draft.interest?.minorUnits ?? 0) < 0 ||
            (draft.fee?.minorUnits ?? 0) < 0,
      ImportTransferDraft draft =>
        draft.amount.minorUnits <= 0 || (draft.feeAmount?.minorUnits ?? 0) < 0,
      _ => draft.amount.minorUnits <= 0,
    };
    if (invalid) {
      throw ImportWorkflowException(
        ImportErrorCode.invalidDraftValue,
        message: '交易金额必须符合该账务行为的正数或非负数规则。',
        groupIndex: groupIndex,
      );
    }
  }

  Future<String> _createGroup(
    ImportTransactionGroupDraft group,
    int groupIndex,
    _ResolutionContext context,
  ) async {
    final topLevelId = await _createTopLevel(
      group.topLevel,
      groupIndex,
      context,
    );
    for (final child in group.children) {
      await _createChild(child, topLevelId, groupIndex, context);
    }
    return topLevelId;
  }

  Future<String> _createTopLevel(
    ImportTransactionDraft draft,
    int groupIndex,
    _ResolutionContext context,
  ) async {
    return switch (draft) {
      ImportExpenseDraft draft => _ledger.createExpense(
        amount: draft.amount,
        paidFromAccountId: await context.account(
          draft.paidFrom,
          _TargetUsage.settlement,
          groupIndex: groupIndex,
          allowExplicitNone: true,
        ),
        expenseCategoryId: await context.category(
          draft.category,
          groupIndex: groupIndex,
        ),
        occurredAt: draft.occurredAt,
        postedAt: draft.postedAt,
        note: draft.note,
        isExcludedFromStats: draft.isExcludedFromStats,
        isExcludedFromBudget: draft.isExcludedFromBudget,
      ),
      ImportIncomeDraft draft => _ledger.createIncome(
        amount: draft.amount,
        receiveAccountId: await context.account(
          draft.receiveAccount,
          _TargetUsage.settlement,
          groupIndex: groupIndex,
          allowExplicitNone: true,
        ),
        incomeCategoryId: await context.category(
          draft.category,
          groupIndex: groupIndex,
        ),
        occurredAt: draft.occurredAt,
        postedAt: draft.postedAt,
        note: draft.note,
        isExcludedFromStats: draft.isExcludedFromStats,
        isExcludedFromBudget: draft.isExcludedFromBudget,
      ),
      ImportTransferDraft draft => _ledger.createTransfer(
        amount: draft.amount,
        fromAccountId: await context.account(
          draft.fromAccount,
          _TargetUsage.settlement,
          groupIndex: groupIndex,
        ),
        toAccountId: await context.account(
          draft.toAccount,
          _TargetUsage.settlement,
          groupIndex: groupIndex,
        ),
        occurredAt: draft.occurredAt,
        postedAt: draft.postedAt,
        feeAmount: draft.feeAmount,
        note: draft.note,
      ),
      ImportReimbursementAdvanceDraft draft => _ledger
          .createReimbursementAdvance(
            amount: draft.amount,
            receivableAccountId: await context.account(
              draft.receivableAccount,
              _TargetUsage.reimbursement,
              groupIndex: groupIndex,
            ),
            paidFromAccountId: await context.account(
              draft.paidFrom,
              _TargetUsage.settlement,
              groupIndex: groupIndex,
            ),
            expenseCategoryId: await context.category(
              draft.category,
              groupIndex: groupIndex,
            ),
            occurredAt: draft.occurredAt,
            postedAt: draft.postedAt,
            note: draft.note,
            isExcludedFromStats: draft.isExcludedFromStats,
            isExcludedFromBudget: draft.isExcludedFromBudget,
          ),
      ImportRepaymentDraft draft => _ledger.createRepayment(
        principal: draft.principal,
        liabilityAccountId: await context.account(
          draft.liabilityAccount,
          _TargetUsage.liability,
          groupIndex: groupIndex,
        ),
        paidFromAccountId: await context.account(
          draft.paidFrom,
          _TargetUsage.settlement,
          groupIndex: groupIndex,
        ),
        occurredAt: draft.occurredAt,
        postedAt: draft.postedAt,
        interest: draft.interest,
        fee: draft.fee,
        note: draft.note,
      ),
      ImportInterestExpenseDraft draft => _ledger.createInterestExpense(
        amount: draft.amount,
        paidFromAccountId: await context.account(
          draft.paidFrom,
          _TargetUsage.settlement,
          groupIndex: groupIndex,
        ),
        occurredAt: draft.occurredAt,
        postedAt: draft.postedAt,
        note: draft.note,
      ),
      ImportBorrowingDraft draft => _ledger.createBorrowing(
        amount: draft.amount,
        liabilityAccountId: await context.account(
          draft.liabilityAccount,
          _TargetUsage.liability,
          groupIndex: groupIndex,
        ),
        receiveAccountId: await context.account(
          draft.receiveAccount,
          _TargetUsage.fund,
          groupIndex: groupIndex,
        ),
        occurredAt: draft.occurredAt,
        postedAt: draft.postedAt,
        note: draft.note,
      ),
      ImportOpeningBalanceDraft draft => _ledger.createOpeningBalance(
        amount: draft.amount,
        accountId: await context.account(
          draft.liabilityAccount,
          _TargetUsage.liability,
          groupIndex: groupIndex,
        ),
        occurredAt: draft.occurredAt,
        postedAt: draft.postedAt,
        note: draft.note,
      ),
      _ =>
        throw ImportWorkflowException(
          ImportErrorCode.invalidDraftStructure,
          groupIndex: groupIndex,
        ),
    };
  }

  Future<String> _createChild(
    ImportTransactionDraft draft,
    String topLevelId,
    int groupIndex,
    _ResolutionContext context,
  ) async {
    return switch (draft) {
      ImportRefundDraft draft => _ledger.createRefund(
        topLevelTransactionId: topLevelId,
        amount: draft.amount,
        refundToAccountId: await context.account(
          draft.refundTo,
          _TargetUsage.settlement,
          groupIndex: groupIndex,
        ),
        occurredAt: draft.occurredAt,
        postedAt: draft.postedAt,
        note: draft.note,
      ),
      ImportReimbursementReceiptDraft draft => _ledger
          .createReimbursementReceipt(
            topLevelTransactionId: topLevelId,
            amount: draft.amount,
            receivableAccountId: await context.account(
              draft.receivableAccount,
              _TargetUsage.reimbursement,
              groupIndex: groupIndex,
            ),
            receiveAccountId: await context.account(
              draft.receiveAccount,
              _TargetUsage.settlement,
              groupIndex: groupIndex,
            ),
            occurredAt: draft.occurredAt,
            postedAt: draft.postedAt,
            note: draft.note,
          ),
      ImportReimbursementCloseDraft draft => _ledger.closeReimbursement(
        topLevelTransactionId: topLevelId,
        actualReceivedAmount: draft.actualReceivedAmount,
        receivableAccountId: await context.account(
          draft.receivableAccount,
          _TargetUsage.reimbursement,
          groupIndex: groupIndex,
        ),
        receiveAccountId:
            draft.actualReceivedAmount.minorUnits == 0
                ? await context.account(
                  draft.receivableAccount,
                  _TargetUsage.reimbursement,
                  groupIndex: groupIndex,
                )
                : await context.account(
                  draft.receiveAccount,
                  _TargetUsage.settlement,
                  groupIndex: groupIndex,
                ),
        occurredAt: draft.occurredAt,
        postedAt: draft.postedAt,
        note: draft.note,
      ),
      _ =>
        throw ImportWorkflowException(
          ImportErrorCode.invalidDraftStructure,
          groupIndex: groupIndex,
        ),
    };
  }
}

class _DraftUsage {
  const _DraftUsage(this.key, this.kinds);

  final ImportMappingKey key;
  final Set<ImportMappingTargetKind> kinds;
}

enum _TargetUsage {
  settlement,
  fund,
  liability,
  reimbursement,
  incomeCategory,
  expenseCategory,
}

class _ResolutionContext {
  _ResolutionContext({
    required this.source,
    required this.mappings,
    this.plannedCreations = const {},
    this.ghostMappingKeys = const {},
    required this.ledger,
  });

  final ImportSource source;
  final Map<ImportMappingKey, String> mappings;
  final Map<ImportMappingKey, ImportMappingCreation> plannedCreations;
  final Set<ImportMappingKey> ghostMappingKeys;
  final ImportLedgerPort ledger;
  final Map<String, ImportLedgerTarget?> _targets = {};
  String? _ghostAccountId;

  Future<String> account(
    ImportAccountReference reference,
    _TargetUsage usage, {
    required int groupIndex,
    bool allowExplicitNone = false,
  }) async {
    if (reference.isExplicitNone) {
      if (!allowExplicitNone) {
        throw ImportWorkflowException(
          ImportErrorCode.mappingMissing,
          message: '该交易所需账户不能使用“无账户”。',
          groupIndex: groupIndex,
        );
      }
      final ghostId = _ghostAccountId ??= await ledger.resolveGhostAccountId();
      final ghost = await _target(ghostId);
      if (ghost == null || ghost.isArchived) {
        throw ImportWorkflowException(
          ImportErrorCode.mappingTargetUnavailable,
          message: '幽灵账户不可用。',
          groupIndex: groupIndex,
        );
      }
      return ghostId;
    }
    final sourceEntityKey = reference.sourceEntityKey;
    if (sourceEntityKey == null) {
      throw ImportWorkflowException(
        ImportErrorCode.mappingMissing,
        message: '来源账户缺失、未解析或尚未映射。',
        groupIndex: groupIndex,
      );
    }
    return _mappedTarget(
      ImportMappingKey(
        source: source,
        entityKind: ImportEntityKind.account,
        sourceEntityKey: sourceEntityKey,
      ),
      usage,
      groupIndex,
    );
  }

  Future<String> category(
    ImportCategoryReference reference, {
    required int groupIndex,
  }) {
    return _mappedTarget(
      ImportMappingKey(
        source: source,
        entityKind: ImportEntityKind.category,
        sourceEntityKey: reference.sourceEntityKey,
      ),
      switch (reference.kind) {
        ImportCategoryKind.income => _TargetUsage.incomeCategory,
        ImportCategoryKind.expense => _TargetUsage.expenseCategory,
      },
      groupIndex,
    );
  }

  Future<String> _mappedTarget(
    ImportMappingKey key,
    _TargetUsage usage,
    int groupIndex,
  ) async {
    final targetId = mappings[key];
    if (targetId == null) {
      final creation = plannedCreations[key];
      if (creation != null) {
        if (!_creationSupports(creation, usage)) {
          throw ImportWorkflowException(
            ImportErrorCode.mappingTargetRoleInvalid,
            message: '${creation.name} 与该交易的账户角色不兼容。',
            groupIndex: groupIndex,
          );
        }
        return 'planned:${key.entityKind.name}:${key.sourceEntityKey}';
      }
      throw ImportWorkflowException(
        ImportErrorCode.mappingMissing,
        groupIndex: groupIndex,
      );
    }
    final target = await _target(targetId);
    if (target == null || target.isArchived) {
      throw ImportWorkflowException(
        ImportErrorCode.mappingTargetUnavailable,
        groupIndex: groupIndex,
      );
    }
    if (!_supports(target, usage, key)) {
      throw ImportWorkflowException(
        ImportErrorCode.mappingTargetRoleInvalid,
        message: '${target.displayPath} 与该交易的账户角色不兼容。',
        groupIndex: groupIndex,
      );
    }
    return targetId;
  }

  bool _creationSupports(ImportMappingCreation creation, _TargetUsage usage) {
    return switch (usage) {
      _TargetUsage.settlement =>
        creation.kind == ImportMappingTargetKind.asset ||
            creation.kind == ImportMappingTargetKind.liability,
      _TargetUsage.fund => creation.kind == ImportMappingTargetKind.asset,
      _TargetUsage.liability =>
        creation.kind == ImportMappingTargetKind.liability,
      _TargetUsage.reimbursement =>
        creation.kind == ImportMappingTargetKind.reimbursement,
      _TargetUsage.incomeCategory =>
        creation.kind == ImportMappingTargetKind.incomeCategory,
      _TargetUsage.expenseCategory =>
        creation.kind == ImportMappingTargetKind.expenseCategory,
    };
  }

  Future<ImportLedgerTarget?> _target(String id) async {
    if (_targets.containsKey(id)) return _targets[id];
    final target = await ledger.findTarget(id);
    _targets[id] = target;
    return target;
  }

  bool _supports(
    ImportLedgerTarget target,
    _TargetUsage usage,
    ImportMappingKey key,
  ) {
    return switch (usage) {
      _TargetUsage.settlement =>
        target.kind == ImportLedgerTargetKind.asset ||
            target.kind == ImportLedgerTargetKind.liability ||
            (target.kind == ImportLedgerTargetKind.ghost &&
                ghostMappingKeys.contains(key)),
      _TargetUsage.fund => target.kind == ImportLedgerTargetKind.asset,
      _TargetUsage.liability => target.kind == ImportLedgerTargetKind.liability,
      _TargetUsage.reimbursement =>
        target.kind == ImportLedgerTargetKind.reimbursement,
      _TargetUsage.incomeCategory =>
        target.kind == ImportLedgerTargetKind.incomeCategory,
      _TargetUsage.expenseCategory =>
        target.kind == ImportLedgerTargetKind.expenseCategory,
    };
  }
}
