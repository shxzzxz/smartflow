import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:smartflow/app/provider.dart';
import 'package:smartflow/application/ledger/ledger_query_api.dart';
import 'package:smartflow/core/money/money.dart';
import 'package:smartflow/feature/account/view_model/account_transactions_view_model.dart';
import 'package:smartflow/feature/shared/provider/ledger_query_providers.dart';
import 'package:smartflow/widget/business/finance/finance_tone.dart';

void main() {
  group('AccountTransactionsViewModel', () {
    test('builds controlled day groups in account ledger mode', () async {
      final transactionService = _FakeTransactionQueryService();
      final accountService = _FakeAccountQueryService(accountsById: _accounts);
      final container = _container(
        transactionService,
        accountService,
        overrides: [
          transactionListProvider(
            settlementAccountId: 'cash',
            limit: accountTransactionPageSize,
          ).overrideWith((ref) => Stream.value([_item('tx-1')])),
        ],
      );

      final sub = container.listen(
        accountTransactionsViewModelProvider('cash'),
        (_, _) {},
      );
      addTearDown(sub.close);
      await container.read(
        transactionListProvider(
          settlementAccountId: 'cash',
          limit: accountTransactionPageSize,
        ).future,
      );
      await container.read(accountLookupProvider.future);
      await container.pump();
      await _flush();

      final state = container.read(
        accountTransactionsViewModelProvider('cash'),
      );
      expect(state, isA<AccountTransactionsLoaded>());
      final loaded = state as AccountTransactionsLoaded;
      final row = loaded.groups.single.rows.single;
      expect(row.transactionId, 'tx-1');
      expect(row.amountText, '-12.34');
      expect(row.amountTone, FinanceTone.neutral);
      expect(loaded.hasMore, isFalse);
    });

    test(
      'loads a larger prefix once and stops at the end of the feed',
      () async {
        final transactionService = _FakeTransactionQueryService();
        final accountService = _FakeAccountQueryService(
          accountsById: _accounts,
        );
        final firstPage = [
          for (var i = 0; i < accountTransactionPageSize; i++)
            _item('tx-$i', occurredAt: DateTime(2026, 1, 2, 8, i)),
        ];
        final container = _container(transactionService, accountService);

        final sub = container.listen(
          accountTransactionsViewModelProvider('cash'),
          (_, _) {},
        );
        addTearDown(sub.close);
        await container.read(accountLookupProvider.future);
        await container.pump();
        transactionService.emit(firstPage);
        await _flush();

        container
            .read(accountTransactionsViewModelProvider('cash').notifier)
            .loadMore();
        await container.pump();
        expect(transactionService.queries, hasLength(2));
        expect(transactionService.queries.last.limit, 40);
        expect(transactionService.queries.last.offset, 0);
        final loading = container.read(
          accountTransactionsViewModelProvider('cash'),
        );
        expect(loading, isA<AccountTransactionsLoaded>());
        expect((loading as AccountTransactionsLoaded).isLoadingMore, isTrue);

        container
            .read(accountTransactionsViewModelProvider('cash').notifier)
            .loadMore();
        expect(transactionService.queries, hasLength(2));

        transactionService.emit([
          ...firstPage,
          _item('tx-next', occurredAt: DateTime(2026, 1, 1, 8)),
        ]);
        await _flush();

        final state = container.read(
          accountTransactionsViewModelProvider('cash'),
        );
        expect(state, isA<AccountTransactionsLoaded>());
        final loaded = state as AccountTransactionsLoaded;
        expect(loaded.groups.expand((group) => group.rows), hasLength(21));
        expect(loaded.groups, hasLength(2));
        expect(loaded.hasMore, isFalse);

        container
            .read(accountTransactionsViewModelProvider('cash').notifier)
            .loadMore();
        expect(transactionService.queries, hasLength(2));
      },
    );

    test(
      'preserves rows and retries the same prefix after load-more failure',
      () async {
        final transactionService = _FakeTransactionQueryService();
        final accountService = _FakeAccountQueryService(
          accountsById: _accounts,
        );
        final firstPage = [
          for (var i = 0; i < accountTransactionPageSize; i++)
            _item('tx-$i', occurredAt: DateTime(2026, 1, 2, 8, i)),
        ];
        final container = _container(transactionService, accountService);

        final sub = container.listen(
          accountTransactionsViewModelProvider('cash'),
          (_, _) {},
        );
        addTearDown(sub.close);
        await container.read(accountLookupProvider.future);
        await container.pump();
        transactionService.emit(firstPage);
        await _flush();

        container
            .read(accountTransactionsViewModelProvider('cash').notifier)
            .loadMore();
        await container.pump();
        transactionService.fail(StateError('next page failed'));
        await _flush();

        final failed = container.read(
          accountTransactionsViewModelProvider('cash'),
        );
        expect(failed, isA<AccountTransactionsLoaded>());
        final failedLoaded = failed as AccountTransactionsLoaded;
        expect(failedLoaded.rows, hasLength(accountTransactionPageSize));
        expect(failedLoaded.hasMore, isTrue);
        expect(failedLoaded.isLoadingMore, isFalse);
        expect(failedLoaded.loadMoreErrorMessage, isNotNull);

        container
            .read(accountTransactionsViewModelProvider('cash').notifier)
            .loadMore();
        await container.pump();

        expect(transactionService.queries, hasLength(3));
        expect(transactionService.queries.last.limit, 40);
        expect(transactionService.queries.last.offset, 0);
        final retrying = container.read(
          accountTransactionsViewModelProvider('cash'),
        );
        expect(retrying, isA<AccountTransactionsLoaded>());
        expect((retrying as AccountTransactionsLoaded).isLoadingMore, isTrue);

        transactionService.emit([
          ...firstPage,
          _item('tx-next', occurredAt: DateTime(2026, 1, 1, 8)),
        ]);
        await _flush();
        final recovered =
            container.read(accountTransactionsViewModelProvider('cash'))
                as AccountTransactionsLoaded;
        expect(recovered.rows, hasLength(accountTransactionPageSize + 1));
        expect(recovered.loadMoreErrorMessage, isNull);
      },
    );
  });
}

