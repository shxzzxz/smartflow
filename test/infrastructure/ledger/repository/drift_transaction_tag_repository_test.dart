import 'package:drift/drift.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:smartflow/application/ledger/tag/query/tag_read_models.dart';
import 'package:smartflow/domain/ledger/valobj/ledger_enum.dart';
import 'package:smartflow/infrastructure/database/app_database.dart';
import 'package:smartflow/infrastructure/ledger/repository/drift_transaction_tag_repository.dart';

import '../../../helper/test_app_database.dart';

void main() {
  test('lists tags in vocabulary order with usage counts', () async {
    final database = createTestDatabase();
    addTearDown(database.close);
    await _insertTags(database, {'tag-b': '旅行', 'tag-a': '装修', 'tag-c': '项目'});
    await _link(database, 'tx-1', 'tag-b');

    final tags = await DriftTransactionTagRepository(database).listTags();

    expect(tags.map((tag) => tag.name), ['旅行', '装修', '项目']);
    expect(tags.firstWhere((tag) => tag.name == '旅行').usageCount, 1);
    expect(tags.firstWhere((tag) => tag.name == '装修').usageCount, 0);
  });

  test('replaces transaction tags wholesale and drops unknown ids', () async {
    final database = createTestDatabase();
    addTearDown(database.close);
    await _insertTransaction(database, 'tx-1');
    await _insertTags(database, {'tag-a': '旅行', 'tag-b': '装修'});
    final repository = DriftTransactionTagRepository(database);

    await repository.replaceTransactionTags(
      transactionId: 'tx-1',
      tagIds: const {'tag-a', 'missing-tag'},
    );
    expect(await repository.transactionTagIds('tx-1'), {'tag-a'});

    await repository.replaceTransactionTags(
      transactionId: 'tx-1',
      tagIds: const {'tag-b'},
    );
    expect(await repository.transactionTagIds('tx-1'), {'tag-b'});

    await repository.replaceTransactionTags(
      transactionId: 'tx-1',
      tagIds: const {},
    );
    expect(await repository.transactionTagIds('tx-1'), isEmpty);
  });

  test(
    'child transactions inherit the tags of their top-level group',
    () async {
      final database = createTestDatabase();
      addTearDown(database.close);
      await _insertTransaction(database, 'top');
      await _insertTransaction(database, 'child', parentTransactionId: 'top');
      await _insertTags(database, {'tag-a': '旅行'});
      final repository = DriftTransactionTagRepository(database);

      await repository.replaceTransactionTags(
        transactionId: 'top',
        tagIds: const {'tag-a'},
      );

      expect(await repository.transactionTagIds('child'), {'tag-a'});
      expect(await repository.transactionTagIds('missing'), isEmpty);
    },
  );

  test('merging retags transactions and removes the source tag', () async {
    final database = createTestDatabase();
    addTearDown(database.close);
    await _insertTransaction(database, 'tx-1');
    await _insertTransaction(database, 'tx-2');
    await _insertTags(database, {'tag-a': '旅行', 'tag-b': '出差'});
    final repository = DriftTransactionTagRepository(database);
    await repository.replaceTransactionTags(
      transactionId: 'tx-1',
      tagIds: const {'tag-a', 'tag-b'},
    );
    await repository.replaceTransactionTags(
      transactionId: 'tx-2',
      tagIds: const {'tag-b'},
    );

    await repository.mergeTags(sourceId: 'tag-a', targetId: 'tag-b');

    expect((await repository.listTags()).map((tag) => tag.name), ['出差']);
    expect(await repository.transactionTagIds('tx-1'), {'tag-b'});
    expect(await repository.transactionTagIds('tx-2'), {'tag-b'});
  });

  test('deleting a tag removes its associations', () async {
    final database = createTestDatabase();
    addTearDown(database.close);
    await _insertTransaction(database, 'tx-1');
    await _insertTags(database, {'tag-a': '旅行'});
    final repository = DriftTransactionTagRepository(database);
    await repository.replaceTransactionTags(
      transactionId: 'tx-1',
      tagIds: const {'tag-a'},
    );

    await repository.deleteTag('tag-a');

    expect(await repository.listTags(), isEmpty);
    expect(await repository.transactionTagIds('tx-1'), isEmpty);
  });

  test('moving a tag materializes the vocabulary order', () async {
    final database = createTestDatabase();
    addTearDown(database.close);
    await _insertTags(database, {
      'tag-a': 'alpha',
      'tag-b': 'beta',
      'tag-c': 'gamma',
    });
    final repository = DriftTransactionTagRepository(database);

    await repository.moveTag(id: 'tag-c', delta: -1);

    expect((await repository.listTags()).map((tag) => tag.name), [
      'alpha',
      'gamma',
      'beta',
    ]);
  });

  test('watchTags emits again after tag table changes', () async {
    final database = createTestDatabase();
    addTearDown(database.close);
    final repository = DriftTransactionTagRepository(database);
    final stream = repository.watchTags();
    final first = await stream.first;
    expect(first, isEmpty);

    await repository.insertTag(id: 'tag-a', name: '旅行');
    final second = await repository.watchTags().first;
    expect(second, hasLength(1));
    expect(
      second.single,
      const TagView(id: 'tag-a', name: '旅行', sortOrder: 0, usageCount: 0),
    );
  });
}

Future<void> _insertTags(AppDatabase database, Map<String, String> byId) async {
  await database.batch((batch) {
    byId.forEach((id, name) {
      batch.insert(database.tags, TagsCompanion.insert(id: id, name: name));
    });
  });
}

Future<void> _link(
  AppDatabase database,
  String transactionId,
  String tagId,
) async {
  await database
      .into(database.transactionTags)
      .insert(
        TransactionTagsCompanion.insert(
          transactionId: transactionId,
          tagId: tagId,
        ),
      );
}

Future<void> _insertTransaction(
  AppDatabase database,
  String id, {
  String? parentTransactionId,
}) async {
  await database
      .into(database.transactions)
      .insert(
        TransactionsCompanion.insert(
          id: id,
          businessPurpose: BusinessPurpose.dailyExpense,
          occurredAt: DateTime(2026, 1, 1),
          postedAt: DateTime(2026, 1, 1),
          primaryAmountMinor: 100,
          parentTransactionId: Value(parentTransactionId),
          sourceKind: SourceKind.manual,
        ),
      );
}
