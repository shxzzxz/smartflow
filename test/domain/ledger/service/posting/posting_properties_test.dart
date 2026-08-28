import 'package:flutter_test/flutter_test.dart';
import 'package:smartflow/core/money/money.dart';
import 'package:smartflow/domain/ledger/entity/account.dart';
import 'package:smartflow/domain/ledger/entity/transaction.dart';
import 'package:smartflow/domain/ledger/service/posting/posting_engine.dart';
import 'package:smartflow/domain/ledger/service/posting/posting_instruction_resolver.dart';
import 'package:smartflow/domain/ledger/service/posting/posting_rule.dart';
import 'package:smartflow/domain/ledger/valobj/ledger_enum.dart';
import 'package:smartflow/domain/ledger/valobj/posting_instruction.dart';

import '../../../../helper/sequential_id_generator.dart';
import '../../../../helper/posting_instruction_fixtures.dart';

void main() {
  final occurredAt = DateTime(2026, 8, 1, 9);
  final postedAt = DateTime(2026, 8, 2, 10);
  const systemAccountIds = <SystemKey, String>{
    SystemKey.openingBalance: 'system-opening',
    SystemKey.reimbursementGapIncome: 'system-gap-income',
    SystemKey.interestExpense: 'system-interest-expense',
    SystemKey.feeExpense: 'system-fee-expense',
    SystemKey.discountIncome: 'system-discount-income',
    SystemKey.interestIncome: 'system-interest-income',
    SystemKey.badDebtExpense: 'system-bad-debt-expense',
    SystemKey.debtReliefIncome: 'system-debt-relief-income',
    SystemKey.ghostAccount: 'system-ghost',
  };
  const accountTypes = <String, AccountType>{
    'cash': AccountType.asset,
    'bank': AccountType.asset,
    'receivable': AccountType.asset,
    'liability': AccountType.liability,
    'food': AccountType.expense,
    'travel': AccountType.expense,
    'salary': AccountType.income,
  };

  test('posting instructions round-trip through transaction lines', () {
    final engine = PostingEngine(
      idGenerator: SequentialIdGenerator(prefix: 'round-trip'),
    );
    const resolver = DefaultPostingInstructionResolver();
    final instructions = <PostingInstruction>[
      singleExpenseInstruction(
        amount: const Money(minorUnits: 1200),
        paidFromAccountId: 'cash',
        expenseAccountId: 'food',
        occurredAt: occurredAt,
        postedAt: postedAt,
        counterpartyName: 'merchant',
        note: 'expense',
        isExcludedFromStats: true,
        isExcludedFromBudget: true,
        sourceKind: SourceKind.import,
      ),
      IncomeInstruction(
        amount: const Money(minorUnits: 2300),
        receiveAccountId: 'bank',
        incomeAccountId: 'salary',
        occurredAt: occurredAt,
        postedAt: postedAt,
        counterpartyName: 'employer',
        note: 'income',
        isExcludedFromStats: true,
        sourceKind: SourceKind.import,
      ),
      singleReimbursementAdvanceInstruction(
        amount: const Money(minorUnits: 3400),
        receivableAccountId: 'receivable',
        paidFromAccountId: 'cash',
        expenseAccountId: 'travel',
        occurredAt: occurredAt,
        postedAt: postedAt,
        counterpartyName: 'hotel',
        note: 'advance',
        sourceKind: SourceKind.import,
      ),
      TransferInstruction(
        amount: const Money(minorUnits: 4500),
        fromAccountId: 'cash',
        toAccountId: 'bank',
        feeAmount: const Money(minorUnits: 50),
        occurredAt: occurredAt,
        postedAt: postedAt,
        counterpartyName: 'bank',
        note: 'transfer',
        sourceKind: SourceKind.import,
      ),
      RepaymentInstruction(
        principal: const Money(minorUnits: 5000),
        interest: const Money(minorUnits: 300),
        fee: const Money(minorUnits: 100),
        discount: const Money(minorUnits: 50),
        liabilityAccountId: 'liability',
        paidFromAccountId: 'cash',
        occurredAt: occurredAt,
        postedAt: postedAt,
        counterpartyName: 'lender',
        note: 'repayment',
        sourceKind: SourceKind.import,
      ),
      BorrowingInstruction(
        amount: const Money(minorUnits: 6100),
        liabilityAccountId: 'liability',
        receiveAccountId: 'bank',
        occurredAt: occurredAt,
        postedAt: postedAt,
        counterpartyName: 'lender',
        note: 'borrowing',
        sourceKind: SourceKind.import,
      ),
      LendingInstruction(
        amount: const Money(minorUnits: 7200),
        receivableAccountId: 'receivable',
        paidFromAccountId: 'cash',
        occurredAt: occurredAt,
        postedAt: postedAt,
        counterpartyName: 'borrower',
        note: 'lending',
        sourceKind: SourceKind.import,
      ),
      ReceivableCollectionInstruction(
        principal: const Money(minorUnits: 7000),
        interest: const Money(minorUnits: 300),
        receivableAccountId: 'receivable',
        receiveAccountId: 'bank',
        occurredAt: occurredAt,
        postedAt: postedAt,
        counterpartyName: 'borrower',
        note: 'collection',
        sourceKind: SourceKind.import,
      ),
      BadDebtInstruction(
        amount: const Money(minorUnits: 8400),
        receivableAccountId: 'receivable',
        occurredAt: occurredAt,
        postedAt: postedAt,
        counterpartyName: 'borrower',
        note: 'bad debt',
        isExcludedFromStats: true,
        isExcludedFromBudget: true,
        sourceKind: SourceKind.import,
      ),
      DebtReliefInstruction(
        amount: const Money(minorUnits: 9500),
        liabilityAccountId: 'liability',
        occurredAt: occurredAt,
        postedAt: postedAt,
        counterpartyName: 'lender',
        note: 'relief',
        isExcludedFromStats: true,
        sourceKind: SourceKind.import,
      ),
    ];

    for (final instruction in instructions) {
      final transaction = engine.create(
        instruction,
        systemAccountIds: systemAccountIds,
      );
      final withReversedEntries = transaction.copyWith(
        entries: transaction.entries.reversed.toList(),
      );
      final resolved = resolver.resolve(withReversedEntries);
      final recreated = engine.create(
        resolved,
        systemAccountIds: systemAccountIds,
      );

      expect(recreated.businessPurpose, transaction.businessPurpose);
      expect(recreated.primaryAmount, transaction.primaryAmount);
      expect(recreated.occurredAt, transaction.occurredAt);
      expect(recreated.postedAt, transaction.postedAt);
      expect(recreated.counterpartyName, transaction.counterpartyName);
      expect(recreated.note, transaction.note);
      expect(recreated.isExcludedFromStats, transaction.isExcludedFromStats);
      expect(recreated.isExcludedFromBudget, transaction.isExcludedFromBudget);
      expect(recreated.sourceKind, transaction.sourceKind);
      expect(sameLines(recreated.lines, transaction.lines), isTrue);
    }
  });

  test('posting transaction lines is reproducible and idempotent', () {
    final engine = PostingEngine(
      idGenerator: SequentialIdGenerator(prefix: 'replay'),
    );
    final expense = engine.createExpense(
      singleExpenseInstruction(
        amount: const Money(minorUnits: 10000),
        paidFromAccountId: 'cash',
        expenseAccountId: 'food',
        occurredAt: occurredAt,
      ),
    );
    final advance = engine.createReimbursementAdvance(
      singleReimbursementAdvanceInstruction(
        amount: const Money(minorUnits: 10000),
        receivableAccountId: 'receivable',
        paidFromAccountId: 'cash',
        expenseAccountId: 'travel',
        occurredAt: occurredAt,
      ),
    );
    final reimbursementRefund = engine.createRefund(
      instruction: singleRefundInstruction(
        parentTransactionId: advance.id,
        amount: const Money(minorUnits: 500),
        refundToAccountId: 'cash',
        occurredAt: occurredAt,
      ),
      parent: advance,
    );
    final asset = Account(
      id: 'bank',
      name: 'bank',
      type: AccountType.asset,
      balance: const Money(minorUnits: 10000),
    );
    final transactions = <Transaction>[
      expense,
      engine.createIncome(
        IncomeInstruction(
          amount: const Money(minorUnits: 1000),
          receiveAccountId: 'bank',
          incomeAccountId: 'salary',
          occurredAt: occurredAt,
        ),
      ),
      engine.createTransfer(
        TransferInstruction(
          amount: const Money(minorUnits: 1000),
          fromAccountId: 'cash',
          toAccountId: 'bank',
          feeAmount: const Money(minorUnits: 50),
          occurredAt: occurredAt,
        ),
        systemAccountIds: systemAccountIds,
      ),
      engine.createRefund(
        instruction: singleRefundInstruction(
          parentTransactionId: expense.id,
          amount: const Money(minorUnits: 500),
          refundToAccountId: 'cash',
          occurredAt: occurredAt,
        ),
        parent: expense,
      ),
      advance,
      reimbursementRefund,
      engine.createReimbursementReceipt(
        instruction: singleReimbursementReceiptInstruction(
          advanceTransactionId: advance.id,
          amount: const Money(minorUnits: 2000),
          receivableAccountId: 'receivable',
          receiveAccountId: 'bank',
          occurredAt: occurredAt,
        ),
        advance: advance,
      ),
      engine.createReimbursementClose(
        instruction: singleReimbursementCloseInstruction(
          advanceTransactionId: advance.id,
          actualReceivedAmount: const Money(minorUnits: 8500),
          receivableAccountId: 'receivable',
          receiveAccountId: 'bank',
          occurredAt: occurredAt,
        ),
        advance: advance,
        outstanding: const Money(minorUnits: 8000),
        gapIncomeAccountId: systemAccountIds[SystemKey.reimbursementGapIncome],
      ),
      engine.createRepayment(
        RepaymentInstruction(
          principal: const Money(minorUnits: 1000),
          interest: const Money(minorUnits: 100),
          fee: const Money(minorUnits: 50),
          discount: const Money(minorUnits: 25),
          liabilityAccountId: 'liability',
          paidFromAccountId: 'cash',
          occurredAt: occurredAt,
        ),
        systemAccountIds: systemAccountIds,
      ),
      engine.createBorrowing(
        BorrowingInstruction(
          amount: const Money(minorUnits: 1000),
          liabilityAccountId: 'liability',
          receiveAccountId: 'bank',
          occurredAt: occurredAt,
        ),
      ),
      engine.createLending(
        LendingInstruction(
          amount: const Money(minorUnits: 1000),
          receivableAccountId: 'receivable',
          paidFromAccountId: 'cash',
          occurredAt: occurredAt,
        ),
      ),
      engine.createReceivableCollection(
        ReceivableCollectionInstruction(
          principal: const Money(minorUnits: 1000),
          interest: const Money(minorUnits: 100),
          receivableAccountId: 'receivable',
          receiveAccountId: 'bank',
          occurredAt: occurredAt,
        ),
        systemAccountIds: systemAccountIds,
      ),
      engine.createBadDebt(
        BadDebtInstruction(
          amount: const Money(minorUnits: 1000),
          receivableAccountId: 'receivable',
          occurredAt: occurredAt,
        ),
        systemAccountIds: systemAccountIds,
      ),
      engine.createDebtRelief(
        DebtReliefInstruction(
          amount: const Money(minorUnits: 1000),
          liabilityAccountId: 'liability',
          occurredAt: occurredAt,
        ),
        systemAccountIds: systemAccountIds,
      ),
      engine.createOpeningBalance(
        instruction: OpeningBalanceInstruction(
          accountId: asset.id,
          amount: const Money(minorUnits: 1000),
          occurredAt: occurredAt,
        ),
        account: asset,
        equityAccountId: systemAccountIds[SystemKey.openingBalance]!,
      ),
      engine.createBalanceAdjustment(
        instruction: BalanceAdjustmentInstruction(
          accountId: asset.id,
          targetBalance: const Money(minorUnits: 9000),
          occurredAt: occurredAt,
        ),
        account: asset,
        signedDelta: const Money(minorUnits: -1000),
        equityAccountId: systemAccountIds[SystemKey.openingBalance]!,
      ),
    ];

    expect(
      transactions.map((transaction) => transaction.businessPurpose).toSet(),
      BusinessPurpose.values.toSet(),
    );
    for (final transaction in transactions) {
      final firstReplay = engine.postEntries(
        transactionId: transaction.id,
        businessPurpose: transaction.businessPurpose,
        lines: transaction.lines,
        systemAccountIds: systemAccountIds,
        accountTypes: accountTypes,
      );
      final secondReplay = engine.postEntries(
        transactionId: transaction.id,
        businessPurpose: transaction.businessPurpose,
        lines: transaction.lines,
        systemAccountIds: systemAccountIds,
        accountTypes: accountTypes,
      );

      expect(sameEntries(firstReplay, transaction.entries), isTrue);
      expect(sameEntries(secondReplay, firstReplay), isTrue);
    }
  });
}
