// ignore_for_file: riverpod_lint/scoped_providers_should_specify_dependencies

import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:smartflow/application/credit/credit_query_api.dart';
import 'package:smartflow/core/money/money.dart';
import 'package:smartflow/feature/calendar/view_model/calendar_bills_view_model.dart';
import 'package:smartflow/feature/calendar/view_model/calendar_view_model.dart';
import 'package:smartflow/feature/shared/presentation/account_lookup.dart';
import 'package:smartflow/feature/shared/provider/ledger_query_providers.dart';

void main() {
  test('moves from loading to loaded day state', () async {
    final date = DateTime(2026, 1, 15);
    final month = DateTime(2026, 1);
    final container = ProviderContainer(
      overrides: [
        calendarCreditDueItemsProvider(
          month,
        ).overrideWith((ref) async => [_dueItem(date)]),
        accountLookupProvider.overrideWith(
          (ref) => Stream.value(const AccountLookup({})),
        ),
      ],
    );
    addTearDown(container.dispose);
    final sub = container.listen(
      calendarDayBillsViewModelProvider(date),
      (_, _) {},
    );
    addTearDown(sub.close);

    expect(
      container.read(calendarDayBillsViewModelProvider(date)),
      isA<CalendarBillsPageLoading>(),
    );
    await container.read(calendarCreditDueItemsProvider(month).future);
    await container.read(accountLookupProvider.future);
    await container.pump();

    final state = container.read(calendarDayBillsViewModelProvider(date));
    expect(state, isA<CalendarBillsPageLoaded>());
    final loaded = state as CalendarBillsPageLoaded;
    expect(loaded.title, '1月15日待还账单');
    expect(loaded.rows, hasLength(1));
  });

  test('maps a monthly query failure to page error state', () async {
    final month = DateTime(2026, 1);
    final container = ProviderContainer(
      retry: (_, _) => null,
      overrides: [
        calendarMonthlyBillSummariesProvider(
          month,
        ).overrideWith((ref) => Future.error(Exception('query failed'))),
        accountLookupProvider.overrideWith(
          (ref) => Stream.value(const AccountLookup({})),
        ),
      ],
    );
    addTearDown(container.dispose);
    final errorState = Completer<CalendarBillsPageError>();
    final sub = container.listen(calendarMonthBillsViewModelProvider(month), (
      _,
      next,
    ) {
      if (next case final CalendarBillsPageError error) {
        errorState.complete(error);
      }
    });
    addTearDown(sub.close);

    final state = await errorState.future;
    expect(state.message, '账单加载失败，请稍后重试');
  });
}

CreditDueCalendarItemReadModel _dueItem(DateTime date) {
  return CreditDueCalendarItemReadModel.billItem(
    accountId: 'card',
    billId: 'bill',
    billItemId: 'item',
    dueDate: date,
    itemType: BillItemType.consumption,
    status: BillItemStatus.pending,
    principal: const Money(minorUnits: 1000),
    interest: Money.zero(),
    fee: Money.zero(),
    pendingTotal: const Money(minorUnits: 1000),
    isOverdue: false,
  );
}
