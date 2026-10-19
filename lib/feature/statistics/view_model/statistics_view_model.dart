import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../../app/provider.dart';
import '../../../application/ledger/ledger_query_api.dart';
import '../../shared/provider/current_date_time_provider.dart';
import '../../shared/provider/ledger_query_providers.dart';
import 'package:smartflow/feature/shared/presentation/transaction_list_presentation.dart';
import '../presentation/statistics_period_presentation.dart';
import '../presentation/statistics_presentation.dart';

part 'statistics_view_model.g.dart';

/// 统计页可切换的页面级视图。新增视图时需同步提供对应 View 与页面壳分支。
enum StatisticsViewType {
  period('期间分析'),
  state('当前状态');

  const StatisticsViewType(this.label);

  final String label;
}

enum StatisticsPeriodGranularity { year, month, date }

enum StatisticsPeriodMode { single, range }

enum StatisticsComparisonMode { previousPeriod, previousYear, none }

enum CashflowChartForm { bar, line }

enum StatisticsCategoryKind { expense, income }

enum StatisticsDrilldownScope { cashflow, balance }

enum StatisticsComparisonMetric { expense, income }

@riverpod
class StatisticsViewModel extends _$StatisticsViewModel {
  @override
  StatisticsControlState build() {
    final now = ref.watch(currentDateTimeProvider);
    return StatisticsControlState(
      viewType: StatisticsViewType.period,
      granularity: StatisticsPeriodGranularity.month,
      mode: StatisticsPeriodMode.single,
      periodFrom: DateTime(now.year, now.month),
      periodUntil: DateTime(now.year, now.month + 1),
      comparisonMode: StatisticsComparisonMode.previousPeriod,
      chartForm: CashflowChartForm.bar,
      comparisonMetric: StatisticsComparisonMetric.expense,
      categoryKind: StatisticsCategoryKind.expense,
      categoryLevel: StatisticsCategoryLevel.primary,
    );
  }

  void selectView(StatisticsViewType view) {
    state = state.copyWith(viewType: view);
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
    );
  }

  void selectChartForm(CashflowChartForm form) =>
      state = state.copyWith(chartForm: form);

  void selectComparisonMode(StatisticsComparisonMode mode) =>
      state = state.copyWith(comparisonMode: mode);

  void selectComparisonMetric(StatisticsComparisonMetric metric) =>
      state = state.copyWith(comparisonMetric: metric);

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
  final asOfDate = DateTime(now.year, now.month, now.day);
  return StatisticsPageState(
    control: control,
    periodLabel: formatStatisticsRangeLabel(range.from, range.until),
    asOfDate: asOfDate,
    lastSelectableDate: now,
    content: control.viewType == StatisticsViewType.period
        ? ref.watch(
            statisticsRangeContentProvider(
              range.from,
              range.until,
              range.balancePointIntervalDays,
            ),
          )
        : const StatisticsContentState.loading(),
  );
}

