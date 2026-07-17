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

enum StatisticsDrilldownScope { cashflow, balance }

@riverpod
class StatisticsViewModel extends _$StatisticsViewModel {
  @override
  StatisticsControlState build() {
    final now = ref.watch(currentDateTimeProvider);
    return StatisticsControlState(
      visibleMonth: DateTime(now.year, now.month),
      section: StatisticsSection.cashflow,
    );
  }

  void pickMonth(DateTime month) {
    state = state.copyWith(visibleMonth: DateTime(month.year, month.month));
  }

  void shiftMonth(int delta) {
    final month = state.visibleMonth;
    state = state.copyWith(
      visibleMonth: DateTime(month.year, month.month + delta),
    );
  }

  void selectSection(StatisticsSection section) {
    state = state.copyWith(section: section);
  }
}

@riverpod
StatisticsPageState statisticsPage(Ref ref) {
  final control = ref.watch(statisticsViewModelProvider);
  return StatisticsPageState(
    visibleMonth: control.visibleMonth,
    section: control.section,
    content: ref.watch(statisticsContentProvider(control.visibleMonth)),
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
  });

  final DateTime visibleMonth;
  final StatisticsSection section;

  StatisticsControlState copyWith({
    DateTime? visibleMonth,
    StatisticsSection? section,
  }) {
    return StatisticsControlState(
      visibleMonth: visibleMonth ?? this.visibleMonth,
      section: section ?? this.section,
    );
  }
}

class StatisticsPageState {
  const StatisticsPageState({
    required this.visibleMonth,
    required this.section,
    required this.content,
  });

  final DateTime visibleMonth;
  final StatisticsSection section;
  final StatisticsContentState content;
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
