import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:smartflow/app/provider.dart';
import 'package:smartflow/application/ledger/ledger_query_api.dart';
import 'package:smartflow/core/money/money.dart';
import 'package:smartflow/feature/account/view_model/account_transactions_view_model.dart';
import 'package:smartflow/feature/shared/provider/ledger_query_providers.dart';
import 'package:smartflow/widget/business/transaction_list_presentation.dart';

void main() {
  group('AccountTransactionsViewModel', () {
    test('builds controlled rows in account ledger mode', () async {
      final transactionService = _FakeTransactionQueryService();
      final accountService = _FakeAccountQueryService(accountsById: _accounts);
      final container = _container(
        transactionService,
        accountService,
        overrides: [
          transactionListProvider(
            accountId: 'cash',
          ).overrideWith((ref) => Stream.value([_item()])),
        ],
      );

      final sub = container.listen(
        accountTransactionsViewModelProvider('cash'),
        (_, _) {},
      );
      addTearDown(sub.close);
      await container.read(transactionListProvider(accountId: 'cash').future);
      await container.read(accountsByIdProvider.future);
      await container.pump();
      await _flush();

      final state = container.read(
        accountTransactionsViewModelProvider('cash'),
      );
      expect(state, isA<AccountTransactionsLoaded>());
      final loaded = state as AccountTransactionsLoaded;
      expect(loaded.rows.single.transactionId, 'tx-1');
      expect(loaded.rows.single.amountText, '-12.34');
      expect(loaded.rows.single.amountTone, FinanceTone.neutral);
    });
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

TransactionListReadModel _item() {
  return TransactionListReadModel(
    id: 'tx-1',
    rootTransactionId: 'tx-1',
    businessPurpose: BusinessPurpose.dailyExpense,
    businessState: BusinessState.current,
    occurredAt: DateTime(2026, 1, 1, 8, 30),
    primaryAmount: const Money(minorUnits: 1234),
    isExcludedFromStats: false,
    isExcludedFromBudget: false,
    entries: const [
      Entry(
        id: 'entry-cash',
        transactionId: 'tx-1',
        accountId: 'cash',
        direction: EntryDirection.credit,
        amount: Money(minorUnits: 1234),
      ),
      Entry(
        id: 'entry-food',
        transactionId: 'tx-1',
        accountId: 'food',
        direction: EntryDirection.debit,
        amount: Money(minorUnits: 1234),
      ),
    ],
    details: const [],
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

  void close() {
    for (final controller in List.of(_controllers)) {
      controller.close();
    }
    _controllers.clear();
  }
}
