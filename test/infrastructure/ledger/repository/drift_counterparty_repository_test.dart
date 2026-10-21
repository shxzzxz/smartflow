import 'package:drift/drift.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:smartflow/domain/ledger/valobj/ledger_enum.dart';
import 'package:smartflow/infrastructure/database/app_database.dart';
import 'package:smartflow/infrastructure/ledger/repository/drift_counterparty_repository.dart';

import '../../../helper/test_app_database.dart';

void main() {
  test('lists counterparties by name and resolves ids', () async {
    final database = createTestDatabase();
    addTearDown(database.close);
    final repository = DriftCounterpartyRepository(database);
    await repository.insertCounterparty(id: 'cp-b', name: '农夫山泉');
    await repository.insertCounterparty(id: 'cp-a', name: '自如');

    final counterparties = await repository.listCounterparties();
    expect(counterparties.map((item) => item.name), ['农夫山泉', '自如']);

    final byId = await repository.findByIds(const {'cp-a', 'missing'});
    expect(byId.keys, {'cp-a'});
    expect(byId['cp-a']?.name, '自如');
  });

  test(
    'counterparty names are unique without a database foreign key',
    () async {
      final database = createTestDatabase();
      addTearDown(database.close);
      final repository = DriftCounterpartyRepository(database);
      await repository.insertCounterparty(id: 'cp-a', name: '自如');

      await expectLater(
        repository.insertCounterparty(id: 'cp-b', name: '自如'),
        throwsA(isA<Exception>()),
      );
      expect(
        await database
            .customSelect('PRAGMA foreign_key_list(counterparties)')
            .get(),
        isEmpty,
      );
      expect(
        await database
            .customSelect('PRAGMA foreign_key_list(transactions)')
            .get(),
        isEmpty,
      );
    },
  );

  test(
    'counts transaction references and detaches them before deletion',
    () async {
      final database = createTestDatabase();
      addTearDown(database.close);
      final repository = DriftCounterpartyRepository(database);
      await repository.insertCounterparty(id: 'cp-a', name: '自如');
      await database.batch((batch) {
        batch.insertAll(database.transactions, [
          _transaction('tx-1', 'cp-a'),
          _transaction('tx-2', 'cp-a'),
          _transaction('tx-3'),
        ]);
      });

      final counterparty = (await repository.listCounterparties()).single;
      expect(counterparty.usageCount, 2);

      await repository.renameCounterparty(id: 'cp-a', name: '链家');
      expect((await repository.findByIds({'cp-a'}))['cp-a']?.name, '链家');

      await repository.clearTransactionReferences('cp-a');
      final rows = await database.select(database.transactions).get();
      expect(rows.map((row) => row.counterpartyId), [null, null, null]);

      await repository.deleteCounterparty('cp-a');
      expect(await repository.listCounterparties(), isEmpty);
    },
  );
}

TransactionsCompanion _transaction(String id, [String? counterpartyId]) {
  return TransactionsCompanion.insert(
    id: id,
    businessPurpose: BusinessPurpose.dailyExpense,
    occurredAt: DateTime(2026, 10, 1),
    postedAt: DateTime(2026, 10, 1),
    primaryAmountMinor: 100,
    counterpartyId: Value(counterpartyId),
    sourceKind: SourceKind.manual,
  );
}
