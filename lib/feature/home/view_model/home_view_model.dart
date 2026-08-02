import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../../app/provider.dart';
import '../../../application/ledger/ledger_query_api.dart';
import '../../../core/time/month_key.dart';
import 'package:smartflow/feature/shared/presentation/account_lookup.dart';
import 'package:smartflow/feature/shared/presentation/transaction_list_presentation.dart';
import '../../shared/provider/current_date_time_provider.dart';
import '../../shared/provider/ledger_query_providers.dart';

part 'home_view_model.g.dart';

const homeTransactionPageSize = 50;

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
          limit: homeTransactionPageSize,
        ),
      );
}

@riverpod
class HomeTransactionFeedViewModel extends _$HomeTransactionFeedViewModel {
  var _requestGeneration = 0;
  var _refreshRequested = false;

  @override
  HomeTransactionFeedState build(DateTime visibleMonth) {
    final provider = homeTransactionsProvider(visibleMonth);
    final transactions = ref.read(provider);
    ref.listen(provider, (_, next) => _applyFirstPage(next));
    return switch (transactions) {
      AsyncData(:final value) => HomeTransactionFeedState.loaded(
        items: value,
        hasMore: value.length == homeTransactionPageSize,
      ),
      AsyncError() => const HomeTransactionFeedState.error(
        message: '加载失败，请稍后重试',
      ),
      AsyncLoading() => const HomeTransactionFeedState.loading(),
    };
  }

  void _applyFirstPage(AsyncValue<List<TransactionListReadModel>> next) {
    final current = state;
    switch (next) {
      case AsyncData(:final value):
        _applyFirstPageData(current, value);
      case AsyncError():
        _applyFirstPageError(current);
      case AsyncLoading():
        _applyFirstPageLoading(current);
    }
  }

  void _applyFirstPageData(
    HomeTransactionFeedState current,
    List<TransactionListReadModel> items,
  ) {
    if (_refreshRequested ||
        current is! HomeTransactionFeedLoaded ||
        current.items.length <= homeTransactionPageSize) {
      _refreshRequested = false;
      _requestGeneration += 1;
      state = HomeTransactionFeedState.loaded(
        items: items,
        hasMore: items.length == homeTransactionPageSize,
      );
      return;
    }
    _requestGeneration += 1;
    state = current.copyWith(hasPendingRefresh: true, isLoadingMore: false);
  }

  void _applyFirstPageError(HomeTransactionFeedState current) {
    if (current is! HomeTransactionFeedLoaded) {
      state = const HomeTransactionFeedState.error(message: '加载失败，请稍后重试');
      return;
    }
    if (_refreshRequested) {
      _refreshRequested = false;
      state = current.copyWith(
        hasPendingRefresh: true,
        isRefreshing: false,
        refreshErrorMessage: '刷新交易失败，请重试',
      );
    }
  }

  void _applyFirstPageLoading(HomeTransactionFeedState current) {
    if (current is! HomeTransactionFeedLoaded) {
      state = const HomeTransactionFeedState.loading();
    }
  }

  Future<void> loadMore() async {
    final current = state;
    if (current is! HomeTransactionFeedLoaded ||
        !current.hasMore ||
        current.isLoadingMore) {
      return;
    }
    final cursorItem = current.items.last;
    final requestGeneration = _requestGeneration;
    state = current.copyWith(isLoadingMore: true);
    try {
      final month = MonthKey(
        year: visibleMonth.year,
        month: visibleMonth.month,
      );
      final nextPage = await ref
          .read(transactionQueryServiceProvider)
          .findTransactions(
            TransactionListQuery(
              topLevelOnly: true,
              occurredFrom: month.start,
              occurredUntil: month.nextMonthStart,
              limit: homeTransactionPageSize,
              before: TransactionListCursor(
                occurredAt: cursorItem.occurredAt,
                id: cursorItem.id,
              ),
            ),
          );
      if (!ref.mounted || requestGeneration != _requestGeneration) return;
      state = current.copyWith(
        items: [...current.items, ...nextPage],
        hasMore: nextPage.length == homeTransactionPageSize,
        isLoadingMore: false,
      );
    } catch (_) {
      if (!ref.mounted || requestGeneration != _requestGeneration) return;
      state = current.copyWith(
        isLoadingMore: false,
        loadMoreErrorMessage: '加载更多交易失败，请重试',
      );
    }
  }

  void refresh() {
    final current = state;
    if (current is! HomeTransactionFeedLoaded || current.isRefreshing) return;
    _requestGeneration += 1;
    _refreshRequested = true;
    state = current.copyWith(hasPendingRefresh: false, isRefreshing: true);
    ref.invalidate(homeTransactionsProvider(visibleMonth));
  }
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
  final transactions = ref.watch(
    homeTransactionFeedViewModelProvider(visibleMonth),
  );
  final comparison = ref.watch(homeCashflowComparisonProvider(visibleMonth));
  final dailySummaries = ref.watch(
    homeDailyCashflowSummariesProvider(visibleMonth),
  );
  final accountsById = ref.watch(accountsByIdProvider);

