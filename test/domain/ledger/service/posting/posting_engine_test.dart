import 'package:flutter_test/flutter_test.dart';
import 'package:smartflow/core/money/money.dart';
import 'package:smartflow/domain/ledger/entity/account.dart';
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
      expect(transaction.lines.map((line) => line.role), [
        TransactionRole.category,
        TransactionRole.settlementOut,
      ]);
      expect(entriesAreBalanced(transaction.entries), isTrue);
      expect(
        transaction.entries.map((entry) => (entry.accountId, entry.direction)),
        containsAll([
          ('food', EntryDirection.debit),
          ('cash', EntryDirection.credit),
        ]),
      );
    });

    test('preserves import source and independent posted time', () {
      final engine = PostingEngine(
        idGenerator: SequentialIdGenerator(prefix: 'tx'),
      );
      final occurredAt = DateTime(2026, 5, 1, 9);
      final postedAt = DateTime(2026, 5, 3, 18);

      final transaction = engine.createExpense(
        ExpenseInstruction(
          amount: Money.parse('12.30'),
          paidFromAccountId: 'cash',
          expenseAccountId: 'food',
          occurredAt: occurredAt,
          postedAt: postedAt,
          sourceKind: SourceKind.import,
        ),
      );

      expect(transaction.sourceKind, SourceKind.import);
      expect(transaction.occurredAt, occurredAt);
      expect(transaction.postedAt, postedAt);
    });

    test('propagates import metadata to reimbursement children', () {
      final engine = PostingEngine(
        idGenerator: SequentialIdGenerator(prefix: 'tx'),
      );
      final advance = engine.createReimbursementAdvance(
        ReimbursementAdvanceInstruction(
          amount: Money.parse('100.00'),
          receivableAccountId: 'receivable',
          paidFromAccountId: 'cash',
          expenseAccountId: 'travel',
          occurredAt: DateTime(2026, 5, 1),
          postedAt: DateTime(2026, 5, 2),
          sourceKind: SourceKind.import,
        ),
      );
      final receipt = engine.createReimbursementReceipt(
        instruction: ReimbursementReceiptInstruction(
          advanceTransactionId: advance.id,
          amount: Money.parse('100.00'),
          receivableAccountId: 'receivable',
          receiveAccountId: 'bank',
          occurredAt: DateTime(2026, 5, 3),
          postedAt: DateTime(2026, 5, 4),
        ),
        advance: advance,
      );

      expect(advance.sourceKind, SourceKind.import);
      expect(advance.postedAt, DateTime(2026, 5, 2));
      expect(receipt.sourceKind, SourceKind.import);
      expect(receipt.postedAt, DateTime(2026, 5, 4));
    });

    test('allows import opening balance to carry its source kind', () {
      final engine = PostingEngine(
        idGenerator: SequentialIdGenerator(prefix: 'tx'),
      );
      final account = Account(
        id: 'loan',
        name: 'loan',
        type: AccountType.liability,
        balance: Money.zero(),
      );

      final transaction = engine.createOpeningBalance(
        instruction: OpeningBalanceInstruction(
          accountId: account.id,
          amount: Money.parse('100.00'),
          occurredAt: DateTime(2026, 5, 1),
          postedAt: DateTime(2026, 5, 2),
          sourceKind: SourceKind.import,
        ),
        account: account,
        equityAccountId: 'opening',
      );

      expect(transaction.sourceKind, SourceKind.import);
      expect(transaction.postedAt, DateTime(2026, 5, 2));
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
        systemAccountIds: const {
          SystemKey.interestExpense: 'interest-expense',
        },
      );

      expect(transaction.businessPurpose, BusinessPurpose.debtRepayment);
      expect(entriesAreBalanced(transaction.entries), isTrue);
      expect(
        transaction.lines.first.role,
        TransactionRole.liability,
      );
      expect(transaction.lines.first.amount, Money.zero());
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
        postedAt: DateTime(2026, 5, 2),
        isExcludedFromStats: true,
        isExcludedFromBudget: true,
      );

      final edited = const ExpenseEditPatch().applyTo(current);

      expect(edited.amount, current.amount);
      expect(edited.paidFromAccountId, 'cash');
      expect(edited.expenseAccountId, 'food');
      expect(edited.postedAt, current.postedAt);
      expect(edited.isExcludedFromStats, isTrue);
      expect(edited.isExcludedFromBudget, isTrue);
    });

    test('advance edit patch converts an expense to reimbursement advance', () {
      final current = ExpenseInstruction(
        amount: Money.parse('12.30'),
        paidFromAccountId: 'cash',
        expenseAccountId: 'food',
        occurredAt: DateTime(2026, 5, 1),
        postedAt: DateTime(2026, 5, 2),
        isExcludedFromStats: true,
        isExcludedFromBudget: true,
      );

      final edited = const ReimbursementAdvanceEditPatch(
        receivableAccountId: 'receivable',
      ).applyTo(current);

      expect(edited.amount, current.amount);
      expect(edited.receivableAccountId, 'receivable');
      expect(edited.paidFromAccountId, 'cash');
      expect(edited.expenseAccountId, 'food');
      expect(edited.postedAt, current.postedAt);
      expect(edited.isExcludedFromStats, isTrue);
      expect(edited.isExcludedFromBudget, isTrue);
    });

    test('transfer edit patch preserves posting time and accepts zero fee', () {
      final current = TransferInstruction(
        amount: Money.parse('12.30'),
        fromAccountId: 'cash',
        toAccountId: 'bank',
        feeAmount: Money.parse('1.00'),
        occurredAt: DateTime(2026, 5, 1),
        postedAt: DateTime(2026, 5, 2),
      );

      final edited = TransferEditPatch(
        amount: Money.parse('20.00'),
        feeAmount: Money.zero(),
      ).applyTo(current);

      expect(edited.amount, Money.parse('20.00'));
      expect(edited.feeAmount, Money.zero());
      expect(edited.postedAt, current.postedAt);

      final unchanged = const TransferEditPatch().applyTo(current);
      expect(unchanged.feeAmount, current.feeAmount);
    });

    test('repayment edit patch preserves posting time', () {
      final current = RepaymentInstruction(
        principal: Money.parse('100.00'),
        liabilityAccountId: 'loan',
        paidFromAccountId: 'cash',
        occurredAt: DateTime(2026, 5, 1),
        postedAt: DateTime(2026, 5, 2),
      );

      final edited = RepaymentEditPatch(
        principal: Money.parse('80.00'),
      ).applyTo(current);

      expect(edited.principal, Money.parse('80.00'));
      expect(edited.postedAt, current.postedAt);
    });

    test('refund edit patch preserves posting time', () {
      final current = RefundInstruction(
        parentTransactionId: 'parent',
        amount: Money.parse('12.30'),
        refundToAccountId: 'cash',
        occurredAt: DateTime(2026, 5, 1),
        postedAt: DateTime(2026, 5, 2),
      );

      final edited = RefundEditPatch(
        amount: Money.parse('10.00'),
      ).applyTo(current);

      expect(edited.amount, Money.parse('10.00'));
      expect(edited.postedAt, current.postedAt);
    });

    test('reimbursement children inherit parent reporting flags', () {
      final engine = PostingEngine(
        idGenerator: SequentialIdGenerator(prefix: 'tx'),
      );
      final advance = engine.createReimbursementAdvance(
        ReimbursementAdvanceInstruction(
          amount: Money.parse('100.00'),
          receivableAccountId: 'receivable',
          paidFromAccountId: 'cash',
          expenseAccountId: 'travel',
          occurredAt: DateTime(2026, 5, 1),
          isExcludedFromStats: true,
          isExcludedFromBudget: true,
        ),
      );

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
