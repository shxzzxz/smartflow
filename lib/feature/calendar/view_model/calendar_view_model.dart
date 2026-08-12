import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../../app/provider.dart';
import '../../../application/credit/credit_query_api.dart';
import '../../../application/ledger/ledger_query_api.dart';
import '../../../application/shared/app_settings_store.dart';
import '../../../core/time/month_key.dart';
import 'package:smartflow/feature/shared/presentation/transaction_list_presentation.dart';
import '../../shared/provider/current_date_time_provider.dart';
import '../../shared/provider/ledger_query_providers.dart';
import '../presentation/calendar_month_presentation.dart';

part 'calendar_view_model.g.dart';

const calendarTransactionPageSize = 50;

@riverpod
class CalendarViewModel extends _$CalendarViewModel {
  @override
  CalendarPageState build() {
    final now = ref.watch(currentDateTimeProvider);
    return CalendarPageState(
      visibleMonth: DateTime(now.year, now.month),
      selectedDate: normalizeDate(now),
      showLunar: true,
    );
  }

  void pickMonth(DateTime month) {
    final visibleMonth = DateTime(month.year, month.month);
    state = state.copyWith(
      visibleMonth: visibleMonth,
      selectedDate: clampSelectedDateToMonth(state.selectedDate, visibleMonth),
    );
  }

  void shiftMonth(int delta) {
    final nextMonth = DateTime(
      state.visibleMonth.year,
      state.visibleMonth.month + delta,
    );
    state = state.copyWith(
      visibleMonth: nextMonth,
      selectedDate: clampSelectedDateToMonth(state.selectedDate, nextMonth),
    );
  }

  void goToday() {
    final now = ref.read(currentDateTimeProvider);
    state = state.copyWith(
      visibleMonth: DateTime(now.year, now.month),
      selectedDate: normalizeDate(now),
    );
  }

  void selectDate(DateTime date) {
    final normalized = normalizeDate(date);
    state = state.copyWith(
      visibleMonth: DateTime(normalized.year, normalized.month),
      selectedDate: normalized,
    );
  }

  void toggleLunar() {
    state = state.copyWith(showLunar: !state.showLunar);
  }
}

@riverpod
Stream<List<TransactionListReadModel>> calendarTransactions(
  Ref ref,
  DateTime selectedDate,
) {
  return ref
      .watch(transactionQueryServiceProvider)
      .watchTransactions(_dayQuery(selectedDate));
}

TransactionListQuery _dayQuery(
  DateTime selectedDate, {
  TransactionListCursor? before,
}) {
  final day = normalizeDate(selectedDate);
  return TransactionListQuery(
    topLevelOnly: true,
    occurredFrom: day,
    occurredUntil: DateTime(day.year, day.month, day.day + 1),
    limit: calendarTransactionPageSize,
    before: before,
  );
}

