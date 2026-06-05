import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:smartflow/app/provider.dart';
import 'package:smartflow/application/ledger/ledger_query_api.dart';
import 'package:smartflow/core/money/money.dart';
import 'package:smartflow/feature/home/view_model/home_view_model.dart';
import 'package:smartflow/feature/shared/provider/current_date_time_provider.dart';

void main() {
  group('HomeViewModel', () {
    test('combines month streams into loaded page state', () async {
      final transactionService = _FakeTransactionQueryService();
      final metricsService = _FakeFinancialMetricsService();
      final container = _container(transactionService, metricsService);

      container.listen(homeViewModelProvider, (_, _) {});
      expect(
        container.read(homeViewModelProvider).content,
        isA<HomeContentLoading>(),
      );

      transactionService.emit([_item()]);
      metricsService.emitComparison(_comparison());
      metricsService.emitDaily([
        DailyCashflowSummary(
          date: DateTime(2026, 1, 1),
          income: const Money(minorUnits: 10000),
          expense: const Money(minorUnits: 2500),
        ),
      ]);
      await _flush();

      final content = container.read(homeViewModelProvider).content;
      expect(content, isA<HomeContentLoaded>());
      final loaded = content as HomeContentLoaded;
      expect(loaded.summary.metrics.first.amountText, '100.00');
      expect(loaded.groups.single.incomeMinor, 10000);
    });

    test('restarts queries when shifting month', () {
      final transactionService = _FakeTransactionQueryService();
      final metricsService = _FakeFinancialMetricsService();
      final container = _container(transactionService, metricsService);

      container.listen(homeViewModelProvider, (_, _) {});
      container.read(homeViewModelProvider.notifier).shiftMonth(1);

      expect(
        container.read(homeViewModelProvider).visibleMonth,
        DateTime(2026, 2),
      );
      expect(
        container.read(homeViewModelProvider).content,
        isA<HomeContentLoading>(),
      );
      expect(transactionService.queries.last.occurredFrom, DateTime(2026, 2));
      expect(transactionService.queries.last.occurredUntil, DateTime(2026, 3));
      expect(metricsService.comparisonQueries.last.month.year, 2026);
      expect(metricsService.comparisonQueries.last.month.month, 2);
      expect(metricsService.comparisonQueries.last.asOfDate, isNull);
    });
  });
}

ProviderContainer _container(
  _FakeTransactionQueryService transactionService,
  _FakeFinancialMetricsService metricsService,
) {
  final container = ProviderContainer(
    overrides: [
      currentDateTimeProvider.overrideWith((ref) => DateTime(2026, 1, 15, 9)),
      transactionQueryServiceProvider.overrideWithValue(transactionService),
      financialMetricsServiceProvider.overrideWithValue(metricsService),
    ],
  );
  addTearDown(container.dispose);
  addTearDown(transactionService.dispose);
  addTearDown(metricsService.dispose);
  return container;
}

Future<void> _flush() async {
  await Future<void>.delayed(Duration.zero);
  await Future<void>.delayed(Duration.zero);
}

TransactionListItem _item() {
  return TransactionListItem(
    id: 'tx-1',
    rootTransactionId: 'tx-1',
    businessPurpose: BusinessPurpose.dailyIncome,
    businessState: BusinessState.current,
    occurredAt: DateTime(2026, 1, 1, 8),
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
