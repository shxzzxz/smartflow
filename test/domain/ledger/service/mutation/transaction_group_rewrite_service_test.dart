import 'package:smartflow/core/money/money.dart';
import 'package:smartflow/core/patch/patch.dart';
import 'package:smartflow/core/error/app_exception.dart';
import 'package:smartflow/domain/ledger/entity/account.dart';
import 'package:smartflow/domain/ledger/entity/transaction.dart';
import 'package:smartflow/domain/ledger/entity/transaction_group.dart';
import 'package:smartflow/domain/ledger/port/account_repository.dart';
import 'package:smartflow/domain/ledger/port/system_account_resolver.dart';
import 'package:smartflow/domain/ledger/port/transaction_group_repository.dart';
import 'package:smartflow/domain/ledger/service/account/account_role_policy.dart';
import 'package:smartflow/domain/ledger/service/mutation/transaction_group_rewrite_plan.dart';
import 'package:smartflow/domain/ledger/service/mutation/transaction_group_rewrite_service.dart';
import 'package:smartflow/domain/ledger/service/posting/account_posting_service.dart';
import 'package:smartflow/domain/ledger/service/posting/posting_engine.dart';
import 'package:smartflow/domain/ledger/service/posting/posting_instruction_resolver.dart';
import 'package:smartflow/domain/ledger/valobj/ledger_enum.dart';
import 'package:smartflow/domain/ledger/valobj/ledger_violation_reason.dart';
import 'package:smartflow/domain/ledger/valobj/posting_instruction.dart';
import 'package:test/test.dart';

import '../../../../helper/sequential_id_generator.dart';