  if (comparison case AsyncError(:final error)) {
    return HomeContentState.error(message: '加载失败：$error');
  }
  if (dailySummaries case AsyncError(:final error)) {
    return HomeContentState.error(message: '加载失败：$error');
  }
  if (accountsById case AsyncError(:final error)) {
    return HomeContentState.error(message: '加载失败：$error');
  }

  final comparisonValue = comparison.value;
  final dailySummaryValues = dailySummaries.value;
  final accountValues = accountsById.value;
  if (comparisonValue == null ||
      dailySummaryValues == null ||
      accountValues == null) {
    return const HomeContentState.loading();
  }

  if (transactions case HomeTransactionFeedError(:final message)) {
    return HomeContentState.error(message: message);
  }
  if (transactions is HomeTransactionFeedLoading) {
    return const HomeContentState.loading();
  }
  final transactionValues = transactions as HomeTransactionFeedLoaded;

  return HomeContentState.loaded(
    summary: buildMonthlySummaryPresentation(comparisonValue),
    groups: groupTransactionsByDay(
      items: transactionValues.items,
      accountLookup: AccountLookup(accountValues),
      dailySummaries: dailySummaryValues,
    ),
    hasMore: transactionValues.hasMore,
    isLoadingMore: transactionValues.isLoadingMore,
    loadMoreErrorMessage: transactionValues.loadMoreErrorMessage,
    hasPendingRefresh: transactionValues.hasPendingRefresh,
    isRefreshing: transactionValues.isRefreshing,
    refreshErrorMessage: transactionValues.refreshErrorMessage,
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
    required CashflowSummaryPresentation summary,
    required List<TransactionDayGroup> groups,
    required bool hasMore,
    required bool isLoadingMore,
    String? loadMoreErrorMessage,
    required bool hasPendingRefresh,
    required bool isRefreshing,
    String? refreshErrorMessage,
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
  const HomeContentLoaded({
    required this.summary,
    required this.groups,
    required this.hasMore,
    required this.isLoadingMore,
    this.loadMoreErrorMessage,
    required this.hasPendingRefresh,
    required this.isRefreshing,
    this.refreshErrorMessage,
  });

  final CashflowSummaryPresentation summary;
  final List<TransactionDayGroup> groups;
  final bool hasMore;
  final bool isLoadingMore;
  final String? loadMoreErrorMessage;
  final bool hasPendingRefresh;
  final bool isRefreshing;
  final String? refreshErrorMessage;
}

sealed class HomeTransactionFeedState {
  const HomeTransactionFeedState();

  const factory HomeTransactionFeedState.loading() = HomeTransactionFeedLoading;

  const factory HomeTransactionFeedState.error({required String message}) =
      HomeTransactionFeedError;

  const factory HomeTransactionFeedState.loaded({
    required List<TransactionListReadModel> items,
    required bool hasMore,
    bool isLoadingMore,
    String? loadMoreErrorMessage,
    bool hasPendingRefresh,
    bool isRefreshing,
    String? refreshErrorMessage,
  }) = HomeTransactionFeedLoaded;
}

final class HomeTransactionFeedLoading extends HomeTransactionFeedState {
  const HomeTransactionFeedLoading();
}

final class HomeTransactionFeedError extends HomeTransactionFeedState {
  const HomeTransactionFeedError({required this.message});

  final String message;
}

final class HomeTransactionFeedLoaded extends HomeTransactionFeedState {
  const HomeTransactionFeedLoaded({
    required this.items,
    required this.hasMore,
    this.isLoadingMore = false,
    this.loadMoreErrorMessage,
    this.hasPendingRefresh = false,
    this.isRefreshing = false,
    this.refreshErrorMessage,
  });

  final List<TransactionListReadModel> items;
  final bool hasMore;
  final bool isLoadingMore;
  final String? loadMoreErrorMessage;
  final bool hasPendingRefresh;
  final bool isRefreshing;
  final String? refreshErrorMessage;

  HomeTransactionFeedLoaded copyWith({
    List<TransactionListReadModel>? items,
    bool? hasMore,
    bool? isLoadingMore,
    String? loadMoreErrorMessage,
    bool? hasPendingRefresh,
    bool? isRefreshing,
    String? refreshErrorMessage,
  }) {
    return HomeTransactionFeedLoaded(
      items: items ?? this.items,
      hasMore: hasMore ?? this.hasMore,
      isLoadingMore: isLoadingMore ?? this.isLoadingMore,
      loadMoreErrorMessage: loadMoreErrorMessage,
      hasPendingRefresh: hasPendingRefresh ?? this.hasPendingRefresh,
      isRefreshing: isRefreshing ?? this.isRefreshing,
      refreshErrorMessage: refreshErrorMessage,
    );
  }
}
