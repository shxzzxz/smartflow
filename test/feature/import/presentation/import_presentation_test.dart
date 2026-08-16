import 'package:flutter_test/flutter_test.dart';
import 'package:smartflow/application/import/import_api.dart';
import 'package:smartflow/core/money/money.dart';
import 'package:smartflow/feature/import/presentation/import_presentation.dart';

void main() {
  test('formats import operation and group entity presentation', () {
    const entity = ImportSourceEntity(
      source: ImportSource.yimu,
      kind: ImportEntityKind.account,
      sourceEntityKey: 'account:cash',
      displayName: '现金',
    );
    final group = ImportTransactionGroupDraft(
      topLevel: ImportTransferDraft(
        amount: Money.parse('10.00'),
        fromAccount: const ImportAccountReference.source(
          sourceEntityKey: 'account:cash',
          displayName: '现金',
        ),
        toAccount: const ImportAccountReference.source(
          sourceEntityKey: 'account:bank',
          displayName: '银行卡',
        ),
        occurredAt: DateTime(2026, 7, 22, 9, 30),
      ),
      sourceOperationFingerprint: 'fingerprint',
      fingerprintVersion: 1,
    );

    expect(importOperationLabel(group.topLevel.operationKind), '转账');
    expect(importEntityKindLabel(entity), '来源账户');
    expect(importGroupEntities(group, const [entity]), const [entity]);
    expect(formatImportDateTime(group.topLevel.occurredAt), '2026-07-22 09:30');

    final review = ImportPlanReview(
      plan: ImportParseResult(
        source: ImportSource.yimu,
        sourceEntities: const [entity],
        groups: [group],
      ),
      defaultMappings: const {},
      effectiveMappings: {
        const ImportMappingKey(
              source: ImportSource.yimu,
              entityKind: ImportEntityKind.account,
              sourceEntityKey: 'account:cash',
            ):
            'cash',
      },
      suggestions: const [],
      targets: const [
        ImportMappingTarget(
          id: 'cash',
          name: '现金',
          displayPath: '资产 / 现金',
          kind: ImportMappingTargetKind.asset,
          isArchived: false,
        ),
      ],
      mappingItems: [
        ImportMappingReviewItem(
          key: const ImportMappingKey(
            source: ImportSource.yimu,
            entityKind: ImportEntityKind.account,
            sourceEntityKey: 'account:cash',
          ),
          sourceName: '现金',
          sourceDescription: '账户',
          action: ImportMappingAction.map,
          targetName: '现金',
          targetId: 'cash',
          targetPath: '资产 / 现金',
          targetDescription: '资金账户',
          decision: const ExistingTargetDecision('cash'),
        ),
      ],
      groups: [
        ImportGroupReview(
          index: 0,
          group: group,
          issues: const [],
          isExactDuplicate: false,
          isSuspectedDuplicate: false,
        ),
      ],
    );
    final preview = buildImportPreviewGroups(review);
    expect(preview.single.rows.single.title, '转账');
    expect(preview.single.rows.single.amountText, '10.00');
    expect(preview.single.rows.single.accountFlow.out?.label, '资产 / 现金');
    expect(takeImportPreviewRows(preview, 1).single.rows, hasLength(1));
    expect(takeImportPreviewRows(preview, 0), isEmpty);
    expect(formatImportFileSize(512), '512 B');
    expect(formatImportFileSize(1536), '1.5 KB');
  });

  test('formats import entry routes and task names', () {
    expect(importEntrySourceFromRoute('alipay'), ImportEntrySource.alipay);
    expect(ImportEntrySource.generic.routeValue, 'generic');
    expect(
      formatImportTaskName(
        ImportBatch(
          id: 'batch-1',
          source: ImportSource.yimu,
          status: ImportBatchStatus.imported,
          importedGroupCount: 1,
          createdTransactionCount: 1,
          skippedGroupCount: 0,
          importedAt: DateTime(2026, 7, 22, 9, 30, 5),
        ),
      ),
      '一木记账_20260722093005',
    );
  });

  test('updates preview summary after confirmation', () {
    final base = _previewReview();
    final pending = summarizeImportPreview(base);
    final confirmed = summarizeImportPreview(
      base,
      confirmedWarningIndexes: {0},
    );
    final suspected = _previewReview(suspectedDuplicate: true);
    final suspectedConfirmed = summarizeImportPreview(
      suspected,
      confirmedSuspectedDuplicateIndexes: {0},
    );

    expect(pending.pending, 1);
    expect(pending.parsed, 0);
    expect(pending.skipped, 0);
    expect(confirmed.pending, 0);
    expect(confirmed.parsed, 1);
    expect(summarizeImportPreview(suspected).pending, 1);
    expect(suspectedConfirmed.pending, 0);
    expect(suspectedConfirmed.parsed, 1);

    final exactDuplicate = _previewReview(exactDuplicate: true);
    final exactDuplicateSummary = summarizeImportPreview(exactDuplicate);
    final exactDuplicateConfirmed = summarizeImportPreview(
      exactDuplicate,
      confirmedExactDuplicateIndexes: {0},
    );
    expect(exactDuplicateSummary.pending, 1);
    expect(exactDuplicateSummary.skipped, 0);
    expect(exactDuplicateConfirmed.pending, 0);
    expect(exactDuplicateConfirmed.parsed, 1);

    final blockedExactDuplicate = _previewReview(
      exactDuplicate: true,
      blocking: true,
    );
    final blockedExactDuplicateSummary = summarizeImportPreview(
      blockedExactDuplicate,
    );
    expect(blockedExactDuplicateSummary.unparsed, 1);
    expect(blockedExactDuplicateSummary.pending, 0);

    final filtered = _previewReview(
      includeWarning: false,
      filteredRecords: const [
        ImportFilteredRecord(
          reasonCode: 'empty_row',
          reason: '空白记录',
          fileType: ImportSourceFileType(
            source: ImportSource.yimu,
            key: 'bill',
            label: '账单',
          ),
          rowNumber: 8,
        ),
      ],
    );
    final filteredSummary = summarizeImportPreview(filtered);
    expect(filteredSummary.filtered, 1);
    expect(filteredSummary.skipped, 1);
    expect(
      importPreviewAnalysisDescription(filteredSummary),
      '有 1 条来源记录已按规则跳过，可查看全部导入预览。',
    );
  });

  test('distinguishes duplicate badges and row selection state', () {
    final exactDuplicate = buildImportPreviewGroups(
      _previewReview(exactDuplicate: true, includeWarning: false),
    );
    expect(exactDuplicate.single.rows.single.badges.map((b) => b.label), [
      '已导入',
    ]);
    expect(exactDuplicate.single.rows.single.selectable, isFalse);
    expect(exactDuplicate.single.rows.single.selected, isFalse);
    expect(exactDuplicate.single.rows.single.dimmed, isTrue);

    final exactDuplicateSelectable = buildImportPreviewGroups(
      _previewReview(exactDuplicate: true, includeWarning: false),
      selectedGroupIndexes: const {0},
      showSelectionControls: true,
    );
    final selectableRow = exactDuplicateSelectable.single.rows.single;
    expect(selectableRow.selectable, isTrue);
    expect(selectableRow.selected, isTrue);
    expect(selectableRow.dimmed, isFalse);

    final unselectedSelectable = buildImportPreviewGroups(
      _previewReview(exactDuplicate: true, includeWarning: false),
      showSelectionControls: true,
    );
    expect(unselectedSelectable.single.rows.single.selectable, isTrue);
    expect(unselectedSelectable.single.rows.single.selected, isFalse);
    expect(unselectedSelectable.single.rows.single.dimmed, isTrue);

    final suspected = buildImportPreviewGroups(
      _previewReview(suspectedDuplicate: true),
    );
    expect(suspected.single.rows.single.badges.map((b) => b.label), [
      '疑似重复',
    ]);

    final warning = buildImportPreviewGroups(_previewReview());
    expect(warning.single.rows.single.badges.map((b) => b.label), ['需确认']);

    final blocked = buildImportPreviewGroups(
      _previewReview(blocking: true, includeWarning: true),
    );
    expect(blocked.single.rows.single.badges.map((b) => b.label), ['需处理']);
    expect(blocked.single.rows.single.selectable, isFalse);
  });

  test('counts a ghost placeholder as a handled mapping', () {
    const missingAccount = ImportSourceEntity(
      source: ImportSource.yimu,
      kind: ImportEntityKind.account,
      sourceEntityKey: 'review:missing:account:bill:2:account',
      displayName: '缺失账户（账单文件第 2 行）',
      isReviewPlaceholder: true,
    );
    const category = ImportSourceEntity(
      source: ImportSource.yimu,
      kind: ImportEntityKind.category,
      sourceEntityKey: 'category:expense:餐饮',
      displayName: '餐饮',
      categoryKind: ImportCategoryKind.expense,
    );
    final group = ImportTransactionGroupDraft(
      topLevel: ImportExpenseDraft(
        amount: Money.parse('10.00'),
        paidFrom: const ImportAccountReference.source(
          sourceEntityKey: 'review:missing:account:bill:2:account',
          displayName: '缺失账户',
        ),
        category: const ImportCategoryReference(
          sourceEntityKey: 'category:expense:餐饮',
          path: '餐饮',
          kind: ImportCategoryKind.expense,
        ),
        occurredAt: DateTime(2026, 7, 22),
      ),
      sourceOperationFingerprint: 'ghost-fingerprint',
      fingerprintVersion: 1,
    );
    final review = ImportPlanReview(
      plan: ImportParseResult(
        source: ImportSource.yimu,
        sourceEntities: const [missingAccount, category],
        groups: [group],
      ),
      defaultMappings: const {},
      effectiveMappings: {
        ImportMappingKey.fromEntity(missingAccount): 'ghost',
        ImportMappingKey.fromEntity(category): 'expense-category',
      },
      suggestions: const [],
      targets: const [
        ImportMappingTarget(
          id: 'ghost',
          name: '幽灵账户',
          displayPath: '幽灵账户',
          kind: ImportMappingTargetKind.ghost,
          isArchived: false,
        ),
        ImportMappingTarget(
          id: 'expense-category',
          name: '餐饮',
          displayPath: '支出 / 餐饮',
          kind: ImportMappingTargetKind.expenseCategory,
          isArchived: false,
        ),
      ],
      mappingItems: [
        ImportMappingReviewItem(
          key: ImportMappingKey.fromEntity(missingAccount),
          sourceName: '缺失账户',
          sourceDescription: '账户',
          action: ImportMappingAction.map,
          targetName: '无账户',
          targetId: 'ghost',
          targetPath: '无账户',
          targetDescription: '无账户',
          decision: const ExistingTargetDecision('ghost'),
        ),
        ImportMappingReviewItem(
          key: ImportMappingKey.fromEntity(category),
          sourceName: '餐饮',
          sourceDescription: '支出分类',
          action: ImportMappingAction.map,
          targetName: '餐饮',
          targetId: 'expense-category',
          targetPath: '支出 / 餐饮',
          targetDescription: '支出分类',
          decision: const ExistingTargetDecision('expense-category'),
        ),
      ],
      groups: [
        ImportGroupReview(
          index: 0,
          group: group,
          issues: const [],
          isExactDuplicate: false,
          isSuspectedDuplicate: false,
        ),
      ],
    );

    final summary = summarizeImportMappings(review);

    expect(summary.mapped, 2);
    expect(summary.pending, 0);
    expect(summary.unmapped, 0);
    expect(
      buildImportPreviewGroups(
        review,
      ).single.rows.single.accountFlow.out?.label,
      '无账户',
    );
  });
}

