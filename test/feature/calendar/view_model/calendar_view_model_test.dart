import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:smartflow/app/provider.dart';
import 'package:smartflow/application/ledger/ledger_query_api.dart';
import 'package:smartflow/core/money/money.dart';
import 'package:smartflow/feature/calendar/view_model/calendar_view_model.dart';
import 'package:smartflow/feature/shared/provider/current_date_time_provider.dart';

void main() {
  group('CalendarViewModel', () {
    test(
      'combines streams and updates selected date within same month',
      () async {
        final transactionService = _FakeTransactionQueryService();
        final metricsService = _FakeFinancialMetricsService();
        final container = _container(transactionService, metricsService);

        container.listen(calendarViewModelProvider, (_, _) {});
        _emitLoaded(transactionService, metricsService);
        await _flush();

        container
            .read(calendarViewModelProvider.notifier)
            .selectDate(DateTime(2026, 1, 2));

        final state = container.read(calendarViewModelProvider);
        expect(state.visibleMonth, DateTime(2026, 1));
        expect(state.selectedDate, DateTime(2026, 1, 2));
        expect(transactionService.queries, hasLength(1));
        final loaded = state.content as CalendarContentLoaded;
        expect(loaded.month.selectedGroup.date, DateTime(2026, 1, 2));
      },
    );

    test('shifts month and clamps selected date', () {
      final transactionService = _FakeTransactionQueryService();
      final metricsService = _FakeFinancialMetricsService();
      final container = _container(
        transactionService,
        metricsService,
        now: DateTime(2026, 1, 31),
      );

      container.listen(calendarViewModelProvider, (_, _) {});
      container.read(calendarViewModelProvider.notifier).shiftMonth(1);

      final state = container.read(calendarViewModelProvider);
      expect(state.visibleMonth, DateTime(2026, 2));
      expect(state.selectedDate, DateTime(2026, 2, 28));
      expect(state.content, isA<CalendarContentLoading>());
      expect(transactionService.queries.last.occurredFrom, DateTime(2026, 2));
      expect(transactionService.queries.last.occurredUntil, DateTime(2026, 3));
    });

    test('toggle lunar does not restart month queries', () {
      final transactionService = _FakeTransactionQueryService();
      final metricsService = _FakeFinancialMetricsService();
      final container = _container(transactionService, metricsService);

      container.listen(calendarViewModelProvider, (_, _) {});
      container.read(calendarViewModelProvider.notifier).toggleLunar();

      expect(container.read(calendarViewModelProvider).showLunar, false);
      expect(transactionService.queries, hasLength(1));
    });

    test('maps stream error to page error state', () async {
      final transactionService = _FakeTransactionQueryService();
      final metricsService = _FakeFinancialMetricsService();
      final container = _container(transactionService, metricsService);

      container.listen(calendarViewModelProvider, (_, _) {});
      transactionService.emitError(Exception('db failed'));
      await _flush();

      final content = container.read(calendarViewModelProvider).content;
      expect(content, isA<CalendarContentError>());
      expect((content as CalendarContentError).message, contains('db failed'));
    });
  });
}

ProviderContainer _container(
  _FakeTransactionQueryService transactionService,
  _FakeFinancialMetricsService metricsService, {
  DateTime? now,
}) {
  final container = ProviderContainer(
    overrides: [
      currentDateTimeProvider.overrideWith(
        (ref) => now ?? DateTime(2026, 1, 15, 9),
      ),
      transactionQueryServiceProvider.overrideWithValue(transactionService),
      financialMetricsServiceProvider.overrideWithValue(metricsService),
    ],
  );
  addTearDown(container.dispose);
  addTearDown(transactionService.dispose);
  addTearDown(metricsService.dispose);
  return container;
}

void _emitLoaded(
  _FakeTransactionQueryService transactionService,
  _FakeFinancialMetricsService metricsService,
) {
  transactionService.emit([_item(DateTime(2026, 1, 2, 8))]);
  metricsService.emitComparison(_comparison());
  metricsService.emitDaily([
    DailyCashflowSummary(
      date: DateTime(2026, 1, 2),
      income: const Money(minorUnits: 10000),
      expense: const Money(minorUnits: 2500),
    ),
  ]);
}

Future<void> _flush() async {
  await Future<void>.delayed(Duration.zero);
  await Future<void>.delayed(Duration.zero);
}

TransactionListItem _item(DateTime occurredAt) {
  return TransactionListItem(
    id: 'tx-1',
    rootTransactionId: 'tx-1',
    businessPurpose: BusinessPurpose.dailyIncome,
    businessState: BusinessState.current,
    occurredAt: occurredAt,
    primaryAmount: const Money(minorUnits: 10000),
    isExcludedFromStats: false,
    isExcludedFromBudget: false,
    entries: const [],
    details: const [],
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
  final _controllers = <StreamController<List<TransactionListItem>>>[];

  @override
  Stream<List<TransactionListItem>> watchTransactions(
    TransactionListQuery query,
  ) {
    queries.add(query);
    final controller = StreamController<List<TransactionListItem>>.broadcast();
    _controllers.add(controller);
    return controller.stream;
  }

  void emit(List<TransactionListItem> items) {
    _controllers.last.add(items);
  }

  void emitError(Object error) {
    _controllers.last.addError(error);
  }

  void dispose() {
    for (final controller in _controllers) {
      controller.close();
    }
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _FakeFinancialMetricsService implements FinancialMetricsService {
  final comparisonQueries = <CashflowComparisonQuery>[];
  final dailyQueries = <DailyCashflowSummaryQuery>[];
  final _comparisonControllers = <StreamController<CashflowComparison>>[];
  final _dailyControllers = <StreamController<List<DailyCashflowSummary>>>[];

  @override
  Stream<CashflowComparison> watchCashflowComparison(
    CashflowComparisonQuery query,
  ) {
    comparisonQueries.add(query);
    final controller = StreamController<CashflowComparison>.broadcast();
    _comparisonControllers.add(controller);
    return controller.stream;
  }

  @override
  Stream<List<DailyCashflowSummary>> watchDailyCashflowSummaries(
    DailyCashflowSummaryQuery query,
  ) {
    dailyQueries.add(query);
    final controller = StreamController<List<DailyCashflowSummary>>.broadcast();
    _dailyControllers.add(controller);
    return controller.stream;
  }

  void emitComparison(CashflowComparison value) {
    _comparisonControllers.last.add(value);
  }

  void emitDaily(List<DailyCashflowSummary> value) {
    _dailyControllers.last.add(value);
  }

  void dispose() {
    for (final controller in _comparisonControllers) {
      controller.close();
    }
    for (final controller in _dailyControllers) {
      controller.close();
    }
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
