import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:smartflow/app/provider.dart';
import 'package:smartflow/application/credit/credit_query_api.dart';
import 'package:smartflow/application/ledger/ledger_query_api.dart';
import 'package:smartflow/application/transaction_view/transaction_view_query_api.dart';
import 'package:smartflow/core/money/money.dart';
import 'package:smartflow/feature/calendar/view_model/calendar_view_model.dart';
import 'package:smartflow/feature/shared/provider/current_date_time_provider.dart';

void main() {
  group('CalendarViewModel', () {
    test(
      'combines streams and updates selected date within same month',
      () async {
        final businessService = _FakeBusinessItemQueryService();
        final metricsService = _FakeFinancialMetricsService();
        final accountService = _FakeAccountQueryService(
          accountsById: const <String, Account>{},
        );
        final visibleMonth = DateTime(2026, 1);
        final selectedDate = DateTime(2026, 1, 2);
        final container = _container(
          businessService,
          metricsService,
          accountService,
          overrides: [
            calendarBusinessItemsProvider(selectedDate).overrideWith(
              (ref) =>
                  Stream.value(_page([_businessItem(DateTime(2026, 1, 2, 8))])),
            ),
            calendarCashflowComparisonProvider(
              visibleMonth,
            ).overrideWith((ref) => Stream.value(_comparison())),
            calendarDailyCashflowSummariesProvider(visibleMonth).overrideWith(
              (ref) => Stream.value([
                DailyCashflowSummary(
                  date: DateTime(2026, 1, 2),
                  income: const Money(minorUnits: 10000),
                  expense: const Money(minorUnits: 2500),
                ),
              ]),
            ),
          ],
        );

        final viewModelSub = container.listen(
          calendarViewModelProvider,
          (_, _) {},
        );
        addTearDown(viewModelSub.close);
        container
            .read(calendarViewModelProvider.notifier)
            .selectDate(selectedDate);
        final state = container.read(calendarViewModelProvider);
        final contentSub = container.listen(
          calendarContentProvider(
            visibleMonth: state.visibleMonth,
            selectedDate: state.selectedDate,
          ),
          (_, _) {},
        );
        addTearDown(contentSub.close);
        await container.read(
          calendarBusinessItemsProvider(selectedDate).future,
        );
        await container.read(
          calendarCashflowComparisonProvider(visibleMonth).future,
        );
        await container.read(
          calendarDailyCashflowSummariesProvider(visibleMonth).future,
        );
        await container.pump();
        await _flush();

        expect(state.visibleMonth, DateTime(2026, 1));
        expect(state.selectedDate, selectedDate);
        final loaded =
            container.read(
                  calendarContentProvider(
                    visibleMonth: state.visibleMonth,
                    selectedDate: state.selectedDate,
                  ),
                )
                as CalendarContentLoaded;
        expect(loaded.day.group.date, selectedDate);
        expect(loaded.day.group.rows.single.transactionId, 'tx-1');
        expect(loaded.day.isLoading, false);
        expect(loaded.day.hasMore, false);
      },
    );

    test('queries only the selected day and keeps the page limit', () {
      final businessService = _FakeBusinessItemQueryService();
      final metricsService = _FakeFinancialMetricsService();
      final accountService = _FakeAccountQueryService();
      final container = _container(
        businessService,
        metricsService,
        accountService,
      );

      final viewModelSub = container.listen(
        calendarViewModelProvider,
        (_, _) {},
      );
      addTearDown(viewModelSub.close);
      container
          .read(calendarViewModelProvider.notifier)
          .selectDate(DateTime(2026, 1, 14));
      final state = container.read(calendarViewModelProvider);
      final contentSub = container.listen(
        calendarContentProvider(
          visibleMonth: state.visibleMonth,
          selectedDate: state.selectedDate,
        ),
        (_, _) {},
      );
      addTearDown(contentSub.close);

      final query = businessService.queries.last;
      expect(query.occurredFrom, DateTime(2026, 1, 14));
      expect(query.occurredUntil, DateTime(2026, 1, 15));
      expect(query.limit, calendarBusinessItemPageSize);
    });

    test('keeps the month grid visible while the day feed loads', () async {
      final businessService = _FakeBusinessItemQueryService();
      final metricsService = _FakeFinancialMetricsService();
      final accountService = _FakeAccountQueryService(
        accountsById: const <String, Account>{},
      );
      final visibleMonth = DateTime(2026, 1);
      final container = _container(
        businessService,
        metricsService,
        accountService,
        overrides: [
          calendarCashflowComparisonProvider(
            visibleMonth,
          ).overrideWith((ref) => Stream.value(_comparison())),
          calendarDailyCashflowSummariesProvider(
            visibleMonth,
          ).overrideWith((ref) => Stream.value(const [])),
        ],
      );

      final viewModelSub = container.listen(
        calendarViewModelProvider,
        (_, _) {},
      );
      addTearDown(viewModelSub.close);
      final state = container.read(calendarViewModelProvider);
      final content = calendarContentProvider(
        visibleMonth: state.visibleMonth,
        selectedDate: state.selectedDate,
      );
      final contentSub = container.listen(content, (_, _) {});
      addTearDown(contentSub.close);
      await container.read(calendarCreditDueItemsProvider(visibleMonth).future);
      await container.read(
        calendarMonthlyBillSummariesProvider(visibleMonth).future,
      );
      await container.pump();
      await _flush();

      // 当日交易流始终未推送，月度数据已就绪：网格应照常渲染。
      final loaded = container.read(content) as CalendarContentLoaded;
      expect(loaded.month.days, isNotEmpty);
      expect(loaded.day.isLoading, true);
      expect(loaded.day.group.rows, isEmpty);
    });

    test('appends the next page from the last loaded cursor', () async {
      final businessService = _FakeBusinessItemQueryService(
        nextPage: _page([
          _businessItem(DateTime(2026, 1, 15, 6), id: 'tx-older'),
        ]),
      );
      final metricsService = _FakeFinancialMetricsService();
      final accountService = _FakeAccountQueryService();
      final selectedDate = DateTime(2026, 1, 15);
      final firstPage = [
        for (var index = 0; index < calendarBusinessItemPageSize; index++)
          _businessItem(DateTime(2026, 1, 15, 9), id: 'tx-$index'),
      ];
      final container = _container(
        businessService,
        metricsService,
        accountService,
        overrides: [
          calendarBusinessItemsProvider(selectedDate).overrideWith(
            (ref) => Stream.value(_page(firstPage, hasMore: true)),
          ),
        ],
      );

      final feed = calendarTransactionFeedViewModelProvider(selectedDate);
      final feedSub = container.listen(feed, (_, _) {});
      addTearDown(feedSub.close);
      await container.read(calendarBusinessItemsProvider(selectedDate).future);
      await container.pump();
      await _flush();

      expect(
        (container.read(feed) as CalendarTransactionFeedLoaded).hasMore,
        true,
      );
      await container.read(feed.notifier).loadMore();

      final loaded = container.read(feed) as CalendarTransactionFeedLoaded;
      expect(loaded.items, hasLength(calendarBusinessItemPageSize + 1));
      expect(loaded.hasMore, false);
      expect(loaded.isLoadingMore, false);
      final cursor = businessService.queries.last.before;
      expect(
        cursor?.itemKey,
        BusinessItemKey.transactionGroup(
          'tx-${calendarBusinessItemPageSize - 1}',
        ),
      );
      expect(cursor?.anchorAt, DateTime(2026, 1, 15, 9));
    });

    test('shifts month and clamps selected date', () {
      final businessService = _FakeBusinessItemQueryService();
      final metricsService = _FakeFinancialMetricsService();
      final accountService = _FakeAccountQueryService();
      final container = _container(
        businessService,
        metricsService,
        accountService,
        now: DateTime(2026, 1, 31),
      );

      final viewModelSub = container.listen(
        calendarViewModelProvider,
        (_, _) {},
      );
      addTearDown(viewModelSub.close);
      container.read(calendarViewModelProvider.notifier).shiftMonth(1);

      final state = container.read(calendarViewModelProvider);
      expect(state.visibleMonth, DateTime(2026, 2));
      expect(state.selectedDate, DateTime(2026, 2, 28));
      expect(
        container.read(
          calendarContentProvider(
            visibleMonth: state.visibleMonth,
            selectedDate: state.selectedDate,
          ),
        ),
        isA<CalendarContentLoading>(),
      );
      expect(
        metricsService.dailyQueries.last.month.month,
        DateTime(2026, 2).month,
      );
    });

    test('toggle lunar does not restart month queries', () {
      final businessService = _FakeBusinessItemQueryService();
      final metricsService = _FakeFinancialMetricsService();
      final accountService = _FakeAccountQueryService();
      final container = _container(
        businessService,
        metricsService,
        accountService,
      );

      final viewModelSub = container.listen(
        calendarViewModelProvider,
        (_, _) {},
      );
      addTearDown(viewModelSub.close);
      final initialState = container.read(calendarViewModelProvider);
      final contentSub = container.listen(
        calendarContentProvider(
          visibleMonth: initialState.visibleMonth,
          selectedDate: initialState.selectedDate,
        ),
        (_, _) {},
      );
      addTearDown(contentSub.close);
      container.read(calendarViewModelProvider.notifier).toggleLunar();

      expect(container.read(calendarViewModelProvider).showLunar, false);
      expect(businessService.queries, hasLength(1));
    });
  });
}

