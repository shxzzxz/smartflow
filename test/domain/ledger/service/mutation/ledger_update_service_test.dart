import 'package:smartflow/core/error/app_exception.dart';
import 'package:smartflow/core/money/money.dart';
import 'package:smartflow/core/patch/patch.dart';
import 'package:smartflow/domain/ledger/entity/transaction.dart';
import 'package:smartflow/domain/ledger/entity/transaction_group.dart';
import 'package:smartflow/domain/ledger/port/transaction_group_repository.dart';
import 'package:smartflow/domain/ledger/port/transaction_repository.dart';
import 'package:smartflow/domain/ledger/service/mutation/ledger_update_service.dart';
import 'package:smartflow/domain/ledger/service/mutation/transaction_group_rewrite_plan.dart';
import 'package:smartflow/domain/ledger/service/posting/posting_engine.dart';
import 'package:smartflow/domain/ledger/valobj/posting_instruction.dart';
import 'package:test/test.dart';

import '../../../../helper/sequential_id_generator.dart';

void main() {
  test(
    'closed reimbursement rejects basic-info edits to an earlier receipt',
    () async {
      final engine = PostingEngine(
        idGenerator: SequentialIdGenerator(prefix: 'tx'),
      );
      final parent = engine.createReimbursementAdvance(
        ReimbursementAdvanceInstruction(
          amount: Money.parse('100.00'),
          receivableAccountId: 'receivable',
          paidFromAccountId: 'cash',
          expenseAccountId: 'travel',
          occurredAt: DateTime(2026, 7, 1),
        ),
      );
      final receipt = engine.createReimbursementReceipt(
        instruction: ReimbursementReceiptInstruction(
          advanceTransactionId: parent.id,
          amount: Money.parse('60.00'),
          receivableAccountId: 'receivable',
          receiveAccountId: 'bank',
          occurredAt: DateTime(2026, 7, 2),
        ),
        advance: parent,
      );
      final close = engine.createReimbursementClose(
        instruction: ReimbursementCloseInstruction(
          advanceTransactionId: parent.id,
          actualReceivedAmount: Money.parse('40.00'),
          receivableAccountId: 'receivable',
          receiveAccountId: 'bank',
          occurredAt: DateTime(2026, 7, 3),
        ),
        advance: parent,
        outstanding: Money.parse('40.00'),
        gapIncomeAccountId: null,
      );
      final repository = _MemoryTransactionRepository(
        TransactionGroup(
          parentTransaction: parent,
          childTransactions: [receipt, close],
        ),
      );
      final service = LedgerUpdateService(
        transactionRepository: repository,
        transactionGroupRepository: repository,
      );

      await expectLater(
        service.updateBasicInfo(
          UpdateTransactionBasicInfoInstruction(
            transactionId: receipt.id,
            note: const Patch<String?>.set('changed'),
          ),
        ),
        throwsA(isA<BusinessException>()),
      );
    },
  );
}

class _MemoryTransactionRepository
    implements TransactionRepository, TransactionGroupRepository {
  _MemoryTransactionRepository(this.group);

  final TransactionGroup group;

  @override
  Future<Transaction?> findById(String transactionId) async {
    return group.findTransaction(transactionId);
  }

  @override
  Future<Transaction?> findCompleteById(String transactionId) async {
    return group.findTransaction(transactionId);
  }

  @override
  Future<TransactionGroup?> findByParentId(String parentTransactionId) async {
    return parentTransactionId == group.parentTransaction.id ? group : null;
  }

  @override
  Future<TransactionGroup?> findByTransactionId(String transactionId) async {
    return group.findTransaction(transactionId) == null ? null : group;
  }

  @override
  Future<void> applyRewrite(TransactionGroupRewritePlan plan) =>
      throw UnimplementedError();

  @override
  Future<void> deleteChild(String childTransactionId) =>
      throw UnimplementedError();

  @override
  Future<void> deleteGroup(String parentTransactionId) =>
      throw UnimplementedError();

  @override
  Future<void> save(Transaction transaction) => throw UnimplementedError();

  @override
  Future<void> saveAll(Iterable<Transaction> transactions) =>
      throw UnimplementedError();

  @override
  Future<void> updateAll(Iterable<Transaction> transactions) =>
      throw UnimplementedError();

  @override
  Future<Map<String, int>> countEntriesByAccount(Set<String> accountIds) =>
      throw UnimplementedError();

  @override
  Future<Map<String, int>> countReimbursementExpenseRefs(
    Set<String> accountIds,
  ) async => const {};
}
