import 'package:flutter_test/flutter_test.dart';
import 'package:smartflow/application/ledger/tag/command/tag_application_service.dart';
import 'package:smartflow/application/shared/transaction_runner.dart';
import 'package:smartflow/core/id/id_generator.dart';

import '../../../helper/fake_transaction_tag_repository.dart';

void main() {
  late FakeTransactionTagRepository repository;
  late TagApplicationService service;

  setUp(() {
    repository = FakeTransactionTagRepository();
    service = TagApplicationService(
      repository: repository,
      idGenerator: _SequentialIds(),
      transactionRunner: const _DirectTransactionRunner(),
    );
  });

  test('createTag inserts a new tag with a generated id', () async {
    final id = await service.createTag(' 旅行 ');

    expect(id, 'id-1');
    final tags = await service.listTags();
    expect(tags.single.name, '旅行');
  });

  test('createTag reuses the existing tag on name collision', () async {
    await service.createTag('旅行');

    final id = await service.createTag('旅行');

    expect(id, 'id-1');
    expect(await service.listTags(), hasLength(1));
  });

  test('createTag rejects blank names', () async {
    await expectLater(service.createTag('   '), throwsArgumentError);
  });

  test('renameTag rejects names already used by another tag', () async {
    await service.createTag('旅行');
    final workId = await service.createTag('出差');

    await expectLater(
      service.renameTag(id: workId, name: '旅行'),
      throwsStateError,
    );
  });

  test('renameTag allows keeping the current name', () async {
    final travelId = await service.createTag('旅行');

    await service.renameTag(id: travelId, name: '旅行');

    expect((await service.listTags()).single.name, '旅行');
  });

  test('mergeTags rejects merging a tag into itself', () async {
    final id = await service.createTag('旅行');

    await expectLater(
      service.mergeTags(sourceIds: {id}, targetId: id),
      throwsArgumentError,
    );
  });

  test('mergeTags retags transactions onto the target', () async {
    final travelId = await service.createTag('旅行');
    final workId = await service.createTag('出差');
    await repository.replaceTransactionTags(
      transactionId: 'tx-1',
      tagIds: {travelId, workId},
    );
    await repository.replaceTransactionTags(
      transactionId: 'tx-2',
      tagIds: {travelId},
    );

    await service.mergeTags(sourceIds: {travelId}, targetId: workId);

    expect(await service.listTags(), hasLength(1));
    expect(await service.transactionTagIds('tx-1'), {workId});
    expect(await service.transactionTagIds('tx-2'), {workId});
  });

  test('migrateTags retags transactions and keeps source tags', () async {
    final travelId = await service.createTag('旅行');
    final workId = await service.createTag('出差');
    await repository.replaceTransactionTags(
      transactionId: 'tx-1',
      tagIds: {travelId, workId},
    );
    await repository.replaceTransactionTags(
      transactionId: 'tx-2',
      tagIds: {travelId},
    );

    await service.migrateTags(sourceIds: {travelId}, targetId: workId);

    expect((await service.listTags()).map((tag) => tag.id), {travelId, workId});
    expect(await service.transactionTagIds('tx-1'), {workId});
    expect(await service.transactionTagIds('tx-2'), {workId});
  });

  test('deleteTags removes all selected tags and their references', () async {
    final travelId = await service.createTag('旅行');
    final workId = await service.createTag('出差');
    final homeId = await service.createTag('家庭');
    await repository.replaceTransactionTags(
      transactionId: 'tx-1',
      tagIds: {travelId, workId},
    );

    await service.deleteTags({travelId, workId});

    expect((await service.listTags()).map((tag) => tag.id), {homeId});
    expect(await service.transactionTagIds('tx-1'), isEmpty);
  });
}

class _SequentialIds implements IdGenerator {
  var _next = 0;

  @override
  String newId() => 'id-${++_next}';
}

class _DirectTransactionRunner implements TransactionRunner {
  const _DirectTransactionRunner();

  @override
  Future<T> run<T>(Future<T> Function() body) => body();
}
