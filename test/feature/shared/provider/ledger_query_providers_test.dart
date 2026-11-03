import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:smartflow/app/provider.dart';
import 'package:smartflow/application/ledger/ledger_query_api.dart';
import 'package:smartflow/application/transaction_view/transaction_view_query_api.dart';
import 'package:smartflow/core/money/money.dart';
import 'package:smartflow/feature/shared/provider/current_date_time_provider.dart';
import 'package:smartflow/feature/shared/provider/ledger_query_providers.dart';

void main() {
  test('account feed uses ledger impact semantics with child transactions', () {
    final service = _CapturingTransactionFeedQueryService();
    final container = ProviderContainer(
      overrides: [
        transactionFeedQueryServiceProvider.overrideWithValue(service),
      ],
    );
    addTearDown(container.dispose);

    final subscription = container.listen(
      transactionFeedProvider(settlementAccountId: 'cash', limit: 20),
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

class _CapturingTransactionFeedQueryService
    implements TransactionFeedQueryService {
  final queries = <TransactionListQuery>[];

  @override
  Stream<List<TransactionFeedEntry>> watchTransactions(
    TransactionListQuery query,
  ) {
    queries.add(query);
    return Stream.value(const []);
  }

  @override
  Future<List<TransactionFeedEntry>> findTransactions(
    TransactionListQuery query,
  ) {
    throw UnsupportedError('Only stream queries are used by this test.');
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
