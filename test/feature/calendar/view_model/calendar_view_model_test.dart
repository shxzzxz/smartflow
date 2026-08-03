import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:smartflow/app/provider.dart';
import 'package:smartflow/application/credit/credit_query_api.dart';
import 'package:smartflow/application/ledger/ledger_query_api.dart';
import 'package:smartflow/core/money/money.dart';
import 'package:smartflow/feature/calendar/view_model/calendar_view_model.dart';
import 'package:smartflow/feature/shared/provider/current_date_time_provider.dart';
import 'package:smartflow/feature/shared/provider/ledger_query_providers.dart';

void main() {
  group('CalendarViewModel', () {
    test(
      'combines streams and updates selected date within same month',
      () async {
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
            calendarTransactionsProvider(visibleMonth).overrideWith(
              (ref) => Stream.value([_item(DateTime(2026, 1, 2, 8))]),
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
        final initialState = container.read(calendarViewModelProvider);
        final contentSub = container.listen(
          calendarContentProvider(
            visibleMonth: initialState.visibleMonth,
            selectedDate: initialState.selectedDate,
          ),
          (_, _) {},
        );
        addTearDown(contentSub.close);
        await container.read(calendarTransactionsProvider(visibleMonth).future);
        await container.read(
          calendarCashflowComparisonProvider(visibleMonth).future,
        );
        await container.read(
          calendarDailyCashflowSummariesProvider(visibleMonth).future,
        );
        await container.pump();
        await _flush();

        container
            .read(calendarViewModelProvider.notifier)
            .selectDate(DateTime(2026, 1, 2));

        final state = container.read(calendarViewModelProvider);
        expect(state.visibleMonth, DateTime(2026, 1));
        expect(state.selectedDate, DateTime(2026, 1, 2));
        final loaded =
            container.read(
                  calendarContentProvider(
                    visibleMonth: state.visibleMonth,
                    selectedDate: state.selectedDate,
                  ),
                )
                as CalendarContentLoaded;
        expect(loaded.month.selectedGroup.date, DateTime(2026, 1, 2));
        expect(loaded.month.selectedGroup.rows.single.transactionId, 'tx-1');
      },
    );

    test('shifts month and clamps selected date', () {
      final transactionService = _FakeTransactionQueryService();
      final metricsService = _FakeFinancialMetricsService();
      final accountService = _FakeAccountQueryService();
      final container = _container(
        transactionService,
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
      expect(transactionService.queries.last.occurredFrom, DateTime(2026, 2));
      expect(transactionService.queries.last.occurredUntil, DateTime(2026, 3));
    });

    test('toggle lunar does not restart month queries', () {
      final transactionService = _FakeTransactionQueryService();
      final metricsService = _FakeFinancialMetricsService();
      final accountService = _FakeAccountQueryService();
      final container = _container(
        transactionService,
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
      expect(transactionService.queries, hasLength(1));
    });
  });
}

ProviderContainer _container(
  _FakeTransactionQueryService transactionService,
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
      transactionQueryServiceProvider.overrideWithValue(transactionService),
      financialMetricsServiceProvider.overrideWithValue(metricsService),
      accountQueryServiceProvider.overrideWithValue(accountService),
      creditAccountQueryServiceProvider.overrideWithValue(
        const _FakeCreditAccountQueryService(),
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

Future<void> _flush() async {
  await Future<void>.delayed(Duration.zero);
  await Future<void>.delayed(Duration.zero);
}

TransactionListReadModel _item(DateTime occurredAt) {
  return TransactionListReadModel(
    id: 'tx-1',
    businessPurpose: BusinessPurpose.dailyIncome,
    occurredAt: occurredAt,
    primaryAmount: const Money(minorUnits: 10000),
    isExcludedFromStats: false,
    isExcludedFromBudget: false,
    category: null,
    settlementEntries: const [],
    adjustments: const [],
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
  final _streams = <_ReplayStream<List<TransactionListReadModel>>>[];

  @override
  Stream<List<TransactionListReadModel>> watchTransactions(
    TransactionListQuery query,
  ) {
    queries.add(query);
    final stream = _ReplayStream<List<TransactionListReadModel>>();
    _streams.add(stream);
    return stream.watch();
  }

  void emit(List<TransactionListReadModel> items) {
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
