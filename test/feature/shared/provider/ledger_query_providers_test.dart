import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:smartflow/app/provider.dart';
import 'package:smartflow/application/ledger/ledger_query_api.dart';
import 'package:smartflow/core/money/money.dart';
import 'package:smartflow/feature/shared/provider/current_date_time_provider.dart';
import 'package:smartflow/feature/shared/provider/ledger_query_providers.dart';

void main() {
  test('account feed uses ledger impact semantics with child transactions', () {
    final service = _CapturingTransactionQueryService();
    final container = ProviderContainer(
      overrides: [transactionQueryServiceProvider.overrideWithValue(service)],
    );
    addTearDown(container.dispose);

    final subscription = container.listen(
      transactionListProvider(settlementAccountId: 'cash', limit: 20),
      (_, _) {},
    );
    addTearDown(subscription.close);

    final query = service.queries.single;
    expect(query.match, isA<TransactionImpactMatch>());
    expect(query.match.settlementAccountIds, {'cash'});
    expect(query.topLevelOnly, isFalse);
  });

  test('current balance metrics include later writes from the same day', () {
    final service = _CapturingFinancialMetricsService();
    final container = ProviderContainer(
      overrides: [
        currentDateTimeProvider.overrideWithValue(DateTime(2026, 7, 14, 9)),
        financialMetricsServiceProvider.overrideWithValue(service),
      ],
    );
    addTearDown(container.dispose);

    final balanceSubscription = container.listen(
      balanceSheetComparisonProvider,
      (_, _) {},
    );
    final trendSubscription = container.listen(
      netAssetTrendProvider(),
      (_, _) {},
    );
    addTearDown(balanceSubscription.close);
    addTearDown(trendSubscription.close);

    expect(service.balanceQuery?.asOfExclusive, DateTime(2026, 7, 15));
    expect(service.trendQuery?.currentAsOfExclusive, DateTime(2026, 7, 15));
  });
}

class _CapturingFinancialMetricsService implements FinancialMetricsService {
  BalanceSheetComparisonQuery? balanceQuery;
  NetAssetTrendQuery? trendQuery;

  @override
  Stream<BalanceSheetComparison> watchBalanceSheetComparison(
    BalanceSheetComparisonQuery query,
  ) {
    balanceQuery = query;
    return Stream.value(
      const BalanceSheetComparison(
        current: BalanceSheetSnapshot(
          assets: Money(minorUnits: 0),
          liabilities: Money(minorUnits: 0),
        ),
        previous: BalanceSheetSnapshot(
          assets: Money(minorUnits: 0),
          liabilities: Money(minorUnits: 0),
        ),
      ),
    );
  }

  @override
  Stream<List<NetAssetTrendPoint>> watchNetAssetTrend(
    NetAssetTrendQuery query,
  ) {
    trendQuery = query;
    return Stream.value(const []);
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _CapturingTransactionQueryService implements TransactionQueryService {
  final queries = <TransactionListQuery>[];

  @override
  Stream<List<TransactionReadModel>> watchTransactions(
    TransactionListQuery query,
  ) {
    queries.add(query);
    return Stream.value(const []);
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
