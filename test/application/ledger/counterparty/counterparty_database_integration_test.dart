import 'package:drift/drift.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:smartflow/application/ledger/counterparty/command/counterparty_application_service.dart';
import 'package:smartflow/application/ledger/counterparty/query/counterparty_read_models.dart';
import 'package:smartflow/application/ledger/counterparty/query/port/counterparty_repository.dart';
import 'package:smartflow/core/id/id_generator.dart';
import 'package:smartflow/domain/ledger/valobj/ledger_enum.dart';
import 'package:smartflow/infrastructure/database/app_database.dart';
import 'package:smartflow/infrastructure/database/drift_transaction_runner.dart';
import 'package:smartflow/infrastructure/ledger/repository/drift_counterparty_repository.dart';

import '../../../helper/test_app_database.dart';

void main() {
  test(
    'migrating counterparties retargets transactions and keeps the vocabulary',
    () async {
      final database = createTestDatabase();
      addTearDown(database.close);
      final repository = DriftCounterpartyRepository(database);
      await repository.insertCounterparty(id: 'cp-a', name: '自如');
      await repository.insertCounterparty(id: 'cp-b', name: '链家');
      await database.into(database.transactions).insert(_transaction());
      final service = _service(database, repository);

      await service.migrateCounterparties(
        sourceIds: const {'cp-a'},
        targetId: 'cp-b',
      );

      final transaction = await database
          .select(database.transactions)
          .getSingle();
      expect(transaction.counterpartyId, 'cp-b');
      expect((await repository.listCounterparties()).map((item) => item.id), {
        'cp-a',
        'cp-b',
      });
    },
  );

  test(
    'merging counterparties retargets transactions and removes the source',
    () async {
      final database = createTestDatabase();
      addTearDown(database.close);
      final repository = DriftCounterpartyRepository(database);
      await repository.insertCounterparty(id: 'cp-a', name: '自如');
      await repository.insertCounterparty(id: 'cp-b', name: '链家');
      await database.into(database.transactions).insert(_transaction());
      final service = _service(database, repository);

      await service.mergeCounterparties(
        sourceIds: const {'cp-a'},
        targetId: 'cp-b',
      );

      final transaction = await database
          .select(database.transactions)
          .getSingle();
      expect(transaction.counterpartyId, 'cp-b');
      expect((await repository.listCounterparties()).map((item) => item.id), {
        'cp-b',
      });
    },
  );

  test(
    'bulk deletion clears references for every selected counterparty',
    () async {
      final database = createTestDatabase();
      addTearDown(database.close);
      final repository = DriftCounterpartyRepository(database);
      await repository.insertCounterparty(id: 'cp-a', name: '自如');
      await repository.insertCounterparty(id: 'cp-b', name: '链家');
      await repository.insertCounterparty(id: 'cp-c', name: '农夫山泉');
      await database.batch((batch) {
        batch.insertAll(database.transactions, [
          _transaction(),
          _transaction(id: 'tx-2', counterpartyId: 'cp-b'),
        ]);
      });
      final service = _service(database, repository);

      await service.deleteCounterparties({'cp-a', 'cp-b'});

      final transactions = await database.select(database.transactions).get();
      expect(transactions.map((item) => item.counterpartyId), [null, null]);
      expect((await repository.listCounterparties()).map((item) => item.id), {
        'cp-c',
      });
    },
  );

  test(
    'rolls back retargeting when a merged counterparty cannot be deleted',
    () async {
      final database = createTestDatabase();
      addTearDown(database.close);
      final repository = DriftCounterpartyRepository(database);
      await repository.insertCounterparty(id: 'cp-a', name: '自如');
      await repository.insertCounterparty(id: 'cp-b', name: '链家');
      await database.into(database.transactions).insert(_transaction());
      final service = _service(database, _FailOnDeleteRepository(repository));

      await expectLater(
        service.mergeCounterparties(
          sourceIds: const {'cp-a'},
          targetId: 'cp-b',
        ),
        throwsA(isA<StateError>()),
      );

      final transaction = await database
          .select(database.transactions)
          .getSingle();
      expect(transaction.counterpartyId, 'cp-a');
      expect((await repository.listCounterparties()).map((item) => item.id), {
        'cp-a',
        'cp-b',
      });
    },
  );

  test(
    'deleting a counterparty clears references and removes the vocabulary',
    () async {
      final database = createTestDatabase();
      addTearDown(database.close);
      final repository = DriftCounterpartyRepository(database);
      await repository.insertCounterparty(id: 'cp-a', name: '自如');
      await database.into(database.transactions).insert(_transaction());
      final service = _service(database, repository);

      await service.deleteCounterparty('cp-a');

      final transaction = await database
          .select(database.transactions)
          .getSingle();
      expect(transaction.counterpartyId, null);
      expect(await repository.listCounterparties(), isEmpty);
    },
  );

  test(
    'rolls back reference cleanup when deleting the vocabulary fails',
    () async {
      final database = createTestDatabase();
      addTearDown(database.close);
      final repository = DriftCounterpartyRepository(database);
      await repository.insertCounterparty(id: 'cp-a', name: '自如');
      await database.into(database.transactions).insert(_transaction());
      final service = _service(database, _FailingDeleteRepository(repository));

      await expectLater(
        service.deleteCounterparty('cp-a'),
        throwsA(isA<StateError>()),
      );

      final transaction = await database
          .select(database.transactions)
          .getSingle();
      expect(transaction.counterpartyId, 'cp-a');
      expect(await repository.listCounterparties(), hasLength(1));
    },
  );
}

CounterpartyApplicationService _service(
  AppDatabase database,
  CounterpartyRepository repository,
) {
  return CounterpartyApplicationService(
    repository: repository,
    idGenerator: const _Ids(),
    transactionRunner: DriftTransactionRunner(database),
  );
}

TransactionsCompanion _transaction({
  String id = 'tx-1',
  String counterpartyId = 'cp-a',
}) {
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

class _FailingDeleteRepository implements CounterpartyRepository {
  const _FailingDeleteRepository(this._delegate);

  final DriftCounterpartyRepository _delegate;

  @override
  Future<void> clearTransactionReferences(String counterpartyId) {
    return _delegate.clearTransactionReferences(counterpartyId);
  }

  @override
  Future<void> deleteCounterparty(String id) {
    throw StateError('delete failed');
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _Ids implements IdGenerator {
  const _Ids();

  @override
  String newId() => 'unused';
}

class _FailOnDeleteRepository implements CounterpartyRepository {
  const _FailOnDeleteRepository(this._delegate);

  final DriftCounterpartyRepository _delegate;

  @override
  Future<List<CounterpartyView>> listCounterparties() {
    return _delegate.listCounterparties();
  }

  @override
  Future<void> reassignTransactionReferences({
    required Set<String> sourceIds,
    required String targetId,
  }) {
    return _delegate.reassignTransactionReferences(
      sourceIds: sourceIds,
      targetId: targetId,
    );
  }

  @override
  Future<void> deleteCounterparty(String id) {
    throw StateError('merge failed');
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
