import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:smartflow/app/provider.dart';
import 'package:smartflow/application/ledger/ledger_query_api.dart';
import 'package:smartflow/core/money/money.dart';
import 'package:smartflow/feature/shared/presentation/account_lookup.dart';
import 'package:smartflow/feature/shared/provider/ledger_query_providers.dart';
import 'package:smartflow/feature/transaction/view_model/filtered_transactions_view_model.dart';

void main() {
  test(
    'category feed includes child categories and only top-level transactions',
    () async {
      final service = _RecordingTransactionQueryService();
      final container = ProviderContainer(
        overrides: [
          transactionQueryServiceProvider.overrideWithValue(service),
          accountLookupProvider.overrideWithValue(
            AsyncData(AccountLookup(_accounts)),
          ),
        ],
      );
      addTearDown(container.dispose);

      final provider = filteredTransactionsProvider(
        FilteredTransactionTarget.category,
        'food',
        filteredTransactionPageSize,
      );
      final subscription = container.listen(provider, (_, _) {});
      addTearDown(subscription.close);
      await container.read(provider.future);

      final query = service.queries.single;
      expect(query.categoryAccountIds, {'food', 'breakfast'});
      expect(query.tagIds, isNull);
      expect(query.topLevelOnly, isTrue);
      expect(query.limit, filteredTransactionPageSize);
    },
  );

  test('tag feed applies the selected tag filter', () async {
    final service = _RecordingTransactionQueryService();
    final container = ProviderContainer(
      overrides: [
        transactionQueryServiceProvider.overrideWithValue(service),
        accountLookupProvider.overrideWithValue(
          AsyncData(AccountLookup(_accounts)),
        ),
      ],
    );
    addTearDown(container.dispose);

    final provider = filteredTransactionsProvider(
      FilteredTransactionTarget.tag,
      'travel',
      filteredTransactionPageSize,
    );
    final subscription = container.listen(provider, (_, _) {});
    addTearDown(subscription.close);
    await container.read(provider.future);

    final query = service.queries.single;
    expect(query.categoryAccountIds, isNull);
    expect(query.tagIds, {'travel'});
    expect(query.topLevelOnly, isTrue);
  });
}

final _accounts = <String, Account>{
  'food': _category('food', '餐饮'),
  'breakfast': _category('breakfast', '早餐', parentId: 'food'),
};

Account _category(String id, String name, {String? parentId}) {
  return Account(
    id: id,
    name: name,
    type: AccountType.expense,
    parentId: parentId,
    balance: Money.zero(),
  );
}

class _RecordingTransactionQueryService implements TransactionQueryService {
  final queries = <TransactionListQuery>[];

  @override
  Stream<List<TransactionListReadModel>> watchTransactions(
    TransactionListQuery query,
  ) {
    queries.add(query);
    return Stream.value(const []);
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
