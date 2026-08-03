import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../../app/provider.dart';
import '../../../application/ledger/ledger_query_api.dart';
import '../../../core/time/month_key.dart';
import '../../shared/provider/current_date_time_provider.dart';
import '../../shared/provider/ledger_query_providers.dart';
import 'package:smartflow/feature/shared/presentation/transaction_list_presentation.dart';
import '../presentation/statistics_presentation.dart';

part 'statistics_view_model.g.dart';

enum StatisticsSection { cashflow, balance }

enum StatisticsPeriodGranularity { year, month, date }

enum StatisticsPeriodMode { single, range }

enum CashflowChartMetric { expense, income, compare }

enum CashflowChartForm { bar, line }

enum StatisticsCategoryKind { expense, income }

enum StatisticsDrilldownScope { cashflow, balance }

@riverpod
class StatisticsViewModel extends _$StatisticsViewModel {
  @override
  StatisticsControlState build() {
    final now = ref.watch(currentDateTimeProvider);
    return StatisticsControlState(
      visibleMonth: DateTime(now.year, now.month),
      section: StatisticsSection.cashflow,
      granularity: StatisticsPeriodGranularity.month,
      mode: StatisticsPeriodMode.single,
      periodFrom: DateTime(now.year, now.month),
      periodUntil: DateTime(now.year, now.month + 1),
      chartMetric: CashflowChartMetric.expense,
      chartForm: CashflowChartForm.bar,
      categoryKind: StatisticsCategoryKind.expense,
      categoryLevel: StatisticsCategoryLevel.primary,
    );
  }

  void selectSection(StatisticsSection section) {
    state = state.copyWith(section: section);
  }

  void applyPeriodSelection({
    required StatisticsPeriodGranularity granularity,
    required StatisticsPeriodMode mode,
    required DateTime from,
    required DateTime untilExclusive,
  }) {
    state = state.copyWith(
      granularity: granularity,
      mode: mode,
      periodFrom: from,
      periodUntil: untilExclusive,
      visibleMonth: DateTime(from.year, from.month),
    );
  }

  void selectChartMetric(CashflowChartMetric metric) =>
      state = state.copyWith(chartMetric: metric);

  void selectChartForm(CashflowChartForm form) =>
      state = state.copyWith(chartForm: form);

  void selectCategoryKind(StatisticsCategoryKind kind) =>
      state = state.copyWith(categoryKind: kind);

  void selectCategoryLevel(StatisticsCategoryLevel level) =>
      state = state.copyWith(categoryLevel: level);
}

@riverpod
StatisticsPageState statisticsPage(Ref ref) {
  final control = ref.watch(statisticsViewModelProvider);
  final now = ref.watch(currentDateTimeProvider);
  final range = control.range(now);
  return StatisticsPageState(
    visibleMonth: control.visibleMonth,
    section: control.section,
    control: control,
    periodLabel: control.periodLabel,
    lastSelectableDate: now,
    content: ref.watch(
      statisticsRangeContentProvider(
        range.from,
        range.until,
        range.balancePointIntervalDays,
      ),
    ),
  );
}

@riverpod
Stream<StatisticsRangeReport> statisticsRangeReport(
  Ref ref,
  DateTime from,
  DateTime until,
  int balancePointIntervalDays,
) {
  return ref
      .watch(financialMetricsServiceProvider)
      .watchStatisticsRangeReport(
        StatisticsRangeReportQuery(
          from: from,
          until: until,
          balancePointIntervalDays: balancePointIntervalDays,
        ),
      );
}

@riverpod
StatisticsContentState statisticsRangeContent(
  Ref ref,
  DateTime from,
  DateTime until,
  int balancePointIntervalDays,
) {
  final report = ref.watch(
    statisticsRangeReportProvider(from, until, balancePointIntervalDays),
  );
  if (report case AsyncError(:final error)) {
    return StatisticsContentState.error(message: '加载失败：$error');
  }
  final reportValue = report.value;
  if (reportValue == null) {
    return const StatisticsContentState.loading();
  }
  return StatisticsContentState.loaded(
    presentation: buildRangeStatisticsPresentation(report: reportValue),
  );
}

@riverpod
Stream<CashflowReport> statisticsCashflowReport(
  Ref ref,
  DateTime visibleMonth,
) {
  final now = ref.watch(currentDateTimeProvider);
  final month = MonthKey(year: visibleMonth.year, month: visibleMonth.month);
  final asOfDate =
      now.year == month.year && now.month == month.month ? now : null;
  return ref
      .watch(financialMetricsServiceProvider)
      .watchCashflowReport(
        CashflowReportQuery(month: month, asOfDate: asOfDate),
      );
}

