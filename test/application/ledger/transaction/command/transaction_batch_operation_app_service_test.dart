import 'package:flutter_test/flutter_test.dart';
import 'package:smartflow/application/ledger/ledger_command_api.dart';
import 'package:smartflow/application/ledger/ledger_query_port_api.dart';
import 'package:smartflow/application/shared/transaction_runner.dart';
import 'package:smartflow/core/money/money.dart';
import 'package:smartflow/domain/ledger/entity/transaction.dart';
import '../../../../helper/fake_transaction_tag_repository.dart';

void main() {
  test('批量新增标签会保留每笔交易已有标签', () async {
    final tagRepository = FakeTransactionTagRepository();
    await tagRepository.replaceTransactionTags(
      transactionId: 'tx-1',
      tagIds: {'existing'},
    );
    final service = TransactionBatchOperationAppServiceImpl(
      transactionRunner: _RecordingRunner(),
      transactionReadRepository: _FakeReadRepository([
        _transaction('tx-1', BusinessPurpose.dailyExpense),
        _transaction('tx-2', BusinessPurpose.dailyIncome),
      ]),
      transactionEditService: _FakeEditService(),
      transactionTagRepository: tagRepository,
    );

    final result = await service.updateTags(
      BatchTransactionTagsCommand(
        transactionIds: {'tx-1', 'tx-2'},
        operation: TransactionTagBatchOperation.add,
        tagIds: {'new'},
      ),
    );

    expect(result.updatedGroupCount, 2);
    expect(result.skippedGroupCount, 0);
    expect(await tagRepository.transactionTagIds('tx-1'), {'existing', 'new'});
    expect(await tagRepository.transactionTagIds('tx-2'), {'new'});
  });

  test('批量删除标签只移除指定标签', () async {
    final tagRepository = FakeTransactionTagRepository();
    await tagRepository.replaceTransactionTags(
      transactionId: 'tx-1',
      tagIds: {'keep', 'remove'},
    );
    final service = _service(
      tagRepository: tagRepository,
      transactions: [_transaction('tx-1', BusinessPurpose.transfer)],
    );

    final result = await service.updateTags(
      BatchTransactionTagsCommand(
        transactionIds: {'tx-1'},
        operation: TransactionTagBatchOperation.remove,
        tagIds: {'remove'},
      ),
    );

    expect(result.updatedGroupCount, 1);
    expect(await tagRepository.transactionTagIds('tx-1'), {'keep'});
  });

  test('批量清空标签会移除选中交易的全部标签', () async {
    final tagRepository = FakeTransactionTagRepository();
    await tagRepository.replaceTransactionTags(
      transactionId: 'tx-1',
      tagIds: {'work', 'travel'},
    );
    final service = _service(
      tagRepository: tagRepository,
      transactions: [
        _transaction('tx-1', BusinessPurpose.reimbursementAdvance),
      ],
    );

    final result = await service.updateTags(
      BatchTransactionTagsCommand(
        transactionIds: {'tx-1'},
        operation: TransactionTagBatchOperation.clear,
      ),
    );

    expect(result.updatedGroupCount, 1);
    expect(await tagRepository.transactionTagIds('tx-1'), isEmpty);
  });

  test('批量删除会跳过带业务归属的交易组', () async {
    final editService = _FakeEditService();
    final service = TransactionBatchOperationAppServiceImpl(
      transactionRunner: _RecordingRunner(),
      transactionReadRepository: _FakeReadRepository(
        const [],
        cleanupTargets: [
          TransactionCleanupTarget(transactionId: 'plain-1', owned: false),
          TransactionCleanupTarget(transactionId: 'owned-1', owned: true),
        ],
      ),
      transactionEditService: editService,
      transactionTagRepository: FakeTransactionTagRepository(),
    );

    final result = await service.deleteTransactions(
      BatchDeleteTransactionsCommand(transactionIds: {'plain-1', 'owned-1'}),
    );

    expect(result.deletedGroupCount, 1);
    expect(result.skippedGroupCount, 1);
    expect(editService.deletedIds, ['plain-1']);
  });

  test('批量标签操作会跳过不支持标签的交易', () async {
    final tagRepository = FakeTransactionTagRepository();
    final service = _service(
      tagRepository: tagRepository,
      transactions: [
        _transaction('tx-1', BusinessPurpose.dailyExpense),
        _transaction('tx-2', BusinessPurpose.openingBalance),
      ],
    );

    final result = await service.updateTags(
      BatchTransactionTagsCommand(
        transactionIds: {'tx-1', 'tx-2'},
        operation: TransactionTagBatchOperation.add,
        tagIds: {'new'},
      ),
    );

    expect(result.updatedGroupCount, 1);
    expect(result.skippedGroupCount, 1);
    expect(await tagRepository.transactionTagIds('tx-1'), {'new'});
    expect(await tagRepository.transactionTagIds('tx-2'), isEmpty);
  });
}

TransactionBatchOperationAppService _service({
  required FakeTransactionTagRepository tagRepository,
  required List<Transaction> transactions,
}) {
  return TransactionBatchOperationAppServiceImpl(
    transactionRunner: _RecordingRunner(),
    transactionReadRepository: _FakeReadRepository(transactions),
    transactionEditService: _FakeEditService(),
    transactionTagRepository: tagRepository,
  );
}

Transaction _transaction(String id, BusinessPurpose purpose) {
  return Transaction(
    id: id,
    businessPurpose: purpose,
    occurredAt: DateTime(2026, 1, 1),
    primaryAmount: const Money(minorUnits: 1000),
    isExcludedFromStats: false,
    isExcludedFromBudget: false,
    sourceKind: SourceKind.manual,
  );
}

class _RecordingRunner implements TransactionRunner {
  @override
  Future<T> run<T>(Future<T> Function() body) => body();
}

class _FakeReadRepository implements TransactionReadRepository {
  _FakeReadRepository(this.transactions, {this.cleanupTargets = const []});

  final List<Transaction> transactions;
  final List<TransactionCleanupTarget> cleanupTargets;

  @override
  Future<List<Transaction>> findByIds(Set<String> ids) async {
    return transactions
        .where((transaction) => ids.contains(transaction.id))
        .toList();
  }

  @override
  Future<List<TransactionCleanupTarget>> findCleanupTargets(
    TransactionCleanupQuery query,
  ) async => cleanupTargets;

  @override
  dynamic noSuchMethod(Invocation invocation) =>
      throw UnimplementedError('${invocation.memberName}');
}

class _FakeEditService implements TransactionEditAppService {
  final List<String> deletedIds = [];

  @override
  Future<void> deleteTransaction(DeleteTransactionCommand command) async {
    deletedIds.add(command.transactionId);
  }

  @override
  dynamic noSuchMethod(Invocation invocation) =>
      throw UnimplementedError('${invocation.memberName}');
}
