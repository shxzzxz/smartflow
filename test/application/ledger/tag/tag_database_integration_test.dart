import 'package:flutter_test/flutter_test.dart';
import 'package:smartflow/application/ledger/tag/command/tag_application_service.dart';
import 'package:smartflow/application/ledger/tag/query/port/tag_repository.dart';
import 'package:smartflow/application/ledger/tag/query/tag_read_models.dart';
import 'package:smartflow/core/id/id_generator.dart';
import 'package:smartflow/domain/ledger/valobj/ledger_enum.dart';
import 'package:smartflow/infrastructure/database/app_database.dart';
import 'package:smartflow/infrastructure/database/drift_transaction_runner.dart';
import 'package:smartflow/infrastructure/ledger/repository/drift_transaction_tag_repository.dart';

import '../../../helper/test_app_database.dart';

void main() {
  test(
    'batch migration rolls back after retagging an earlier source',
    () async {
      final database = createTestDatabase();
      addTearDown(database.close);
      final repository = DriftTransactionTagRepository(database);
      await repository.insertTag(id: 'tag-a', name: '旅行');
      await repository.insertTag(id: 'tag-b', name: '出差');
      await repository.insertTag(id: 'tag-c', name: '家庭');
      await database.batch((batch) {
        batch.insertAll(database.transactions, [
          _transaction('tx-1'),
          _transaction('tx-2'),
        ]);
      });
      await repository.replaceTransactionTags(
        transactionId: 'tx-1',
        tagIds: const {'tag-a'},
      );
      await repository.replaceTransactionTags(
        transactionId: 'tx-2',
        tagIds: const {'tag-b'},
      );
      final service = TagApplicationService(
        repository: _FailOnMigrateRepository(repository),
        idGenerator: const _Ids(),
        transactionRunner: DriftTransactionRunner(database),
      );

      await expectLater(
        service.migrateTags(sourceIds: {'tag-a', 'tag-b'}, targetId: 'tag-c'),
        throwsA(isA<StateError>()),
      );

      expect(await repository.transactionTagIds('tx-1'), {'tag-a'});
      expect(await repository.transactionTagIds('tx-2'), {'tag-b'});
    },
  );

  test(
    'batch deletion rolls back when a later tag cannot be removed',
    () async {
      final database = createTestDatabase();
      addTearDown(database.close);
      final repository = DriftTransactionTagRepository(database);
      await repository.insertTag(id: 'tag-a', name: '旅行');
      await repository.insertTag(id: 'tag-b', name: '出差');
      final service = TagApplicationService(
        repository: _FailingDeleteRepository(repository),
        idGenerator: const _Ids(),
        transactionRunner: DriftTransactionRunner(database),
      );

      await expectLater(
        service.deleteTags({'tag-a', 'tag-b'}),
        throwsA(isA<StateError>()),
      );

      expect((await repository.listTags()).map((tag) => tag.id), {
        'tag-a',
        'tag-b',
      });
    },
  );
}

class _FailingDeleteRepository implements TransactionTagRepository {
  const _FailingDeleteRepository(this._delegate);

  final TransactionTagRepository _delegate;

  @override
  Future<void> deleteTag(String id) {
    if (id == 'tag-b') throw StateError('delete failed');
    return _delegate.deleteTag(id);
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _FailOnMigrateRepository implements TransactionTagRepository {
  _FailOnMigrateRepository(this._delegate);

  final TransactionTagRepository _delegate;
  var _migrationCount = 0;

  @override
  Future<List<TagView>> listTags() => _delegate.listTags();

  @override
  Future<void> migrateTag({
    required String sourceId,
    required String targetId,
  }) {
    _migrationCount++;
    if (_migrationCount == 2) throw StateError('migration failed');
    return _delegate.migrateTag(sourceId: sourceId, targetId: targetId);
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _Ids implements IdGenerator {
  const _Ids();

  @override
  String newId() => 'unused';
}

TransactionsCompanion _transaction(String id) {
  return TransactionsCompanion.insert(
    id: id,
    businessPurpose: BusinessPurpose.dailyExpense,
    occurredAt: DateTime(2026, 10, 1),
    postedAt: DateTime(2026, 10, 1),
    primaryAmountMinor: 100,
    sourceKind: SourceKind.manual,
  );
}