ProviderContainer _container(
  _FakeBusinessItemQueryService businessService,
  _FakeFinancialMetricsService metricsService,
  _FakeAccountQueryService accountService, {
  DateTime? now,
  List<dynamic> overrides = const [],
}) {
  final container = ProviderContainer(
    overrides: [
      currentDateTimeProvider.overrideWith(
        (ref) => now ?? DateTime(2026, 1, 15, 9),
      ),
      businessItemQueryServiceProvider.overrideWithValue(businessService),
      financialMetricsServiceProvider.overrideWithValue(metricsService),
      accountQueryServiceProvider.overrideWithValue(accountService),
      creditAccountQueryServiceProvider.overrideWithValue(
        const _FakeCreditAccountQueryService(),
      ),
      ...overrides,
    ],
  );
  addTearDown(container.dispose);
  addTearDown(businessService.dispose);
  addTearDown(metricsService.dispose);
  addTearDown(accountService.dispose);
  return container;
}

Future<void> _flush() async {
  await Future<void>.delayed(Duration.zero);
  await Future<void>.delayed(Duration.zero);
}

TransactionReadModel _item(DateTime occurredAt, {String id = 'tx-1'}) {
  return TransactionReadModel(
    id: id,
    businessPurpose: BusinessPurpose.dailyIncome,
    occurredAt: occurredAt,
    primaryAmount: const Money(minorUnits: 10000),
    isExcludedFromStats: false,
    isExcludedFromBudget: false,
    impactsByAccountId: const {},
  );
}

