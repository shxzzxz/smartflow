import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../../app/provider.dart';
import '../../../application/ledger/ledger_query_api.dart';
import '../../../core/time/month_key.dart';
import '../../../widget/business/account_lookup.dart';
import '../../../widget/business/transaction_list_presentation.dart';
import '../../shared/provider/current_date_time_provider.dart';
import '../../shared/provider/ledger_query_providers.dart';

part 'home_view_model.g.dart';

@riverpod
class HomeViewModel extends _$HomeViewModel {
  @override
  HomePageState build() {
    final now = ref.watch(currentDateTimeProvider);
    return HomePageState(visibleMonth: DateTime(now.year, now.month));
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
}

@riverpod
Stream<List<TransactionListReadModel>> homeTransactions(
  Ref ref,
  DateTime visibleMonth,
) {
  final month = MonthKey(year: visibleMonth.year, month: visibleMonth.month);
  return ref
      .watch(transactionQueryServiceProvider)
      .watchTransactions(
        TransactionListQuery(
          topLevelOnly: true,
          occurredFrom: month.start,
          occurredUntil: month.nextMonthStart,
        ),
      );
}

@riverpod
Stream<CashflowComparison> homeCashflowComparison(
  Ref ref,
  DateTime visibleMonth,
) {
  final now = ref.watch(currentDateTimeProvider);
  final month = MonthKey(year: visibleMonth.year, month: visibleMonth.month);
  final asOfDate =
      now.year == month.year && now.month == month.month ? now : null;
  return ref
      .watch(financialMetricsServiceProvider)
      .watchCashflowComparison(
        CashflowComparisonQuery(month: month, asOfDate: asOfDate),
      );
}

@riverpod
Stream<List<DailyCashflowSummary>> homeDailyCashflowSummaries(
  Ref ref,
  DateTime visibleMonth,
) {
  final month = MonthKey(year: visibleMonth.year, month: visibleMonth.month);
  return ref
      .watch(financialMetricsServiceProvider)
      .watchDailyCashflowSummaries(DailyCashflowSummaryQuery(month: month));
}

@riverpod
HomeContentState homeContent(Ref ref, DateTime visibleMonth) {
  final transactions = ref.watch(homeTransactionsProvider(visibleMonth));
  final comparison = ref.watch(homeCashflowComparisonProvider(visibleMonth));
  final dailySummaries = ref.watch(
    homeDailyCashflowSummariesProvider(visibleMonth),
  );
  final accountsById = ref.watch(accountsByIdProvider);

  if (transactions case AsyncError(:final error)) {
    return HomeContentState.error(message: '加载失败：$error');
  }
  if (comparison case AsyncError(:final error)) {
    return HomeContentState.error(message: '加载失败：$error');
  }
  if (dailySummaries case AsyncError(:final error)) {
    return HomeContentState.error(message: '加载失败：$error');
  }
  if (accountsById case AsyncError(:final error)) {
    return HomeContentState.error(message: '加载失败：$error');
  }

  final transactionValues = transactions.value;
  final comparisonValue = comparison.value;
  final dailySummaryValues = dailySummaries.value;
  final accountValues = accountsById.value;
  if (transactionValues == null ||
      comparisonValue == null ||
      dailySummaryValues == null ||
      accountValues == null) {
    return const HomeContentState.loading();
  }

  return HomeContentState.loaded(
    summary: buildMonthlySummaryPresentation(comparisonValue),
    groups: groupTransactionsByDay(
      items: transactionValues,
      accountLookup: AccountLookup(accountValues),
      dailySummaries: dailySummaryValues,
    ),
  );
}

class HomePageState {
  const HomePageState({required this.visibleMonth});

  final DateTime visibleMonth;

  HomePageState copyWith({DateTime? visibleMonth}) {
    return HomePageState(visibleMonth: visibleMonth ?? this.visibleMonth);
  }
}

sealed class HomeContentState {
  const HomeContentState();

  const factory HomeContentState.loading() = HomeContentLoading;

  const factory HomeContentState.error({required String message}) =
      HomeContentError;

  const factory HomeContentState.loaded({
    required MonthlySummaryPresentation summary,
    required List<TransactionDayGroup> groups,
  }) = HomeContentLoaded;
}

final class HomeContentLoading extends HomeContentState {
  const HomeContentLoading();
}

final class HomeContentError extends HomeContentState {
  const HomeContentError({required this.message});

  final String message;
}

final class HomeContentLoaded extends HomeContentState {
  const HomeContentLoaded({required this.summary, required this.groups});

  final MonthlySummaryPresentation summary;
  final List<TransactionDayGroup> groups;
}
