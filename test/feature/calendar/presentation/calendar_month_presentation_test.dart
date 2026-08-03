import 'package:flutter_test/flutter_test.dart';
import 'package:smartflow/application/credit/credit_query_api.dart';
import 'package:smartflow/application/ledger/ledger_query_api.dart';
import 'package:smartflow/core/money/money.dart';
import 'package:smartflow/feature/calendar/presentation/calendar_month_presentation.dart';
import 'package:smartflow/feature/calendar/presentation/lunar_label_resolver.dart';

void main() {
  group('calendar month presentation', () {
    test('builds calendar grid and selected day group', () {
      final presentation = buildCalendarMonthPresentation(
        visibleMonth: DateTime(2026, 2),
        selectedDate: DateTime(2026, 2, 14),
        today: DateTime(2026, 2, 1),
        transactions: [_item(occurredAt: DateTime(2026, 2, 14, 8))],
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
      expect(selected.incomeText, '50');
      expect(selected.expenseText, '12');
      expect(selected.lunarLabel, 'L14');
      expect(selected.markerLabel, '班');

      expect(presentation.selectedGroup.date, DateTime(2026, 2, 14));
      expect(presentation.selectedGroup.rows.single.transactionId, 'tx-1');
      expect(presentation.summary.metrics.map((metric) => metric.amountText), [
        '50',
        '12',
        '38',
      ]);
    });

    test('clamps selected date to target month last day', () {
      expect(
        clampSelectedDateToMonth(DateTime(2026, 1, 31), DateTime(2026, 2)),
        DateTime(2026, 2, 28),
      );
    });

    test(
      'preserves signed compact daily totals and hides only all-zero totals',
      () {
        final mixed = _day(incomeMinor: 12400 * 100, expenseMinor: -3000);
        final refundOnly = _day(incomeMinor: 0, expenseMinor: -3000);
        final empty = _day(incomeMinor: 0, expenseMinor: 0);

        expect(mixed.hasCashflow, true);
        expect(mixed.incomeText, '1.24万');
        expect(mixed.expenseText, '-30');
        expect(refundOnly.hasCashflow, true);
        expect(empty.hasCashflow, false);
      },
    );

    test('formats every monthly summary metric compactly', () {
      final presentation = buildCalendarMonthlySummaryPresentation(
        const CashflowSummary(
          income: Money(minorUnits: 12400 * 100),
          expense: Money(minorUnits: 20000 * 100),
        ),
        monthlyBillSummaries: [
          MonthlyBillSummaryReadModel(
            accountId: 'credit',
            billId: 'bill',
            period: BillPeriod(year: 2026, month: 7),
            status: BillStatus.open,
            expectedPrincipal: const Money(minorUnits: 25000 * 100),
            expectedInterest: const Money(minorUnits: 0),
            expectedFee: const Money(minorUnits: 0),
            pendingPrincipal: const Money(minorUnits: 25000 * 100),
            itemCount: 1,
          ),
        ],
      );

      expect(presentation.metrics.map((metric) => metric.amountText), [
        '1.24万',
        '2万',
        '-7600',
        '2.5万',
      ]);
    });
  });
}

CalendarDayPresentation _day({
  required int incomeMinor,
  required int expenseMinor,
}) {
  return CalendarDayPresentation(
    date: DateTime(2026, 7, 22),
    isInVisibleMonth: true,
    isSelected: false,
    isToday: false,
    incomeMinor: incomeMinor,
    expenseMinor: expenseMinor,
    dueItemCount: 0,
    lunarLabel: '',
    markerLabel: null,
  );
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
    businessPurpose: BusinessPurpose.dailyIncome,
    occurredAt: occurredAt,
    primaryAmount: const Money(minorUnits: 5000),
    isExcludedFromStats: false,
    isExcludedFromBudget: false,
    category: null,
    settlementEntries: const [],
    adjustments: const [],
  );
}
