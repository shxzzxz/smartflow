import 'package:drift/drift.dart' hide isNotNull, isNull;
import 'package:flutter_test/flutter_test.dart';
import 'package:smartflow/core/money/money.dart';
import 'package:smartflow/core/patch/patch.dart';
import 'package:smartflow/domain/ledger/entity/entry.dart';
import 'package:smartflow/domain/ledger/entity/transaction.dart';
import 'package:smartflow/domain/ledger/entity/transaction_detail_record.dart';
import 'package:smartflow/domain/ledger/service/mutation/transaction_group_rewrite_plan.dart';
import 'package:smartflow/domain/ledger/valobj/ledger_enum.dart';
import 'package:smartflow/infrastructure/database/app_database.dart';
import 'package:smartflow/infrastructure/ledger/repository/drift_posting_repository.dart';

import '../../../helper/test_app_database.dart';

void main() {
  test(
    'group writes preserve row-only lines and delete the requested scope',
    () async {
      final database = createTestDatabase();
      addTearDown(database.close);
      final repository = DriftPostingRepository(database);
      final parent = _transaction('parent');
      final childA = _transaction('child-a', parentTransactionId: parent.id);
      final childB = _transaction('child-b', parentTransactionId: parent.id);
      await repository.saveAll([parent, childA, childB]);
      final beforeLines = await _lineSnapshots(database, parent.id);

      final updatedParent = parent.copyWith(
        notePatch: const Patch<String>.set('metadata only'),
      );
      await repository.applyRewrite(
        TransactionGroupRewritePlan(
          rewrites: const [],
          rowUpdates: [updatedParent],
          currentGroup: (await repository.findByParentId(parent.id))!,
        ),
      );

      final storedParent = await repository.findCompleteById(parent.id);
      expect(storedParent?.note, 'metadata only');
      expect(await _lineSnapshots(database, parent.id), beforeLines);

      await repository.deleteChild(childA.id);
      expect(await repository.findCompleteById(parent.id), isNotNull);
      expect(await repository.findCompleteById(childA.id), isNull);
      expect(await repository.findCompleteById(childB.id), isNotNull);

      await repository.deleteGroup(parent.id);
      expect(await repository.findCompleteById(parent.id), isNull);
      expect(await repository.findCompleteById(childB.id), isNull);
      final remainingLines =
          await database
              .customSelect(
                "SELECT COUNT(*) AS count FROM transaction_details "
                "WHERE transaction_id IN ('parent', 'child-a', 'child-b')",
              )
              .getSingle();
      expect(remainingLines.read<int>('count'), 0);
    },
  );
}

Transaction _transaction(String id, {String? parentTransactionId}) {
  const amount = Money(minorUnits: 1000);
  return Transaction(
    id: id,
    businessPurpose:
        parentTransactionId == null
            ? BusinessPurpose.dailyExpense
            : BusinessPurpose.refund,
    occurredAt: DateTime(2026, 7, 1),
    primaryAmount: amount,
    parentTransactionId: parentTransactionId,
    isExcludedFromStats: false,
    isExcludedFromBudget: false,
    sourceKind: SourceKind.manual,
    details: [
      TransactionDetailRecord(
        id: 'detail-$id',
        transactionId: id,
        lineNo: 1,
        type:
            parentTransactionId == null
                ? TransactionDetailType.primaryExpense
                : TransactionDetailType.refundMain,
        amount: amount,
      ),
    ],
    entries: [
      Entry(
        id: 'entry-$id-debit',
        transactionId: id,
        accountId: 'debit-$id',
        direction: EntryDirection.debit,
        amount: amount,
      ),
      Entry(
        id: 'entry-$id-credit',
        transactionId: id,
        accountId: 'credit-$id',
        direction: EntryDirection.credit,
        amount: amount,
      ),
    ],
  );
}

Future<List<String>> _lineSnapshots(
  AppDatabase database,
  String transactionId,
) async {
  final rows =
      await database
          .customSelect(
            'SELECT id, created_at FROM transaction_details WHERE transaction_id = ? '
            'UNION ALL '
            'SELECT id, created_at FROM entries WHERE transaction_id = ? '
            'ORDER BY id',
            variables: [
              Variable<String>(transactionId),
              Variable<String>(transactionId),
            ],
          )
          .get();
  return [
    for (final row in rows)
      '${row.read<String>('id')}:${row.read<int>('created_at')}',
  ];
}
