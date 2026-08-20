import 'package:flutter_test/flutter_test.dart';
import 'package:smartflow/application/ledger/ledger_query_api.dart';
import 'package:smartflow/core/money/money.dart';
import 'package:smartflow/feature/shared/presentation/account_lookup.dart';
import 'package:smartflow/feature/transaction/presentation/transaction_detail_presentation.dart';

void main() {
  test('bad debt detail uses the bad debt expense system category', () {
    final category = _account(
      'bad-debt',
      '坏账损失',
      AccountType.expense,
      systemKey: SystemKey.badDebtExpense,
    );
    final receivable = _account('receivable', '应收', AccountType.asset);
    final detail = _detail(
      purpose: BusinessPurpose.badDebt,
      entries: [
        _entry(category.id, EntryDirection.debit),
        _entry(receivable.id, EntryDirection.credit),
      ],
    );

    final hero = transactionDetailHero(
      detail: detail,
      accountLookup: AccountLookup({
        category.id: category,
        receivable.id: receivable,
      }),
    );

    expect(hero.title, '坏账损失');
    expect(hero.amount, const Money(minorUnits: -10000));
  });

  test('debt relief detail uses the debt relief income system category', () {
    final category = _account(
      'debt-relief',
      '债务减免',
      AccountType.income,
      systemKey: SystemKey.debtReliefIncome,
    );
    final payable = _account('payable', '应付', AccountType.liability);
    final detail = _detail(
      purpose: BusinessPurpose.debtRelief,
      entries: [
        _entry(payable.id, EntryDirection.debit),
        _entry(category.id, EntryDirection.credit),
      ],
    );

    final hero = transactionDetailHero(
      detail: detail,
      accountLookup: AccountLookup({
        category.id: category,
        payable.id: payable,
      }),
    );

    expect(hero.title, '债务减免');
    expect(hero.amount, const Money(minorUnits: 10000));
  });
}

Account _account(
  String id,
  String name,
  AccountType type, {
  SystemKey? systemKey,
}) => Account(
  id: id,
  name: name,
  type: type,
  balance: Money.zero(),
  systemKey: systemKey,
);

TransactionDetail _detail({
  required BusinessPurpose purpose,
  required List<Entry> entries,
}) => TransactionDetail(
  transaction: Transaction(
    id: 'transaction',
    businessPurpose: purpose,
    occurredAt: DateTime(2026, 8, 20),
    primaryAmount: const Money(minorUnits: 10000),
    isExcludedFromStats: false,
    isExcludedFromBudget: false,
    sourceKind: SourceKind.manual,
    entries: entries,
  ),
  createdAt: DateTime(2026, 8, 20),
  details: const [],
  entries: entries,
);

Entry _entry(String accountId, EntryDirection direction) => Entry(
  id: '$accountId-entry',
  transactionId: 'transaction',
  accountId: accountId,
  direction: direction,
  amount: const Money(minorUnits: 10000),
);
