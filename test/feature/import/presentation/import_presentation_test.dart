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
  });
}
