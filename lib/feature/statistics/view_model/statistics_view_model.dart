import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../../app/provider.dart';
import '../../../application/ledger/ledger_query_api.dart';
import '../../../core/time/month_key.dart';
import '../../shared/provider/current_date_time_provider.dart';
import '../../shared/provider/ledger_query_providers.dart';
import 'package:smartflow/feature/shared/presentation/account_lookup.dart';
import 'package:smartflow/feature/shared/presentation/transaction_list_presentation.dart';
import '../presentation/statistics_presentation.dart';

part 'statistics_view_model.g.dart';

enum StatisticsSection { cashflow, balance }

enum StatisticsPeriodKind { month, year, custom }

enum CashflowChartMetric { expense, income, net, compare, cumulative }

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
      periodKind: StatisticsPeriodKind.month,
      customFrom: DateTime(
        now.year,
        now.month,
        now.day,
      ).subtract(const Duration(days: 30)),
      customUntil: DateTime(now.year, now.month, now.day + 1),
      chartMetric: CashflowChartMetric.expense,
      categoryKind: StatisticsCategoryKind.expense,
      categoryLevel: StatisticsCategoryLevel.primary,
      valueMode: StatisticsValueMode.amount,
    );
  }

  void pickMonth(DateTime month) {
    state = state.copyWith(visibleMonth: DateTime(month.year, month.month));
  }

  void selectSection(StatisticsSection section) {
    state = state.copyWith(section: section);
  }

  void selectPeriodKind(StatisticsPeriodKind kind) {
    state = state.copyWith(periodKind: kind);
  }

  void selectCustomRange(DateTime from, DateTime untilInclusive) {
    state = state.copyWith(
      periodKind: StatisticsPeriodKind.custom,
      customFrom: DateTime(from.year, from.month, from.day),
      customUntil: DateTime(
        untilInclusive.year,
        untilInclusive.month,
        untilInclusive.day + 1,
      ),
    );
  }

  void selectChartMetric(CashflowChartMetric metric) =>
      state = state.copyWith(chartMetric: metric);

  void selectCategoryKind(StatisticsCategoryKind kind) =>
      state = state.copyWith(categoryKind: kind);

  void selectCategoryLevel(StatisticsCategoryLevel level) =>
      state = state.copyWith(categoryLevel: level);

  void selectValueMode(StatisticsValueMode mode) =>
      state = state.copyWith(valueMode: mode);
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
  final accounts = ref.watch(accountsByIdProvider);
  if (report case AsyncError(:final error)) {
    return StatisticsContentState.error(message: '加载失败：$error');
  }
  if (accounts case AsyncError(:final error)) {
    return StatisticsContentState.error(message: '加载失败：$error');
  }
  if (report.value == null || accounts.value == null) {
    return const StatisticsContentState.loading();
  }
  return StatisticsContentState.loaded(
    presentation: buildRangeStatisticsPresentation(
      report: report.value!,
      accountsById: accounts.value!,
    ),
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
  required String accountIdsKey,
  required DateTime? occurredFrom,
  required DateTime occurredUntil,
  required StatisticsDrilldownScope scope,
}) {
  final accountIds =
      accountIdsKey.split(',').where((id) => id.isNotEmpty).toSet();
  return ref
      .watch(transactionQueryServiceProvider)
      .watchTransactions(
        TransactionListQuery(
          accountIds: accountIds,
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
  required String accountIdsKey,
  required DateTime? occurredFrom,
  required DateTime occurredUntil,
  required StatisticsDrilldownScope scope,
}) {
  final transactions = ref.watch(
    statisticsTransactionsProvider(
      accountIdsKey: accountIdsKey,
      occurredFrom: occurredFrom,
      occurredUntil: occurredUntil,
      scope: scope,
    ),
  );
  final accounts = ref.watch(accountsByIdProvider);
  if (transactions case AsyncError(:final error)) {
    return StatisticsTransactionsContentState.error(message: '加载失败：$error');
  }
  if (accounts case AsyncError(:final error)) {
    return StatisticsTransactionsContentState.error(message: '加载失败：$error');
  }
  final transactionValues = transactions.value;
  final accountValues = accounts.value;
  if (transactionValues == null || accountValues == null) {
    return const StatisticsTransactionsContentState.loading();
  }
  return StatisticsTransactionsContentState.loaded(
    groups: groupTransactionsByDay(
      items: transactionValues,
      accountLookup: AccountLookup(accountValues),
    ),
  );
}

class StatisticsControlState {
  const StatisticsControlState({
    required this.visibleMonth,
    required this.section,
    required this.periodKind,
    required this.customFrom,
    required this.customUntil,
    required this.chartMetric,
    required this.categoryKind,
    required this.categoryLevel,
    required this.valueMode,
  });

  final DateTime visibleMonth;
  final StatisticsSection section;
  final StatisticsPeriodKind periodKind;
  final DateTime customFrom;
  final DateTime customUntil;
  final CashflowChartMetric chartMetric;
  final StatisticsCategoryKind categoryKind;
  final StatisticsCategoryLevel categoryLevel;
  final StatisticsValueMode valueMode;

  StatisticsTimeGrouping get trendGrouping => switch (periodKind) {
    StatisticsPeriodKind.month => StatisticsTimeGrouping.day,
    StatisticsPeriodKind.year => StatisticsTimeGrouping.month,
    StatisticsPeriodKind.custom => switch (customUntil
        .difference(customFrom)
        .inDays) {
      <= 45 => StatisticsTimeGrouping.day,
      <= 180 => StatisticsTimeGrouping.week,
      <= 730 => StatisticsTimeGrouping.month,
      _ => StatisticsTimeGrouping.year,
    },
  };

  String get periodLabel => switch (periodKind) {
    StatisticsPeriodKind.month => '${visibleMonth.year}年${visibleMonth.month}月',
    StatisticsPeriodKind.year => '${visibleMonth.year}年',
    StatisticsPeriodKind.custom =>
      '${customFrom.year}.${customFrom.month}.${customFrom.day} - '
          '${customUntil.subtract(const Duration(days: 1)).year}.'
          '${customUntil.subtract(const Duration(days: 1)).month}.'
          '${customUntil.subtract(const Duration(days: 1)).day}',
  };

  StatisticsDateRange range(DateTime now) {
    switch (periodKind) {
      case StatisticsPeriodKind.month:
        final start = DateTime(visibleMonth.year, visibleMonth.month);
        final end = DateTime(visibleMonth.year, visibleMonth.month + 1);
        return StatisticsDateRange(
          from: start,
          until: _validUntil(start, _capAtTomorrow(end, now)),
          balancePointIntervalDays: 1,
        );
      case StatisticsPeriodKind.year:
        final start = DateTime(visibleMonth.year);
        final end = DateTime(visibleMonth.year + 1);
        return StatisticsDateRange(
          from: start,
          until: _validUntil(start, _capAtTomorrow(end, now)),
          balancePointIntervalDays: 1,
        );
      case StatisticsPeriodKind.custom:
        final days = customUntil.difference(customFrom).inDays;
        return StatisticsDateRange(
          from: customFrom,
          until: customUntil,
          balancePointIntervalDays: switch (days) {
            <= 45 => 1,
            <= 180 => 7,
            <= 730 => 1,
            _ => 30,
          },
        );
    }
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
    StatisticsPeriodKind? periodKind,
    DateTime? customFrom,
    DateTime? customUntil,
    CashflowChartMetric? chartMetric,
    StatisticsCategoryKind? categoryKind,
    StatisticsCategoryLevel? categoryLevel,
    StatisticsValueMode? valueMode,
  }) {
    return StatisticsControlState(
      visibleMonth: visibleMonth ?? this.visibleMonth,
      section: section ?? this.section,
      periodKind: periodKind ?? this.periodKind,
      customFrom: customFrom ?? this.customFrom,
      customUntil: customUntil ?? this.customUntil,
      chartMetric: chartMetric ?? this.chartMetric,
      categoryKind: categoryKind ?? this.categoryKind,
      categoryLevel: categoryLevel ?? this.categoryLevel,
      valueMode: valueMode ?? this.valueMode,
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
