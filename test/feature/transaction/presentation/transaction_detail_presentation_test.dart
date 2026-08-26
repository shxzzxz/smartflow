import 'package:flutter_test/flutter_test.dart';
import 'package:smartflow/application/ledger/ledger_query_api.dart';
import 'package:smartflow/core/money/money.dart';
import 'package:smartflow/feature/shared/presentation/account_lookup.dart';
import 'package:smartflow/feature/transaction/presentation/transaction_detail_presentation.dart';

void main() {
  test('detail title reads category lines instead of entries', () {
    final detail = _detail(BusinessPurpose.dailyIncome, const [
      TransactionLine(id: 'category', transactionId: 'tx', lineNo: 1, role: TransactionRole.category, accountId: 'salary', amount: Money(minorUnits: 10000)),
    ]);
    final salary = Account(id: 'salary', name: '工资', type: AccountType.income, balance: Money.zero());
    final hero = transactionDetailHero(detail: detail, accountLookup: AccountLookup({'salary': salary}));
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

  test('transfer fee is read from the fee line', () {
    final detail = _detail(BusinessPurpose.transfer, const [
      TransactionLine(id: 'fee', transactionId: 'tx', lineNo: 1, role: TransactionRole.fee, amount: Money(minorUnits: 300)),
    ]);
    expect(transactionTransferFee(detail)?.minorUnits, 300);
  });
}

TransactionReadModel _detail(BusinessPurpose purpose, [List<TransactionLine> lines = const []]) => TransactionReadModel(
  id: 'tx',
  businessPurpose: purpose,
  occurredAt: DateTime(2026, 8, 20),
  primaryAmount: const Money(minorUnits: 10000),
  isExcludedFromStats: false,
  isExcludedFromBudget: false,
  lines: lines,
);
