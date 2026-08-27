import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:smartflow/app/provider.dart';
import 'package:smartflow/application/ledger/ledger_query_api.dart';
import 'package:smartflow/application/shared/app_settings_store.dart';
import 'package:smartflow/core/money/money.dart';
import 'package:smartflow/core/time/month_key.dart';
import 'package:smartflow/feature/home/view_model/home_view_model.dart';
import 'package:smartflow/feature/shared/provider/current_date_time_provider.dart';

void main() {
  group('HomeViewModel', () {
    test('combines month streams into loaded page state', () async {
      final transactionService = _FakeTransactionQueryService();
      final metricsService = _FakeFinancialMetricsService();
      final accountService = _FakeAccountQueryService(
        accountsById: const <String, Account>{},
      );
      final visibleMonth = DateTime(2026, 1);
      final container = _container(
        transactionService,
        metricsService,
        accountService,
        overrides: [
          homeTransactionsProvider(
            visibleMonth,
          ).overrideWith((ref) => Stream.value([_item()])),
          homeCashflowComparisonProvider(
            visibleMonth,
          ).overrideWith((ref) => Stream.value(_comparison())),
          homeDailyCashflowSummariesProvider(visibleMonth).overrideWith(
            (ref) => Stream.value([
              DailyCashflowSummary(
                date: DateTime(2026, 1, 1),
                income: const Money(minorUnits: 10000),
                expense: const Money(minorUnits: 2500),
              ),
            ]),
          ),
        ],
      );

      final viewModelSub = container.listen(homeViewModelProvider, (_, _) {});
      addTearDown(viewModelSub.close);
      expect(container.read(homeViewModelProvider).visibleMonth, visibleMonth);
      final contentSub = container.listen(
        homeContentProvider(visibleMonth),
        (_, _) {},
      );
      addTearDown(contentSub.close);
      await container.read(homeTransactionsProvider(visibleMonth).future);
      await container.read(homeCashflowComparisonProvider(visibleMonth).future);
      await container.read(
        homeDailyCashflowSummariesProvider(visibleMonth).future,
      );
      await container.pump();
      await _flush();

      final content = container.read(homeContentProvider(visibleMonth));
      expect(content, isA<HomeContentLoaded>());
      final loaded = content as HomeContentLoaded;
      expect(
        loaded.summary.metrics.first.amount,
        const Money(minorUnits: 10000),
      );
      expect(loaded.groups.single.incomeMinor, 10000);
      expect(loaded.groups.single.rows.single.transactionId, 'tx-1');
    });

    test('captions income and expense by the selected period metric', () async {
      final transactionService = _FakeTransactionQueryService();
      final metricsService = _FakeFinancialMetricsService();
      final accountService = _FakeAccountQueryService(
        accountsById: const <String, Account>{},
      );
      final visibleMonth = DateTime(2026, 1);
      final container = _container(
        transactionService,
        metricsService,
        accountService,
        settingsStore: _MemorySettingsStore(
          const AppSettings(
            cashflowPeriodMetric: CashflowPeriodMetric.previousMonthRatio,
          ),
        ),
        overrides: [
          homeTransactionsProvider(
            visibleMonth,
          ).overrideWith((ref) => Stream.value([_item()])),
          homeCashflowComparisonProvider(
            visibleMonth,
          ).overrideWith((ref) => Stream.value(_comparison())),
          homeDailyCashflowSummariesProvider(visibleMonth).overrideWith(
            (ref) => Stream.value([
              DailyCashflowSummary(
                date: DateTime(2026, 1, 1),
                income: const Money(minorUnits: 10000),
                expense: const Money(minorUnits: 2500),
              ),
            ]),
          ),
        ],
      );

      final contentSub = container.listen(
        homeContentProvider(visibleMonth),
        (_, _) {},
      );
      addTearDown(contentSub.close);
      await container.read(homeTransactionsProvider(visibleMonth).future);
      await container.read(homeCashflowComparisonProvider(visibleMonth).future);
      await container.read(
        homeDailyCashflowSummariesProvider(visibleMonth).future,
      );
      await container.pump();
      await _flush();

      final loaded =
          container.read(homeContentProvider(visibleMonth))
              as HomeContentLoaded;
      expect(loaded.summary.metrics.first.caption, '已达上月 100%');
      expect(loaded.summary.metrics[1].caption, '已达上月 63%');
    });

    test('restarts queries when shifting month', () {
      final transactionService = _FakeTransactionQueryService();
      final metricsService = _FakeFinancialMetricsService();
      final accountService = _FakeAccountQueryService();
      final container = _container(
        transactionService,
        metricsService,
        accountService,
      );

      final viewModelSub = container.listen(homeViewModelProvider, (_, _) {});
      addTearDown(viewModelSub.close);
      container.read(homeViewModelProvider.notifier).shiftMonth(1);
      final visibleMonth = container.read(homeViewModelProvider).visibleMonth;
      final contentSub = container.listen(
        homeContentProvider(visibleMonth),
        (_, _) {},
      );
      addTearDown(contentSub.close);

      expect(
        container.read(homeViewModelProvider).visibleMonth,
        DateTime(2026, 2),
      );
      expect(
        container.read(homeContentProvider(visibleMonth)),
        isA<HomeContentLoading>(),
      );
      expect(transactionService.queries.last.occurredFrom, DateTime(2026, 2));
      expect(transactionService.queries.last.occurredUntil, DateTime(2026, 3));
      expect(metricsService.comparisonQueries.last.month.year, 2026);
      expect(metricsService.comparisonQueries.last.month.month, 2);
      expect(metricsService.comparisonQueries.last.asOfDate, isNull);
    });

    test(
      'queries the first page of top-level transactions in the visible month',
      () {
        final transactionService = _FakeTransactionQueryService();
        final metricsService = _FakeFinancialMetricsService();
        final accountService = _FakeAccountQueryService();
        final container = _container(
          transactionService,
          metricsService,
          accountService,
        );
        final visibleMonth = DateTime(2026, 1);
        final contentSub = container.listen(
          homeContentProvider(visibleMonth),
          (_, _) {},
        );
        addTearDown(contentSub.close);

        final query = transactionService.queries.single;

        expect(query.limit, homeTransactionPageSize);
        expect(query.topLevelOnly, isTrue);
        expect(query.occurredFrom, DateTime(2026, 1));
        expect(query.occurredUntil, DateTime(2026, 2));
      },
    );

    test(
      'applies category and account filters to the transaction query',
      () async {
        final transactionService = _FakeTransactionQueryService();
        final metricsService = _FakeFinancialMetricsService();
        final accountService = _FakeAccountQueryService();
        final container = _container(
          transactionService,
          metricsService,
          accountService,
        );
        final visibleMonth = DateTime(2026, 1);
        final contentSub = container.listen(
          homeContentProvider(visibleMonth),
          (_, _) {},
        );
        addTearDown(contentSub.close);

        container
            .read(homeViewModelProvider.notifier)
            .applyTransactionFilter(
              categoryAccountIds: {'cat-food', 'cat-lunch'},
              settlementAccountIds: {'acc-cash', 'acc-card'},
            );
        await container.pump();

        final query = transactionService.queries.last;
        expect(query.match, isA<TransactionFactMatch>());
        expect(query.match.categoryAccountIds, {'cat-food', 'cat-lunch'});
        expect(query.match.settlementAccountIds, {'acc-cash', 'acc-card'});
        expect(metricsService.comparisonQueries, hasLength(1));
        expect(metricsService.dailyQueries, hasLength(1));
      },
    );

    test(
      'loads the next month page with an exclusive transaction cursor',
      () async {
        final transactionService = _FakeTransactionQueryService();
        final metricsService = _FakeFinancialMetricsService();
        final accountService = _FakeAccountQueryService(
          accountsById: const <String, Account>{},
        );
        final container = _container(
          transactionService,
          metricsService,
          accountService,
        );
        final visibleMonth = DateTime(2026, 1);
        container
            .read(homeViewModelProvider.notifier)
            .applyTransactionFilter(
              categoryAccountIds: {'cat-food'},
              settlementAccountIds: {'acc-cash'},
            );
        final sub = container.listen(
          homeTransactionFeedViewModelProvider(visibleMonth),
          (_, _) {},
        );
        addTearDown(sub.close);
        final firstPage = [
          for (var i = 0; i < homeTransactionPageSize; i++)
            _item(
              id: 'tx-$i',
              occurredAt: DateTime(
                2026,
                1,
                2,
                8,
                0,
                homeTransactionPageSize - i,
              ),
            ),
        ];
        transactionService.emit(firstPage);
        await _flush();
        transactionService.nextPage = [_item(id: 'tx-next')];

        await container
            .read(homeTransactionFeedViewModelProvider(visibleMonth).notifier)
            .loadMore();

        final query = transactionService.queries.last;
        expect(query.limit, homeTransactionPageSize);
        expect(query.match, isA<TransactionFactMatch>());
        expect(query.match.categoryAccountIds, {'cat-food'});
        expect(query.match.settlementAccountIds, {'acc-cash'});
        expect(query.before?.id, firstPage.last.id);
        expect(query.before?.occurredAt, firstPage.last.occurredAt);
        final state = container.read(
          homeTransactionFeedViewModelProvider(visibleMonth),
        );
        expect(state, isA<HomeTransactionFeedLoaded>());
        final loaded = state as HomeTransactionFeedLoaded;
        expect(loaded.items, hasLength(homeTransactionPageSize + 1));
        expect(loaded.hasMore, isFalse);
      },
    );

    test(
      'keeps loaded pages in place until the user refreshes changed data',
      () async {
        final transactionService = _FakeTransactionQueryService();
        final metricsService = _FakeFinancialMetricsService();
        final accountService = _FakeAccountQueryService(
          accountsById: const <String, Account>{},
        );
        final container = _container(
          transactionService,
          metricsService,
          accountService,
        );
        final visibleMonth = DateTime(2026, 1);
        final sub = container.listen(
          homeTransactionFeedViewModelProvider(visibleMonth),
          (_, _) {},
        );
        addTearDown(sub.close);
        final firstPage = [
          for (var i = 0; i < homeTransactionPageSize; i++)
            _item(id: 'initial-$i'),
        ];
        transactionService.emit(firstPage);
        await _flush();
        transactionService.nextPage = [_item(id: 'older')];
        await container
            .read(homeTransactionFeedViewModelProvider(visibleMonth).notifier)
            .loadMore();

        transactionService.emit([_item(id: 'newer')]);
        await _flush();

        var loaded =
            container.read(homeTransactionFeedViewModelProvider(visibleMonth))
                as HomeTransactionFeedLoaded;
        expect(loaded.items, hasLength(homeTransactionPageSize + 1));
        expect(loaded.items.first.id, 'initial-0');
        expect(loaded.hasPendingRefresh, isTrue);

        container
            .read(homeTransactionFeedViewModelProvider(visibleMonth).notifier)
            .refresh();
        await container.pump();
        transactionService.emit([_item(id: 'newer')]);
        await _flush();

        loaded =
            container.read(homeTransactionFeedViewModelProvider(visibleMonth))
                as HomeTransactionFeedLoaded;
        expect(loaded.items.map((item) => item.id), ['newer']);
        expect(loaded.hasPendingRefresh, isFalse);
        expect(loaded.isRefreshing, isFalse);
      },
    );

    test('ignores an old in-flight page after the filter changes', () async {
      final transactionService = _FakeTransactionQueryService();
      final metricsService = _FakeFinancialMetricsService();
      final accountService = _FakeAccountQueryService(
        accountsById: const <String, Account>{},
      );
      final container = _container(
        transactionService,
        metricsService,
        accountService,
      );
      final visibleMonth = DateTime(2026, 1);
      final sub = container.listen(
        homeTransactionFeedViewModelProvider(visibleMonth),
        (_, _) {},
      );
      addTearDown(sub.close);
      transactionService.emit([
        for (var i = 0; i < homeTransactionPageSize; i++) _item(id: 'old-$i'),
      ]);
      await _flush();
      final oldPage = Completer<List<TransactionReadModel>>();
      transactionService.nextPageFuture = oldPage.future;

      final loadMore =
          container
              .read(homeTransactionFeedViewModelProvider(visibleMonth).notifier)
              .loadMore();
      container
          .read(homeViewModelProvider.notifier)
          .applyTransactionFilter(
            categoryAccountIds: {'cat-food'},
            settlementAccountIds: null,
          );
      await container.pump();
      oldPage.complete([_item(id: 'old-next')]);
      await loadMore;
      transactionService.emit([_item(id: 'new-filter')]);
      await _flush();

      final state =
          container.read(homeTransactionFeedViewModelProvider(visibleMonth))
              as HomeTransactionFeedLoaded;
      expect(state.items.map((item) => item.id), ['new-filter']);
      expect(state.hasPendingRefresh, isFalse);
    });
  });
}

