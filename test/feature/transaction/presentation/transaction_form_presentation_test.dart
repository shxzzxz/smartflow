import 'package:flutter_test/flutter_test.dart';
import 'package:smartflow/application/ledger/ledger_query_api.dart';
import 'package:smartflow/core/money/money.dart';
import 'package:smartflow/feature/transaction/presentation/transaction_form_presentation.dart';

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
    });

    test('maps reimbursement advance detail to form state snapshot', () {
      final detail = _detail(
        purpose: BusinessPurpose.reimbursementAdvance,
        reimbursementExpenseAccountId: 'taxi',
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
      expect(snapshot.reimbursementAccountId, 'company');
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

    test('resolves reimbursement receivable account', () {
      final detail = _detail(
        purpose: BusinessPurpose.reimbursementAdvance,
        entries: [
          _entry('company', EntryDirection.debit),
          _entry('cash', EntryDirection.credit),
        ],
      );

      final accountId = reimbursementReceivableAccountId(detail, {
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
  String? reimbursementExpenseAccountId,
}) {
  final allLines = [
    if (reimbursementExpenseAccountId != null)
      TransactionLine(
        id: 'expense-category',
        transactionId: 'tx-1',
        lineNo: 1,
        role: TransactionRole.reimbursementExpenseCategory,
        accountId: reimbursementExpenseAccountId,
        amount: primaryAmount,
      ),
    for (var index = 0; index < entries.length; index++)
      TransactionLine(
        id: 'role-$index',
        transactionId: 'tx-1',
        lineNo: index + 10,
        role: switch (purpose) {
          BusinessPurpose.dailyIncome => entries[index].direction == EntryDirection.credit ? TransactionRole.category : TransactionRole.settlementIn,
          BusinessPurpose.dailyExpense => entries[index].direction == EntryDirection.debit ? TransactionRole.category : TransactionRole.settlementOut,
          BusinessPurpose.reimbursementAdvance => entries[index].direction == EntryDirection.debit ? TransactionRole.receivable : TransactionRole.settlementOut,
          BusinessPurpose.transfer => entries[index].direction == EntryDirection.debit ? TransactionRole.settlementIn : TransactionRole.settlementOut,
          _ => entries[index].direction == EntryDirection.debit ? TransactionRole.settlementIn : TransactionRole.settlementOut,
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

Account _account(String id, {AccountType type = AccountType.asset}) {
  return Account(
    id: id,
    name: id,
    type: type,
    balance: const Money(minorUnits: 0),
  );
}