BusinessItemReadModel _businessItem(DateTime occurredAt, {String id = 'tx-1'}) {
  final transaction = _item(occurredAt, id: id);
  return BusinessItemReadModel.fromCandidate(
    candidate: BusinessItemAnchorCandidate(
      itemKey: BusinessItemKey.transactionGroup(transaction.id),
      anchorTransactionId: transaction.id,
      anchorAt: transaction.occurredAt,
    ),
    anchorTransaction: transaction,
    summary: const LedgerBusinessItemSummary(),
  );
}

BusinessItemPage _page(
  List<BusinessItemReadModel> items, {
  bool hasMore = false,
}) {
  return BusinessItemPage(items: items, hasMore: hasMore);
}

CashflowComparison _comparison() {
  return const CashflowComparison(
    current: CashflowSummary(
      income: Money(minorUnits: 10000),
      expense: Money(minorUnits: 2500),
    ),
    previousSamePeriod: CashflowSummary(
      income: Money(minorUnits: 5000),
      expense: Money(minorUnits: 2000),
    ),
    previousFullPeriod: CashflowSummary(
      income: Money(minorUnits: 10000),
      expense: Money(minorUnits: 4000),
    ),
  );
}

class _FakeBusinessItemQueryService implements BusinessItemQueryService {
  _FakeBusinessItemQueryService({BusinessItemPage? nextPage})
    : _nextPage = nextPage ?? _page(const []);