void main() {
  test('editing a refund cannot exceed reimbursement outstanding', () async {
    final engine = PostingEngine(
      idGenerator: SequentialIdGenerator(prefix: 'tx'),
    );
    final parent = engine.createReimbursementAdvance(
      ReimbursementAdvanceInstruction(
        amount: Money.parse('100.00'),
        receivableAccountId: 'receivable',
        paidFromAccountId: 'cash',
        expenseAccountId: 'expense',
        occurredAt: DateTime(2026, 7, 1),
      ),
    );
    final receipt = engine.createReimbursementReceipt(
      instruction: ReimbursementReceiptInstruction(
        advanceTransactionId: parent.id,
        amount: Money.parse('60.00'),
        receivableAccountId: 'receivable',
        receiveAccountId: 'cash',
        occurredAt: DateTime(2026, 7, 2),
      ),
      advance: parent,
    );
    final refund = engine.createRefund(
      instruction: RefundInstruction(
        parentTransactionId: parent.id,
        amount: Money.parse('20.00'),
        refundToAccountId: 'cash',
        occurredAt: DateTime(2026, 7, 2),
      ),
      parent: parent,
      refundOffsetAccountId: 'receivable',
    );
    final service = TransactionGroupRewriteService(
      transactionGroupRepository: _TransactionGroupRepository(
        TransactionGroup(
          parentTransaction: parent,
          childTransactions: [receipt, refund],
        ),
      ),
      accountRepository: _AccountRepository(),
      postingInstructionResolver: const DefaultPostingInstructionResolver(),
      postingEngine: engine,
      accountPostingService: _AccountPostingService(),
      accountRolePolicy: _AccountRolePolicy(),
      systemAccountResolver: _SystemAccountResolver(),
    );

    await expectLater(
      () => service.rewriteRefundTransaction(
        EditRefundTransactionInstruction(
          transactionId: refund.id,
          editPatch: RefundEditPatch(amount: Money.parse('40.01')),
        ),
      ),
      throwsA(isA<BusinessException>()),
    );
  });

  test(
    'editing a receipt cannot exceed reimbursement outstanding after refunds',
    () async {
      final engine = PostingEngine(
        idGenerator: SequentialIdGenerator(prefix: 'tx'),
      );
      final parent = engine.createReimbursementAdvance(
        ReimbursementAdvanceInstruction(
          amount: Money.parse('100.00'),
          receivableAccountId: 'receivable',
          paidFromAccountId: 'cash',
          expenseAccountId: 'expense',
          occurredAt: DateTime(2026, 7, 1),
        ),
      );
      final refund = engine.createRefund(
        instruction: RefundInstruction(
          parentTransactionId: parent.id,
          amount: Money.parse('60.00'),
          refundToAccountId: 'cash',
          occurredAt: DateTime(2026, 7, 2),
        ),
        parent: parent,
        refundOffsetAccountId: 'receivable',
      );
      final receipt = engine.createReimbursementReceipt(
        instruction: ReimbursementReceiptInstruction(
          advanceTransactionId: parent.id,
          amount: Money.parse('20.00'),
          receivableAccountId: 'receivable',
          receiveAccountId: 'cash',
          occurredAt: DateTime(2026, 7, 3),
        ),
        advance: parent,
      );
      final service = TransactionGroupRewriteService(
        transactionGroupRepository: _TransactionGroupRepository(
          TransactionGroup(
            parentTransaction: parent,
            childTransactions: [refund, receipt],
          ),
        ),
        accountRepository: _AccountRepository(),
        postingInstructionResolver: const DefaultPostingInstructionResolver(),
        postingEngine: engine,
        accountPostingService: _AccountPostingService(),
        accountRolePolicy: _AccountRolePolicy(),
        systemAccountResolver: _SystemAccountResolver(),
      );

      await expectLater(
        () => service.rewriteReimbursementReceipt(
          EditReimbursementReceiptTransactionInstruction(
            transactionId: receipt.id,
            amount: Money.parse('40.01'),
          ),
        ),
        throwsA(isA<BusinessException>()),
      );
    },
  );

  test('editing reimbursement receipt preserves its posting time', () async {
    final engine = PostingEngine(
      idGenerator: SequentialIdGenerator(prefix: 'tx'),
    );
    final parent = engine.createReimbursementAdvance(
      ReimbursementAdvanceInstruction(
        amount: Money.parse('100.00'),
        receivableAccountId: 'receivable',
        paidFromAccountId: 'cash',
        expenseAccountId: 'expense',
        occurredAt: DateTime(2026, 7, 1),
      ),
    );
    final receipt = engine.createReimbursementReceipt(
      instruction: ReimbursementReceiptInstruction(
        advanceTransactionId: parent.id,
        amount: Money.parse('20.00'),
        receivableAccountId: 'receivable',
        receiveAccountId: 'bank',
        occurredAt: DateTime(2026, 7, 2),
        postedAt: DateTime(2026, 7, 3),
      ),
      advance: parent,
    );
    final service = TransactionGroupRewriteService(
      transactionGroupRepository: _TransactionGroupRepository(
        TransactionGroup(
          parentTransaction: parent,
          childTransactions: [receipt],
        ),
      ),
      accountRepository: _AccountRepository(),
      postingInstructionResolver: const DefaultPostingInstructionResolver(),
      postingEngine: engine,
      accountPostingService: _AccountPostingService(),
      accountRolePolicy: _AccountRolePolicy(),
      systemAccountResolver: _SystemAccountResolver(),
    );

    final result = await service.rewriteReimbursementReceipt(
      EditReimbursementReceiptTransactionInstruction(
        transactionId: receipt.id,
        note: const Patch<String?>.set('metadata only'),
      ),
    );

    expect(result.currentTransaction.postedAt, receipt.postedAt);
  });

  test(
    'editing zero-cash reimbursement close preserves its actual amount',
    () async {
      final engine = PostingEngine(
        idGenerator: SequentialIdGenerator(prefix: 'tx'),
      );
      final parent = engine.createReimbursementAdvance(
        ReimbursementAdvanceInstruction(
          amount: Money.parse('100.00'),
          receivableAccountId: 'receivable',
          paidFromAccountId: 'cash',
          expenseAccountId: 'expense',
          occurredAt: DateTime(2026, 7, 1),
        ),
      );
      final close = engine.createReimbursementClose(
        instruction: ReimbursementCloseInstruction(
          advanceTransactionId: parent.id,
          actualReceivedAmount: Money.zero(),
          receivableAccountId: 'receivable',
          receiveAccountId: 'bank',
          occurredAt: DateTime(2026, 7, 2),
          postedAt: DateTime(2026, 7, 3),
        ),
        advance: parent,
        outstanding: parent.primaryAmount,
        gapIncomeAccountId: null,
      );
      final service = TransactionGroupRewriteService(
        transactionGroupRepository: _TransactionGroupRepository(
          TransactionGroup(
            parentTransaction: parent,
            childTransactions: [close],
          ),
        ),
        accountRepository: _AccountRepository(),
        postingInstructionResolver: const DefaultPostingInstructionResolver(),
        postingEngine: engine,
        accountPostingService: _AccountPostingService(),
        accountRolePolicy: _AccountRolePolicy(),
        systemAccountResolver: _SystemAccountResolver(),
      );

      final result = await service.rewriteReimbursementClose(
        EditReimbursementCloseTransactionInstruction(
          transactionId: close.id,
          note: const Patch<String?>.set('metadata only'),
        ),
      );

      final rewritten = result.currentTransaction;
      expect(rewritten.note, 'metadata only');
      expect(rewritten.postedAt, close.postedAt);
      expect(
        rewritten.entries.where((entry) => entry.accountId == 'bank'),
        isEmpty,
      );
      expect(
        rewritten.lines
            .singleWhere(
              (detail) =>
                  detail.role == TransactionRole.reimbursementGapExpense,
            )
            .amount,
        Money.parse('100.00'),
      );
    },
  );

  test(
    'closed reimbursement only allows deleting the close transaction',
    () async {
      final engine = PostingEngine(
        idGenerator: SequentialIdGenerator(prefix: 'tx'),
      );
      final parent = engine.createReimbursementAdvance(
        ReimbursementAdvanceInstruction(
          amount: Money.parse('100.00'),
          receivableAccountId: 'receivable',
          paidFromAccountId: 'cash',
          expenseAccountId: 'expense',
          occurredAt: DateTime(2026, 7, 1),
        ),
      );
      final receipt = engine.createReimbursementReceipt(
        instruction: ReimbursementReceiptInstruction(
          advanceTransactionId: parent.id,
          amount: Money.parse('40.00'),
          receivableAccountId: 'receivable',
          receiveAccountId: 'bank',
          occurredAt: DateTime(2026, 7, 2),
        ),
        advance: parent,
      );
      final close = engine.createReimbursementClose(
        instruction: ReimbursementCloseInstruction(
          advanceTransactionId: parent.id,
          actualReceivedAmount: Money.parse('60.00'),
          receivableAccountId: 'receivable',
          receiveAccountId: 'bank',
          occurredAt: DateTime(2026, 7, 3),
        ),
        advance: parent,
        outstanding: Money.parse('60.00'),
        gapIncomeAccountId: null,
      );
      final service = TransactionGroupRewriteService(
        transactionGroupRepository: _TransactionGroupRepository(
          TransactionGroup(
            parentTransaction: parent,
            childTransactions: [receipt, close],
          ),
        ),
        accountRepository: _AccountRepository(),
        postingInstructionResolver: const DefaultPostingInstructionResolver(),
        postingEngine: engine,
        accountPostingService: _AccountPostingService(),
        accountRolePolicy: _AccountRolePolicy(),
        systemAccountResolver: _SystemAccountResolver(),
      );

      final deletion = await service.deleteCurrentTransaction(close.id);

      expect(deletion.targetTransactionId, close.id);
      expect(deletion.deletedTransactions, [close]);
      await expectLater(
        service.deleteCurrentTransaction(receipt.id),
        throwsA(isA<BusinessException>()),
      );
    },
  );
}

