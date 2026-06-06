import 'package:flutter_test/flutter_test.dart';
import 'package:smartflow/application/ledger/ledger_query_api.dart';
import 'package:smartflow/core/money/money.dart';
import 'package:smartflow/feature/calendar/presentation/calendar_month_presentation.dart';
import 'package:smartflow/feature/calendar/presentation/lunar_label_resolver.dart';
import 'package:smartflow/widget/business/account_lookup.dart';

void main() {
  group('calendar month presentation', () {
    test('builds calendar grid and selected day group', () {
      final presentation = buildCalendarMonthPresentation(
        visibleMonth: DateTime(2026, 2),
        selectedDate: DateTime(2026, 2, 14),
        today: DateTime(2026, 2, 1),
        transactions: [_item(occurredAt: DateTime(2026, 2, 14, 8))],
        accountLookup: const AccountLookup(<String, Account>{}),
        summary: const CashflowSummary(
          income: Money(minorUnits: 5000),
          expense: Money(minorUnits: 1200),
        ),
        dailySummaries: [
          DailyCashflowSummary(
            date: DateTime(2026, 2, 14),
            income: Money(minorUnits: 5000),
            expense: Money(minorUnits: 1200),
          ),
        ],
        lunarLabelResolver: const _FakeLunarResolver(),
      );

      expect(presentation.days, hasLength(28));
      expect(presentation.days.first.date, DateTime(2026, 2, 1));
      expect(presentation.days.first.isToday, true);

      final selected = presentation.days.singleWhere((day) => day.isSelected);
      expect(selected.date, DateTime(2026, 2, 14));
      expect(selected.incomeText, '+50.00');
      expect(selected.expenseText, '-12.00');
      expect(selected.lunarLabel, 'L14');
      expect(selected.markerLabel, '班');

      expect(presentation.selectedGroup.date, DateTime(2026, 2, 14));
      expect(presentation.selectedGroup.rows.single.transactionId, 'tx-1');
      expect(presentation.summary.metrics.map((metric) => metric.amountText), [
        '50.00',
        '12.00',
        '38.00',
      ]);
    });

    test('clamps selected date to target month last day', () {
      expect(
        clampSelectedDateToMonth(DateTime(2026, 1, 31), DateTime(2026, 2)),
        DateTime(2026, 2, 28),
      );
    });
  });
}

class _FakeLunarResolver implements CalendarLunarLabelResolver {
  const _FakeLunarResolver();

  @override
  CalendarLunarLabel labelFor(DateTime date) {
    return CalendarLunarLabel(text: 'L${date.day}', marker: '班');
  }
}

TransactionListReadModel _item({required DateTime occurredAt}) {
  return TransactionListReadModel(
    id: 'tx-1',
    rootTransactionId: 'tx-1',
    businessPurpose: BusinessPurpose.dailyIncome,
    businessState: BusinessState.current,
    occurredAt: occurredAt,
    primaryAmount: const Money(minorUnits: 5000),
    isExcludedFromStats: false,
    isExcludedFromBudget: false,
    entries: const [],
    details: const [],
  );
}
