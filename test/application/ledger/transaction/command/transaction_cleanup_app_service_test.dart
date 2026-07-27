import 'package:flutter_test/flutter_test.dart';
import 'package:smartflow/application/ledger/ledger_command_api.dart';
import 'package:smartflow/application/ledger/ledger_query_port_api.dart';
import 'package:smartflow/application/shared/transaction_runner.dart';
import 'package:smartflow/domain/ledger/valobj/ledger_violation_reason.dart';

void main() {
  test('跳过带业务归属的交易组，其余按组删除', () async {
    final runner = _RecordingRunner();
    final readRepository = _FakeReadRepository(const [
      TransactionCleanupTarget(transactionId: 'plain-1', owned: false),
      TransactionCleanupTarget(transactionId: 'owned-1', owned: true),
      TransactionCleanupTarget(transactionId: 'plain-2', owned: false),
    ]);
    final editService = _RecordingEditService();
    final service = TransactionCleanupAppServiceImpl(
      transactionRunner: runner,
      transactionReadRepository: readRepository,
      editService: editService,
    );

    final result = await service.cleanupTransactions(
      CleanupTransactionsCommand(
        categoryIds: const {'cat-food'},
        occurredFrom: DateTime(2026, 6, 1),
        occurredUntil: DateTime(2026, 7, 1),
      ),
    );

    expect(result.deletedGroupCount, 2);
    expect(result.skippedGroupCount, 1);
    expect(editService.deletedIds, ['plain-1', 'plain-2']);
    expect(runner.runCalls, 1);
    expect(readRepository.lastQuery?.categoryIds, {'cat-food'});
    expect(readRepository.lastQuery?.accountIds, isNull);
    expect(readRepository.lastQuery?.occurredFrom, DateTime(2026, 6, 1));
    expect(readRepository.lastQuery?.occurredUntil, DateTime(2026, 7, 1));
  });

  test('没有命中时返回零计数且不触发删除', () async {
    final editService = _RecordingEditService();
    final service = TransactionCleanupAppServiceImpl(
      transactionRunner: _RecordingRunner(),
      transactionReadRepository: _FakeReadRepository(const []),
      editService: editService,
    );

    final result = await service.cleanupTransactions(
      const CleanupTransactionsCommand(),
    );

    expect(result.deletedGroupCount, 0);
    expect(result.skippedGroupCount, 0);
    expect(editService.deletedIds, isEmpty);
  });

  test('删除失败时在事务内向外传播异常', () async {
    final editService = _RecordingEditService(failOn: {'plain-2'});
    final service = TransactionCleanupAppServiceImpl(
      transactionRunner: _RecordingRunner(),
      transactionReadRepository: _FakeReadRepository(const [
        TransactionCleanupTarget(transactionId: 'plain-1', owned: false),
        TransactionCleanupTarget(transactionId: 'plain-2', owned: false),
      ]),
      editService: editService,
    );

    await expectLater(
      service.cleanupTransactions(const CleanupTransactionsCommand()),
      throwsA(isA<Exception>()),
    );
    expect(editService.deletedIds, ['plain-1']);
  });
}

class _RecordingRunner implements TransactionRunner {
  int runCalls = 0;

  @override
  Future<T> run<T>(Future<T> Function() body) {
    runCalls++;
    return body();
  }
}

class _FakeReadRepository implements TransactionReadRepository {
  _FakeReadRepository(this.targets);

  final List<TransactionCleanupTarget> targets;
  TransactionCleanupQuery? lastQuery;

  @override
  Future<List<TransactionCleanupTarget>> findCleanupTargets(
    TransactionCleanupQuery query,
  ) async {
    lastQuery = query;
    return targets;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) =>
      throw UnimplementedError('${invocation.memberName}');
}

class _RecordingEditService implements TransactionEditAppService {
  _RecordingEditService({this.failOn = const {}});

  final Set<String> failOn;
  final List<String> deletedIds = [];

  @override
  Future<void> deleteTransaction(DeleteTransactionCommand command) async {
    if (failOn.contains(command.transactionId)) {
      LedgerViolationReason.transactionNotFound.throwException();
    }
    deletedIds.add(command.transactionId);
  }

  @override
  dynamic noSuchMethod(Invocation invocation) =>
      throw UnimplementedError('${invocation.memberName}');
}