@riverpod
Stream<BalanceReport> statisticsBalanceReport(Ref ref, DateTime visibleMonth) {
  final now = ref.watch(currentDateTimeProvider);
  final month = MonthKey(year: visibleMonth.year, month: visibleMonth.month);
  final asOfExclusive =
      now.year == month.year && now.month == month.month
          ? DateTime(now.year, now.month, now.day + 1)
          : month.nextMonthStart;
  return ref
      .watch(financialMetricsServiceProvider)
      .watchBalanceReport(
        BalanceReportQuery(
          month: month,
          asOfExclusive: asOfExclusive,
          trendMonths: 6,
        ),
      );
}

@riverpod
StatisticsContentState statisticsContent(Ref ref, DateTime visibleMonth) {
  final now = ref.watch(currentDateTimeProvider);
  final month = MonthKey(year: visibleMonth.year, month: visibleMonth.month);
  final isCurrentMonth = now.year == month.year && now.month == month.month;
  final reportUntil =
      isCurrentMonth
          ? DateTime(now.year, now.month, now.day + 1)
          : month.nextMonthStart;
  final cashflow = ref.watch(statisticsCashflowReportProvider(visibleMonth));
  final balance = ref.watch(statisticsBalanceReportProvider(visibleMonth));
  final accounts = ref.watch(accountsByIdProvider);

  for (final value in [cashflow, balance, accounts]) {
    if (value case AsyncError(:final error)) {
      return StatisticsContentState.error(message: '加载失败：$error');
    }
  }
  final cashflowValue = cashflow.value;
  final balanceValue = balance.value;
  final accountValues = accounts.value;
  if (cashflowValue == null || balanceValue == null || accountValues == null) {
    return const StatisticsContentState.loading();
  }
  return StatisticsContentState.loaded(
    presentation: buildStatisticsPresentation(
      cashflow: cashflowValue,
      balance: balanceValue,
      accountsById: accountValues,
      cashflowFrom: month.start,
      cashflowUntil: reportUntil,
      balanceUntil: reportUntil,
    ),
  );
}

@riverpod
Stream<List<TransactionListReadModel>> statisticsTransactions(
  Ref ref, {
  required String? categoryId,
  required bool categoryOwnOnly,
  required String? settlementAccountId,
  required DateTime? occurredFrom,
  required DateTime occurredUntil,
  required StatisticsDrilldownScope scope,
}) {
  return ref
      .watch(transactionQueryServiceProvider)
      .watchTransactions(
        TransactionListQuery(
          categoryId: categoryId,
          categoryOwnOnly: categoryOwnOnly,
          settlementAccountId: settlementAccountId,
          occurredFrom: occurredFrom,
          occurredUntil: occurredUntil,
          topLevelOnly: false,
          scope:
              scope == StatisticsDrilldownScope.cashflow
                  ? TransactionScopeFilter.stats
                  : TransactionScopeFilter.assetLiability,
          limit: null,
        ),
      );
}

@riverpod
StatisticsTransactionsContentState statisticsTransactionsContent(
  Ref ref, {
  required String? categoryId,
  required bool categoryOwnOnly,
  required String? settlementAccountId,
  required DateTime? occurredFrom,
  required DateTime occurredUntil,
  required StatisticsDrilldownScope scope,
}) {
  final transactions = ref.watch(
    statisticsTransactionsProvider(
      categoryId: categoryId,
      categoryOwnOnly: categoryOwnOnly,
      settlementAccountId: settlementAccountId,
      occurredFrom: occurredFrom,
      occurredUntil: occurredUntil,
      scope: scope,
    ),
  );
  if (transactions case AsyncError(:final error)) {
    return StatisticsTransactionsContentState.error(message: '加载失败：$error');
  }
  final transactionValues = transactions.value;
  if (transactionValues == null) {
    return const StatisticsTransactionsContentState.loading();
  }
  return StatisticsTransactionsContentState.loaded(
    groups: groupTransactionsByDay(items: transactionValues),
  );
}

class StatisticsControlState {
  const StatisticsControlState({
    required this.visibleMonth,
    required this.section,
    required this.granularity,
    required this.mode,
    required this.periodFrom,
    required this.periodUntil,
    required this.chartMetric,
    required this.chartForm,
    required this.categoryKind,
    required this.categoryLevel,
  });

  final DateTime visibleMonth;
  final StatisticsSection section;
  final StatisticsPeriodGranularity granularity;
  final StatisticsPeriodMode mode;

  /// 统计区间 [periodFrom, periodUntil)，periodUntil 为开区间端点。
  final DateTime periodFrom;
  final DateTime periodUntil;
  final CashflowChartMetric chartMetric;
  final CashflowChartForm chartForm;
  final StatisticsCategoryKind categoryKind;
  final StatisticsCategoryLevel categoryLevel;

  int get _spanDays => periodUntil.difference(periodFrom).inDays;