ProviderContainer _container(
  _FakeTransactionQueryService transactionService,
  _FakeFinancialMetricsService metricsService,
  _FakeAccountQueryService accountService, {
  List<dynamic> overrides = const [],
  AppSettingsStore? settingsStore,
}) {
  final container = ProviderContainer(
    overrides: [
      currentDateTimeProvider.overrideWith((ref) => DateTime(2026, 1, 15, 9)),
      transactionQueryServiceProvider.overrideWithValue(transactionService),
      financialMetricsServiceProvider.overrideWithValue(metricsService),
      accountQueryServiceProvider.overrideWithValue(accountService),
      budgetQueryServiceProvider.overrideWithValue(
        const _FakeBudgetQueryService(),
      ),
      appSettingsStoreProvider.overrideWithValue(
        settingsStore ?? _MemorySettingsStore(),
      ),
      ...overrides,
    ],
  );
  addTearDown(container.dispose);
  addTearDown(transactionService.dispose);
  addTearDown(metricsService.dispose);
  addTearDown(accountService.dispose);
  return container;
}

class _MemorySettingsStore implements AppSettingsStore {
  _MemorySettingsStore([this.settings = const AppSettings()]);

  AppSettings settings;

  @override
  Future<AppSettings> read() async => settings;

  @override
  Future<void> save(AppSettings settings) async {
    this.settings = settings;
  }
}

