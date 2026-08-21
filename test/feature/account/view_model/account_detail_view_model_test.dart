import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:smartflow/app/provider.dart';
import 'package:smartflow/application/credit/credit_command_api.dart';
import 'package:smartflow/application/credit/credit_query_api.dart';
import 'package:smartflow/application/ledger/ledger_command_api.dart';
import 'package:smartflow/application/ledger/ledger_query_api.dart';
import 'package:smartflow/core/error/app_exception.dart';
import 'package:smartflow/core/money/money.dart';
import 'package:smartflow/domain/ledger/valobj/ledger_error_code.dart';
import 'package:smartflow/feature/account/view_model/account_detail_view_model.dart';
import 'package:smartflow/feature/account/view_model/account_view.dart';
import 'package:smartflow/feature/shared/view_model/ui_action_outcome.dart';
import 'package:smartflow/feature/credit/provider/bill_query_providers.dart';
import 'package:smartflow/feature/credit/provider/installment_query_providers.dart';
import 'package:smartflow/feature/shared/provider/ledger_query_providers.dart';
import 'package:smartflow/shared/account_profile/account_profile_kind.dart';

void main() {
  group('accountDetailActions', () {
    test('maps each account profile to its supported detail actions', () {
      expect(
        accountDetailActions(_accountView('receivable', AccountProfileKind.receivable))
            .map((action) => action.label),
        ['借出', '收回', '坏账'],
      );
      final payableActions = accountDetailActions(
        _accountView('payable', AccountProfileKind.payable),
      );
      expect(payableActions.map((action) => action.label), ['借入', '还款', '债务豁免']);
      expect(
        payableActions.first.route,
        '/transaction/new?mode=borrowing&liabilityAccountId=payable',
      );
      expect(
        accountDetailActions(
          _accountView('archived', AccountProfileKind.fund, isArchived: true),
        ),
        isEmpty,
      );
    });
  });

  group('AccountDetailViewModel', () {
    test('builds account detail for an existing account', () async {
      final transactionService = _FakeTransactionQueryService();
      final accountService = _FakeAccountQueryService(accountsById: _accounts);
      final container = _container(
        transactionService,
        accountService,
        overrides: [
          accountListProvider.overrideWith(
            (ref) => Stream.value([_account('cash', '现金')]),
          ),
          creditLiabilityAccountsByAccountIdProvider.overrideWith(
            (ref) => Stream.value(const {}),
          ),
        ],
      );

      final sub = container.listen(
        accountDetailViewModelProvider('cash'),
        (_, _) {},
      );
      addTearDown(sub.close);
      await container.read(accountListProvider.future);
      await container.read(creditLiabilityAccountsByAccountIdProvider.future);
      await container.pump();
      await _flush();

      final state = container.read(accountDetailViewModelProvider('cash'));
      expect(state, isA<AccountDetailLoaded>());
      final loaded = state as AccountDetailLoaded;
      expect(loaded.account.name, '现金');
      expect(loaded.contracts, isA<AccountContractsNotApplicable>());
    });

    test('reports not found when account list does not contain id', () async {
      final transactionService = _FakeTransactionQueryService();
      final accountService = _FakeAccountQueryService(accountsById: _accounts);
      final container = _container(
        transactionService,
        accountService,
        overrides: [
          accountListProvider.overrideWith(
            (ref) => Stream.value([_account('cash', '现金')]),
          ),
          creditLiabilityAccountsByAccountIdProvider.overrideWith(
            (ref) => Stream.value(const {}),
          ),
        ],
      );

      final sub = container.listen(
        accountDetailViewModelProvider('missing'),
        (_, _) {},
      );
      addTearDown(sub.close);
      await container.read(accountListProvider.future);
      await container.read(creditLiabilityAccountsByAccountIdProvider.future);
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
      final container = _container(
        transactionService,
        accountService,
        overrides: [
          accountListProvider.overrideWith(
            (ref) => Stream.value([
              _account('card', '信用卡', type: AccountType.liability),
            ]),
          ),
          creditLiabilityAccountsByAccountIdProvider.overrideWith(
            (ref) => Stream.value({'card': _creditLiabilityAccount('card')}),
          ),
          installmentContractsByAccountProvider(
            'card',
          ).overrideWith((ref) async => [_contract()]),
          billSummariesByAccountProvider('card').overrideWith(
            (ref) async => [
              _bill(year: 2026, month: 7),
              _bill(year: 2026, month: 6),
              _bill(year: 2026, month: 5),
            ],
          ),
        ],
      );

      final sub = container.listen(
        accountDetailViewModelProvider('card'),
        (_, _) {},
      );
      addTearDown(sub.close);
      await container.read(accountListProvider.future);
      await container.read(creditLiabilityAccountsByAccountIdProvider.future);
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
      final bills = (loaded.bills as AccountBillsLoaded).bills;
      expect(bills.map((bill) => bill.period.month), [7, 6]);
    });

    test('archives the account through the archive command', () async {
      final commandService = _FakeAccountAppService();
      final container = _deleteContainer(commandService);

      final outcome =
          await container
              .read(accountDetailViewModelProvider('cash').notifier)
              .archiveAccount();

      expect(outcome, isA<UiActionSuccess<void>>());
      expect(commandService.archiveCommands.single.id, 'cash');
    });

    test('maps archive business failures to a UI failure', () async {
      final commandService = _FakeAccountAppService(
        exception: BusinessException(
          LedgerErrorCode.accountUnavailable,
          message: '账户当前不可用。',
        ),
      );
      final container = _deleteContainer(commandService);

      final outcome =
          await container
              .read(accountDetailViewModelProvider('cash').notifier)
              .archiveAccount();

      expect(outcome, isA<UiActionFailure<void>>());
      final failure = outcome as UiActionFailure<void>;
      expect(failure.error.code, LedgerErrorCode.accountUnavailable.code);
      expect(failure.error.message, '账户当前不可用。');
    });

    test(
      'maps unexpected archive exceptions to an unknown UI failure',
      () async {
        final container = _deleteContainer(
          _FakeAccountAppService(exception: Exception('unexpected')),
        );

        final outcome =
            await container
                .read(accountDetailViewModelProvider('cash').notifier)
                .archiveAccount();

        expect(outcome, isA<UiActionFailure<void>>());
        final failure = outcome as UiActionFailure<void>;
        expect(failure.error.code, 'unknown');
        expect(failure.error.message, '未知错误，请稍后重试。');
      },
    );

    test('permanently deletes a fund account through ledger', () async {
      final commandService = _FakeAccountAppService();
      final container = _deleteContainer(commandService);

      final outcome =
          await container
              .read(accountDetailViewModelProvider('cash').notifier)
              .deletePermanently();

      expect(outcome, isA<UiActionSuccess<void>>());
      expect(commandService.deleteCommands.single.id, 'cash');
    });

    test('permanently deletes a credit account through credit', () async {
      final ledgerService = _FakeAccountAppService();
      final creditService = _FakeCreditAccountAppService();
      final creditAccount = Account(
        id: 'card',
        name: '信用卡',
        type: AccountType.liability,
        subtype: AccountSubtype.payable,
        profileKey: 'credit.credit',
        balance: Money.zero(),
        archivedAt: DateTime(2026),
      );
      final container = _deleteContainer(
        ledgerService,
        account: creditAccount,
        creditService: creditService,
      );

      final outcome =
          await container
              .read(accountDetailViewModelProvider('card').notifier)
              .deletePermanently();

      expect(outcome, isA<UiActionSuccess<void>>());
      expect(creditService.deleteCommands.single.accountId, 'card');
      expect(ledgerService.deleteCommands, isEmpty);
    });
  });
}

