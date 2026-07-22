import 'package:flutter_test/flutter_test.dart';
import 'package:smartflow/application/import/import_plan_app_service.dart';
import 'package:smartflow/core/money/money.dart';
import 'package:smartflow/core/patch/patch.dart';
import 'package:smartflow/domain/import/import_models.dart';
import 'package:smartflow/domain/import/port/yimu_workbook_reader.dart';
import 'package:smartflow/domain/import/service/yimu_import_parser.dart';

void main() {
  test('draft edit clears only parser issues repaired by edited fields', () {
    final service = ImportPlanAppServiceImpl(
      yimuParser: YimuImportParser(reader: const _UnusedReader()),
    );
    final group = ImportTransactionGroupDraft(
      topLevel: ImportTransferDraft(
        amount: Money.zero(),
        fromAccount: const ImportAccountReference.source(
          sourceEntityKey: 'account:cash',
          displayName: '现金',
        ),
        toAccount: const ImportAccountReference.source(
          sourceEntityKey: 'account:bank',
          displayName: '银行卡',
        ),
        occurredAt: DateTime(1970),
      ),
      sourceOperationFingerprint: 'fingerprint',
      fingerprintVersion: 1,
      issues: const [
        ImportIssue(
          code: 'date_invalid',
          message: '日期无效。',
          severity: ImportIssueSeverity.blocking,
        ),
        ImportIssue(
          code: '金额_invalid',
          message: '金额无效。',
          severity: ImportIssueSeverity.blocking,
        ),
        ImportIssue(
          code: 'transfer_amount_invalid',
          message: '转账金额无效。',
          severity: ImportIssueSeverity.blocking,
        ),
        ImportIssue(
          code: '手续费_invalid',
          message: '手续费无效。',
          severity: ImportIssueSeverity.blocking,
        ),
        ImportIssue(
          code: 'multi_currency_unsupported',
          message: '不支持多币种。',
          severity: ImportIssueSeverity.blocking,
        ),
      ],
    );
    final plan = ImportParseResult(source: ImportSource.yimu, groups: [group]);

    final edited = service.editDraft(
      plan: plan,
      groupIndex: 0,
      edit: ImportDraftEdit(
        amount: Money.parse('25.00'),
        occurredAt: DateTime(2026, 7, 22, 9),
        transferFee: Patch.set(Money.parse('1.00')),
      ),
    );

    final editedGroup = edited.groups.single;
    final draft = editedGroup.topLevel as ImportTransferDraft;
    expect(draft.amount, Money.parse('25.00'));
    expect(draft.feeAmount, Money.parse('1.00'));
    expect(draft.occurredAt, DateTime(2026, 7, 22, 9));
    expect(editedGroup.issues.map((issue) => issue.code), [
      'multi_currency_unsupported',
    ]);
    expect(editedGroup.sourceOperationFingerprint, 'fingerprint');
  });

  test('editing a child date does not clear a top-level date blocker', () {
    final service = ImportPlanAppServiceImpl(
      yimuParser: YimuImportParser(reader: const _UnusedReader()),
    );
    final group = ImportTransactionGroupDraft(
      topLevel: ImportExpenseDraft(
        amount: Money.parse('70.00'),
        paidFrom: const ImportAccountReference.source(
          sourceEntityKey: 'account:cash',
          displayName: '现金',
        ),
        category: const ImportCategoryReference(
          sourceEntityKey: 'category:expense:餐饮',
          path: '餐饮',
          kind: ImportCategoryKind.expense,
        ),
        occurredAt: DateTime(1970),
      ),
      children: [
        ImportRefundDraft(
          amount: Money.parse('2.00'),
          refundTo: const ImportAccountReference.source(
            sourceEntityKey: 'account:cash',
            displayName: '现金',
          ),
          occurredAt: DateTime(1970),
        ),
      ],
      sourceOperationFingerprint: 'fingerprint',
      fingerprintVersion: 1,
      issues: const [
        ImportIssue(
          code: 'date_invalid',
          message: '顶层交易日期无效。',
          severity: ImportIssueSeverity.blocking,
        ),
      ],
    );

    final edited = service.editDraft(
      plan: ImportParseResult(source: ImportSource.yimu, groups: [group]),
      groupIndex: 0,
      childIndex: 0,
      edit: ImportDraftEdit(occurredAt: DateTime(2026, 7, 22, 9)),
    );

    expect(
      edited.groups.single.issues.map((issue) => issue.code),
      contains('date_invalid'),
    );
  });
}

class _UnusedReader implements YimuWorkbookReader {
  const _UnusedReader();

  @override
  YimuWorkbook read(ImportFilePayload file) => throw UnimplementedError();
}
