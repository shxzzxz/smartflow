import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../shared/provider/ledger_query_providers.dart';
import '../presentation/calendar_bills_presentation.dart';
import 'calendar_view_model.dart';

part 'calendar_bills_view_model.g.dart';

@riverpod
CalendarBillsPageState calendarDayBillsViewModel(Ref ref, DateTime date) {
  final title = '${date.month}月${date.day}日待还账单';
  final month = DateTime(date.year, date.month);
  final dueItems = ref.watch(calendarCreditDueItemsProvider(month));
  final accountLookup = ref.watch(accountLookupProvider);
  if (dueItems case AsyncError()) {
    return CalendarBillsPageState.error(title: title, message: '账单加载失败，请稍后重试');
  }
  if (accountLookup case AsyncError()) {
    return CalendarBillsPageState.error(title: title, message: '账户加载失败，请稍后重试');
  }
  final items = dueItems.value;
  final lookup = accountLookup.value;
  if (items == null || lookup == null) {
    return CalendarBillsPageState.loading(title: title);
  }
  return CalendarBillsPageState.loaded(
    title: title,
    emptyMessage: '当日暂无待还账单明细',
    rows: buildCalendarDayBillRows(
      date: date,
      items: items,
      accountLookup: lookup,
    ),
  );
}

@riverpod
CalendarBillsPageState calendarMonthBillsViewModel(Ref ref, DateTime month) {
  final title = '${month.year}年${month.month}月账单';
  final bills = ref.watch(calendarMonthlyBillSummariesProvider(month));
  final accountLookup = ref.watch(accountLookupProvider);
  if (bills case AsyncError()) {
    return CalendarBillsPageState.error(title: title, message: '账单加载失败，请稍后重试');
  }
  if (accountLookup case AsyncError()) {
    return CalendarBillsPageState.error(title: title, message: '账户加载失败，请稍后重试');
  }
  final billValues = bills.value;
  final lookup = accountLookup.value;
  if (billValues == null || lookup == null) {
    return CalendarBillsPageState.loading(title: title);
  }
  return CalendarBillsPageState.loaded(
    title: title,
    emptyMessage: '本月暂无账单',
    rows: buildCalendarMonthBillRows(bills: billValues, accountLookup: lookup),
  );
}

sealed class CalendarBillsPageState {
  const CalendarBillsPageState();

  const factory CalendarBillsPageState.loading({required String title}) =
      CalendarBillsPageLoading;

  const factory CalendarBillsPageState.error({
    required String title,
    required String message,
  }) = CalendarBillsPageError;

  const factory CalendarBillsPageState.loaded({
    required String title,
    required String emptyMessage,
    required List<CalendarBillRowPresentation> rows,
  }) = CalendarBillsPageLoaded;
}

final class CalendarBillsPageLoading extends CalendarBillsPageState {
  const CalendarBillsPageLoading({required this.title});

  final String title;
}

final class CalendarBillsPageError extends CalendarBillsPageState {
  const CalendarBillsPageError({required this.title, required this.message});

  final String title;
  final String message;
}

final class CalendarBillsPageLoaded extends CalendarBillsPageState {
  const CalendarBillsPageLoaded({
    required this.title,
    required this.emptyMessage,
    required this.rows,
  });

  final String title;
  final String emptyMessage;
  final List<CalendarBillRowPresentation> rows;
}