ProviderContainer _deleteContainer(
  _FakeAccountAppService commandService, {
  Account? account,
  _FakeCreditAccountAppService? creditService,
}) {
  final transactionService = _FakeTransactionQueryService();
  final selectedAccount = account ?? _accounts['cash']!;
  final accountQueryService = _FakeAccountQueryService(
    accountsById: {selectedAccount.id: selectedAccount},
  );
  return _container(
    transactionService,
    accountQueryService,
    overrides: [
      accountAppServiceProvider.overrideWithValue(commandService),
      if (creditService != null)
        creditAccountAppServiceProvider.overrideWithValue(creditService),
      accountListProvider.overrideWith(
        (ref) => Stream.value([selectedAccount]),
      ),
      creditLiabilityAccountsByAccountIdProvider.overrideWith(
        (ref) => Stream.value(const {}),
      ),
    ],
  );
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
      creditAccountQueryServiceProvider.overrideWithValue(
        const _FakeCreditAccountQueryService(),
      ),
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

AccountView _accountView(
  String id,
  AccountProfileKind kind, {
  bool isArchived = false,
}) => AccountView(
  id: id,
  name: id,
  kind: kind,
  balance: Money.zero(),
  iconKey: kind.iconKey,
  isArchived: isArchived,
);

Account _account(
  String id,
  String name, {
  AccountType type = AccountType.asset,
  String? iconKey,
  DateTime? archivedAt,
}) {
  final subtype = switch (type) {
    AccountType.asset => AccountSubtype.fund,
    AccountType.liability => AccountSubtype.payable,
    _ => null,
  };
  final profileKey = switch (type) {
    AccountType.asset => 'ledger.fund',
    AccountType.liability => 'credit.credit',
    _ => null,
  };
  return Account(
    id: id,
    name: name,
    type: type,
    subtype: subtype,
    profileKey: profileKey,
    iconKey: iconKey,
    archivedAt: archivedAt,
    balance: const Money(minorUnits: 0),
  );
}

CreditLiabilityAccountReadModel _creditLiabilityAccount(String accountId) {
  return CreditLiabilityAccountReadModel(
    id: 'credit-$accountId',
    accountId: accountId,
    kind: CreditLiabilityAccountKind.credit,
    billingDay: 5,
    repaymentDay: 25,
    billingDayToNext: true,
  );
}

BillSummaryReadModel _bill({required int year, required int month}) {
  return BillSummaryReadModel(
    id: 'bill-$year-$month',
    accountId: 'card',
    period: BillPeriod(year: year, month: month),
    status: BillStatus.billed,
    expectedPrincipal: Money.zero(),
    expectedInterest: Money.zero(),
    expectedFee: Money.zero(),
    pendingPrincipal: Money.zero(),
    itemCount: 0,
    overdueItemCount: 0,
  );
}

InstallmentContractReadModel _contract() {
  return InstallmentContractReadModel(
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
  Future<Account?> findAccountById(String id) async {
    return _accountsById?[id];
  }

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

class _FakeCreditAccountQueryService implements CreditAccountQueryService {
  const _FakeCreditAccountQueryService();

  @override
  Future<CreditAccountOverviewReadModel?> findOverview(String accountId) async {
    return null;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _FakeAccountAppService implements AccountAppService {
  _FakeAccountAppService({this.exception});

  final Object? exception;
  final archiveCommands = <ArchiveAccountCommand>[];
  final deleteCommands = <DeleteAccountCommand>[];

  @override
  Future<Account> createAccount(CreateAccountCommand command) {
    throw UnimplementedError();
  }

  @override
  Future<void> editAccount(EditAccountCommand command) {
    throw UnimplementedError();
  }

  @override
  Future<void> archiveAccount(ArchiveAccountCommand command) async {
    archiveCommands.add(command);
    final exception = this.exception;
    if (exception != null) throw exception;
  }

  @override
  Future<void> restoreAccount(RestoreAccountCommand command) async {
    final exception = this.exception;
    if (exception != null) throw exception;
  }

  @override
  Future<void> deleteAccount(DeleteAccountCommand command) async {
    deleteCommands.add(command);
    final exception = this.exception;
    if (exception != null) throw exception;
  }
}

class _FakeCreditAccountAppService implements CreditAccountAppService {
  final deleteCommands = <DeleteCreditLiabilityAccountCommand>[];

  @override
  Future<void> deleteAccount(
    DeleteCreditLiabilityAccountCommand command,
  ) async {
    deleteCommands.add(command);
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
