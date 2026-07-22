import '../../../application/credit/credit_query_api.dart';
import '../../../application/ledger/ledger_query_api.dart';
import '../../../core/money/money.dart';
import '../../../core/money/money_formatter.dart';
import 'package:smartflow/feature/shared/presentation/account_lookup.dart';
import 'package:smartflow/feature/shared/presentation/transaction_list_presentation.dart';
import 'package:smartflow/widget/business/finance/finance_tone.dart';

import 'lunar_label_resolver.dart';

class CalendarMonthPresentation {
  const CalendarMonthPresentation({
    required this.summary,
    required this.days,
    required this.selectedGroup,
  });

  final CalendarMonthlySummaryPresentation summary;
  final List<CalendarDayPresentation> days;
  final TransactionDayGroup selectedGroup;
}

class CalendarMonthlySummaryPresentation {
  const CalendarMonthlySummaryPresentation({required this.metrics});

  final List<CalendarMonthlySummaryMetricPresentation> metrics;
}

class CalendarMonthlySummaryMetricPresentation {
  const CalendarMonthlySummaryMetricPresentation({
    required this.label,
    required this.amountText,
    required this.tone,
  });

  final String label;
  final String amountText;
  final FinanceTone tone;
}

class CalendarDayPresentation {
  const CalendarDayPresentation({
    required this.date,
    required this.isInVisibleMonth,
    required this.isSelected,
    required this.isToday,
    required this.incomeMinor,
    required this.expenseMinor,
    required this.dueItemCount,
    required this.lunarLabel,
    required this.markerLabel,
  });

  final DateTime date;
  final bool isInVisibleMonth;
  final bool isSelected;
  final bool isToday;
  final int incomeMinor;
  final int expenseMinor;
  final int dueItemCount;
  final String lunarLabel;
  final String? markerLabel;

  bool get hasCashflow => incomeMinor != 0 || expenseMinor != 0;

  String get incomeText => _formatCompactMinorAmount(incomeMinor);

  String get expenseText => _formatCompactMinorAmount(expenseMinor);
}

String _formatCompactMinorAmount(int minorUnits) {
  return formatMoney(
    Money(minorUnits: minorUnits),
    style: MoneyFormatStyle.compact,
  );
}

CalendarMonthPresentation buildCalendarMonthPresentation({
  required DateTime visibleMonth,
  required DateTime selectedDate,
  required List<TransactionListReadModel> transactions,
  required AccountLookup accountLookup,
  required CashflowSummary summary,
  required List<DailyCashflowSummary> dailySummaries,
  List<CreditDueCalendarItemReadModel> creditDueItems = const [],
  List<MonthlyBillSummaryReadModel> monthlyBillSummaries = const [],
  DateTime? today,
  CalendarLunarLabelResolver lunarLabelResolver =
      const DefaultCalendarLunarLabelResolver(),
}) {
  return CalendarMonthPresentation(
    summary: buildCalendarMonthlySummaryPresentation(
      summary,
      monthlyBillSummaries: monthlyBillSummaries,
    ),
    days: buildCalendarDayPresentations(
      visibleMonth: visibleMonth,
      selectedDate: selectedDate,
      dailySummaries: dailySummaries,
      creditDueItems: creditDueItems,
      today: today,
      lunarLabelResolver: lunarLabelResolver,
    ),
    selectedGroup: transactionGroupForDate(
      date: selectedDate,
      transactions: transactions,
      accountLookup: accountLookup,
      dailySummaries: dailySummaries,
    ),
  );
}

CalendarMonthlySummaryPresentation buildCalendarMonthlySummaryPresentation(
  CashflowSummary summary, {
  List<MonthlyBillSummaryReadModel> monthlyBillSummaries = const [],
}) {
  final billDueMinor = monthlyBillSummaries.fold<int>(
    0,
    (sum, bill) => sum + bill.pendingPrincipal.minorUnits,
  );
  final metrics = [
    CalendarMonthlySummaryMetricPresentation(
      label: '收入',
      amountText: formatMoney(summary.income, style: MoneyFormatStyle.compact),
      tone: FinanceTone.income,
    ),
    CalendarMonthlySummaryMetricPresentation(
      label: '支出',
      amountText: formatMoney(summary.expense, style: MoneyFormatStyle.compact),
      tone: FinanceTone.expense,
    ),
    CalendarMonthlySummaryMetricPresentation(
      label: '净收入',
      amountText: formatMoney(summary.net, style: MoneyFormatStyle.compact),
      tone: FinanceTone.neutral,
    ),
  ];
  if (monthlyBillSummaries.isNotEmpty) {
    metrics.add(
      CalendarMonthlySummaryMetricPresentation(
        label: '应还',
        amountText: _formatCompactMinorAmount(billDueMinor),
        tone: FinanceTone.expense,
      ),
    );
  }
  return CalendarMonthlySummaryPresentation(metrics: metrics);
}

