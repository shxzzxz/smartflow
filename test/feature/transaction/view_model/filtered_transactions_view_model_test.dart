import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:smartflow/app/provider.dart';
import 'package:smartflow/application/ledger/ledger_query_api.dart';
import 'package:smartflow/application/ledger/ledger_command_api.dart';
import 'package:smartflow/core/money/money.dart';
import 'package:smartflow/feature/shared/presentation/account_lookup.dart';
import 'package:smartflow/feature/shared/provider/counterparty_providers.dart';
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
      expect(query.match.categoryAccountIds, {'food', 'breakfast'});
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
    expect(query.match.categoryAccountIds, isNull);
    expect(query.tagIds, {'travel'});
    expect(query.topLevelOnly, isTrue);
  });

  test('counterparty feed applies the selected counterparty filter', () async {
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
      FilteredTransactionTarget.counterparty,
      'ziroom',
      filteredTransactionPageSize,
    );
    final subscription = container.listen(provider, (_, _) {});
    addTearDown(subscription.close);
    await container.read(provider.future);

    final query = service.queries.single;
    expect(query.counterpartyId, 'ziroom');
    expect(query.tagIds, isNull);
    expect(query.topLevelOnly, isTrue);
  });

  test('counterparty feed labels the current vocabulary name', () async {
    final service = _RecordingTransactionQueryService();
    final container = ProviderContainer(
      overrides: [
        transactionQueryServiceProvider.overrideWithValue(service),
        accountLookupProvider.overrideWithValue(
          AsyncData(AccountLookup(_accounts)),
        ),
        counterpartyListProvider.overrideWithValue(
          const AsyncData([
            CounterpartyView(id: 'ziroom', name: '自如', usageCount: 2),
          ]),
        ),
      ],
    );
    addTearDown(container.dispose);

    final provider = filteredTransactionsViewModelProvider(
      FilteredTransactionTarget.counterparty,
      'ziroom',
    );
    final subscription = container.listen(provider, (_, _) {});
    addTearDown(subscription.close);
    for (var i = 0; i < 10; i++) {
      await Future<void>.delayed(Duration.zero);
      await container.pump();
    }

    final state = container.read(provider);
    expect(state, isA<FilteredTransactionsLoaded>());
    final loaded = state as FilteredTransactionsLoaded;
    expect(loaded.title, '自如');
    expect(loaded.subtitle, '对手方交易');
  });

  test(
    'selection survives paging and excludes transactions removed by refresh',
    () async {
      final fixture = await _BatchFixture.create(count: 21);
      addTearDown(fixture.dispose);
      final vm = fixture.viewModel;
      vm.enterBatchMode('tx-0');
      vm.toggleSelectAll();
      expect(fixture.state.selectedVisibleIds.length, 20);

      vm.loadMore();
      await fixture.flush();
      expect(fixture.state.visibleTransactionIds.length, 21);
      expect(fixture.state.selectedVisibleIds.length, 20);
      expect(fixture.state.selectedVisibleIds, isNot(contains('tx-20')));
      vm.toggleSelectAll();
      expect(fixture.state.selectedVisibleIds.length, 21);

      fixture.query.items = fixture.query.items.skip(1).toList();
      fixture.query.changes.add(fixture.query.items);
      await fixture.flush();
      expect(fixture.state.selectedVisibleIds.length, 20);
      expect(fixture.state.selectedVisibleIds, isNot(contains('tx-0')));
      vm.toggleSelectAll();
      expect(fixture.state.selectedVisibleIds, isEmpty);
      vm.exitBatchMode();
      expect(fixture.state.batch.active, isFalse);
      expect(fixture.state.batch.selectedIds, isEmpty);
    },
  );

  for (final operation in TransactionTagBatchOperation.values) {
    test(
      'category batch forwards $operation with selected transaction and tag ids',
      () async {
        final fixture = await _BatchFixture.create();
        addTearDown(fixture.dispose);
        fixture.viewModel.enterBatchMode('tx-0');
        final tagIds = operation == TransactionTagBatchOperation.clear
            ? <String>{}
            : {'travel'};
        await fixture.viewModel.updateTags(
          ids: fixture.state.selectedVisibleIds,
          operation: operation,
          tagIds: tagIds,
        );
        final command = fixture.service.tagCommands.single;
        expect(command.transactionIds, {'tx-0'});
        expect(command.operation, operation);
        expect(command.tagIds, tagIds);
        expect(fixture.state.batch.active, isTrue);
        expect(fixture.state.batch.submitting, isFalse);
      },
    );
  }

  test('batch submission locks selection and recovers after failure', () async {
    final fixture = await _BatchFixture.create();
    addTearDown(fixture.dispose);
    final completion = Completer<TransactionBatchTagResult>();
    fixture.service.tagResult = completion.future;
    final vm = fixture.viewModel;
    vm.enterBatchMode('tx-0');
    final pending = vm.updateTags(
      ids: fixture.state.selectedVisibleIds,
      operation: TransactionTagBatchOperation.add,
      tagIds: {'travel'},
    );
    expect(fixture.state.batch.submitting, isTrue);
    vm.toggleSelectAll();
    vm.setTransactionSelected('tx-1', true);
    vm.exitBatchMode();
    expect(fixture.state.selectedVisibleIds, {'tx-0'});
    expect(fixture.state.batch.active, isTrue);

    final assertion = expectLater(pending, throwsA(isA<Exception>()));
    completion.completeError(Exception('save failed'));
    await assertion;
    expect(fixture.state.batch.submitting, isFalse);
    expect(fixture.state.selectedVisibleIds, {'tx-0'});
    vm.setTransactionSelected('tx-1', true);
    expect(fixture.state.selectedVisibleIds, {'tx-0', 'tx-1'});
  });

  test(
    'partial delete retains skipped selection and full delete exits batch',
    () async {
      final fixture = await _BatchFixture.create();
      addTearDown(fixture.dispose);
      final vm = fixture.viewModel;
      vm.enterBatchMode('tx-0');
      vm.toggleSelectAll();
      fixture.service.deleteResult = const TransactionCleanupResult(
        deletedGroupCount: 1,
        skippedGroupCount: 1,
      );
      await vm.deleteTransactions(fixture.state.selectedVisibleIds);
      expect(fixture.service.deleteCommands.single.transactionIds, {
        'tx-0',
        'tx-1',
      });
      fixture.query.items = fixture.query.items.skip(1).toList();
      fixture.query.changes.add(fixture.query.items);
      await fixture.flush();
      expect(fixture.state.batch.active, isTrue);
      expect(fixture.state.batch.submitting, isFalse);
      expect(fixture.state.selectedVisibleIds, {'tx-1'});

      fixture.service.deleteResult = const TransactionCleanupResult(
        deletedGroupCount: 1,
        skippedGroupCount: 0,
      );
      await vm.deleteTransactions(fixture.state.selectedVisibleIds);
      expect(fixture.state.batch.active, isFalse);
      expect(fixture.state.batch.selectedIds, isEmpty);
    },
  );

  test(
    'delete failure restores actions and retains selection for retry',
    () async {
      final fixture = await _BatchFixture.create();
      addTearDown(fixture.dispose);
      fixture.viewModel.enterBatchMode('tx-0');
      fixture.service.deleteError = Exception('delete failed');
      await expectLater(
        fixture.viewModel.deleteTransactions(fixture.state.selectedVisibleIds),
        throwsA(isA<Exception>()),
      );
      expect(fixture.state.batch.active, isTrue);
      expect(fixture.state.batch.submitting, isFalse);
      expect(fixture.state.selectedVisibleIds, {'tx-0'});
    },
  );
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
  Stream<List<TransactionReadModel>> watchTransactions(
    TransactionListQuery query,
  ) {
    queries.add(query);
    return Stream.value(const []);
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _BatchFixture {
  _BatchFixture(this.container, this.query, this.service);

  final ProviderContainer container;
  final _BatchQueryService query;
  final _RecordingBatchService service;
  final provider = filteredTransactionsViewModelProvider(
    FilteredTransactionTarget.category,
    'food',
  );

  FilteredTransactionsViewModel get viewModel =>
      container.read(provider.notifier);
  FilteredTransactionsLoaded get state =>
      container.read(provider) as FilteredTransactionsLoaded;

  static Future<_BatchFixture> create({int count = 2}) async {
    final query = _BatchQueryService(count);
    final service = _RecordingBatchService();
    final container = ProviderContainer(
      overrides: [
        transactionQueryServiceProvider.overrideWithValue(query),
        transactionBatchOperationAppServiceProvider.overrideWithValue(service),
        accountLookupProvider.overrideWithValue(
          AsyncData(AccountLookup(_accounts)),
        ),
      ],
    );
    final fixture = _BatchFixture(container, query, service);
    container.listen(fixture.provider, (_, _) {});
    await fixture.flush();
    return fixture;
  }

  Future<void> flush() async {
    for (var i = 0; i < 10; i++) {
      await Future<void>.delayed(Duration.zero);
      await container.pump();
    }
  }

  Future<void> dispose() async {
    container.dispose();
    await query.changes.close();
  }
}

class _BatchQueryService implements TransactionQueryService {
  _BatchQueryService(int count)
    : items = [
        for (var i = 0; i < count; i++)
          TransactionReadModel(
            id: 'tx-$i',
            businessPurpose: BusinessPurpose.dailyExpense,
            occurredAt: DateTime(2026, 10, 1, 12),
            primaryAmount: const Money(minorUnits: 1234),
            isExcludedFromStats: false,
            isExcludedFromBudget: false,
            impactsByAccountId: const {},
          ),
      ];

  List<TransactionReadModel> items;
  final changes = StreamController<List<TransactionReadModel>>.broadcast();

  @override
  Stream<List<TransactionReadModel>> watchTransactions(
    TransactionListQuery query,
  ) async* {
    yield items.take(query.limit!).toList();
    yield* changes.stream.map((items) => items.take(query.limit!).toList());
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _RecordingBatchService implements TransactionBatchOperationAppService {
  final tagCommands = <BatchTransactionTagsCommand>[];
  final deleteCommands = <BatchDeleteTransactionsCommand>[];
  Future<TransactionBatchTagResult>? tagResult;
  Exception? deleteError;
  TransactionCleanupResult deleteResult = const TransactionCleanupResult(
    deletedGroupCount: 1,
    skippedGroupCount: 0,
  );

  @override
  Future<TransactionCleanupResult> deleteTransactions(
    BatchDeleteTransactionsCommand command,
  ) async {
    deleteCommands.add(command);
    if (deleteError case final error?) throw error;
    return deleteResult;
  }

  @override
  Future<TransactionBatchTagResult> updateTags(
    BatchTransactionTagsCommand command,
  ) {
    tagCommands.add(command);
    return tagResult ??
        Future.value(
          const TransactionBatchTagResult(
            updatedGroupCount: 1,
            skippedGroupCount: 0,
          ),
        );
  }
}
