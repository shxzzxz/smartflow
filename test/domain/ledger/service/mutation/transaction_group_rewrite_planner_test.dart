import 'package:test/test.dart';
import 'package:smartflow/core/money/money.dart';
import 'package:smartflow/core/error/app_exception.dart';
import 'package:smartflow/domain/ledger/entity/transaction_group.dart';
import 'package:smartflow/domain/ledger/service/mutation/transaction_group_rewrite_planner.dart';
import 'package:smartflow/domain/ledger/service/posting/posting_engine.dart';
import 'package:smartflow/domain/ledger/service/posting/posting_instruction_resolver.dart';
import 'package:smartflow/domain/ledger/valobj/ledger_enum.dart';
import 'package:smartflow/domain/ledger/valobj/ledger_error_code.dart';

import '../../../../helper/fake_system_account_resolver.dart';
import '../../../../helper/posting_instruction_fixtures.dart';
import '../../../../helper/sequential_id_generator.dart';

void main() {
  test(
    'metadata-only parent edit updates the row without rewriting lines',
    () async {
      final engine = PostingEngine(
        idGenerator: SequentialIdGenerator(prefix: 'tx'),
      );
      final current = engine.createExpense(
        singleExpenseInstruction(
          amount: Money.parse('100.00'),
          paidFromAccountId: 'cash',
          expenseAccountId: 'food',
          occurredAt: DateTime(2026, 7, 1),
          note: 'before',
        ),
      );
      final candidate = engine.createExpense(
        singleExpenseInstruction(
          amount: Money.parse('100.00'),
          paidFromAccountId: 'cash',
          expenseAccountId: 'food',
          occurredAt: current.occurredAt,
          note: 'after',
        ),
      );
      final planner = TransactionGroupRewritePlanner(
        postingEngine: engine,
        postingInstructionResolver: const DefaultPostingInstructionResolver(),
        systemAccountResolver: const FakeSystemAccountResolver(),
      );

      final plan = await planner.planParentRewrite(
        currentGroup: TransactionGroup(
          parentTransaction: current,
          childTransactions: const [],
        ),
        candidateParent: candidate,
      );

      expect(plan.rewrites, isEmpty);
      expect(plan.rowUpdates.single.id, current.id);
      expect(plan.rowUpdates.single.note, 'after');
    },
  );

  test(
    'editing an expense category rewrites the refund offset without changing child identity',
    () async {
      final engine = PostingEngine(
        idGenerator: SequentialIdGenerator(prefix: 'tx'),
      );
      final parent = engine.createExpense(
        singleExpenseInstruction(
          amount: Money.parse('100.00'),
          paidFromAccountId: 'cash',
          expenseAccountId: 'food',
          occurredAt: DateTime(2026, 7, 1),
        ),
      );
      final refund = engine.createRefund(
        instruction: singleRefundInstruction(
          parentTransactionId: parent.id,
          amount: Money.parse('20.00'),
          refundToAccountId: 'cash',
          occurredAt: DateTime(2026, 7, 2),
          postedAt: DateTime(2026, 7, 3),
        ),
        parent: parent,
      );
      final candidate = engine.createExpense(
        singleExpenseInstruction(
          amount: Money.parse('100.00'),
          paidFromAccountId: 'cash',
          expenseAccountId: 'transport',
          occurredAt: parent.occurredAt,
        ),
      );
      final planner = TransactionGroupRewritePlanner(
        postingEngine: engine,
        postingInstructionResolver: const DefaultPostingInstructionResolver(),
        systemAccountResolver: const FakeSystemAccountResolver(),
      );

      final plan = await planner.planParentRewrite(
        currentGroup: TransactionGroup(
          parentTransaction: parent,
          childTransactions: [refund],
        ),
        candidateParent: candidate,
      );

      final rewrittenParent = plan.currentGroup.parentTransaction;
      final rewrittenRefund = plan.currentGroup.childTransactions.single;
      expect(rewrittenParent.id, parent.id);
      expect(rewrittenRefund.id, refund.id);
      expect(rewrittenRefund.parentTransactionId, parent.id);
      expect(rewrittenRefund.businessPurpose, BusinessPurpose.refund);
      expect(rewrittenRefund.primaryAmount, refund.primaryAmount);
      expect(rewrittenRefund.postedAt, refund.postedAt);
      expect(
        rewrittenRefund.entries
            .singleWhere((entry) => entry.direction == EntryDirection.credit)
            .accountId,
        'transport',
      );
      expect(plan.rewrites.map((rewrite) => rewrite.before.id), {
        parent.id,
        refund.id,
      });
    },
  );

  test(
    'reimbursement advance with a receipt cannot be edited as an expense',
    () async {
      final engine = PostingEngine(
        idGenerator: SequentialIdGenerator(prefix: 'tx'),
      );
      final parent = engine.createReimbursementAdvance(
        singleReimbursementAdvanceInstruction(
          amount: Money.parse('100.00'),
          receivableAccountId: 'receivable',
          paidFromAccountId: 'cash',
          expenseAccountId: 'travel',
          occurredAt: DateTime(2026, 7, 1),
        ),
      );
      final receipt = engine.createReimbursementReceipt(
        instruction: singleReimbursementReceiptInstruction(
          advanceTransactionId: parent.id,
          amount: Money.parse('20.00'),
          receivableAccountId: 'receivable',
          receiveAccountId: 'bank',
          occurredAt: DateTime(2026, 7, 2),
        ),
        advance: parent,
      );
      final candidate = engine.createExpense(
        singleExpenseInstruction(
          amount: parent.primaryAmount,
          paidFromAccountId: 'cash',
          expenseAccountId: 'travel',
          occurredAt: parent.occurredAt,
        ),
      );
      final planner = TransactionGroupRewritePlanner(
        postingEngine: engine,
        postingInstructionResolver: const DefaultPostingInstructionResolver(),
        systemAccountResolver: const FakeSystemAccountResolver(),
      );

      await expectLater(
        planner.planParentRewrite(
          currentGroup: TransactionGroup(
            parentTransaction: parent,
            childTransactions: [receipt],
          ),
          candidateParent: candidate,
        ),
        throwsA(isA<BusinessException>()),
      );
    },
  );

  test(
    'expense with refund can become reimbursement advance and resets group reporting flags',
    () async {
      final engine = PostingEngine(
        idGenerator: SequentialIdGenerator(prefix: 'tx'),
      );
      final parent = engine.createExpense(
        singleExpenseInstruction(
          amount: Money.parse('100.00'),
          paidFromAccountId: 'cash',
          expenseAccountId: 'travel',
          occurredAt: DateTime(2026, 7, 1),
          isExcludedFromStats: true,
          isExcludedFromBudget: true,
        ),
      );
      final refund = engine.createRefund(
        instruction: singleRefundInstruction(
          parentTransactionId: parent.id,
          amount: Money.parse('20.00'),
          refundToAccountId: 'cash',
          occurredAt: DateTime(2026, 7, 2),
        ),
        parent: parent,
      );
      final candidate = engine.createReimbursementAdvance(
        singleReimbursementAdvanceInstruction(
          amount: parent.primaryAmount,
          receivableAccountId: 'receivable',
          paidFromAccountId: 'cash',
          expenseAccountId: 'travel',
          occurredAt: parent.occurredAt,
        ),
      );
      final planner = TransactionGroupRewritePlanner(
        postingEngine: engine,
        postingInstructionResolver: const DefaultPostingInstructionResolver(),
        systemAccountResolver: const FakeSystemAccountResolver(),
      );

      final plan = await planner.planParentRewrite(
        currentGroup: TransactionGroup(
          parentTransaction: parent,
          childTransactions: [refund],
        ),
        candidateParent: candidate,
      );

      final rewrittenRefund = plan.currentGroup.childTransactions.single;
      expect(plan.currentGroup.parentTransaction.id, parent.id);
      expect(plan.currentGroup.parentTransaction.isExcludedFromStats, isFalse);
      expect(plan.currentGroup.parentTransaction.isExcludedFromBudget, isFalse);
      expect(rewrittenRefund.id, refund.id);
      expect(rewrittenRefund.isExcludedFromStats, isFalse);
      expect(rewrittenRefund.isExcludedFromBudget, isFalse);
      expect(
        rewrittenRefund.entries
            .singleWhere((entry) => entry.direction == EntryDirection.credit)
            .accountId,
        'receivable',
      );
    },
  );

  test('closed reimbursement rejects a parent amount edit', () async {
    final engine = PostingEngine(
      idGenerator: SequentialIdGenerator(prefix: 'tx'),
    );
    final parent = engine.createReimbursementAdvance(
      singleReimbursementAdvanceInstruction(
        amount: Money.parse('100.00'),
        receivableAccountId: 'receivable',
        paidFromAccountId: 'cash',
        expenseAccountId: 'travel',
        occurredAt: DateTime(2026, 7, 1),
      ),
    );
    final close = engine.createReimbursementClose(
      instruction: singleReimbursementCloseInstruction(
        advanceTransactionId: parent.id,
        actualReceivedAmount: Money.parse('100.00'),
        receivableAccountId: 'receivable',
        receiveAccountId: 'bank',
        occurredAt: DateTime(2026, 7, 2),
      ),
      advance: parent,
      outstanding: parent.primaryAmount,
      gapIncomeAccountId: null,
    );
    final candidate = engine.createReimbursementAdvance(
      singleReimbursementAdvanceInstruction(
        amount: Money.parse('120.00'),
        receivableAccountId: 'receivable',
        paidFromAccountId: 'cash',
        expenseAccountId: 'travel',
        occurredAt: parent.occurredAt,
      ),
    );
    final planner = TransactionGroupRewritePlanner(
      postingEngine: engine,
      postingInstructionResolver: const DefaultPostingInstructionResolver(),
      systemAccountResolver: const FakeSystemAccountResolver(),
    );

    await expectLater(
      planner.planParentRewrite(
        currentGroup: TransactionGroup(
          parentTransaction: parent,
          childTransactions: [close],
        ),
        candidateParent: candidate,
      ),
      throwsA(isA<BusinessException>()),
    );
  });

  test(
    'advance amount cannot fall below received reimbursement total',
    () async {
      final engine = PostingEngine(
        idGenerator: SequentialIdGenerator(prefix: 'tx'),
      );
      final parent = engine.createReimbursementAdvance(
        singleReimbursementAdvanceInstruction(
          amount: Money.parse('100.00'),
          receivableAccountId: 'receivable',
          paidFromAccountId: 'cash',
          expenseAccountId: 'travel',
          occurredAt: DateTime(2026, 7, 1),
        ),
      );
      final receipt = engine.createReimbursementReceipt(
        instruction: singleReimbursementReceiptInstruction(
          advanceTransactionId: parent.id,
          amount: Money.parse('60.00'),
          receivableAccountId: 'receivable',
          receiveAccountId: 'bank',
          occurredAt: DateTime(2026, 7, 2),
        ),
        advance: parent,
      );
      final candidate = engine.createReimbursementAdvance(
        singleReimbursementAdvanceInstruction(
          amount: Money.parse('50.00'),
          receivableAccountId: 'receivable',
          paidFromAccountId: 'cash',
          expenseAccountId: 'travel',
          occurredAt: parent.occurredAt,
        ),
      );
      final planner = TransactionGroupRewritePlanner(
        postingEngine: engine,
        postingInstructionResolver: const DefaultPostingInstructionResolver(),
        systemAccountResolver: const FakeSystemAccountResolver(),
      );

      await expectLater(
        planner.planParentRewrite(
          currentGroup: TransactionGroup(
            parentTransaction: parent,
            childTransactions: [receipt],
          ),
          candidateParent: candidate,
        ),
        throwsA(
          isA<BusinessException>().having(
            (error) => error.code,
            'code',
            LedgerErrorCode.transactionInvalidCommand.code,
          ),
        ),
      );
    },
  );

  test(
    'advance amount cannot fall below combined refunds and receipts',
    () async {
      final engine = PostingEngine(
        idGenerator: SequentialIdGenerator(prefix: 'tx'),
      );
      final parent = engine.createReimbursementAdvance(
        singleReimbursementAdvanceInstruction(
          amount: Money.parse('100.00'),
          receivableAccountId: 'receivable',
          paidFromAccountId: 'cash',
          expenseAccountId: 'travel',
          occurredAt: DateTime(2026, 7, 1),
        ),
      );
      final receipt = engine.createReimbursementReceipt(
        instruction: singleReimbursementReceiptInstruction(
          advanceTransactionId: parent.id,
          amount: Money.parse('60.00'),
          receivableAccountId: 'receivable',
          receiveAccountId: 'bank',
          occurredAt: DateTime(2026, 7, 2),
        ),
        advance: parent,
      );
      final refund = engine.createRefund(
        instruction: singleRefundInstruction(
          parentTransactionId: parent.id,
          amount: Money.parse('20.00'),
          refundToAccountId: 'bank',
          occurredAt: DateTime(2026, 7, 2),
        ),
        parent: parent,
      );
      final candidate = engine.createReimbursementAdvance(
        singleReimbursementAdvanceInstruction(
          amount: Money.parse('70.00'),
          receivableAccountId: 'receivable',
          paidFromAccountId: 'cash',
          expenseAccountId: 'travel',
          occurredAt: parent.occurredAt,
        ),
      );
      final planner = TransactionGroupRewritePlanner(
        postingEngine: engine,
        postingInstructionResolver: const DefaultPostingInstructionResolver(),
        systemAccountResolver: const FakeSystemAccountResolver(),
      );

      await expectLater(
        planner.planParentRewrite(
          currentGroup: TransactionGroup(
            parentTransaction: parent,
            childTransactions: [receipt, refund],
          ),
          candidateParent: candidate,
        ),
        throwsA(isA<BusinessException>()),
      );
    },
  );

  test(
    'editing reimbursement receivable account rebases receipt entries without changing receipt facts',
    () async {
      final engine = PostingEngine(
        idGenerator: SequentialIdGenerator(prefix: 'tx'),
      );
      final parent = engine.createReimbursementAdvance(
        singleReimbursementAdvanceInstruction(
          amount: Money.parse('100.00'),
          receivableAccountId: 'receivable-old',
          paidFromAccountId: 'cash',
          expenseAccountId: 'travel',
          occurredAt: DateTime(2026, 7, 1),
        ),
      );
      final receipt = engine.createReimbursementReceipt(
        instruction: singleReimbursementReceiptInstruction(
          advanceTransactionId: parent.id,
          amount: Money.parse('20.00'),
          receivableAccountId: 'receivable-old',
          receiveAccountId: 'bank',
          occurredAt: DateTime(2026, 7, 2),
          note: 'receipt-note',
        ),
        advance: parent,
      );
      final candidate = engine.createReimbursementAdvance(
        singleReimbursementAdvanceInstruction(
          amount: parent.primaryAmount,
          receivableAccountId: 'receivable-new',
          paidFromAccountId: 'cash',
          expenseAccountId: 'travel',
          occurredAt: parent.occurredAt,
        ),
      );
      final planner = TransactionGroupRewritePlanner(
        postingEngine: engine,
        postingInstructionResolver: const DefaultPostingInstructionResolver(),
        systemAccountResolver: const FakeSystemAccountResolver(),
      );

      final plan = await planner.planParentRewrite(
        currentGroup: TransactionGroup(
          parentTransaction: parent,
          childTransactions: [receipt],
        ),
        candidateParent: candidate,
      );

      final rewritten = plan.currentGroup.childTransactions.single;
      expect(rewritten.id, receipt.id);
      expect(rewritten.primaryAmount, receipt.primaryAmount);
      expect(rewritten.occurredAt, receipt.occurredAt);
      expect(rewritten.note, receipt.note);
      expect(
        rewritten.entries
            .singleWhere((entry) => entry.direction == EntryDirection.credit)
            .accountId,
        'receivable-new',
      );
      expect(
        rewritten.entries
            .singleWhere((entry) => entry.direction == EntryDirection.debit)
            .accountId,
        'bank',
      );
    },
  );

  test('receivable rebase does not rewrite close gap-income entry', () async {
    final engine = PostingEngine(
      idGenerator: SequentialIdGenerator(prefix: 'tx'),
    );
    final parent = engine.createReimbursementAdvance(
      singleReimbursementAdvanceInstruction(
        amount: Money.parse('100.00'),
        receivableAccountId: 'receivable-old',
        paidFromAccountId: 'cash',
        expenseAccountId: 'travel',
        occurredAt: DateTime(2026, 7, 1),
      ),
    );
    final close = engine.createReimbursementClose(
      instruction: singleReimbursementCloseInstruction(
        advanceTransactionId: parent.id,
        actualReceivedAmount: Money.parse('110.00'),
        receivableAccountId: 'receivable-old',
        receiveAccountId: 'bank',
        occurredAt: DateTime(2026, 7, 2),
      ),
      advance: parent,
      outstanding: Money.parse('100.00'),
      gapIncomeAccountId: 'system-gap-income',
    );
    final candidate = engine.createReimbursementAdvance(
      singleReimbursementAdvanceInstruction(
        amount: parent.primaryAmount,
        receivableAccountId: 'receivable-new',
        paidFromAccountId: 'cash',
        expenseAccountId: 'travel',
        occurredAt: parent.occurredAt,
      ),
    );
    final planner = TransactionGroupRewritePlanner(
      postingEngine: engine,
      postingInstructionResolver: const DefaultPostingInstructionResolver(),
      systemAccountResolver: const FakeSystemAccountResolver(),
    );

    final plan = await planner.planParentRewrite(
      currentGroup: TransactionGroup(
        parentTransaction: parent,
        childTransactions: [close],
      ),
      candidateParent: candidate,
    );

    expect(
      plan.currentGroup.childTransactions.single.entries
          .singleWhere((entry) => entry.accountId == 'system-gap-income')
          .accountId,
      'system-gap-income',
    );
  });

  test('editing advance category rebases close gap-expense entry', () async {
    final engine = PostingEngine(
      idGenerator: SequentialIdGenerator(prefix: 'tx'),
    );
    final parent = engine.createReimbursementAdvance(
      singleReimbursementAdvanceInstruction(
        amount: Money.parse('100.00'),
        receivableAccountId: 'receivable',
        paidFromAccountId: 'cash',
        expenseAccountId: 'travel-old',
        occurredAt: DateTime(2026, 7, 1),
      ),
    );
    final close = engine.createReimbursementClose(
      instruction: singleReimbursementCloseInstruction(
        advanceTransactionId: parent.id,
        actualReceivedAmount: Money.parse('90.00'),
        receivableAccountId: 'receivable',
        receiveAccountId: 'bank',
        occurredAt: DateTime(2026, 7, 2),
      ),
      advance: parent,
      outstanding: parent.primaryAmount,
      gapIncomeAccountId: null,
    );
    final candidate = engine.createReimbursementAdvance(
      singleReimbursementAdvanceInstruction(
        amount: parent.primaryAmount,
        receivableAccountId: 'receivable',
        paidFromAccountId: 'cash',
        expenseAccountId: 'travel-new',
        occurredAt: parent.occurredAt,
      ),
    );
    final planner = TransactionGroupRewritePlanner(
      postingEngine: engine,
      postingInstructionResolver: const DefaultPostingInstructionResolver(),
      systemAccountResolver: const FakeSystemAccountResolver(),
    );

    final plan = await planner.planParentRewrite(
      currentGroup: TransactionGroup(
        parentTransaction: parent,
        childTransactions: [close],
      ),
      candidateParent: candidate,
    );

    expect(
      plan.currentGroup.childTransactions.single.entries
          .singleWhere(
            (entry) =>
                entry.direction == EntryDirection.debit &&
                entry.accountId != 'bank',
          )
          .accountId,
      'travel-new',
    );
  });
}
