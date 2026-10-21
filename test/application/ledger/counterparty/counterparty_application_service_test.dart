import 'package:flutter_test/flutter_test.dart';
import 'package:smartflow/application/ledger/counterparty/command/counterparty_application_service.dart';
import 'package:smartflow/application/shared/transaction_runner.dart';
import 'package:smartflow/core/id/id_generator.dart';

import '../../../helper/fake_counterparty_repository.dart';

void main() {
  late FakeCounterpartyRepository repository;
  late CounterpartyApplicationService service;

  setUp(() {
    repository = FakeCounterpartyRepository();
    service = CounterpartyApplicationService(
      repository: repository,
      idGenerator: _SequentialIds(),
      transactionRunner: const _DirectTransactionRunner(),
    );
  });

  test('creates a trimmed counterparty with a generated id', () async {
    final id = await service.createCounterparty('  自如  ');

    expect(id, 'id-1');
    final counterparties = await service.listCounterparties();
    expect(counterparties.single.name, '自如');
  });

  test('reuses an existing counterparty with the same name', () async {
    final first = await service.createCounterparty('自如');
    final second = await service.createCounterparty(' 自如 ');

    expect(second, first);
    expect(await service.listCounterparties(), hasLength(1));
  });

  test('rejects blank names', () async {
    await expectLater(service.createCounterparty('   '), throwsArgumentError);
  });

  test('renames a counterparty and rejects a duplicate name', () async {
    final first = await service.createCounterparty('自如');
    final second = await service.createCounterparty('农夫山泉');

    await service.renameCounterparty(id: second, name: '  怡宝  ');

    expect((await service.listCounterparties()).map((item) => item.name), [
      '怡宝',
      '自如',
    ]);
    await expectLater(
      service.renameCounterparty(id: second, name: '自如'),
      throwsStateError,
    );
    expect((await service.listCounterparties()).map((item) => item.id), {
      first,
      second,
    });
  });

  test(
    'deletes a counterparty after clearing transaction references',
    () async {
      final id = await service.createCounterparty('自如');

      await service.deleteCounterparty(id);

      expect(repository.clearedCounterpartyIds, {id});
      expect(await service.listCounterparties(), isEmpty);
    },
  );
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