ImportPlanReview _previewReview({
  bool suspectedDuplicate = false,
  bool exactDuplicate = false,
  bool blocking = false,
  bool includeWarning = true,
  List<ImportFilteredRecord> filteredRecords = const [],
}) {
  final group = ImportTransactionGroupDraft(
    topLevel: ImportTransferDraft(
      amount: Money.parse('10.00'),
      fromAccount: const ImportAccountReference.source(
        sourceEntityKey: 'account:cash',
        displayName: '现金',
      ),
      toAccount: const ImportAccountReference.source(
        sourceEntityKey: 'account:bank',
        displayName: '银行卡',
      ),
      occurredAt: DateTime(2026, 7, 22, 9, 30),
    ),
    sourceOperationFingerprint: 'warning-fingerprint',
    fingerprintVersion: 1,
  );
  return ImportPlanReview(
    plan: ImportParseResult(
      source: ImportSource.yimu,
      groups: [group],
      filteredRecords: filteredRecords,
    ),
    defaultMappings: const {},
    effectiveMappings: const {},
    suggestions: const [],
    groups: [
      ImportGroupReview(
        index: 0,
        group: group,
        issues:
            includeWarning
                ? [
                  ImportIssue(
                    code: 'warning',
                    message: '来源记录需要确认。',
                    severity:
                        blocking
                            ? ImportIssueSeverity.blocking
                            : ImportIssueSeverity.warning,
                  ),
                ]
                : const [],
        isExactDuplicate: exactDuplicate,
        isSuspectedDuplicate: suspectedDuplicate,
      ),
    ],
  );
}
