import '../../../application/credit/credit_query_api.dart';
import '../../../application/ledger/ledger_query_api.dart';
import '../../../application/shared/app_settings_store.dart';
import '../../../core/money/money.dart';
import '../../../core/money/money_formatter.dart';
import 'package:smartflow/feature/shared/presentation/transaction_list_presentation.dart';
import 'package:smartflow/widget/business/finance/finance_tone.dart';

import 'lunar_label_resolver.dart';

class CalendarMonthPresentation {
  const CalendarMonthPresentation({required this.summary, required this.days});

  final CalendarMonthlySummaryPresentation summary;
  final List<CalendarDayPresentation> days;
}

/// 选中日的交易分页独立于月度网格：网格与日汇总来自整月聚合，
/// 交易明细按单日分页拉取，两者的加载状态互不阻塞。
class CalendarDaySectionPresentation {
  const CalendarDaySectionPresentation({
    required this.group,
    required this.dueBillItems,
    required this.isLoading,
    required this.hasMore,
    required this.isLoadingMore,
    this.loadMoreErrorMessage,
  });

  final TransactionDayGroup group;
  final List<CreditDueCalendarItemReadModel> dueBillItems;
  final bool isLoading;
  final bool hasMore;
  final bool isLoadingMore;
  final String? loadMoreErrorMessage;
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
    this.heat,
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

  /// 热力图关闭、或当日该维度金额为 0 时为空。
  final CalendarDayHeatPresentation? heat;

  bool get hasCashflow => incomeMinor != 0 || expenseMinor != 0;

  String get incomeText => _formatCompactMinorAmount(incomeMinor);

  String get expenseText => _formatCompactMinorAmount(expenseMinor);
}

/// 热力强度按当月该维度的最大绝对值归一化，[intensity] 取 (0, 1]。
class CalendarDayHeatPresentation {
  const CalendarDayHeatPresentation({
    required this.intensity,
    required this.tone,
  });

  final double intensity;
  final FinanceTone tone;
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
  required CashflowSummary summary,
  required List<DailyCashflowSummary> dailySummaries,
  List<CreditDueCalendarItemReadModel> creditDueItems = const [],
  List<MonthlyBillSummaryReadModel> monthlyBillSummaries = const [],
  CalendarHeatMetric? heatMetric,
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
      heatMetric: heatMetric,
      today: today,
      lunarLabelResolver: lunarLabelResolver,
    ),
  );
}

CalendarMonthlySummaryPresentation buildCalendarMonthlySummaryPresentation(
  CashflowSummary summary, {
  List<MonthlyBillSummaryReadModel> monthlyBillSummaries = const [],
}) {
  final billPendingMinor = monthlyBillSummaries.fold<int>(
    0,
    (sum, bill) => sum + bill.pendingTotal.minorUnits,
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
  ];
  if (monthlyBillSummaries.isNotEmpty) {
    metrics.add(
      CalendarMonthlySummaryMetricPresentation(
        label: '待还',
        amountText: _formatCompactMinorAmount(billPendingMinor),
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
  CalendarHeatMetric? heatMetric,
  DateTime? today,
  CalendarLunarLabelResolver lunarLabelResolver =
      const DefaultCalendarLunarLabelResolver(),
}) {
  final month = DateTime(visibleMonth.year, visibleMonth.month);
  final normalizedSelected = normalizeDate(selectedDate);
  final normalizedToday = normalizeDate(today ?? DateTime.now());
  final totalsByDate = _totalsByDate(dailySummaries);
  final duesByDate = _dueCountsByDate(creditDueItems);
  final heatScale =
      heatMetric == null ? null : _HeatScale(heatMetric, totalsByDate.values);

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
        heat: heatScale?.heatFor(totalsByDate[date]),
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
  required CalendarDayHeatPresentation? heat,
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
    heat: heat,
  );
}

/// 按当月该维度的最大绝对值把每日金额归一化为 (0, 1] 的热力强度。
/// 色调跟随金额方向：与维度同向取 income / expense，反向（退款、净支出）取另一侧。
class _HeatScale {
  _HeatScale(this.metric, Iterable<_DayTotals> totals)
    : _maxAbsMinor = totals.fold<int>(0, (max, item) {
        final value = _metricMinor(metric, item).abs();
        return value > max ? value : max;
      });

  final CalendarHeatMetric metric;
  final int _maxAbsMinor;

  CalendarDayHeatPresentation? heatFor(_DayTotals? totals) {
    if (totals == null || _maxAbsMinor == 0) return null;
    final minorUnits = _metricMinor(metric, totals);
    if (minorUnits == 0) return null;
    final isPositive = minorUnits > 0;
    return CalendarDayHeatPresentation(
      intensity: minorUnits.abs() / _maxAbsMinor,
      tone: switch (metric) {
        CalendarHeatMetric.expense =>
          isPositive ? FinanceTone.expense : FinanceTone.income,
        CalendarHeatMetric.income || CalendarHeatMetric.net =>
          isPositive ? FinanceTone.income : FinanceTone.expense,
      },
    );
  }

  static int _metricMinor(CalendarHeatMetric metric, _DayTotals totals) {
    return switch (metric) {
      CalendarHeatMetric.expense => totals.expenseMinor,
      CalendarHeatMetric.income => totals.incomeMinor,
      CalendarHeatMetric.net => totals.incomeMinor - totals.expenseMinor,
    };
  }
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
