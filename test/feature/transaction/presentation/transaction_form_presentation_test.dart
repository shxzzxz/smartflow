import 'package:flutter_test/flutter_test.dart';
import 'package:smartflow/application/ledger/ledger_query_api.dart';
import 'package:smartflow/core/money/money.dart';
import 'package:smartflow/feature/transaction/presentation/transaction_form_presentation.dart';
import 'package:smartflow/domain/orchestration/valobj/advance_enums.dart';
import 'package:smartflow/shared/account_profile/account_profile_kind.dart';

void main() {
  group('transactionFormEditSnapshot', () {
    test('maps daily income detail to form state snapshot', () {
      final detail = _detail(
        purpose: BusinessPurpose.dailyIncome,
        entries: [
          _entry('bank', EntryDirection.debit),
          _entry('salary', EntryDirection.credit),
        ],
      );

      final snapshot = transactionFormEditSnapshot(
        detail: detail,
        expenseTree: const [],
        incomeTree: [
          CategoryNode(
            account: _account('income-root', type: AccountType.income),
            children: [_account('salary', type: AccountType.income)],
          ),
        ],
        accountsById: {
          'bank': _account('bank'),
          'salary': _account('salary', type: AccountType.income),
        },
      );

      expect(snapshot.mode, TransactionFormMode.income);
      expect(snapshot.amountText, '12.34');
      expect(snapshot.incomeCategoryId, 'salary');
      expect(snapshot.incomeRootId, 'income-root');
      expect(snapshot.toAccountId, 'bank');
      expect(snapshot.categoryAllocations?.single.accountId, 'salary');
      expect(snapshot.settlementAllocations?.single.accountId, 'bank');
    });

    test('maps daily income allocations for multi-category editing', () {
      final detail = _detail(
        purpose: BusinessPurpose.dailyIncome,
        primaryAmount: const Money(minorUnits: 2468),
        entries: const [],
        lines: const [
          TransactionLine(
            id: 'salary',
            transactionId: 'tx-1',
            lineNo: 1,
            role: TransactionRole.category,
            accountId: 'salary',
            amount: Money(minorUnits: 1800),
          ),
          TransactionLine(
            id: 'bonus',
            transactionId: 'tx-1',
            lineNo: 2,
            role: TransactionRole.category,
            accountId: 'bonus',
            amount: Money(minorUnits: 668),
          ),
          TransactionLine(
            id: 'bank',
            transactionId: 'tx-1',
            lineNo: 3,
            role: TransactionRole.settlementIn,
            accountId: 'bank',
            amount: Money(minorUnits: 2000),
          ),
          TransactionLine(
            id: 'cash',
            transactionId: 'tx-1',
            lineNo: 4,
            role: TransactionRole.settlementIn,
            accountId: 'cash',
            amount: Money(minorUnits: 468),
          ),
        ],
      );

      final snapshot = transactionFormEditSnapshot(
        detail: detail,
        expenseTree: const [],
        incomeTree: const [],
        accountsById: {'bank': _account('bank'), 'cash': _account('cash')},
      );

      expect(
        snapshot.categoryAllocations?.map(
          (item) => '${item.accountId}:${item.amount.minorUnits}',
        ),
        ['salary:1800', 'bonus:668'],
      );
      expect(
        snapshot.settlementAllocations?.map(
          (item) => '${item.accountId}:${item.amount.minorUnits}',
        ),
        ['bank:2000', 'cash:468'],
      );
    });

    test('maps advance detail to form state snapshot', () {
      final detail = _detail(
        purpose: BusinessPurpose.advance,
        advanceExpenseAccountId: 'taxi',
        entries: [
          _entry('company', EntryDirection.debit),
          _entry('cash', EntryDirection.credit),
        ],
      );

      final snapshot = transactionFormEditSnapshot(
        detail: detail,
        expenseTree: [
          CategoryNode(
            account: _account('travel', type: AccountType.expense),
            children: [_account('taxi', type: AccountType.expense)],
          ),
        ],
        incomeTree: const [],
        accountsById: {
          'company': _account('company'),
          'cash': _account('cash'),
          'taxi': _account('taxi', type: AccountType.expense),
        },
      );

      expect(snapshot.mode, TransactionFormMode.expense);
      expect(snapshot.expenseCategoryId, 'taxi');
      expect(snapshot.expenseRootId, 'travel');
      expect(snapshot.fromAccountId, 'cash');
      expect(snapshot.advanceReceivableAccountId, 'company');
    });

    test('maps transfer fee detail to form state snapshot', () {
      final detail = _detail(
        purpose: BusinessPurpose.transfer,
        entries: [
          _entry('bank', EntryDirection.debit),
          _entry('cash', EntryDirection.credit),
        ],
        lines: const [
          TransactionLine(
            id: 'fee',
            transactionId: 'tx-1',
            lineNo: 2,
            role: TransactionRole.fee,
            amount: Money(minorUnits: 300),
          ),
        ],
      );

      final snapshot = transactionFormEditSnapshot(
        detail: detail,
        expenseTree: const [],
        incomeTree: const [],
        accountsById: {'bank': _account('bank'), 'cash': _account('cash')},
      );

      expect(snapshot.mode, TransactionFormMode.transfer);
      expect(snapshot.feeText, '3');
    });

    test('trims insignificant decimal zeros for editing', () {
      final wholeAmountSnapshot = transactionFormEditSnapshot(
        detail: _detail(
          purpose: BusinessPurpose.dailyIncome,
          primaryAmount: const Money(minorUnits: 120000),
          entries: [
            _entry('bank', EntryDirection.debit),
            _entry('salary', EntryDirection.credit),
          ],
        ),
        expenseTree: const [],
        incomeTree: const [],
        accountsById: {
          'bank': _account('bank'),
          'salary': _account('salary', type: AccountType.income),
        },
      );
      final oneDecimalSnapshot = transactionFormEditSnapshot(
        detail: _detail(
          purpose: BusinessPurpose.dailyIncome,
          primaryAmount: const Money(minorUnits: 120050),
          entries: [
            _entry('bank', EntryDirection.debit),
            _entry('salary', EntryDirection.credit),
          ],
        ),
        expenseTree: const [],
        incomeTree: const [],
        accountsById: {
          'bank': _account('bank'),
          'salary': _account('salary', type: AccountType.income),
        },
      );

      expect(wholeAmountSnapshot.amountText, '1200');
      expect(oneDecimalSnapshot.amountText, '1200.5');
    });
  });

  group('transaction semantic helpers', () {
    test('maps relation scenes to shared ledger modes and form copy', () {
      expect(
        TransactionRelationScene.borrowing.mode,
        TransactionFormMode.borrowing,
      );
      expect(
        TransactionRelationScene.lending.mode,
        TransactionFormMode.lending,
      );
      expect(
        TransactionRelationScene.deposit.mode,
        TransactionFormMode.lending,
      );
      expect(TransactionRelationScene.lending.label, '借出');
      expect(TransactionRelationScene.deposit.label, '押金');
      expect(TransactionRelationScene.deposit.cashAccountLabel, '付款账户');
      expect(TransactionRelationScene.deposit.receivableAccountLabel, '押金账户');
      expect(
        transactionRelationSceneForMode(TransactionFormMode.borrowing),
        TransactionRelationScene.borrowing,
      );
      expect(
        transactionRelationSceneForMode(TransactionFormMode.lending),
        TransactionRelationScene.lending,
      );
    });

    test('filters account-managed scenes by account profile', () {
      final accounts = [
        _account(
          'reimbursement',
          profileKey: AccountProfileKind.reimbursement.key,
        ),
        _account('receivable', profileKey: AccountProfileKind.receivable.key),
      ];

      expect(
        advanceAccountsForExpenseScene(
          TransactionExpenseScene.reimbursementAccount,
          accounts,
        ).map((account) => account.id),
        ['reimbursement'],
      );
      expect(
        advanceAccountsForExpenseScene(
          TransactionExpenseScene.aaAccount,
          accounts,
        ).map((account) => account.id),
        ['receivable'],
      );
      expect(
        advanceAccountsForExpenseScene(
          TransactionExpenseScene.aa,
          accounts,
        ).map((account) => account.id),
        ['reimbursement', 'receivable'],
      );
      expect(
        advanceAccountsForExpenseScene(
          TransactionExpenseScene.onBehalfAccount,
          accounts,
        ).map((account) => account.id),
        ['reimbursement', 'receivable'],
      );
    });

    test('maps account and itemized scenes to the same business scenarios', () {
      expect(
        TransactionExpenseScene.reimbursement.advanceTrackingMode,
        AdvanceTrackingMode.itemized,
      );
      expect(
        TransactionExpenseScene.reimbursementAccount.advanceTrackingMode,
        AdvanceTrackingMode.account,
      );
      expect(
        TransactionExpenseScene.reimbursementAccount.advanceScenario,
        AdvanceScenario.reimbursement,
      );
      expect(
        TransactionExpenseScene.aa.advanceTrackingMode,
        AdvanceTrackingMode.itemized,
      );
      expect(
        TransactionExpenseScene.aaAccount.advanceTrackingMode,
        AdvanceTrackingMode.account,
      );
      expect(
        TransactionExpenseScene.aaAccount.advanceScenario,
        AdvanceScenario.aa,
      );
      expect(
        TransactionExpenseScene.onBehalf.advanceTrackingMode,
        AdvanceTrackingMode.itemized,
      );
      expect(
        TransactionExpenseScene.onBehalfAccount.advanceTrackingMode,
        AdvanceTrackingMode.account,
      );

      expect(TransactionExpenseScene.reimbursementAccount.label, '报销（账户）');
      expect(TransactionExpenseScene.aaAccount.label, 'AA（账户）');
      expect(TransactionExpenseScene.consumptionInstallment.label, '消费分期');
      expect(TransactionExpenseScene.consumptionInstallment.isAdvance, isFalse);
      expect(
        transactionExpenseSceneForAdvanceScenario(
          AdvanceScenario.reimbursement,
          trackingMode: AdvanceTrackingMode.account,
        ),
        TransactionExpenseScene.reimbursementAccount,
      );
      expect(
        transactionExpenseSceneForAdvanceScenario(
          AdvanceScenario.aa,
          trackingMode: AdvanceTrackingMode.account,
        ),
        TransactionExpenseScene.aaAccount,
      );
      expect(
        transactionExpenseSceneForAdvanceScenario(
          AdvanceScenario.onBehalf,
          trackingMode: AdvanceTrackingMode.account,
        ),
        TransactionExpenseScene.onBehalfAccount,
      );
    });

    test('rounds AA per-person amount up to the next cent', () {
      const total = Money(minorUnits: 3700);

      expect(
        selfBorneAmountForExpenseScene(
          scene: TransactionExpenseScene.aa,
          total: total,
          aaPeopleCount: 3,
        ),
        const Money(minorUnits: 1232),
      );
      expect(
        advanceAmountForExpenseScene(
          scene: TransactionExpenseScene.aa,
          total: total,
          aaPeopleCount: 3,
        ),
        const Money(minorUnits: 2468),
      );
      expect(
        advanceAmountForExpenseScene(
          scene: TransactionExpenseScene.reimbursement,
          total: total,
          aaPeopleCount: 3,
        ),
        total,
      );
      expect(
        advanceAmountForExpenseScene(
          scene: TransactionExpenseScene.aaAccount,
          total: total,
          aaPeopleCount: 3,
        ),
        const Money(minorUnits: 2468),
      );
    });

    test('resolves refund target with selected account first', () {
      final accounts = [_account('cash'), _account('bank')];

      expect(
        effectiveRefundToAccountId(
          selectedId: 'bank',
          parentSettlementAccountId: 'cash',
          accounts: accounts,
        ),
        'bank',
      );
      expect(
        effectiveRefundToAccountId(
          selectedId: 'missing',
          parentSettlementAccountId: 'cash',
          accounts: accounts,
        ),
        'cash',
      );
      expect(
        effectiveRefundToAccountId(
          selectedId: 'missing',
          parentSettlementAccountId: 'also-missing',
          accounts: accounts,
        ),
        isNull,
      );
    });

    test('resolves parent settlement account for refund', () {
      final detail = _detail(
        purpose: BusinessPurpose.dailyExpense,
        entries: [
          _entry('food', EntryDirection.debit),
          _entry('cash', EntryDirection.credit),
        ],
      );

      final accountId = parentSettlementAccountIdForRefund(detail, {
        'food': _account('food', type: AccountType.expense),
        'cash': _account('cash'),
      });

      expect(accountId, 'cash');
    });

    test('resolves advance receivable account', () {
      final detail = _detail(
        purpose: BusinessPurpose.advance,
        entries: [
          _entry('company', EntryDirection.debit),
          _entry('cash', EntryDirection.credit),
        ],
      );

      final accountId = advanceReceivableAccountId(detail, {
        'company': _account('company'),
        'cash': _account('cash'),
      });

      expect(accountId, 'company');
    });
  });
}