class _FakeBudgetQueryService implements BudgetQueryService {
  const _FakeBudgetQueryService();

  @override
  Stream<MonthlyBudgetReport> watchMonthlyReport(MonthKey month) {
    return Stream.value(
      MonthlyBudgetReport(month: month, categoryGroups: const []),
    );
  }
}

Future<void> _flush() async {
  await Future<void>.delayed(Duration.zero);
  await Future<void>.delayed(Duration.zero);
}

TransactionReadModel _item({String id = 'tx-1', DateTime? occurredAt}) {
  return TransactionReadModel(
    id: id,
    businessPurpose: BusinessPurpose.dailyIncome,
    occurredAt: occurredAt ?? DateTime(2026, 1, 1, 8),
    primaryAmount: const Money(minorUnits: 10000),
    isExcludedFromStats: false,
    isExcludedFromBudget: false,
    impactsByAccountId: const {},
  );
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

class _FakeTransactionQueryService implements TransactionQueryService {
  final queries = <TransactionListQuery>[];
  final _streams = <_ReplayStream<List<TransactionReadModel>>>[];
  List<TransactionReadModel>? nextPage;
  Future<List<TransactionReadModel>>? nextPageFuture;

  @override
  Stream<List<TransactionReadModel>> watchTransactions(
    TransactionListQuery query,
  ) {
    queries.add(query);
    final stream = _ReplayStream<List<TransactionReadModel>>();
    _streams.add(stream);
    return stream.watch();
  }

  @override
  Future<List<TransactionReadModel>> findTransactions(
    TransactionListQuery query,
  ) async {
    queries.add(query);
    if (nextPageFuture case final future?) return future;
    return nextPage ?? const [];
  }

  void emit(List<TransactionReadModel> items) {
    _streams.last.add(items);
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
