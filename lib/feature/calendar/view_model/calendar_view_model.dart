import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../../app/provider.dart';
import '../../../application/ledger/ledger_query_api.dart';
import '../../../core/time/month_key.dart';
import '../../../widget/business/account_lookup.dart';
import '../../../widget/business/transaction_list_presentation.dart';
import '../../shared/provider/current_date_time_provider.dart';
import '../presentation/calendar_month_presentation.dart';

part 'calendar_view_model.g.dart';

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
CalendarContentState calendarContent(
  Ref ref, {
  required DateTime visibleMonth,
  required DateTime selectedDate,
}) {
  final now = ref.watch(currentDateTimeProvider);
  final transactions = ref.watch(calendarTransactionsProvider(visibleMonth));
  final comparison = ref.watch(
    calendarCashflowComparisonProvider(visibleMonth),
  );
  final dailySummaries = ref.watch(
    calendarDailyCashflowSummariesProvider(visibleMonth),
  );
  final accountsById = ref.watch(accountsByIdProvider);

  if (transactions case AsyncError(:final error)) {
    return CalendarContentState.error(message: '加载失败：$error');
  }
  if (comparison case AsyncError(:final error)) {
    return CalendarContentState.error(message: '加载失败：$error');
  }
  if (dailySummaries case AsyncError(:final error)) {
    return CalendarContentState.error(message: '加载失败：$error');
  }
  if (accountsById case AsyncError(:final error)) {
    return CalendarContentState.error(message: '加载失败：$error');
  }

  final transactionValues = transactions.value;
  final comparisonValue = comparison.value;
  final dailySummaryValues = dailySummaries.value;
  final accountValues = accountsById.value;
  if (transactionValues == null ||
      comparisonValue == null ||
      dailySummaryValues == null ||
      accountValues == null) {
    return const CalendarContentState.loading();
  }

  return CalendarContentState.loaded(
    month: buildCalendarMonthPresentation(
      visibleMonth: visibleMonth,
      selectedDate: selectedDate,
      transactions: transactionValues,
      accountLookup: AccountLookup(accountValues),
      summary: comparisonValue.current,
      dailySummaries: dailySummaryValues,
      today: now,
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
