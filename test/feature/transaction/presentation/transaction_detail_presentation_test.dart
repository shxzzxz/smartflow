import 'package:flutter_test/flutter_test.dart';
import 'package:smartflow/application/ledger/ledger_query_api.dart';
import 'package:smartflow/core/money/money.dart';
import 'package:smartflow/feature/shared/presentation/account_lookup.dart';
import 'package:smartflow/feature/transaction/presentation/transaction_detail_presentation.dart';

void main() {
  test('detail title reads category lines instead of entries', () {
    final detail = _detail(BusinessPurpose.dailyIncome, const [
      TransactionLine(
        id: 'category',
        transactionId: 'tx',
        lineNo: 1,
        role: TransactionRole.category,
        accountId: 'salary',
        amount: Money(minorUnits: 10000),
      ),
    ]);
    final salary = Account(
      id: 'salary',
      name: '工资',
      type: AccountType.income,
      balance: Money.zero(),
    );
    final hero = transactionDetailHero(
      detail: detail,
      accountLookup: AccountLookup({'salary': salary}),
    );
    expect(hero.title, '工资');
  });

  test('bad debt falls back to its purpose label', () {
    final hero = transactionDetailHero(
      detail: _detail(BusinessPurpose.badDebt),
      accountLookup: const AccountLookup({}),
    );
    expect(hero.title, '坏账');
    expect(hero.amount.minorUnits, -10000);
  });

  test('builds separately priced category breakdown items', () {
    final detail = _detail(BusinessPurpose.dailyExpense, const [
      TransactionLine(
        id: 'food-line',
        transactionId: 'tx',
        lineNo: 1,
        role: TransactionRole.category,
        accountId: 'food',
        amount: Money(minorUnits: 6000),
      ),
      TransactionLine(
        id: 'travel-line',
        transactionId: 'tx',
        lineNo: 2,
        role: TransactionRole.category,
        accountId: 'travel',
        amount: Money(minorUnits: 4000),
      ),
    ]);
    final lookup = AccountLookup({
      'food': Account(
        id: 'food',
        name: '餐饮',
        type: AccountType.expense,
        iconKey: 'meal',
        balance: Money.zero(),
      ),
      'travel': Account(
        id: 'travel',
        name: '交通',
        type: AccountType.expense,
        iconKey: 'taxi',
        balance: Money.zero(),
      ),
    });
    final hero = transactionDetailHero(detail: detail, accountLookup: lookup);
    final breakdowns = transactionDetailAllocationBreakdowns(
      detail: detail,
      accountLookup: lookup,
    );

    expect(hero.title, '多分类');
    expect(hero.iconKey, isNull);
    expect(breakdowns.single.kind, DetailAllocationKind.category);
    expect(breakdowns.single.title, '分类构成');
    expect(breakdowns.single.items.map((item) => item.title), ['餐饮', '交通']);
    expect(breakdowns.single.items.map((item) => item.amount.minorUnits), [
      6000,
      4000,
    ]);
  });

  test('uses a shared account breakdown label for settlement allocations', () {
    final detail = _detail(BusinessPurpose.dailyExpense, const [
      TransactionLine(
        id: 'cash-line',
        transactionId: 'tx',
        lineNo: 1,
        role: TransactionRole.settlementOut,
        accountId: 'cash',
        amount: Money(minorUnits: 6000),
      ),
      TransactionLine(
        id: 'bank-line',
        transactionId: 'tx',
        lineNo: 2,
        role: TransactionRole.settlementOut,
        accountId: 'bank',
        amount: Money(minorUnits: 4000),
      ),
    ]);
    final lookup = AccountLookup({
      'cash': Account(
        id: 'cash',
        name: '现金',
        type: AccountType.asset,
        balance: Money.zero(),
      ),
      'bank': Account(
        id: 'bank',
        name: '银行卡',
        type: AccountType.asset,
        balance: Money.zero(),
      ),
    });

    final breakdown = transactionDetailAllocationBreakdowns(
      detail: detail,
      accountLookup: lookup,
    ).single;

    expect(breakdown.kind, DetailAllocationKind.account);
    expect(breakdown.title, '账户构成');
    expect(breakdown.items.map((item) => item.title), ['现金', '银行卡']);
  });

  test('transfer fee is read from the fee line', () {
    final detail = _detail(BusinessPurpose.transfer, const [
      TransactionLine(
        id: 'fee',
        transactionId: 'tx',
        lineNo: 1,
        role: TransactionRole.fee,
        amount: Money(minorUnits: 300),
      ),
    ]);
    expect(transactionTransferFee(detail)?.minorUnits, 300);
  });
}

TransactionReadModel _detail(
  BusinessPurpose purpose, [
  List<TransactionLine> lines = const [],
]) => TransactionReadModel(
  id: 'tx',
  businessPurpose: purpose,
  occurredAt: DateTime(2026, 8, 20),
  primaryAmount: const Money(minorUnits: 10000),
  isExcludedFromStats: false,
  isExcludedFromBudget: false,
  lines: lines,
);