ProviderContainer _container(
  _FakeTransactionQueryService transactionService,
  _FakeAccountQueryService accountService, {
  List<dynamic> overrides = const [],
}) {
  final container = ProviderContainer(
    overrides: [
      transactionQueryServiceProvider.overrideWithValue(transactionService),
      accountQueryServiceProvider.overrideWithValue(accountService),
      ...overrides,
    ],
  );
  addTearDown(container.dispose);
  addTearDown(transactionService.dispose);
  addTearDown(accountService.dispose);
  return container;
}

Future<void> _flush() async {
  await Future<void>.delayed(Duration.zero);
  await Future<void>.delayed(Duration.zero);
}

final _accounts = <String, Account>{
  'cash': _account('cash', '现金', iconKey: 'cash'),
  'food': _account('food', '餐饮', type: AccountType.expense, iconKey: 'meal'),
};

TransactionListReadModel _item(String id, {DateTime? occurredAt}) {
  return TransactionListReadModel(
    id: id,
    businessPurpose: BusinessPurpose.dailyExpense,
    occurredAt: occurredAt ?? DateTime(2026, 1, 1, 8, 30),
    primaryAmount: const Money(minorUnits: 1234),
    isExcludedFromStats: false,
    isExcludedFromBudget: false,
    primaryCategoryId: 'food',
    impactsByAccountId: const {
      'food': TransactionAccountImpact(
        debitAmount: Money(minorUnits: 1234),
        creditAmount: Money(minorUnits: 0),
        netChange: Money(minorUnits: 1234),
      ),
      'cash': TransactionAccountImpact(
        debitAmount: Money(minorUnits: 0),
        creditAmount: Money(minorUnits: 1234),
        netChange: Money(minorUnits: -1234),
      ),
    },
    adjustments: const [],
  );
}

Account _account(
  String id,
  String name, {
  AccountType type = AccountType.asset,
  String? iconKey,
}) {
  return Account(
    id: id,
    name: name,
    type: type,
    iconKey: iconKey,
    balance: const Money(minorUnits: 0),
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

  void fail(Object error) {
    _streams.last.addError(error);
  }

  void dispose() {
    for (final stream in _streams) {
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

  void addError(Object error) {
    for (final controller in List.of(_controllers)) {
      if (!controller.isClosed) {
        controller.addError(error);
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
