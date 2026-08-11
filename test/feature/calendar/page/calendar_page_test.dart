import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:smartflow/app/provider.dart';
import 'package:smartflow/application/credit/credit_query_api.dart';
import 'package:smartflow/application/ledger/ledger_query_api.dart';
import 'package:smartflow/core/money/money.dart';
import 'package:smartflow/design_system/theme/app_theme.dart';
import 'package:smartflow/feature/calendar/page/calendar_page.dart';
import 'package:smartflow/feature/calendar/view_model/calendar_view_model.dart';
import 'package:smartflow/feature/shared/provider/current_date_time_provider.dart';
import 'package:smartflow/widget/business/transaction/transaction_row.dart';

final _selectedDate = DateTime(2026, 1, 15);
final _visibleMonth = DateTime(2026, 1);

void main() {
  testWidgets('renders the selected day rows under the month grid', (
    tester,
  ) async {
    await _pumpCalendar(
      tester,
      dayTransactions: [_item(_selectedDate.add(const Duration(hours: 9)))],
    );

    expect(find.text('1月15日'), findsOneWidget);
    expect(find.byType(TransactionRow), findsOneWidget);
    expect(find.text('当天暂无交易记录'), findsNothing);
  });

  testWidgets('shows the per-day empty message when the day has no rows', (
    tester,
  ) async {
    await _pumpCalendar(tester, dayTransactions: const []);

    expect(find.text('1月15日'), findsOneWidget);
    expect(find.byType(TransactionRow), findsNothing);
    expect(find.text('当天暂无交易记录'), findsOneWidget);
  });

  testWidgets('loads the next day page when scrolled to the end', (
    tester,
  ) async {
    final service = _FakeTransactionQueryService(
      nextPage: [
        _item(_selectedDate.add(const Duration(hours: 1)), id: 'older'),
      ],
    );
    await _pumpCalendar(
      tester,
      transactionService: service,
      dayTransactions: [
        for (var index = 0; index < calendarTransactionPageSize; index++)
          _item(_selectedDate.add(const Duration(hours: 9)), id: 'tx-$index'),
      ],
    );

    await tester.drag(find.byType(CustomScrollView), const Offset(0, -8000));
    await tester.pumpAndSettle();

    final paged = service.queries.where((query) => query.before != null);
    expect(paged, isNotEmpty);
    expect(paged.last.occurredFrom, _selectedDate);
    expect(paged.last.occurredUntil, DateTime(2026, 1, 16));
  });
}

Future<void> _pumpCalendar(
  WidgetTester tester, {
  required List<TransactionListReadModel> dayTransactions,
  _FakeTransactionQueryService? transactionService,
}) async {
  tester.view.physicalSize = const Size(600, 900);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);

  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        currentDateTimeProvider.overrideWith(
          (ref) => _selectedDate.add(const Duration(hours: 9)),
        ),
        transactionQueryServiceProvider.overrideWithValue(
          transactionService ?? _FakeTransactionQueryService(),
        ),
        creditAccountQueryServiceProvider.overrideWithValue(
          const _FakeCreditAccountQueryService(),
        ),
        accountQueryServiceProvider.overrideWithValue(
          _FakeAccountQueryService(),
        ),
        calendarTransactionsProvider(
          _selectedDate,
        ).overrideWith((ref) => Stream.value(dayTransactions)),
        calendarCashflowComparisonProvider(
          _visibleMonth,
        ).overrideWith((ref) => Stream.value(_comparison())),
        calendarDailyCashflowSummariesProvider(_visibleMonth).overrideWith(
          (ref) => Stream.value([
            DailyCashflowSummary(
              date: _selectedDate,
              income: const Money(minorUnits: 10000),
              expense: Money.zero(),
            ),
          ]),
        ),
      ],
      child: MaterialApp(theme: AppTheme.light(), home: const CalendarPage()),
    ),
  );
  await tester.pumpAndSettle();
}

TransactionListReadModel _item(DateTime occurredAt, {String id = 'tx-1'}) {
  return TransactionListReadModel(
    id: id,
    businessPurpose: BusinessPurpose.dailyIncome,
    occurredAt: occurredAt,
    primaryAmount: const Money(minorUnits: 10000),
    isExcludedFromStats: false,
    isExcludedFromBudget: false,
    primaryCategoryId: null,
    impactsByAccountId: const {},
    adjustments: const [],
  );
}

CashflowComparison _comparison() {
  return const CashflowComparison(
    current: CashflowSummary(
      income: Money(minorUnits: 10000),
      expense: Money(minorUnits: 0),
    ),
    previousSamePeriod: CashflowSummary(
      income: Money(minorUnits: 0),
      expense: Money(minorUnits: 0),
    ),
    previousFullPeriod: CashflowSummary(
      income: Money(minorUnits: 0),
      expense: Money(minorUnits: 0),
    ),
  );
}

class _FakeTransactionQueryService implements TransactionQueryService {
  _FakeTransactionQueryService({
    List<TransactionListReadModel> nextPage = const [],
  }) : _nextPage = nextPage;

  final List<TransactionListReadModel> _nextPage;
  final queries = <TransactionListQuery>[];

  @override
  Stream<List<TransactionListReadModel>> watchTransactions(
    TransactionListQuery query,
  ) {
    queries.add(query);
    return const Stream.empty();
  }

  @override
  Future<List<TransactionListReadModel>> findTransactions(
    TransactionListQuery query,
  ) async {
    queries.add(query);
    return _nextPage;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _FakeAccountQueryService implements AccountQueryService {
  @override
  Stream<Map<String, Account>> watchAccountsById() {
    return Stream.value(const {});
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _FakeCreditAccountQueryService implements CreditAccountQueryService {
  const _FakeCreditAccountQueryService();

  @override
  Future<List<CreditDueCalendarItemReadModel>> listDueCalendarItems(
    CreditDueCalendarQuery query,
  ) async {
    return const [];
  }

  @override
  Future<List<MonthlyBillSummaryReadModel>> listMonthlyBillSummaries(
    MonthlyBillSummaryQuery query,
  ) async {
    return const [];
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
