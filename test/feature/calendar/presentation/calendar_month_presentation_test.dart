import 'package:flutter_test/flutter_test.dart';
import 'package:smartflow/application/credit/credit_query_api.dart';
import 'package:smartflow/application/ledger/ledger_query_api.dart';
import 'package:smartflow/application/shared/app_settings_store.dart';
import 'package:smartflow/core/money/money.dart';
import 'package:smartflow/feature/calendar/presentation/calendar_month_presentation.dart';
import 'package:smartflow/feature/calendar/presentation/lunar_label_resolver.dart';
import 'package:smartflow/widget/business/finance/finance_tone.dart';

void main() {
  group('calendar month presentation', () {
    test('builds calendar grid', () {
      final presentation = buildCalendarMonthPresentation(
        visibleMonth: DateTime(2026, 2),
        selectedDate: DateTime(2026, 2, 14),
        today: DateTime(2026, 2, 1),
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

      expect(presentation.summary.metrics.map((metric) => metric.amountText), [
        '50',
        '12',
      ]);
    });

    test('clamps selected date to target month last day', () {
      expect(
        clampSelectedDateToMonth(DateTime(2026, 1, 31), DateTime(2026, 2)),
        DateTime(2026, 2, 28),
      );
    });

    test('leaves every day without heat when no metric is selected', () {
      final days = _daysWithHeat(metric: null);

      expect(days.every((day) => day.heat == null), true);
    });

    test('scales expense heat against the strongest day of the month', () {
      final days = _daysWithHeat(metric: CalendarHeatMetric.expense);

      expect(_heatAt(days, 2)?.intensity, 1.0);
      expect(_heatAt(days, 2)?.tone, FinanceTone.expense);
      // 100 / 400 按最大值归一化，1000 的收入日在支出维度上没有热力。
      expect(_heatAt(days, 3)?.intensity, 0.25);
      expect(_heatAt(days, 4), null);
    });

    test('flips the heat tone when the day runs against the metric', () {
      final days = _daysWithHeat(metric: CalendarHeatMetric.expense);

      expect(_heatAt(days, 5)?.tone, FinanceTone.income);
    });

    test('grades net heat by sign', () {
      final days = _daysWithHeat(metric: CalendarHeatMetric.net);

      expect(_heatAt(days, 4)?.tone, FinanceTone.income);
      expect(_heatAt(days, 2)?.tone, FinanceTone.expense);
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

    test('sums the pending total of monthly bills into the 待还 metric', () {
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
            expectedInterest: const Money(minorUnits: 300 * 100),
            expectedFee: const Money(minorUnits: 200 * 100),
            pendingPrincipal: const Money(minorUnits: 25000 * 100),
            pendingTotal: const Money(minorUnits: 25500 * 100),
            itemCount: 1,
          ),
        ],
      );

      expect(
        presentation.metrics.map((metric) => (metric.label, metric.amountText)),
        [('收入', '1.24万'), ('支出', '2万'), ('待还', '2.55万')],
      );
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

List<CalendarDayPresentation> _daysWithHeat({
  required CalendarHeatMetric? metric,
}) {
  return buildCalendarDayPresentations(
    visibleMonth: DateTime(2026, 2),
    selectedDate: DateTime(2026, 2, 1),
    today: DateTime(2026, 2, 1),
    creditDueItems: const [],
    heatMetric: metric,
    dailySummaries: [
      _summary(day: 2, incomeMinor: 0, expenseMinor: 400),
      _summary(day: 3, incomeMinor: 0, expenseMinor: 100),
      _summary(day: 4, incomeMinor: 1000, expenseMinor: 0),
      _summary(day: 5, incomeMinor: 0, expenseMinor: -200),
    ],
    lunarLabelResolver: const _FakeLunarResolver(),
  );
}

DailyCashflowSummary _summary({
  required int day,
  required int incomeMinor,
  required int expenseMinor,
}) {
  return DailyCashflowSummary(
    date: DateTime(2026, 2, day),
    income: Money(minorUnits: incomeMinor),
    expense: Money(minorUnits: expenseMinor),
  );
}

CalendarDayHeatPresentation? _heatAt(
  List<CalendarDayPresentation> days,
  int day,
) {
  return days.singleWhere((item) => item.date == DateTime(2026, 2, day)).heat;
}

class _FakeLunarResolver implements CalendarLunarLabelResolver {
  const _FakeLunarResolver();

  @override
  CalendarLunarLabel labelFor(DateTime date) {
    return CalendarLunarLabel(text: 'L${date.day}', marker: '班');
  }
}