@riverpod
Stream<StatisticsRangeReport> statisticsRangeReport(
  Ref ref,
  DateTime from,
  DateTime until,
  int balancePointIntervalDays,
  DateTime? comparisonFrom,
  DateTime? comparisonUntil,
) {
  return ref
      .watch(financialMetricsServiceProvider)
      .watchStatisticsRangeReport(
        StatisticsRangeReportQuery(
          from: from,
          until: until,
          balancePointIntervalDays: balancePointIntervalDays,
          comparisonFrom: comparisonFrom,
          comparisonUntil: comparisonUntil,
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
  final control = ref.watch(statisticsViewModelProvider);
  final now = ref.watch(currentDateTimeProvider);
  final comparison = control.comparisonRange(now);
  final report = ref.watch(
    statisticsRangeReportProvider(
      from,
      until,
      balancePointIntervalDays,
      comparison?.from,
      comparison?.until,
    ),
  );
  if (report case AsyncError()) {
    return const StatisticsContentState.error(message: '加载失败，请稍后重试。');
  }
  final reportValue = report.value;
  if (reportValue == null) {
    return const StatisticsContentState.loading();
  }
  final cashflow = buildStatisticsCashflowTrend(reportValue);
  return StatisticsContentState.loaded(
    overview: buildStatisticsOverview(
      reportValue,
      dailySummaries: cashflow.dailySummaries,
    ),
    comparison: buildStatisticsComparison(
      reportValue,
      label: comparison?.label,
    ),
    cashflow: cashflow,
    categories: buildStatisticsCategoryAnalysis(
      reportValue,
      comparisonLabel: comparison?.label,
    ),
    tags: buildStatisticsTagAnalysis(
      reportValue,
      comparisonLabel: comparison?.label,
    ),
    balance: buildStatisticsBalanceTrend(reportValue),
  );
}

@riverpod
Stream<List<TransactionReadModel>> statisticsTransactions(
  Ref ref, {
  required CategorySelection? category,
  required String? settlementAccountId,
  required String? tagId,
  required bool untaggedOnly,
  required DateTime? occurredFrom,
  required DateTime occurredUntil,
  required StatisticsDrilldownScope scope,
  AccountType? accountType,
}) async* {
  final accountLookup = await ref.watch(accountLookupProvider.future);
  final categoryAccountIds = category == null
      ? scope == StatisticsDrilldownScope.cashflow
            ? accountLookup.byId.values
                  .where(
                    (account) => accountType == null
                        ? account.type == AccountType.income ||
                              account.type == AccountType.expense
                        : account.type == accountType,
                  )
                  .map((account) => account.id)
                  .toSet()
            : null
      : resolveCategoryAccountIds([category], accountLookup.byId);
  yield* ref
      .watch(transactionQueryServiceProvider)
      .watchTransactions(
        TransactionListQuery(
          match: TransactionImpactMatch(
            categoryAccountIds: categoryAccountIds,
            settlementAccountIds: settlementAccountId == null
                ? null
                : {settlementAccountId},
          ),
          tagIds: tagId == null ? null : {tagId},
          untaggedOnly: untaggedOnly,
          occurredFrom: occurredFrom,
          occurredUntil: occurredUntil,
          topLevelOnly: false,
          scope: scope == StatisticsDrilldownScope.cashflow
              ? TransactionScopeFilter.stats
              : TransactionScopeFilter.assetLiability,
          limit: null,
        ),
      );
}

@riverpod
StatisticsTransactionsContentState statisticsTransactionsContent(
  Ref ref, {
  required CategorySelection? category,
  required String? settlementAccountId,
  required String? tagId,
  required bool untaggedOnly,
  required DateTime? occurredFrom,
  required DateTime occurredUntil,
  required StatisticsDrilldownScope scope,
  AccountType? accountType,
}) {
  final transactions = ref.watch(
    statisticsTransactionsProvider(
      category: category,
      settlementAccountId: settlementAccountId,
      tagId: tagId,
      untaggedOnly: untaggedOnly,
      occurredFrom: occurredFrom,
      occurredUntil: occurredUntil,
      scope: scope,
      accountType: accountType,
    ),
  );
  final accountLookup = ref.watch(accountLookupProvider);
  if (transactions case AsyncError()) {
    return const StatisticsTransactionsContentState.error(
      message: '加载失败，请稍后重试。',
    );
  }
  if (accountLookup case AsyncError()) {
    return const StatisticsTransactionsContentState.error(
      message: '加载失败，请稍后重试。',
    );
  }
  final transactionValues = transactions.value;
  final lookup = accountLookup.value;
  if (transactionValues == null || lookup == null) {
    return const StatisticsTransactionsContentState.loading();
  }
  final cashflowAccountIds = lookup.byId.values
      .where(
        (account) => accountType == null
            ? account.type == AccountType.income ||
                  account.type == AccountType.expense
            : account.type == accountType,
      )
      .map((account) => account.id)
      .toSet();
  final amountSource = scope == StatisticsDrilldownScope.cashflow
      ? TransactionCashflowImpactAmountSource(
          category != null
              ? resolveCategoryAccountIds([category], lookup.byId)
              : cashflowAccountIds,
        )
      : category != null
      ? TransactionCategoryImpactAmountSource(
          resolveCategoryAccountIds([category], lookup.byId),
        )
      : settlementAccountId != null
      ? TransactionAccountImpactAmountSource(settlementAccountId)
      : const TransactionGroupAmountSource();
  return StatisticsTransactionsContentState.loaded(
    groups: groupTransactionsByDay(
      items: transactionValues,
      accountLookup: lookup,
      amountSource: amountSource,
    ),
  );
}

class StatisticsControlState {
  const StatisticsControlState({
    required this.viewType,
    required this.granularity,
    required this.mode,
    required this.periodFrom,
    required this.periodUntil,
    required this.comparisonMode,
    required this.chartForm,
    required this.comparisonMetric,
    required this.categoryKind,
    required this.categoryLevel,
  });

  final StatisticsViewType viewType;
  final StatisticsPeriodGranularity granularity;
  final StatisticsPeriodMode mode;

  /// 统计区间 [periodFrom, periodUntil)，periodUntil 为开区间端点。
  final DateTime periodFrom;
  final DateTime periodUntil;
  final StatisticsComparisonMode comparisonMode;
  final CashflowChartForm chartForm;
  final StatisticsComparisonMetric comparisonMetric;
  final StatisticsCategoryKind categoryKind;
  final StatisticsCategoryLevel categoryLevel;

  StatisticsDateRange range(DateTime now) {
    return StatisticsDateRange(
      from: periodFrom,
      until: _validUntil(periodFrom, _capAtTomorrow(periodUntil, now)),
      // 保留日级快照，由展示层根据实际绘图区宽度决定聚合粒度。
      balancePointIntervalDays: 1,
    );
  }

  StatisticsComparisonRange? comparisonRange(DateTime now) {
    return comparisonRangeFor(comparisonMode, now);
  }

  StatisticsComparisonRange? comparisonRangeFor(
    StatisticsComparisonMode comparisonSelection,
    DateTime now,
  ) {
    if (comparisonSelection == StatisticsComparisonMode.none) return null;
    final currentFrom = periodFrom;
    final currentUntil = _validUntil(
      periodFrom,
      _capAtTomorrow(periodUntil, now),
    );

    if (comparisonSelection == StatisticsComparisonMode.previousYear) {
      return StatisticsComparisonRange(
        from: _shiftYear(currentFrom),
        until: _shiftYear(currentUntil),
        label: '同比',
      );
    }

    if (mode == StatisticsPeriodMode.range ||
        granularity == StatisticsPeriodGranularity.date) {
      final duration = currentUntil.difference(currentFrom);
      return StatisticsComparisonRange(
        from: currentFrom.subtract(duration),
        until: currentFrom,
        label: '环比',
      );
    }

    if (granularity == StatisticsPeriodGranularity.month) {
      final previousStart = DateTime(currentFrom.year, currentFrom.month - 1);
      if (currentUntil.isBefore(periodUntil)) {
        final previousEnd = DateTime(currentFrom.year, currentFrom.month);
        final candidate = previousStart.add(
          currentUntil.difference(currentFrom),
        );
        return StatisticsComparisonRange(
          from: previousStart,
          until: candidate.isAfter(previousEnd) ? previousEnd : candidate,
          label: '环比',
        );
      }
      return StatisticsComparisonRange(
        from: previousStart,
        until: currentFrom,
        label: '环比',
      );
    }

    if (granularity == StatisticsPeriodGranularity.year) {
      return StatisticsComparisonRange(
        from: _shiftYear(currentFrom),
        until: _shiftYear(currentUntil),
        label: '同比',
      );
    }
    return null;
  }

  static DateTime _shiftYear(DateTime value) {
    final targetYear = value.year - 1;
    final lastDay = DateTime(targetYear, value.month + 1, 0).day;
    return DateTime(
      targetYear,
      value.month,
      value.day > lastDay ? lastDay : value.day,
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
    StatisticsViewType? viewType,
    StatisticsPeriodGranularity? granularity,
    StatisticsPeriodMode? mode,
    DateTime? periodFrom,
    DateTime? periodUntil,
    StatisticsComparisonMode? comparisonMode,
    CashflowChartForm? chartForm,
    StatisticsComparisonMetric? comparisonMetric,
    StatisticsCategoryKind? categoryKind,
    StatisticsCategoryLevel? categoryLevel,
  }) {
    return StatisticsControlState(
      viewType: viewType ?? this.viewType,
      granularity: granularity ?? this.granularity,
      mode: mode ?? this.mode,
      periodFrom: periodFrom ?? this.periodFrom,
      periodUntil: periodUntil ?? this.periodUntil,
      comparisonMode: comparisonMode ?? this.comparisonMode,
      chartForm: chartForm ?? this.chartForm,
      comparisonMetric: comparisonMetric ?? this.comparisonMetric,
      categoryKind: categoryKind ?? this.categoryKind,
      categoryLevel: categoryLevel ?? this.categoryLevel,
    );
  }
}

class StatisticsPageState {
  const StatisticsPageState({
    required this.content,
    required this.control,
    required this.periodLabel,
    required this.asOfDate,
    required this.lastSelectableDate,
  });

  final StatisticsContentState content;
  final StatisticsControlState control;
  final String periodLabel;
  final DateTime asOfDate;
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

class StatisticsComparisonRange {
  const StatisticsComparisonRange({
    required this.from,
    required this.until,
    required this.label,
  });

  final DateTime from;
  final DateTime until;
  final String label;
}

sealed class StatisticsContentState {
  const StatisticsContentState();

  const factory StatisticsContentState.loading() = StatisticsContentLoading;

  const factory StatisticsContentState.error({required String message}) =
      StatisticsContentError;

  const factory StatisticsContentState.loaded({
    required StatisticsOverviewPresentation overview,
    required StatisticsComparisonPresentation? comparison,
    required StatisticsCashflowTrendPresentation cashflow,
    required StatisticsCategoryAnalysisPresentation categories,
    required StatisticsTagAnalysisPresentation tags,
    required StatisticsBalanceTrendPresentation balance,
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
  const StatisticsContentLoaded({
    required this.overview,
    required this.comparison,
    required this.cashflow,
    required this.categories,
    required this.tags,
    required this.balance,
  });

  final StatisticsOverviewPresentation overview;
  final StatisticsComparisonPresentation? comparison;
  final StatisticsCashflowTrendPresentation cashflow;
  final StatisticsCategoryAnalysisPresentation categories;
  final StatisticsTagAnalysisPresentation tags;
  final StatisticsBalanceTrendPresentation balance;
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
