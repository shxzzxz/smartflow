import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:smartflow/app/provider.dart';
import 'package:smartflow/application/ledger/ledger_query_api.dart';
import 'package:smartflow/application/shared/app_settings_store.dart';
import 'package:smartflow/application/transaction_view/transaction_view_query_api.dart';
import 'package:smartflow/core/money/money.dart';
import 'package:smartflow/core/time/month_key.dart';
import 'package:smartflow/domain/orchestration/valobj/amortization_enums.dart';
import 'package:smartflow/feature/home/view_model/home_view_model.dart';
import 'package:smartflow/feature/shared/provider/current_date_time_provider.dart';

void main() {
  group('HomeViewModel', () {
    test('combines month streams into loaded page state', () async {
      final businessService = _FakeBusinessActivityQueryService();
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
          homeBusinessActivitiesProvider(
            visibleMonth,
          ).overrideWith((ref) => Stream.value(_page([_businessActivity()]))),
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
      await container.read(homeBusinessActivitiesProvider(visibleMonth).future);
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
      final businessService = _FakeBusinessActivityQueryService();
      final metricsService = _FakeFinancialMetricsService();
      final accountService = _FakeAccountQueryService(
        accountsById: const <String, Account>{},
      );
      final visibleMonth = DateTime(2026, 1);
      final container = _container(
        businessService,
        metricsService,
        accountService,
        settingsStore: _MemorySettingsStore(
          const AppSettings(
            cashflowPeriodMetric: CashflowPeriodMetric.previousMonthRatio,
          ),
        ),
        overrides: [
          homeBusinessActivitiesProvider(
            visibleMonth,
          ).overrideWith((ref) => Stream.value(_page([_businessActivity()]))),
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
      await container.read(homeBusinessActivitiesProvider(visibleMonth).future);
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

    test('builds compact business rows from the display setting', () async {
      final businessService = _FakeBusinessActivityQueryService();
      final metricsService = _FakeFinancialMetricsService();
      final accountService = _FakeAccountQueryService(
        accountsById: {
          'food': Account(
            id: 'food',
            name: '餐饮',
            type: AccountType.expense,
            balance: Money.zero(),
            iconKey: 'meal',
          ),
        },
      );
      final visibleMonth = DateTime(2026, 1);
      final transaction = TransactionReadModel(
        id: 'amortization',
        businessPurpose: BusinessPurpose.transfer,
        occurredAt: DateTime(2026, 1, 1, 8),
        primaryAmount: const Money(minorUnits: 12000),
        isExcludedFromStats: false,
        isExcludedFromBudget: false,
        ownership: const TransactionOwnership(
          ownerType: orchestrationAmortizationOwnerType,
          ownerId: 'plan-1',
        ),
        lines: const [
          TransactionLine(
            id: 'amortization-category',
            transactionId: 'amortization',
            lineNo: 1,
            role: TransactionRole.category,
            accountId: 'food',
            amount: Money(minorUnits: 12000),
          ),
        ],
      );
      final item = _businessActivity(
        transaction: transaction,
        summary: const AmortizationBusinessActivitySummary(
          kind: AmortizationKind.prepaidExpense,
          status: AmortizationStatus.active,
          originalAmount: Money(minorUnits: 12000),
          recognizedAmount: Money(minorUnits: 2400),
          remainingAmount: Money(minorUnits: 9600),
          postedPeriodCount: 2,
          totalPeriodCount: 10,
        ),
      );
      final container = _container(
        businessService,
        metricsService,
        accountService,
        settingsStore: _MemorySettingsStore(
          const AppSettings(
            transactionListDisplayMode: TransactionListDisplayMode.compact,
          ),
        ),
        overrides: [
          homeBusinessActivitiesProvider(
            visibleMonth,
          ).overrideWith((ref) => Stream.value(_page([item]))),
          homeCashflowComparisonProvider(
            visibleMonth,
          ).overrideWith((ref) => Stream.value(_comparison())),
          homeDailyCashflowSummariesProvider(visibleMonth).overrideWith(
            (ref) => Stream.value([
              DailyCashflowSummary(
                date: DateTime(2026, 1, 1),
                income: Money.zero(),
                expense: Money.zero(),
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
      await container.read(homeBusinessActivitiesProvider(visibleMonth).future);
      await container.read(homeCashflowComparisonProvider(visibleMonth).future);
      await container.read(
        homeDailyCashflowSummariesProvider(visibleMonth).future,
      );
      await container.pump();
      await _flush();

      final loaded =
          container.read(homeContentProvider(visibleMonth))
              as HomeContentLoaded;
      final row = loaded.groups.single.rows.single;
      expect(row.title, '餐饮');
      expect(row.supportingText, isNull);
      expect(row.badges.map((badge) => badge.label), ['摊销 2/10']);
    });

    test('restarts queries when shifting month', () {
      final businessService = _FakeBusinessActivityQueryService();
      final metricsService = _FakeFinancialMetricsService();
      final accountService = _FakeAccountQueryService();
      final container = _container(
        businessService,
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
      expect(businessService.queries.last.occurredFrom, DateTime(2026, 2));
      expect(businessService.queries.last.occurredUntil, DateTime(2026, 3));
      expect(metricsService.comparisonQueries.last.month.year, 2026);
      expect(metricsService.comparisonQueries.last.month.month, 2);
      expect(metricsService.comparisonQueries.last.asOfDate, isNull);
    });

    test(
      'queries the first page of business activities in the visible month',
      () {
        final businessService = _FakeBusinessActivityQueryService();
        final metricsService = _FakeFinancialMetricsService();
        final accountService = _FakeAccountQueryService();
        final container = _container(
          businessService,
          metricsService,
          accountService,
        );
        final visibleMonth = DateTime(2026, 1);
        final contentSub = container.listen(
          homeContentProvider(visibleMonth),
          (_, _) {},
        );
        addTearDown(contentSub.close);

        final query = businessService.queries.single;

        expect(query.limit, homeBusinessActivityPageSize);
        expect(query.occurredFrom, DateTime(2026, 1));
        expect(query.occurredUntil, DateTime(2026, 2));
      },
    );

    test(
      'applies category and account filters to the business-activity query',
      () async {
        final businessService = _FakeBusinessActivityQueryService();
        final metricsService = _FakeFinancialMetricsService();
        final accountService = _FakeAccountQueryService();
        final container = _container(
          businessService,
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

        final query = businessService.queries.last;
        expect(query.categoryAccountIds, {'cat-food', 'cat-lunch'});
        expect(query.settlementAccountIds, {'acc-cash', 'acc-card'});
        expect(metricsService.comparisonQueries, hasLength(1));
        expect(metricsService.dailyQueries, hasLength(1));
      },
    );

    test(
      'loads the next month page with an exclusive business-activity cursor',
      () async {
        final businessService = _FakeBusinessActivityQueryService();
        final metricsService = _FakeFinancialMetricsService();
        final accountService = _FakeAccountQueryService(
          accountsById: const <String, Account>{},
        );
        final container = _container(
          businessService,
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
          for (var i = 0; i < homeBusinessActivityPageSize; i++)
            _businessActivity(
              id: 'tx-$i',
              occurredAt: DateTime(
                2026,
                1,
                2,
                8,
                0,
                homeBusinessActivityPageSize - i,
              ),
            ),
        ];
        businessService.emit(_page(firstPage, hasMore: true));
        await _flush();
        businessService.nextPage = _page([_businessActivity(id: 'tx-next')]);

        await container
            .read(homeTransactionFeedViewModelProvider(visibleMonth).notifier)
            .loadMore();

        final query = businessService.queries.last;
        expect(query.limit, homeBusinessActivityPageSize);
        expect(query.categoryAccountIds, {'cat-food'});
        expect(query.settlementAccountIds, {'acc-cash'});
        expect(
          query.before?.activityKey,
          const BusinessActivityKey.transactionGroup('tx-49'),
        );
        final state = container.read(
          homeTransactionFeedViewModelProvider(visibleMonth),
        );
        expect(state, isA<HomeTransactionFeedLoaded>());
        final loaded = state as HomeTransactionFeedLoaded;
        expect(loaded.items, hasLength(homeBusinessActivityPageSize + 1));
        expect(loaded.hasMore, isFalse);
      },
    );

    test(
      'keeps loaded pages in place until the user refreshes changed data',
      () async {
        final businessService = _FakeBusinessActivityQueryService();
        final metricsService = _FakeFinancialMetricsService();
        final accountService = _FakeAccountQueryService(
          accountsById: const <String, Account>{},
        );
        final container = _container(
          businessService,
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
          for (var i = 0; i < homeBusinessActivityPageSize; i++)
            _businessActivity(id: 'initial-$i'),
        ];
        businessService.emit(_page(firstPage, hasMore: true));
        await _flush();
        businessService.nextPage = _page([_businessActivity(id: 'older')]);
        await container
            .read(homeTransactionFeedViewModelProvider(visibleMonth).notifier)
            .loadMore();

        businessService.emit(_page([_businessActivity(id: 'newer')]));
        await _flush();

        var loaded =
            container.read(homeTransactionFeedViewModelProvider(visibleMonth))
                as HomeTransactionFeedLoaded;
        expect(loaded.items, hasLength(homeBusinessActivityPageSize + 1));
        expect(loaded.items.first.anchorTransactionId, 'initial-0');
        expect(loaded.hasPendingRefresh, isTrue);

        container
            .read(homeTransactionFeedViewModelProvider(visibleMonth).notifier)
            .refresh();
        await container.pump();
        businessService.emit(_page([_businessActivity(id: 'newer')]));
        await _flush();

        loaded =
            container.read(homeTransactionFeedViewModelProvider(visibleMonth))
                as HomeTransactionFeedLoaded;
        expect(loaded.items.map((item) => item.anchorTransactionId), ['newer']);
        expect(loaded.hasPendingRefresh, isFalse);
        expect(loaded.isRefreshing, isFalse);
      },
    );

    test('ignores an old in-flight page after the filter changes', () async {
      final businessService = _FakeBusinessActivityQueryService();
      final metricsService = _FakeFinancialMetricsService();
      final accountService = _FakeAccountQueryService(
        accountsById: const <String, Account>{},
      );
      final container = _container(
        businessService,
        metricsService,
        accountService,
      );
      final visibleMonth = DateTime(2026, 1);
      final sub = container.listen(
        homeTransactionFeedViewModelProvider(visibleMonth),
        (_, _) {},
      );
      addTearDown(sub.close);
      businessService.emit(
        _page([
          for (var i = 0; i < homeBusinessActivityPageSize; i++)
            _businessActivity(id: 'old-$i'),
        ], hasMore: true),
      );
      await _flush();
      final oldPage = Completer<BusinessActivityPage>();
      businessService.nextPageFuture = oldPage.future;

      final loadMore = container
          .read(homeTransactionFeedViewModelProvider(visibleMonth).notifier)
          .loadMore();
      container
          .read(homeViewModelProvider.notifier)
          .applyTransactionFilter(
            categoryAccountIds: {'cat-food'},
            settlementAccountIds: null,
          );
      await container.pump();
      oldPage.complete(_page([_businessActivity(id: 'old-next')]));
      await loadMore;
      businessService.emit(_page([_businessActivity(id: 'new-filter')]));
      await _flush();

      final state =
          container.read(homeTransactionFeedViewModelProvider(visibleMonth))
              as HomeTransactionFeedLoaded;
      expect(state.items.map((item) => item.anchorTransactionId), [
        'new-filter',
      ]);
      expect(state.hasPendingRefresh, isFalse);
    });

    test(
      'ignores exit calls on an auto-disposed batch mode notifier',
      () async {
        final container = ProviderContainer();
        addTearDown(container.dispose);

        final subscription = container.listen(homeBatchModeProvider, (_, _) {});
        final notifier = container.read(homeBatchModeProvider.notifier);
        subscription.close();
        await _flush();

        expect(notifier.exit, returnsNormally);
      },
    );
  });
}

ProviderContainer _container(
  _FakeBusinessActivityQueryService businessService,
  _FakeFinancialMetricsService metricsService,
  _FakeAccountQueryService accountService, {
  List<dynamic> overrides = const [],
  AppSettingsStore? settingsStore,
}) {
  final container = ProviderContainer(
    overrides: [
      currentDateTimeProvider.overrideWith((ref) => DateTime(2026, 1, 15, 9)),
      businessActivityQueryServiceProvider.overrideWithValue(businessService),
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
  addTearDown(businessService.dispose);
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

BusinessActivityReadModel _businessActivity({
  String id = 'tx-1',
  DateTime? occurredAt,
  TransactionReadModel? transaction,
  BusinessActivitySummary summary = const LedgerBusinessActivitySummary(),
}) {
  final anchor = transaction ?? _item(id: id, occurredAt: occurredAt);
  final ownership = anchor.ownership;
  return BusinessActivityReadModel.fromCandidate(
    candidate: BusinessActivityAnchorCandidate(
      activityKey: ownership == null
          ? BusinessActivityKey.transactionGroup(anchor.id)
          : BusinessActivityKey(
              type: ownership.ownerType,
              id: ownership.ownerId,
            ),
      anchorTransactionId: anchor.id,
      anchorAt: anchor.occurredAt,
    ),
    anchorTransaction: anchor,
    summary: summary,
  );
}

BusinessActivityPage _page(
  List<BusinessActivityReadModel> items, {
  bool hasMore = false,
}) {
  return BusinessActivityPage(items: items, hasMore: hasMore);
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

class _FakeBusinessActivityQueryService
    implements BusinessActivityQueryService {
  final queries = <BusinessActivityPageQuery>[];
  final _streams = <_ReplayStream<BusinessActivityPage>>[];
  BusinessActivityPage? nextPage;
  Future<BusinessActivityPage>? nextPageFuture;

  @override
  Stream<BusinessActivityPage> watchPage(BusinessActivityPageQuery query) {
    queries.add(query);
    final stream = _ReplayStream<BusinessActivityPage>();
    _streams.add(stream);
    return stream.watch();
  }

  @override
  Future<BusinessActivityPage> findPage(BusinessActivityPageQuery query) async {
    queries.add(query);
    if (nextPageFuture case final future?) return future;
    return nextPage ?? _page(const []);
  }

  void emit(BusinessActivityPage page) {
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
