import 'dart:async';

import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../../app/provider.dart';
import '../../../application/ledger/ledger_query_api.dart';
import '../../../core/time/month_key.dart';
import '../../../widget/business/transaction_list_presentation.dart';
import '../../shared/provider/current_date_time_provider.dart';

part 'home_view_model.g.dart';

@riverpod
class HomeViewModel extends _$HomeViewModel {
  StreamSubscription<List<TransactionListItem>>? _transactionsSubscription;
  StreamSubscription<CashflowComparison>? _comparisonSubscription;
  StreamSubscription<List<DailyCashflowSummary>>? _dailySubscription;

  int _generation = 0;
  List<TransactionListItem>? _transactions;
  CashflowComparison? _comparison;
  List<DailyCashflowSummary>? _dailySummaries;
  bool _hasError = false;

  @override
  HomePageState build() {
    final now = ref.watch(currentDateTimeProvider);
    final visibleMonth = DateTime(now.year, now.month);
    ref.onDispose(_cancelSubscriptions);
    _watchMonth(visibleMonth, now: now);
    return HomePageState(
      visibleMonth: visibleMonth,
      content: const HomeContentState.loading(),
    );
  }

  void pickMonth(DateTime month) {
    _setVisibleMonth(DateTime(month.year, month.month));
  }

  void shiftMonth(int delta) {
    final month = state.visibleMonth;
    _setVisibleMonth(DateTime(month.year, month.month + delta));
  }

  void _setVisibleMonth(DateTime visibleMonth) {
    state = state.copyWith(
      visibleMonth: visibleMonth,
      content: const HomeContentState.loading(),
    );
    _watchMonth(visibleMonth, now: ref.read(currentDateTimeProvider));
  }

  void _watchMonth(DateTime visibleMonth, {required DateTime now}) {
    final generation = ++_generation;
    _cancelSubscriptions();
    _transactions = null;
    _comparison = null;
    _dailySummaries = null;
    _hasError = false;

    final month = MonthKey(year: visibleMonth.year, month: visibleMonth.month);
    final transactionService = ref.read(transactionQueryServiceProvider);
    final metricsService = ref.read(financialMetricsServiceProvider);
    final asOfDate =
        now.year == month.year && now.month == month.month ? now : null;

    _transactionsSubscription = transactionService
        .watchTransactions(
          TransactionListQuery(
            topLevelOnly: true,
            occurredFrom: month.start,
            occurredUntil: month.nextMonthStart,
          ),
        )
        .listen(
          (value) {
            if (!_isCurrent(generation)) return;
            _transactions = value;
            _publishLoadedIfReady(generation);
          },
          onError: (Object error, StackTrace stackTrace) {
            _publishError(generation, error);
          },
        );
    _comparisonSubscription = metricsService
        .watchCashflowComparison(
          CashflowComparisonQuery(month: month, asOfDate: asOfDate),
        )
        .listen(
          (value) {
            if (!_isCurrent(generation)) return;
            _comparison = value;
            _publishLoadedIfReady(generation);
          },
          onError: (Object error, StackTrace stackTrace) {
            _publishError(generation, error);
          },
        );
    _dailySubscription = metricsService
        .watchDailyCashflowSummaries(DailyCashflowSummaryQuery(month: month))
        .listen(
          (value) {
            if (!_isCurrent(generation)) return;
            _dailySummaries = value;
            _publishLoadedIfReady(generation);
          },
          onError: (Object error, StackTrace stackTrace) {
            _publishError(generation, error);
          },
        );
  }

  void _publishLoadedIfReady(int generation) {
    if (!_isCurrent(generation) || _hasError) return;
    final transactions = _transactions;
    final comparison = _comparison;
    final dailySummaries = _dailySummaries;
    if (transactions == null || comparison == null || dailySummaries == null) {
      return;
    }

    state = state.copyWith(
      content: HomeContentState.loaded(
        summary: buildMonthlySummaryPresentation(comparison),
        groups: groupTransactionsByDay(transactions, dailySummaries),
      ),
    );
  }

  void _publishError(int generation, Object error) {
    if (!_isCurrent(generation)) return;
    _hasError = true;
    state = state.copyWith(
      content: HomeContentState.error(message: '加载失败：$error'),
    );
  }

  bool _isCurrent(int generation) {
    return generation == _generation;
  }

  void _cancelSubscriptions() {
    _transactionsSubscription?.cancel();
    _comparisonSubscription?.cancel();
    _dailySubscription?.cancel();
    _transactionsSubscription = null;
    _comparisonSubscription = null;
    _dailySubscription = null;
  }
}

class HomePageState {
  const HomePageState({required this.visibleMonth, required this.content});

  final DateTime visibleMonth;
  final HomeContentState content;

  HomePageState copyWith({DateTime? visibleMonth, HomeContentState? content}) {
    return HomePageState(
      visibleMonth: visibleMonth ?? this.visibleMonth,
      content: content ?? this.content,
    );
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