List<CalendarDayPresentation> buildCalendarDayPresentations({
  required DateTime visibleMonth,
  required DateTime selectedDate,
  required List<DailyCashflowSummary> dailySummaries,
  required List<CreditDueCalendarItemReadModel> creditDueItems,
  DateTime? today,
  CalendarLunarLabelResolver lunarLabelResolver =
      const DefaultCalendarLunarLabelResolver(),
}) {
  final month = DateTime(visibleMonth.year, visibleMonth.month);
  final normalizedSelected = normalizeDate(selectedDate);
  final normalizedToday = normalizeDate(today ?? DateTime.now());
  final totalsByDate = _totalsByDate(dailySummaries);
  final duesByDate = _dueCountsByDate(creditDueItems);

  return [
    for (final date in calendarGridDates(month))
      _buildCalendarDay(
        date: date,
        month: month,
        normalizedSelected: normalizedSelected,
        normalizedToday: normalizedToday,
        totals: totalsByDate[date],
        dueItemCount: duesByDate[date] ?? 0,
        lunarLabel: lunarLabelResolver.labelFor(date),
      ),
  ];
}

CalendarDayPresentation _buildCalendarDay({
  required DateTime date,
  required DateTime month,
  required DateTime normalizedSelected,
  required DateTime normalizedToday,
  required _DayTotals? totals,
  required int dueItemCount,
  required CalendarLunarLabel lunarLabel,
}) {
  return CalendarDayPresentation(
    date: date,
    isInVisibleMonth: date.year == month.year && date.month == month.month,
    isSelected: isSameDate(date, normalizedSelected),
    isToday: isSameDate(date, normalizedToday),
    incomeMinor: totals?.incomeMinor ?? 0,
    expenseMinor: totals?.expenseMinor ?? 0,
    dueItemCount: dueItemCount,
    lunarLabel: lunarLabel.text,
    markerLabel: dueItemCount > 0 ? '$dueItemCount' : lunarLabel.marker,
  );
}

List<DateTime> calendarGridDates(DateTime visibleMonth) {
  final month = DateTime(visibleMonth.year, visibleMonth.month);
  final firstDayWeekdayIndex = month.weekday % DateTime.daysPerWeek;
  final startDate = month.subtract(Duration(days: firstDayWeekdayIndex));
  final lastDay = DateTime(month.year, month.month + 1, 0);
  final trailingDays =
      DateTime.daysPerWeek - 1 - (lastDay.weekday % DateTime.daysPerWeek);
  final totalDays = firstDayWeekdayIndex + lastDay.day + trailingDays;
  return [
    for (var index = 0; index < totalDays; index++)
      normalizeDate(startDate.add(Duration(days: index))),
  ];
}

DateTime clampSelectedDateToMonth(DateTime selectedDate, DateTime month) {
  final targetMonth = DateTime(month.year, month.month);
  final lastDay = DateTime(targetMonth.year, targetMonth.month + 1, 0).day;
  final day = selectedDate.day > lastDay ? lastDay : selectedDate.day;
  return DateTime(targetMonth.year, targetMonth.month, day);
}

Map<DateTime, _DayTotals> _totalsByDate(List<DailyCashflowSummary> summaries) {
  return {
    for (final summary in summaries)
      normalizeDate(summary.date): _DayTotals(
        incomeMinor: summary.income.minorUnits,
        expenseMinor: summary.expense.minorUnits,
      ),
  };
}

Map<DateTime, int> _dueCountsByDate(
  List<CreditDueCalendarItemReadModel> dueItems,
) {
  final result = <DateTime, int>{};
  for (final item in dueItems) {
    final date = normalizeDate(item.dueDate);
    result[date] = (result[date] ?? 0) + 1;
  }
  return result;
}

class _DayTotals {
  const _DayTotals({required this.incomeMinor, required this.expenseMinor});

  final int incomeMinor;
  final int expenseMinor;
}