/// 选中日的交易分页。首页数据由 [calendarTransactions] 订阅推送，
/// 后续页按游标补拉；任何交易变更都会把列表重置回第一页。
@riverpod
class CalendarTransactionFeedViewModel
    extends _$CalendarTransactionFeedViewModel {
  var _requestGeneration = 0;

  @override
  CalendarTransactionFeedState build(DateTime selectedDate) {
    final provider = calendarTransactionsProvider(selectedDate);
    ref.listen(provider, (_, next) => _applyFirstPage(next));
    return _firstPageState(ref.read(provider));
  }

  CalendarTransactionFeedState _firstPageState(
    AsyncValue<List<TransactionListReadModel>> value,
  ) {
    return switch (value) {
      AsyncData(:final value) => CalendarTransactionFeedState.loaded(
        items: value,
        hasMore: value.length == calendarTransactionPageSize,
      ),
      AsyncError() => const CalendarTransactionFeedState.error(
        message: '加载失败，请稍后重试',
      ),
      AsyncLoading() => const CalendarTransactionFeedState.loading(),
    };
  }

  void _applyFirstPage(AsyncValue<List<TransactionListReadModel>> next) {
    if (next is AsyncLoading && state is CalendarTransactionFeedLoaded) return;
    _requestGeneration += 1;
    state = _firstPageState(next);
  }

  Future<void> loadMore() async {
    final current = state;
    if (current is! CalendarTransactionFeedLoaded ||
        !current.hasMore ||
        current.isLoadingMore) {
      return;
    }
    final cursorItem = current.items.last;
    final requestGeneration = _requestGeneration;
    state = current.copyWith(isLoadingMore: true);
    try {
      final nextPage = await ref
          .read(transactionQueryServiceProvider)
          .findTransactions(
            _dayQuery(
              selectedDate,
              before: TransactionListCursor(
                occurredAt: cursorItem.occurredAt,
                id: cursorItem.id,
              ),
            ),
          );
      if (!ref.mounted || requestGeneration != _requestGeneration) return;
      state = current.copyWith(
        items: [...current.items, ...nextPage],
        hasMore: nextPage.length == calendarTransactionPageSize,
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
}

@riverpod
Stream<CashflowComparison> calendarCashflowComparison(
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
Stream<List<DailyCashflowSummary>> calendarDailyCashflowSummaries(
  Ref ref,
  DateTime visibleMonth,
) {
  final month = MonthKey(year: visibleMonth.year, month: visibleMonth.month);
  return ref
      .watch(financialMetricsServiceProvider)
      .watchDailyCashflowSummaries(DailyCashflowSummaryQuery(month: month));
}

@riverpod
Future<List<CreditDueCalendarItemReadModel>> calendarCreditDueItems(
  Ref ref,
  DateTime visibleMonth,
) {
  final month = MonthKey(year: visibleMonth.year, month: visibleMonth.month);
  return ref
      .watch(creditAccountQueryServiceProvider)
      .listDueCalendarItems(
        CreditDueCalendarQuery(from: month.start, until: month.nextMonthStart),
      );
}

@riverpod
Future<List<MonthlyBillSummaryReadModel>> calendarMonthlyBillSummaries(
  Ref ref,
  DateTime visibleMonth,
) {
  final month = MonthKey(year: visibleMonth.year, month: visibleMonth.month);
  return ref
      .watch(creditAccountQueryServiceProvider)
      .listMonthlyBillSummaries(MonthlyBillSummaryQuery(month: month));
}

@riverpod
CalendarContentState calendarContent(
  Ref ref, {
  required DateTime visibleMonth,
  required DateTime selectedDate,
  CalendarHeatMetric? heatMetric,
}) {
  final now = ref.watch(currentDateTimeProvider);
  final comparison = ref.watch(
    calendarCashflowComparisonProvider(visibleMonth),
  );
  final dailySummaries = ref.watch(
    calendarDailyCashflowSummariesProvider(visibleMonth),
  );
  final creditDueItems = ref.watch(
    calendarCreditDueItemsProvider(visibleMonth),
  );
  final monthlyBillSummaries = ref.watch(
    calendarMonthlyBillSummariesProvider(visibleMonth),
  );
  final accountLookup = ref.watch(accountLookupProvider);
  final feed = ref.watch(
    calendarTransactionFeedViewModelProvider(selectedDate),
  );

  if (comparison case AsyncError(:final error)) {
    return CalendarContentState.error(message: '加载失败：$error');
  }
  if (dailySummaries case AsyncError(:final error)) {
    return CalendarContentState.error(message: '加载失败：$error');
  }
  if (creditDueItems case AsyncError(:final error)) {
    return CalendarContentState.error(message: '加载失败：$error');
  }
  if (monthlyBillSummaries case AsyncError(:final error)) {
    return CalendarContentState.error(message: '加载失败：$error');
  }
  if (accountLookup case AsyncError(:final error)) {
    return CalendarContentState.error(message: '加载失败：$error');
  }
  if (feed case CalendarTransactionFeedError(:final message)) {
    return CalendarContentState.error(message: message);
  }

  final comparisonValue = comparison.value;
  final dailySummaryValues = dailySummaries.value;
  final creditDueItemValues = creditDueItems.value;
  final monthlyBillSummaryValues = monthlyBillSummaries.value;
  final lookup = accountLookup.value;
  if (comparisonValue == null ||
      dailySummaryValues == null ||
      creditDueItemValues == null ||
      monthlyBillSummaryValues == null ||
      lookup == null) {
    return const CalendarContentState.loading();
  }

  final loadedFeed = feed is CalendarTransactionFeedLoaded ? feed : null;
  return CalendarContentState.loaded(
    month: buildCalendarMonthPresentation(
      visibleMonth: visibleMonth,
      selectedDate: selectedDate,
      summary: comparisonValue.current,
      dailySummaries: dailySummaryValues,
      creditDueItems: creditDueItemValues,
      monthlyBillSummaries: monthlyBillSummaryValues,
      heatMetric: heatMetric,
      today: now,
    ),
    day: CalendarDaySectionPresentation(
      group: transactionGroupForDate(
        date: selectedDate,
        transactions: loadedFeed?.items ?? const [],
        dailySummaries: dailySummaryValues,
        accountLookup: lookup,
      ),
      dueBillItems: [
        for (final item in creditDueItemValues)
          if (isSameDate(item.dueDate, selectedDate)) item,
      ],
      isLoading: loadedFeed == null,
      hasMore: loadedFeed?.hasMore ?? false,
      isLoadingMore: loadedFeed?.isLoadingMore ?? false,
      loadMoreErrorMessage: loadedFeed?.loadMoreErrorMessage,
    ),
  );
}

class CalendarPageState {
  const CalendarPageState({
    required this.visibleMonth,
    required this.selectedDate,
    required this.showLunar,
  });

  final DateTime visibleMonth;
  final DateTime selectedDate;
  final bool showLunar;

  CalendarPageState copyWith({
    DateTime? visibleMonth,
    DateTime? selectedDate,
    bool? showLunar,
  }) {
    return CalendarPageState(
      visibleMonth: visibleMonth ?? this.visibleMonth,
      selectedDate: selectedDate ?? this.selectedDate,
      showLunar: showLunar ?? this.showLunar,
    );
  }
}

sealed class CalendarContentState {
  const CalendarContentState();

  const factory CalendarContentState.loading() = CalendarContentLoading;

  const factory CalendarContentState.error({required String message}) =
      CalendarContentError;

  const factory CalendarContentState.loaded({
    required CalendarMonthPresentation month,
    required CalendarDaySectionPresentation day,
  }) = CalendarContentLoaded;
}

final class CalendarContentLoading extends CalendarContentState {
  const CalendarContentLoading();
}

final class CalendarContentError extends CalendarContentState {
  const CalendarContentError({required this.message});

  final String message;
}

final class CalendarContentLoaded extends CalendarContentState {
  const CalendarContentLoaded({required this.month, required this.day});

  final CalendarMonthPresentation month;
  final CalendarDaySectionPresentation day;
}

sealed class CalendarTransactionFeedState {
  const CalendarTransactionFeedState();

  const factory CalendarTransactionFeedState.loading() =
      CalendarTransactionFeedLoading;

  const factory CalendarTransactionFeedState.error({required String message}) =
      CalendarTransactionFeedError;

  const factory CalendarTransactionFeedState.loaded({
    required List<TransactionListReadModel> items,
    required bool hasMore,
    bool isLoadingMore,
    String? loadMoreErrorMessage,
  }) = CalendarTransactionFeedLoaded;
}

final class CalendarTransactionFeedLoading
    extends CalendarTransactionFeedState {
  const CalendarTransactionFeedLoading();
}

final class CalendarTransactionFeedError extends CalendarTransactionFeedState {
  const CalendarTransactionFeedError({required this.message});

  final String message;
}

final class CalendarTransactionFeedLoaded extends CalendarTransactionFeedState {
  const CalendarTransactionFeedLoaded({
    required this.items,
    required this.hasMore,
    this.isLoadingMore = false,
    this.loadMoreErrorMessage,
  });

  final List<TransactionListReadModel> items;
  final bool hasMore;
  final bool isLoadingMore;
  final String? loadMoreErrorMessage;

  CalendarTransactionFeedLoaded copyWith({
    List<TransactionListReadModel>? items,
    bool? hasMore,
    bool? isLoadingMore,
    String? loadMoreErrorMessage,
  }) {
    return CalendarTransactionFeedLoaded(
      items: items ?? this.items,
      hasMore: hasMore ?? this.hasMore,
      isLoadingMore: isLoadingMore ?? this.isLoadingMore,
      loadMoreErrorMessage: loadMoreErrorMessage,
    );
  }
}