  final BusinessItemPage _nextPage;
  final queries = <BusinessItemPageQuery>[];
  final _streams = <_ReplayStream<BusinessItemPage>>[];

  @override
  Stream<BusinessItemPage> watchPage(BusinessItemPageQuery query) {
    queries.add(query);
    final stream = _ReplayStream<BusinessItemPage>();
    _streams.add(stream);
    return stream.watch();
  }

  @override
  Future<BusinessItemPage> findPage(BusinessItemPageQuery query) async {
    queries.add(query);
    return _nextPage;
  }

  void emit(BusinessItemPage page) {
    _streams.last.add(page);
  }

  void dispose() {
    for (final stream in _streams) {
      stream.close();
    }
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _FakeFinancialMetricsService implements FinancialMetricsService {
  final comparisonQueries = <CashflowComparisonQuery>[];
  final dailyQueries = <DailyCashflowSummaryQuery>[];
  final _comparisonStreams = <_ReplayStream<CashflowComparison>>[];
  final _dailyStreams = <_ReplayStream<List<DailyCashflowSummary>>>[];

  @override
  Stream<CashflowComparison> watchCashflowComparison(
    CashflowComparisonQuery query,
  ) {
    comparisonQueries.add(query);
    final stream = _ReplayStream<CashflowComparison>();
    _comparisonStreams.add(stream);
    return stream.watch();
  }

  @override
  Stream<List<DailyCashflowSummary>> watchDailyCashflowSummaries(
    DailyCashflowSummaryQuery query,
  ) {
    dailyQueries.add(query);
    final stream = _ReplayStream<List<DailyCashflowSummary>>();
    _dailyStreams.add(stream);
    return stream.watch();
  }

  void emitComparison(CashflowComparison value) {
    _comparisonStreams.last.add(value);
  }

  void emitDaily(List<DailyCashflowSummary> value) {
    _dailyStreams.last.add(value);
  }

  void dispose() {
    for (final stream in _comparisonStreams) {
      stream.close();
    }
    for (final stream in _dailyStreams) {
      stream.close();
    }
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _FakeAccountQueryService implements AccountQueryService {
  _FakeAccountQueryService({Map<String, Account>? accountsById})
    : _accountsById = accountsById;

  final Map<String, Account>? _accountsById;
  final _byIdStreams = <_ReplayStream<Map<String, Account>>>[];

  @override
  Stream<Map<String, Account>> watchAccountsById() {
    final accountsById = _accountsById;
    if (accountsById != null) {
      return Stream.value(accountsById);
    }
    final stream = _ReplayStream<Map<String, Account>>();
    _byIdStreams.add(stream);
    return stream.watch();
  }

  void emitById(Map<String, Account> value) {
    _byIdStreams.last.add(value);
  }

  void dispose() {
    for (final stream in _byIdStreams) {
      stream.close();
    }
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

class _ReplayStream<T> {
  final _controllers = <StreamController<T>>[];
  T? _value;
  bool _hasValue = false;

  Stream<T> watch() {
    late StreamController<T> controller;
    controller = StreamController<T>.broadcast(
      sync: true,
      onListen: () {
        if (_hasValue) {
          controller.add(_value as T);
        }
      },
      onCancel: () {
        if (!controller.hasListener) {
          _controllers.remove(controller);
        }
      },
    );
    _controllers.add(controller);
    return controller.stream;
  }

  void add(T value) {
    _value = value;
    _hasValue = true;
    for (final controller in List.of(_controllers)) {
      if (!controller.isClosed) {
        controller.add(value);
      }
    }
  }

  void close() {
    for (final controller in List.of(_controllers)) {
      controller.close();
    }
    _controllers.clear();
  }
}
