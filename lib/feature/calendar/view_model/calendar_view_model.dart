import 'dart:async';

import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../../app/provider.dart';
import '../../../application/ledger/ledger_query_api.dart';
import '../../../core/time/month_key.dart';
import '../../../widget/business/transaction_list_presentation.dart';
import '../../shared/provider/current_date_time_provider.dart';
import '../presentation/calendar_month_presentation.dart';

part 'calendar_view_model.g.dart';

@riverpod
class CalendarViewModel extends _$CalendarViewModel {
  StreamSubscription<List<TransactionListItem>>? _transactionsSubscription;
  StreamSubscription<CashflowComparison>? _comparisonSubscription;
  StreamSubscription<List<DailyCashflowSummary>>? _dailySubscription;

  int _generation = 0;
  List<TransactionListItem>? _transactions;
  CashflowSummary? _summary;
  List<DailyCashflowSummary>? _dailySummaries;
  bool _hasError = false;

  @override
  CalendarPageState build() {
    final now = ref.watch(currentDateTimeProvider);
    final visibleMonth = DateTime(now.year, now.month);
    final selectedDate = normalizeDate(now);
    ref.onDispose(_cancelSubscriptions);
    _watchMonth(visibleMonth, now: now);
    return CalendarPageState(
      visibleMonth: visibleMonth,
      selectedDate: selectedDate,
      showLunar: true,
      content: const CalendarContentState.loading(),
    );
  }

  void pickMonth(DateTime month) {
    final visibleMonth = DateTime(month.year, month.month);
    _setVisibleMonthAndSelectedDate(
      visibleMonth,
      clampSelectedDateToMonth(state.selectedDate, visibleMonth),
    );
  }

  void shiftMonth(int delta) {
    final nextMonth = DateTime(
      state.visibleMonth.year,
      state.visibleMonth.month + delta,
    );
    _setVisibleMonthAndSelectedDate(
      nextMonth,
      clampSelectedDateToMonth(state.selectedDate, nextMonth),
    );
  }

  void goToday() {
    final now = ref.read(currentDateTimeProvider);
    final todayMonth = DateTime(now.year, now.month);
    _setVisibleMonthAndSelectedDate(todayMonth, normalizeDate(now));
  }

  void selectDate(DateTime date) {
    final normalized = normalizeDate(date);
    final visibleMonth = DateTime(normalized.year, normalized.month);
    _setVisibleMonthAndSelectedDate(visibleMonth, normalized);
  }

  void toggleLunar() {
    state = state.copyWith(showLunar: !state.showLunar);
  }

  void _setVisibleMonthAndSelectedDate(
    DateTime visibleMonth,
    DateTime selectedDate,
  ) {
    final monthChanged =
        visibleMonth.year != state.visibleMonth.year ||
        visibleMonth.month != state.visibleMonth.month;
    state = state.copyWith(
      visibleMonth: visibleMonth,
      selectedDate: selectedDate,
      content:
          monthChanged ? const CalendarContentState.loading() : state.content,
    );
    if (monthChanged) {
      _watchMonth(visibleMonth, now: ref.read(currentDateTimeProvider));
    } else {
      _publishLoadedIfReady(_generation);
    }
  }

  void _watchMonth(DateTime visibleMonth, {required DateTime now}) {
    final generation = ++_generation;
    _cancelSubscriptions();
    _transactions = null;
    _summary = null;
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
            _summary = value.current;
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
    final summary = _summary;
    final dailySummaries = _dailySummaries;
    if (transactions == null || summary == null || dailySummaries == null) {
      return;
    }

    state = state.copyWith(
      content: CalendarContentState.loaded(
        month: buildCalendarMonthPresentation(
          visibleMonth: state.visibleMonth,
          selectedDate: state.selectedDate,
          transactions: transactions,
          summary: summary,
          dailySummaries: dailySummaries,
          today: ref.read(currentDateTimeProvider),
        ),
      ),
    );
  }

  void _publishError(int generation, Object error) {
    if (!_isCurrent(generation)) return;
    _hasError = true;
    state = state.copyWith(
      content: CalendarContentState.error(message: '加载失败：$error'),
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

class CalendarPageState {
  const CalendarPageState({
    required this.visibleMonth,
    required this.selectedDate,
    required this.showLunar,
    required this.content,
  });

  final DateTime visibleMonth;
  final DateTime selectedDate;
  final bool showLunar;
  final CalendarContentState content;

  CalendarPageState copyWith({
    DateTime? visibleMonth,
    DateTime? selectedDate,
    bool? showLunar,
    CalendarContentState? content,
  }) {
    return CalendarPageState(
      visibleMonth: visibleMonth ?? this.visibleMonth,
      selectedDate: selectedDate ?? this.selectedDate,
      showLunar: showLunar ?? this.showLunar,
      content: content ?? this.content,
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
  const CalendarContentLoaded({required this.month});

  final CalendarMonthPresentation month;
}