TransactionReadModel _detail({
  required BusinessPurpose purpose,
  required List<Entry> entries,
  List<TransactionLine> lines = const [],
  Money primaryAmount = const Money(minorUnits: 1234),
  String? advanceExpenseAccountId,
}) {
  final allLines = [
    if (advanceExpenseAccountId != null)
      TransactionLine(
        id: 'expense-category',
        transactionId: 'tx-1',
        lineNo: 1,
        role: TransactionRole.advanceExpenseCategory,
        accountId: advanceExpenseAccountId,
        amount: primaryAmount,
      ),
    for (var index = 0; index < entries.length; index++)
      TransactionLine(
        id: 'role-$index',
        transactionId: 'tx-1',
        lineNo: index + 10,
        role: switch (purpose) {
          BusinessPurpose.dailyIncome =>
            entries[index].direction == EntryDirection.credit
                ? TransactionRole.category
                : TransactionRole.settlementIn,
          BusinessPurpose.dailyExpense =>
            entries[index].direction == EntryDirection.debit
                ? TransactionRole.category
                : TransactionRole.settlementOut,
          BusinessPurpose.advance =>
            entries[index].direction == EntryDirection.debit
                ? TransactionRole.receivable
                : TransactionRole.settlementOut,
          BusinessPurpose.transfer =>
            entries[index].direction == EntryDirection.debit
                ? TransactionRole.settlementIn
                : TransactionRole.settlementOut,
          _ =>
            entries[index].direction == EntryDirection.debit
                ? TransactionRole.settlementIn
                : TransactionRole.settlementOut,
        },
        accountId: entries[index].accountId,
        amount: entries[index].amount,
      ),
    ...lines,
  ];
  final transaction = Transaction(
    id: 'tx-1',
    businessPurpose: purpose,
    occurredAt: DateTime(2026, 1, 2, 8, 30),
    primaryAmount: primaryAmount,
    isExcludedFromStats: false,
    isExcludedFromBudget: false,
    sourceKind: SourceKind.manual,
    note: 'note',
    lines: allLines,
  );
  return TransactionReadModel.fromTransaction(
    transaction: transaction,
    createdAt: DateTime(2026, 1, 2, 8, 30),
    lines: allLines,
  );
}

Entry _entry(String accountId, EntryDirection direction) {
  return Entry(
    id: 'entry-$accountId',
    transactionId: 'tx-1',
    accountId: accountId,
    direction: direction,
    amount: const Money(minorUnits: 1234),
  );
}

Account _account(
  String id, {
  AccountType type = AccountType.asset,
  String? profileKey,
}) {
  return Account(
    id: id,
    name: id,
    type: type,
    profileKey: profileKey,
    balance: const Money(minorUnits: 0),
  );
}
