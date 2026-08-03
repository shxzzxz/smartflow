import 'package:smartflow/application/ledger/transaction/command/transaction_ledger_writer.dart';
import 'package:smartflow/application/shared/transaction_runner.dart';
import 'package:smartflow/core/money/money.dart';
import 'package:smartflow/domain/ledger/entity/account.dart';
import 'package:smartflow/domain/ledger/entity/transaction.dart';
import 'package:smartflow/domain/ledger/entity/transaction_group.dart';
import 'package:smartflow/domain/ledger/port/account_repository.dart';
import 'package:smartflow/domain/ledger/port/transaction_group_repository.dart';
import 'package:smartflow/domain/ledger/port/transaction_repository.dart';
import 'package:smartflow/domain/ledger/service/mutation/transaction_group_rewrite_plan.dart';
import 'package:smartflow/domain/ledger/service/mutation/transaction_deletion_result.dart';
import 'package:smartflow/domain/ledger/service/mutation/transaction_group_rewrite_result.dart';
import 'package:smartflow/domain/ledger/valobj/ledger_enum.dart';
import 'package:test/test.dart';

void main() {
  test(
    'plans and persists a rewrite inside one transaction boundary',
    () async {
      final runner = _TrackingRunner();
      final transactions = _FakeTransactionRepository(runner);
      final accounts = _FakeAccountRepository(runner);
      final writer = TransactionLedgerWriter(
        transactionRunner: runner,
        transactionRepository: transactions,
        transactionGroupRepository: transactions,
        accountRepository: accounts,
      );
      final before = _transaction('tx-1', amount: 1000);
      final after = _transaction('tx-1', amount: 1200);

      final result = await writer.planAndPersistRewrite(() async {
        expect(runner.inTransaction, isTrue);
        return TransactionGroupRewriteResult(
          plan: TransactionGroupRewritePlan(
            rewrites: [TransactionRewrite(before: before, after: after)],
            rowUpdates: const [],
            currentGroup: TransactionGroup(
              parentTransaction: after,
              childTransactions: const [],
            ),
          ),
          accounts: const [],
          currentTransaction: after,
        );
      });

      expect(result.transactionId, 'tx-1');
      expect(transactions.rewrittenIds, ['tx-1']);
      expect(accounts.saveAllCalls, 1);
      expect(runner.inTransaction, isFalse);
    },
  );

  test(
    'plans and persists a deletion inside one transaction boundary',
    () async {
      final runner = _TrackingRunner();
      final transactions = _FakeTransactionRepository(runner);
      final accounts = _FakeAccountRepository(runner);
      final writer = TransactionLedgerWriter(
        transactionRunner: runner,
        transactionRepository: transactions,
        transactionGroupRepository: transactions,
        accountRepository: accounts,
      );

      await writer.planAndPersistDeletion(() async {
        expect(runner.inTransaction, isTrue);
        return TransactionDeletionResult(
          targetTransactionId: 'parent',
          deletesGroup: true,
          deletedTransactions: [_transaction('parent'), _transaction('child')],
          accounts: const [],
        );
      });

      expect(transactions.deletedIds, {'parent', 'child'});
      expect(accounts.saveAllCalls, 1);
      expect(runner.inTransaction, isFalse);
    },
  );
}

Transaction _transaction(String id, {int amount = 1000}) {
  return Transaction(
    id: id,
    businessPurpose: BusinessPurpose.dailyExpense,
    occurredAt: DateTime(2026, 1, 1),
    primaryAmount: Money(minorUnits: amount),
    isExcludedFromStats: false,
    isExcludedFromBudget: false,
    sourceKind: SourceKind.manual,
  );
}

class _TrackingRunner implements TransactionRunner {
  bool inTransaction = false;

  @override
  Future<T> run<T>(Future<T> Function() body) async {
    expect(inTransaction, isFalse);
    inTransaction = true;
    try {
      return await body();
    } finally {
      inTransaction = false;
    }
  }
}

class _FakeTransactionRepository
    implements TransactionRepository, TransactionGroupRepository {
  _FakeTransactionRepository(this.runner);

  final _TrackingRunner runner;
  final rewrittenIds = <String>[];
  Set<String> deletedIds = const {};

  @override
  Future<void> applyRewrite(TransactionGroupRewritePlan plan) async {
    expect(runner.inTransaction, isTrue);
    rewrittenIds.addAll(plan.rewrites.map((rewrite) => rewrite.after.id));
  }

  @override
  Future<void> deleteGroup(String parentTransactionId) async {
    expect(runner.inTransaction, isTrue);
    deletedIds = {'parent', 'child'};
  }

  @override
  Future<void> deleteChild(String childTransactionId) async {
    expect(runner.inTransaction, isTrue);
    deletedIds = {childTransactionId};
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _FakeAccountRepository implements AccountRepository {
  _FakeAccountRepository(this.runner);

  final _TrackingRunner runner;
  int saveAllCalls = 0;

  @override
  Future<void> saveAll(Iterable<Account> accounts) async {
    expect(runner.inTransaction, isTrue);
    saveAllCalls++;
  }

  @override
  Future<List<Account>> findByGroupId(String? groupId) async => const [];

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
