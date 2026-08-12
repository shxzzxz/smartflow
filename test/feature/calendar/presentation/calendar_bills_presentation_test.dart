import 'package:flutter_test/flutter_test.dart';
import 'package:smartflow/application/credit/credit_query_api.dart';
import 'package:smartflow/application/ledger/ledger_query_api.dart';
import 'package:smartflow/core/money/money.dart';
import 'package:smartflow/feature/calendar/presentation/calendar_bills_presentation.dart';
import 'package:smartflow/feature/shared/presentation/account_lookup.dart';

void main() {
  final lookup = AccountLookup({
    'card': Account(
      id: 'card',
      name: '信用卡',
      type: AccountType.liability,
      balance: Money.zero(),
    ),
  });

  test('builds only the selected day bill item rows', () {
    final rows = buildCalendarDayBillRows(
      date: DateTime(2026, 1, 15),
      items: [
        _dueItem(DateTime(2026, 1, 15), BillItemType.installment),
        _dueItem(DateTime(2026, 1, 16), BillItemType.consumption),
      ],
      accountLookup: lookup,
    );

    expect(rows, hasLength(1));
    expect(rows.single.accountName, '信用卡');
    expect(rows.single.supportingTexts, ['分期明细']);
    expect(rows.single.amount, const Money(minorUnits: 9300));
  });

  test(
    'uses pending amount for open bills and total amount for settled bills',
    () {
      final rows = buildCalendarMonthBillRows(
        bills: [
          _bill('open', BillStatus.open, pendingMinor: 8000),
          _bill('settled', BillStatus.settled, pendingMinor: 0),
        ],
        accountLookup: const AccountLookup({}),
      );

      expect(rows.first.accountName, '未知账户');
      expect(rows.first.supportingTexts, ['2 条明细', '累积中']);
      expect(rows.first.amount, const Money(minorUnits: 8000));
      expect(rows.last.supportingTexts, ['2 条明细', '已了结']);
      expect(rows.last.amount, const Money(minorUnits: 10500));
    },
  );
}

CreditDueCalendarItemReadModel _dueItem(DateTime date, BillItemType type) {
  return CreditDueCalendarItemReadModel.billItem(
    accountId: 'card',
    billId: 'bill',
    billItemId: 'item-${date.day}',
    dueDate: date,
    itemType: type,
    principal: const Money(minorUnits: 9000),
    interest: const Money(minorUnits: 300),
    fee: Money.zero(),
    pendingTotal: const Money(minorUnits: 9300),
  );
}

MonthlyBillSummaryReadModel _bill(
  String id,
  BillStatus status, {
  required int pendingMinor,
}) {
  return MonthlyBillSummaryReadModel(
    accountId: 'missing',
    billId: id,
    period: BillPeriod(year: 2026, month: 1),
    status: status,
    expectedPrincipal: const Money(minorUnits: 10000),
    expectedInterest: const Money(minorUnits: 300),
    expectedFee: const Money(minorUnits: 200),
    pendingPrincipal: Money(minorUnits: pendingMinor),
    pendingTotal: Money(minorUnits: pendingMinor),
    itemCount: 2,
  );
}
