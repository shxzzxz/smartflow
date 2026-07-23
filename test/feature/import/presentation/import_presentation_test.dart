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
}
