import 'package:flutter_test/flutter_test.dart';
import 'package:smartflow/core/money/money.dart';
import 'package:smartflow/domain/accounting/accounting_api.dart';
import 'package:smartflow/features/calendar/view_models/calendar_month_presentation.dart';
import 'package:smartflow/features/calendar/view_models/lunar_label_resolver.dart';

void main() {
  group('calendar month presentation', () {
    test('builds a Sunday-first month grid with leading and trailing days', () {
      final dates = calendarGridDates(DateTime(2024, 5));

      expect(dates, hasLength(35));
      expect(dates.first, DateTime(2024, 4, 28));
      expect(dates.last, DateTime(2024, 6, 1));
    });

    test('clamps selected day when switching to a shorter month', () {
      expect(
        clampSelectedDateToMonth(DateTime(2024, 1, 31), DateTime(2024, 2)),
        DateTime(2024, 2, 29),
      );
      expect(
        clampSelectedDateToMonth(DateTime(2023, 1, 31), DateTime(2023, 2)),
        DateTime(2023, 2, 28),
      );
    });

    test(
      'uses cashflow lines instead of lunar labels when a day has records',
      () {
        final days = buildCalendarMonthPresentation(
          visibleMonth: DateTime(2024, 5),
          selectedDate: DateTime(2024, 5, 3),
          today: DateTime(2024, 5, 1),
          transactions: [
            _item(
              id: 1,
              purpose: BusinessPurpose.dailyIncome,
              occurredAt: DateTime(2024, 5, 3, 8, 30),
              amountMinor: 30000,
            ),
            _item(
              id: 2,
              purpose: BusinessPurpose.dailyExpense,
              occurredAt: DateTime(2024, 5, 3, 9, 16),
              amountMinor: 19800,
            ),
          ],
          dailySummaries: [
            _dailySummary(
              DateTime(2024, 5, 3),
              incomeMinor: 30000,
              expenseMinor: 19800,
            ),
          ],
          lunarLabelResolver: const _FakeLunarLabelResolver(),
        );

        final mayThird = days.singleWhere((day) => day.date.day == 3);

        expect(mayThird.isSelected, isTrue);
        expect(mayThird.incomeMinor, 30000);
        expect(mayThird.expenseMinor, 19800);
        expect(mayThird.hasCashflow, isTrue);
        expect(mayThird.incomeText, '+300.00');
        expect(mayThird.expenseText, '-198.00');
        expect(mayThird.lunarLabel, '农历');
        expect(mayThird.markerLabel, isNull);
      },
    );

    test('filters selected day transactions and summarizes the day', () {
      final group = transactionGroupForDate(
        date: DateTime(2024, 5, 3),
        transactions: [
          _item(
            id: 1,
            purpose: BusinessPurpose.dailyIncome,
            occurredAt: DateTime(2024, 5, 3, 8, 30),
            amountMinor: 30000,
          ),
          _item(
            id: 2,
            purpose: BusinessPurpose.dailyExpense,
            occurredAt: DateTime(2024, 5, 4, 9, 16),
            amountMinor: 19800,
          ),
        ],
        dailySummaries: [
          _dailySummary(DateTime(2024, 5, 3), incomeMinor: 42000),
        ],
      );

      expect(group.date, DateTime(2024, 5, 3));
      expect(group.items, hasLength(1));
      expect(group.incomeMinor, 42000);
      expect(group.expenseMinor, 0);
    });
  });

  group('lunar label resolver', () {
    test('returns lunar festival labels', () {
      const resolver = DefaultCalendarLunarLabelResolver();

      final label = resolver.labelFor(DateTime(2024, 2, 10));

      expect(label.text, '春节');
      expect(label.marker, isNull);
    });

    test('keeps workday marker separate from the bottom lunar label', () {
      const resolver = DefaultCalendarLunarLabelResolver();

      final holiday = resolver.labelFor(DateTime(2024, 5, 1));
      final restDay = resolver.labelFor(DateTime(2024, 5, 2));
      final workday = resolver.labelFor(DateTime(2024, 5, 11));

      expect(holiday.text, '劳动节');
      expect(holiday.marker, isNull);
      expect(restDay.text, isNot('劳动节'));
      expect(restDay.marker, isNull);
      expect(workday.text, isNot('班'));
      expect(workday.marker, '班');
    });
  });
}

class _FakeLunarLabelResolver implements CalendarLunarLabelResolver {
  const _FakeLunarLabelResolver();

  @override
  CalendarLunarLabel labelFor(DateTime date) =>
      const CalendarLunarLabel(text: '农历');
}

DailyCashflowSummary _dailySummary(
  DateTime date, {
  int incomeMinor = 0,
  int expenseMinor = 0,
}) {
  return DailyCashflowSummary(
    date: date,
    income: Money(minorUnits: incomeMinor),
    expense: Money(minorUnits: expenseMinor),
  );
}

TransactionListItem _item({
  required int id,
  required BusinessPurpose purpose,
  required DateTime occurredAt,
  required int amountMinor,
}) {
  return TransactionListItem(
    id: id,
    businessPurpose: purpose,
    occurredAt: occurredAt,
    primaryAmount: Money(minorUnits: amountMinor),
    accountNames: '现金',
    isExcludedFromStats: false,
    isExcludedFromBudget: false,
  );
}
