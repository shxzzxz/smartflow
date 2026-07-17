import 'package:flutter_test/flutter_test.dart';
import 'package:smartflow/domain/ledger/valobj/ledger_enum.dart';
import 'package:smartflow/infrastructure/credit/repository/drift_credit_bill_source_repository.dart';
import 'package:smartflow/infrastructure/database/app_database.dart';

import '../../../helper/test_app_database.dart';

void main() {
  test('uses posted_at date when calculating credit consumption', () async {
    final database = createTestDatabase();
    addTearDown(database.close);
    await _insertExpense(
      database,
      id: 'expense',
      occurredAt: DateTime(2026, 3, 31),
      postedAt: DateTime(2026, 4, 1),
      amountMinor: 10000,
    );
    await _insertRefund(
      database,
      id: 'refund',
      occurredAt: DateTime(2026, 4, 2),
      postedAt: DateTime(2026, 3, 31),
      amountMinor: 3000,
    );

    final result = await DriftCreditBillSourceRepository(
      database,
    ).netConsumptionMinor(
      accountId: 'credit-card',
      startInclusive: DateTime(2026, 4, 1),
      endExclusive: DateTime(2026, 5, 1),
    );

    expect(result, 10000);
  });
}

Future<void> _insertExpense(
  AppDatabase database, {
  required String id,
  required DateTime occurredAt,
  required DateTime postedAt,
  required int amountMinor,
}) async {
  await database
      .into(database.transactions)
      .insert(
        TransactionsCompanion.insert(
          id: id,
          businessPurpose: BusinessPurpose.dailyExpense,
          occurredAt: occurredAt,
          postedAt: postedAt,
          primaryAmountMinor: amountMinor,
          sourceKind: SourceKind.manual,
        ),
      );
  await database.batch((batch) {
    batch.insertAll(database.entries, [
      EntriesCompanion.insert(
        id: '$id-credit',
        transactionId: id,
        accountId: 'credit-card',
        direction: EntryDirection.credit,
        amountMinor: amountMinor,
      ),
    ]);
  });
}

Future<void> _insertRefund(
  AppDatabase database, {
  required String id,
  required DateTime occurredAt,
  required DateTime postedAt,
  required int amountMinor,
}) async {
  await database
      .into(database.transactions)
      .insert(
        TransactionsCompanion.insert(
          id: id,
          businessPurpose: BusinessPurpose.refund,
          occurredAt: occurredAt,
          postedAt: postedAt,
          primaryAmountMinor: amountMinor,
          sourceKind: SourceKind.manual,
        ),
      );
  await database.batch((batch) {
    batch.insertAll(database.entries, [
      EntriesCompanion.insert(
        id: '$id-debit',
        transactionId: id,
        accountId: 'credit-card',
        direction: EntryDirection.debit,
        amountMinor: amountMinor,
      ),
    ]);
  });
}