  StatisticsTimeGrouping get trendGrouping => switch (_spanDays) {
    <= 45 => StatisticsTimeGrouping.day,
    <= 180 => StatisticsTimeGrouping.week,
    <= 730 => StatisticsTimeGrouping.month,
    _ => StatisticsTimeGrouping.year,
  };

  String get periodLabel {
    final last = periodUntil.subtract(const Duration(days: 1));
    return '${periodFrom.year}.${periodFrom.month}.${periodFrom.day} - '
        '${last.year}.${last.month}.${last.day}';
  }

  StatisticsDateRange range(DateTime now) {
    return StatisticsDateRange(
      from: periodFrom,
      until: _validUntil(periodFrom, _capAtTomorrow(periodUntil, now)),
      balancePointIntervalDays: switch (_spanDays) {
        <= 45 => 1,
        <= 180 => 7,
        <= 730 => 1,
        _ => 30,
      },
    );
  }

  static DateTime _capAtTomorrow(DateTime end, DateTime now) {
    final tomorrow = DateTime(now.year, now.month, now.day + 1);
    return end.isAfter(tomorrow) ? tomorrow : end;
  }

  static DateTime _validUntil(DateTime start, DateTime until) {
    return until.isAfter(start) ? until : start.add(const Duration(days: 1));
  }

  StatisticsControlState copyWith({
    DateTime? visibleMonth,
    StatisticsSection? section,
    StatisticsPeriodGranularity? granularity,
    StatisticsPeriodMode? mode,
    DateTime? periodFrom,
    DateTime? periodUntil,
    CashflowChartMetric? chartMetric,
    CashflowChartForm? chartForm,
    StatisticsCategoryKind? categoryKind,
    StatisticsCategoryLevel? categoryLevel,
  }) {
    return StatisticsControlState(
      visibleMonth: visibleMonth ?? this.visibleMonth,
      section: section ?? this.section,
      granularity: granularity ?? this.granularity,
      mode: mode ?? this.mode,
      periodFrom: periodFrom ?? this.periodFrom,
      periodUntil: periodUntil ?? this.periodUntil,
      chartMetric: chartMetric ?? this.chartMetric,
      chartForm: chartForm ?? this.chartForm,
      categoryKind: categoryKind ?? this.categoryKind,
      categoryLevel: categoryLevel ?? this.categoryLevel,
    );
  }
}

class StatisticsPageState {
  const StatisticsPageState({
    required this.visibleMonth,
    required this.section,
    required this.content,
    required this.control,
    required this.periodLabel,
    required this.lastSelectableDate,
  });

  final DateTime visibleMonth;
  final StatisticsSection section;
  final StatisticsContentState content;
  final StatisticsControlState control;
  final String periodLabel;
  final DateTime lastSelectableDate;
}

class StatisticsDateRange {
  const StatisticsDateRange({
    required this.from,
    required this.until,
    required this.balancePointIntervalDays,
  });

  final DateTime from;
  final DateTime until;
  final int balancePointIntervalDays;
}

sealed class StatisticsContentState {
  const StatisticsContentState();

  const factory StatisticsContentState.loading() = StatisticsContentLoading;

  const factory StatisticsContentState.error({required String message}) =
      StatisticsContentError;

  const factory StatisticsContentState.loaded({
    required StatisticsPresentation presentation,
  }) = StatisticsContentLoaded;
}

final class StatisticsContentLoading extends StatisticsContentState {
  const StatisticsContentLoading();
}

final class StatisticsContentError extends StatisticsContentState {
  const StatisticsContentError({required this.message});

  final String message;
}

final class StatisticsContentLoaded extends StatisticsContentState {
  const StatisticsContentLoaded({required this.presentation});

  final StatisticsPresentation presentation;
}

sealed class StatisticsTransactionsContentState {
  const StatisticsTransactionsContentState();

  const factory StatisticsTransactionsContentState.loading() =
      StatisticsTransactionsContentLoading;

  const factory StatisticsTransactionsContentState.error({
    required String message,
  }) = StatisticsTransactionsContentError;

  const factory StatisticsTransactionsContentState.loaded({
    required List<TransactionDayGroup> groups,
  }) = StatisticsTransactionsContentLoaded;
}

final class StatisticsTransactionsContentLoading
    extends StatisticsTransactionsContentState {
  const StatisticsTransactionsContentLoading();
}

final class StatisticsTransactionsContentError
    extends StatisticsTransactionsContentState {
  const StatisticsTransactionsContentError({required this.message});

  final String message;
}

final class StatisticsTransactionsContentLoaded
    extends StatisticsTransactionsContentState {
  const StatisticsTransactionsContentLoaded({required this.groups});

  final List<TransactionDayGroup> groups;
}
