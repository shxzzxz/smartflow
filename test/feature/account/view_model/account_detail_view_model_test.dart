import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:smartflow/app/provider.dart';
import 'package:smartflow/application/credit/credit_command_api.dart';
import 'package:smartflow/application/ledger/ledger_query_api.dart';
import 'package:smartflow/core/money/money.dart';
import 'package:smartflow/feature/account/view_model/account_detail_view_model.dart';
import 'package:smartflow/widget/business/transaction_list_presentation.dart';

void main() {
  group('AccountDetailViewModel', () {
    test('builds account detail with controlled transaction groups', () async {
      final transactionService = _FakeTransactionQueryService();
      final accountService = _FakeAccountQueryService(accountsById: _accounts);
      final installmentService = _FakeInstallmentService();
      final container = _container(
        transactionService,
        accountService,
        installmentService,
        overrides: [
          accountListProvider.overrideWith(
            (ref) => Stream.value([_account('cash', '现金')]),
          ),
          transactionListProvider(
            accountId: 'cash',
          ).overrideWith((ref) => Stream.value([_item()])),
        ],
      );

      final sub = container.listen(
        accountDetailViewModelProvider('cash'),
        (_, _) {},
      );
      addTearDown(sub.close);
      await container.read(accountListProvider.future);
      await container.read(transactionListProvider(accountId: 'cash').future);
      await container.read(accountsByIdProvider.future);
      await container.pump();
      await _flush();

      final state = container.read(accountDetailViewModelProvider('cash'));
      expect(state, isA<AccountDetailLoaded>());
      final loaded = state as AccountDetailLoaded;
      expect(loaded.account.name, '现金');
      expect(loaded.transactionGroups.single.rows.single.amountText, '-12.34');
      expect(
        loaded.transactionGroups.single.rows.single.amountTone,
        FinanceTone.expense,
      );
      expect(loaded.contracts, isA<AccountContractsNotApplicable>());
    });

    test('reports not found when account list does not contain id', () async {
      final transactionService = _FakeTransactionQueryService();
      final accountService = _FakeAccountQueryService(accountsById: _accounts);
      final installmentService = _FakeInstallmentService();
      final container = _container(
        transactionService,
        accountService,
        installmentService,
        overrides: [
          accountListProvider.overrideWith(
            (ref) => Stream.value([_account('cash', '现金')]),
          ),
          transactionListProvider(
            accountId: 'missing',
          ).overrideWith((ref) => Stream.value(const [])),
        ],
      );

      final sub = container.listen(
        accountDetailViewModelProvider('missing'),
        (_, _) {},
      );
      addTearDown(sub.close);
      await container.read(accountListProvider.future);
      await container.read(
        transactionListProvider(accountId: 'missing').future,
      );
      await container.read(accountsByIdProvider.future);
      await container.pump();
      await _flush();

      expect(
        container.read(accountDetailViewModelProvider('missing')),
        isA<AccountDetailNotFound>(),
      );
    });

    test('loads installment contracts for liability account', () async {
      final transactionService = _FakeTransactionQueryService();
      final accountService = _FakeAccountQueryService(
        accountsById: {
          ..._accounts,
          'card': _account('card', '信用卡', type: AccountType.liability),
        },
      );
      final installmentService = _FakeInstallmentService();
      final container = _container(
        transactionService,
        accountService,
        installmentService,
        overrides: [
          accountListProvider.overrideWith(
            (ref) => Stream.value([
              _account('card', '信用卡', type: AccountType.liability),
            ]),
          ),
          transactionListProvider(
            accountId: 'card',
          ).overrideWith((ref) => Stream.value(const [])),
          installmentContractsByAccountProvider(
            'card',
          ).overrideWith((ref) async => [_contract()]),
        ],
      );

      final sub = container.listen(
        accountDetailViewModelProvider('card'),
        (_, _) {},
      );
      addTearDown(sub.close);
      await container.read(accountListProvider.future);
      await container.read(transactionListProvider(accountId: 'card').future);
      await container.read(accountsByIdProvider.future);
      await container.read(
        installmentContractsByAccountProvider('card').future,
      );
      await container.pump();
      await _flush();

      final state = container.read(accountDetailViewModelProvider('card'));
      expect(state, isA<AccountDetailLoaded>());
      final loaded = state as AccountDetailLoaded;
      expect(loaded.contracts, isA<AccountContractsLoaded>());
      expect(
        (loaded.contracts as AccountContractsLoaded).contracts.single.id,
        'contract-1',
      );
    });
  });
}

ProviderContainer _container(
  _FakeTransactionQueryService transactionService,
  _FakeAccountQueryService accountService,
  _FakeInstallmentService installmentService, {
  List<dynamic> overrides = const [],
}) {
  final container = ProviderContainer(
    overrides: [
      transactionQueryServiceProvider.overrideWithValue(transactionService),
      accountQueryServiceProvider.overrideWithValue(accountService),
      installmentServiceProvider.overrideWithValue(installmentService),
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

InstallmentContract _contract() {
  return InstallmentContract(
    id: 'contract-1',
    liabilityAccountId: 'card',
    sourceType: InstallmentSourceType.billConversion,
    principal: const Money(minorUnits: 10000),
    totalPeriods: 3,
    borrowingDate: DateTime(2026, 1, 1),
    firstRepaymentDate: DateTime(2026, 2, 1),
    lastRepaymentDate: DateTime(2026, 4, 1),
    repaymentMethod: InstallmentRepaymentMethod.equalInstallment,
    interestAccrualMethod: InterestAccrualMethod.monthly,
    totalFeeMinor: 0,
    status: InstallmentContractStatus.active,
    createdAt: DateTime(2026, 1, 1),
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
  final _accountsStreams = <_ReplayStream<List<Account>>>[];
  final _byIdStreams = <_ReplayStream<Map<String, Account>>>[];

  @override
  Stream<List<Account>> watchAccounts(Set<AccountType> types) {
    final stream = _ReplayStream<List<Account>>();
    _accountsStreams.add(stream);
    return stream.watch();
  }

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

  void emitAccounts(List<Account> value) {
    _accountsStreams.last.add(value);
  }

  void emitById(Map<String, Account> value) {
    _byIdStreams.last.add(value);
  }

  void dispose() {
    for (final stream in _accountsStreams) {
      stream.close();
    }
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

class _FakeInstallmentService implements InstallmentService {
  final _contractsCompleter = Completer<List<InstallmentContract>>();

  @override
  Future<List<InstallmentContract>> listContractsByLiabilityAccount(
    String liabilityAccountId,
  ) {
    return _contractsCompleter.future;
  }

  void completeContracts(List<InstallmentContract> contracts) {
    _contractsCompleter.complete(contracts);
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