class _TransactionGroupRepository implements TransactionGroupRepository {
  _TransactionGroupRepository(this.group);

  final TransactionGroup group;

  @override
  Future<TransactionGroup?> findByTransactionId(String transactionId) async =>
      group;

  @override
  Future<TransactionGroup?> findByParentId(String parentTransactionId) async =>
      group;

  @override
  Future<void> applyRewrite(TransactionGroupRewritePlan plan) async {}

  @override
  Future<void> deleteChild(String childTransactionId) async {}

  @override
  Future<void> deleteGroup(String parentTransactionId) async {}
}

class _AccountRepository implements AccountRepository {
  @override
  Future<List<Account>> findByIds(Set<String> ids) async => const [];

  @override
  Future<Account?> findById(String id) async => null;

  @override
  Future<List<Account>> findChildrenOf(String parentId) async => const [];

  @override
  Future<List<Account>> findByGroupId(String? groupId) async => const [];

  @override
  Future<void> create(Account account) async {}

  @override
  Future<void> save(Account account) async {}

  @override
  Future<void> saveAll(Iterable<Account> accounts) async {}

  @override
  Future<void> delete(String id) async {}
}

class _AccountPostingService implements AccountPostingService {
  @override
  List<Account> apply({
    required Transaction transaction,
    required Map<String, Account> accounts,
  }) => const [];

  @override
  List<Account> applyAll({
    required Iterable<Transaction> transactions,
    required Map<String, Account> accounts,
  }) => const [];

  @override
  List<Account> applyRewrite({
    required Iterable<Transaction> before,
    required Iterable<Transaction> after,
    required Map<String, Account> accounts,
  }) => const [];

  @override
  List<Account> removeAll({
    required Iterable<Transaction> transactions,
    required Map<String, Account> accounts,
  }) => const [];
}

class _AccountRolePolicy implements AccountRolePolicy {
  @override
  Future<LedgerViolationReason?> validate(AccountRoleContext context) async =>
      null;
}

class _SystemAccountResolver implements SystemAccountResolver {
  Future<String> resolveBadDebtExpense() async => 'bad-debt';

  Future<String> resolveDebtReliefIncome() async => 'debt-relief';

  @override
  Future<String> resolveDiscountIncome() async => 'discount';

  @override
  Future<String> resolveFeeExpense() async => 'fee';

  @override
  Future<String> resolveGhostAccount() async => 'ghost';

  @override
  Future<String> resolveInterestExpense() async => 'interest';

  Future<String> resolveInterestIncome() async => 'interest-income';

  @override
  Future<String> resolveOpeningBalance() async => 'opening';

  @override
  Future<String> resolveReimbursementGapIncome() async => 'gap-income';
}
