import 'package:flutter_test/flutter_test.dart';
import 'package:smartflow/core/money/money.dart';
import 'package:smartflow/domain/ledger/service/posting/posting_engine.dart';
import 'package:smartflow/domain/ledger/service/posting/posting_instruction_resolver.dart';
import 'package:smartflow/domain/ledger/service/posting/posting_rule.dart';
import 'package:smartflow/domain/ledger/valobj/ledger_enum.dart';
import 'package:smartflow/domain/ledger/valobj/posting_instruction.dart';

import '../../../../helper/sequential_id_generator.dart';

void main() {
  group('PostingEngine', () {
    test('creates balanced expense transaction', () {
      final engine = PostingEngine(
        idGenerator: SequentialIdGenerator(prefix: 'tx'),
      );

      final transaction = engine.createExpense(
        ExpenseInstruction(
          amount: Money.parse('12.30'),
          paidFromAccountId: 'cash',
          expenseAccountId: 'food',
          occurredAt: DateTime(2026, 5, 1),
        ),
      );

      expect(transaction.businessPurpose, BusinessPurpose.dailyExpense);
      expect(transaction.postedAt, transaction.occurredAt);
      expect(
        transaction.details.single.type,
        TransactionDetailType.primaryExpense,
      );
      expect(entriesAreBalanced(transaction.entries), isTrue);
      expect(
        transaction.entries.map((entry) => (entry.accountId, entry.direction)),
        containsAll([
          ('food', EntryDirection.debit),
          ('cash', EntryDirection.credit),
        ]),
      );
    });

    test('creates and resolves interest-only repayment', () {
      final engine = PostingEngine(
        idGenerator: SequentialIdGenerator(prefix: 'tx'),
      );

      final transaction = engine.createRepayment(
        RepaymentInstruction(
          principal: Money.zero(),
          interest: Money.parse('1.00'),
          liabilityAccountId: 'loan',
          paidFromAccountId: 'cash',
          occurredAt: DateTime(2026, 5, 1),
        ),
        interestExpenseAccountId: 'interest-expense',
      );

      expect(transaction.businessPurpose, BusinessPurpose.debtRepayment);
      expect(entriesAreBalanced(transaction.entries), isTrue);
      expect(
        transaction.details.first.type,
        TransactionDetailType.repaymentPrincipal,
      );
      expect(transaction.details.first.amount, Money.zero());
      final resolved = const DefaultPostingInstructionResolver().resolve(
        transaction,
      );
      expect(resolved, isA<RepaymentInstruction>());
      expect((resolved as RepaymentInstruction).principal, Money.zero());
      expect(resolved.liabilityAccountId, 'loan');
      expect(resolved.interest, Money.parse('1.00'));
    });

    test('creates refund inheriting parent reporting flags', () {
      final engine = PostingEngine(
        idGenerator: SequentialIdGenerator(prefix: 'tx'),
      );
      final parent = engine.createExpense(
        ExpenseInstruction(
          amount: Money.parse('20.00'),
          paidFromAccountId: 'cash',
          expenseAccountId: 'food',
          occurredAt: DateTime(2026, 5, 1),
          isExcludedFromStats: true,
          isExcludedFromBudget: true,
        ),
      );

      final refund = engine.createRefund(
        instruction: RefundInstruction(
          parentTransactionId: parent.id,
          amount: Money.parse('8.00'),
          refundToAccountId: 'cash',
          occurredAt: DateTime(2026, 5, 2),
        ),
        parent: parent,
        refundOffsetAccountId: 'food',
      );

      expect(refund.parentTransactionId, parent.id);
      expect(refund.postedAt, DateTime(2026, 5, 2));
      expect(refund.isExcludedFromStats, isTrue);
      expect(refund.isExcludedFromBudget, isTrue);
      expect(entriesAreBalanced(refund.entries), isTrue);
    });

    test('keeps posting time independent when transaction time changes', () {
      final engine = PostingEngine(
        idGenerator: SequentialIdGenerator(prefix: 'tx'),
      );
      final transaction = engine.createExpense(
        ExpenseInstruction(
          amount: Money.parse('12.30'),
          paidFromAccountId: 'cash',
          expenseAccountId: 'food',
          occurredAt: DateTime(2026, 5, 1),
        ),
      );
      final postedAt = transaction.postedAt;

      transaction.updateBasicInfo(occurredAt: DateTime(2026, 5, 2));

      expect(transaction.occurredAt, DateTime(2026, 5, 2));
      expect(transaction.postedAt, postedAt);
    });

    test('expense edit patch converts a reimbursement advance to expense', () {
      final current = ReimbursementAdvanceInstruction(
        amount: Money.parse('12.30'),
        receivableAccountId: 'receivable',
        paidFromAccountId: 'cash',
        expenseAccountId: 'food',
        occurredAt: DateTime(2026, 5, 1),
      );

      final edited = const ExpenseEditPatch().applyTo(current);

      expect(edited.amount, current.amount);
      expect(edited.paidFromAccountId, 'cash');
      expect(edited.expenseAccountId, 'food');
    });

    test('advance edit patch converts an expense to reimbursement advance', () {
      final current = ExpenseInstruction(
        amount: Money.parse('12.30'),
        paidFromAccountId: 'cash',
        expenseAccountId: 'food',
        occurredAt: DateTime(2026, 5, 1),
      );

      final edited = const ReimbursementAdvanceEditPatch(
        receivableAccountId: 'receivable',
      ).applyTo(current);

      expect(edited.amount, current.amount);
      expect(edited.receivableAccountId, 'receivable');
      expect(edited.paidFromAccountId, 'cash');
      expect(edited.expenseAccountId, 'food');
    });

    test('reimbursement children inherit parent reporting flags', () {
      final engine = PostingEngine(
        idGenerator: SequentialIdGenerator(prefix: 'tx'),
      );
      final advance = engine
          .createReimbursementAdvance(
            ReimbursementAdvanceInstruction(
              amount: Money.parse('100.00'),
              receivableAccountId: 'receivable',
              paidFromAccountId: 'cash',
              expenseAccountId: 'travel',
              occurredAt: DateTime(2026, 5, 1),
            ),
          )
          .copyWith(isExcludedFromStats: true, isExcludedFromBudget: true);

      final receipt = engine.createReimbursementReceipt(
        instruction: ReimbursementReceiptInstruction(
          advanceTransactionId: advance.id,
          amount: Money.parse('20.00'),
          receivableAccountId: 'receivable',
          receiveAccountId: 'bank',
          occurredAt: DateTime(2026, 5, 2),
        ),
        advance: advance,
      );
      final close = engine.createReimbursementClose(
        instruction: ReimbursementCloseInstruction(
          advanceTransactionId: advance.id,
          actualReceivedAmount: Money.parse('80.00'),
          receivableAccountId: 'receivable',
          receiveAccountId: 'bank',
          occurredAt: DateTime(2026, 5, 3),
        ),
        advance: advance,
        outstanding: Money.parse('80.00'),
        gapIncomeAccountId: null,
      );

      expect(receipt.isExcludedFromStats, isTrue);
      expect(receipt.isExcludedFromBudget, isTrue);
      expect(close.isExcludedFromStats, isTrue);
      expect(close.isExcludedFromBudget, isTrue);
    });
  });
}
