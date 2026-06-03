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
  });
}

TransactionDetail _detail({
  required BusinessPurpose purpose,
  required List<Entry> entries,
  String? reimbursementExpenseAccountId,
}) {
  final transaction = Transaction(
    id: 'tx-1',
    rootTransactionId: 'tx-1',
    businessPurpose: purpose,
    occurredAt: DateTime(2026, 1, 2, 8, 30),
    primaryAmount: const Money(minorUnits: 1234),
    mutationKind: MutationKind.original,
    businessState: BusinessState.current,
    isExcludedFromStats: false,
    isExcludedFromBudget: false,
    sourceKind: SourceKind.manual,
    note: 'note',
    reimbursementExpenseAccountId: reimbursementExpenseAccountId,
    entries: entries,
  );
  return TransactionDetail(
    transaction: transaction,
    createdAt: DateTime(2026, 1, 2, 8, 30),
    details: const [],
    entries: entries,
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
