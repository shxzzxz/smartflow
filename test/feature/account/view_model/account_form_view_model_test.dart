import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:smartflow/app/provider.dart';
import 'package:smartflow/application/credit/credit_command_api.dart';
import 'package:smartflow/application/ledger/ledger_command_api.dart';
import 'package:smartflow/core/error/app_exception.dart';
import 'package:smartflow/core/money/money.dart';
import 'package:smartflow/core/patch/patch.dart';
import 'package:smartflow/domain/ledger/valobj/ledger_error_code.dart';
import 'package:smartflow/domain/credit/port/credit_ledger_port.dart';
import 'package:smartflow/feature/account/view_model/account_form_view_model.dart';
import 'package:smartflow/feature/account/view_model/account_view.dart';
import 'package:smartflow/feature/account/view_model/account_views_provider.dart';
import 'package:smartflow/feature/shared/view_model/ui_action_outcome.dart';
import 'package:smartflow/shared/account_profile/account_profile_kind.dart';

void main() {
  group('AccountFormViewModel', () {
    test('new account exposes an immediate data snapshot', () {
      final container = _container(_FakeAccountAppService());

      final asyncState = container.read(accountFormViewModelProvider(null));

      expect(asyncState, isA<AsyncData<AccountFormState?>>());
      expect(asyncState.requireValue!.kind, AccountProfileKind.fund);
      expect(asyncState.requireValue!.initialValues.openingBalance, '0');
    });

    test('maps loading, error, and not-found account snapshots', () {
      final loading = _container(
        _FakeAccountAppService(),
        accountViewState: const AsyncLoading(),
      );
      expect(
        loading.read(accountFormViewModelProvider('account-1')),
        isA<AsyncLoading<AccountFormState?>>(),
      );

      final error = _container(
        _FakeAccountAppService(),
        accountViewState: AsyncValue.error(
          StateError('load failed'),
          StackTrace.empty,
        ),
      );
      expect(
        error.read(accountFormViewModelProvider('account-1')),
        isA<AsyncError<AccountFormState?>>(),
      );

      final notFound = _container(
        _FakeAccountAppService(),
        accountViewState: const AsyncData(null),
      );
      final notFoundState = notFound.read(
        accountFormViewModelProvider('account-1'),
      );
      expect(notFoundState, isA<AsyncData<AccountFormState?>>());
      expect(notFoundState.requireValue, isNull);
    });

    test(
      'initializes one account snapshot idempotently across query updates',
      () {
        final account = AccountView(
          id: 'account-1',
          name: '原始名称',
          kind: AccountProfileKind.fund,
          balance: const Money(minorUnits: 100),
          iconKey: AccountProfileKind.fund.iconKey,
          isArchived: false,
        );
        final updatedAccount = AccountView(
          id: 'account-1',
          name: '外部更新名称',
          kind: AccountProfileKind.fund,
          balance: const Money(minorUnits: 200),
          iconKey: 'external-icon',
          isArchived: false,
        );
        AsyncValue<AccountView?> snapshot = AsyncValue.data(account);
        final snapshotProvider = Provider<AsyncValue<AccountView?>>(
          (ref) => snapshot,
        );
        final container = ProviderContainer(
          overrides: [
            accountViewProvider(
              'account-1',
            ).overrideWith((ref) => ref.watch(snapshotProvider)),
          ],
        );
        addTearDown(container.dispose);
        final viewModel = container.read(
          accountFormViewModelProvider('account-1').notifier,
        );

        viewModel.setIconKey('user-selected-icon');
        snapshot = AsyncValue.data(updatedAccount);
        container.invalidate(snapshotProvider);

        final state =
            container
                .read(accountFormViewModelProvider('account-1'))
                .requireValue!;
        expect(state.initialValues.name, '原始名称');
        expect(state.iconKey, 'user-selected-icon');
      },
    );

    test('creates fund account command and returns success', () async {
      final service = _FakeAccountAppService();
      final container = _container(service);
      final viewModel = container.read(
        accountFormViewModelProvider(null).notifier,
      );

      final outcome = await viewModel.submit(
        nameText: ' Cash ',
        openingBalanceText: '12.34',
        creditLimitText: '',
        noteText: ' daily account ',
      );

      expect(outcome, isA<SubmitSuccess>());
      expect(
        container
            .read(accountFormViewModelProvider(null))
            .requireValue!
            .submitting,
        false,
      );
      final command = service.createCommands.single;
      expect(command.name, 'Cash');
      expect(command.type, AccountType.asset);
      expect(command.openingBalance, const Money(minorUnits: 1234));
      expect(command.note, 'daily account');
    });

    test('creates credit account through credit account service', () async {
      final creditAppService = _FakeCreditAccountAppService();
      final container = _container(
        _FakeAccountAppService(),
        creditAppService: creditAppService,
      );
      final viewModel =
          container.read(accountFormViewModelProvider(null).notifier)
            ..setKind(AccountProfileKind.credit)
            ..setBillingDay(5)
            ..setRepaymentDay(25);

      final outcome = await viewModel.submit(
        nameText: 'Card',
        openingBalanceText: '0',
        creditLimitText: '1000',
        noteText: '',
      );

      expect(outcome, isA<SubmitSuccess>());
      final command = creditAppService.createCommands.single;
      expect(command.kind, CreditLiabilityAccountKind.credit);
      expect(command.creditLimit, const Money(minorUnits: 100000));
      expect(command.billingDay, 5);
      expect(command.repaymentDay, 25);
    });

    test('creates loan account without cycle parameters', () async {
      final creditAppService = _FakeCreditAccountAppService();
      final container = _container(
        _FakeAccountAppService(),
        creditAppService: creditAppService,
      );
      final viewModel = container.read(
        accountFormViewModelProvider(null).notifier,
      )..setKind(AccountProfileKind.loan);

      final outcome = await viewModel.submit(
        nameText: 'Loan',
        openingBalanceText: '0',
        creditLimitText: '3000',
        noteText: '',
      );

      expect(outcome, isA<SubmitSuccess>());
      final command = creditAppService.createCommands.single;
      expect(command.kind, CreditLiabilityAccountKind.loan);
      expect(command.creditLimit, const Money(minorUnits: 300000));
      expect(command.billingDay, isNull);
      expect(command.repaymentDay, isNull);
    });

    test('edits loaded account through edit command', () async {
      final service = _FakeAccountAppService();
      final account = AccountView(
        id: 'account-1',
        name: 'Old',
        kind: AccountProfileKind.fund,
        balance: const Money(minorUnits: 1000),
        iconKey: AccountProfileKind.fund.iconKey,
        isArchived: false,
      );
      final container = _container(service, editAccount: account);
      final viewModel = container.read(
        accountFormViewModelProvider('account-1').notifier,
      );
      final loadedState =
          container
              .read(accountFormViewModelProvider('account-1'))
              .requireValue!;

      expect(loadedState.initialValues.name, 'Old');
      expect(loadedState.initialValues.openingBalance, '10.00');
      expect(loadedState.kind, AccountProfileKind.fund);
      expect(loadedState.iconKey, AccountProfileKind.fund.iconKey);

      final outcome = await viewModel.submit(
        nameText: 'New',
        openingBalanceText: '20',
        creditLimitText: '',
        noteText: '',
      );

      expect(outcome, isA<SubmitSuccess>());
      final command = service.editCommands.single;
      expect(command.id, 'account-1');
      expect(command.name, 'New');
      expect(command.targetBalance, const Money(minorUnits: 2000));
    });

    test(
      'saves a loaded credit account from one consistent snapshot',
      () async {
        final creditAppService = _FakeCreditAccountAppService();
        final account = AccountView(
          id: 'credit-1',
          name: '信用卡',
          kind: AccountProfileKind.credit,
          balance: const Money(minorUnits: 250000),
          iconKey: 'custom-credit',
          isArchived: false,
          note: '账单账户',
          creditLimit: const Money(minorUnits: 1000000),
          billingDay: 5,
          repaymentDay: 20,
          billingDayToNext: false,
        );
        final container = _container(
          _FakeAccountAppService(),
          creditAppService: creditAppService,
          editAccount: account,
        );
        final loaded =
            container
                .read(accountFormViewModelProvider('credit-1'))
                .requireValue!;
        final viewModel = container.read(
          accountFormViewModelProvider('credit-1').notifier,
        );

        expect(loaded.kind, AccountProfileKind.credit);
        expect(loaded.iconKey, 'custom-credit');
        expect(loaded.billingDay, 5);
        expect(loaded.repaymentDay, 20);
        expect(loaded.billingDayToNext, false);

        final outcome = await viewModel.submit(
          nameText: loaded.initialValues.name,
          openingBalanceText: loaded.initialValues.openingBalance,
          creditLimitText: loaded.initialValues.creditLimit,
          noteText: loaded.initialValues.note,
        );

        expect(outcome, isA<SubmitSuccess>());
        final command = creditAppService.editCommands.single;
        expect(command.accountId, 'credit-1');
        expect(
          command.creditLimit.applyTo(null),
          const Money(minorUnits: 1000000),
        );
        expect(command.billingDay.applyTo(null), 5);
        expect(command.repaymentDay.applyTo(null), 20);
        expect(command.billingDayToNext, false);
        expect(command.targetBalance, const Money(minorUnits: 250000));
      },
    );

    test('maps business exception to submit failure', () async {
      final service = _FakeAccountAppService(
        exception: BusinessException(
          LedgerErrorCode.accountInvalidCommand,
          message: '账户参数不合法。',
        ),
      );
      final container = _container(service);
      final viewModel = container.read(
        accountFormViewModelProvider(null).notifier,
      );

      final outcome = await viewModel.submit(
        nameText: 'Cash',
        openingBalanceText: '0',
        creditLimitText: '',
        noteText: '',
      );

      expect(outcome, isA<SubmitFailure>());
      final failure = outcome as SubmitFailure;
      expect(failure.error.code, LedgerErrorCode.accountInvalidCommand.code);
      expect(failure.error.message, '账户参数不合法。');
      expect(
        container
            .read(accountFormViewModelProvider(null))
            .requireValue!
            .submitting,
        false,
      );
    });

    test('rethrows unexpected exceptions after resetting submitting', () async {
      final unexpected = StateError('unexpected');
      final service = _FakeAccountAppService(exception: unexpected);
      final container = _container(service);
      final viewModel = container.read(
        accountFormViewModelProvider(null).notifier,
      );

      await expectLater(
        () => viewModel.submit(
          nameText: 'Cash',
          openingBalanceText: '0',
          creditLimitText: '',
          noteText: '',
        ),
        throwsA(same(unexpected)),
      );
      expect(
        container
            .read(accountFormViewModelProvider(null))
            .requireValue!
            .submitting,
        false,
      );
    });
  });
}

ProviderContainer _container(
  _FakeAccountAppService service, {
  _FakeCreditAccountAppService? creditAppService,
  AccountView? editAccount,
  AsyncValue<AccountView?>? accountViewState,
}) {
  final container = ProviderContainer(
    overrides: [
      accountAppServiceProvider.overrideWith((ref) => service),
      creditAccountAppServiceProvider.overrideWith(
        (ref) => creditAppService ?? _FakeCreditAccountAppService(),
      ),
      if (editAccount != null)
        accountViewProvider(
          editAccount.id,
        ).overrideWithValue(AsyncValue.data(editAccount)),
      if (accountViewState != null)
        accountViewProvider('account-1').overrideWithValue(accountViewState),
    ],
  );
  addTearDown(container.dispose);
  return container;
}

class _FakeCreditAccountAppService implements CreditAccountAppService {
  final createCommands = <CreateCreditLiabilityAccountCommand>[];
  final editCommands = <EditCreditLiabilityAccountCommand>[];

  @override
  Future<CreditLedgerAccountSnapshot> createAccount(
    CreateCreditLiabilityAccountCommand command,
  ) async {
    createCommands.add(command);
    return const CreditLedgerAccountSnapshot(
      id: 'credit-created',
      balance: Money(minorUnits: 0),
      isArchived: false,
    );
  }

  @override
  Future<void> editAccount(EditCreditLiabilityAccountCommand command) async {
    editCommands.add(command);
  }
}

Account _account(
  String id, {
  String? name,
  Money balance = const Money(minorUnits: 0),
}) {
  return Account(
    id: id,
    name: name ?? id,
    type: AccountType.asset,
    balance: balance,
  );
}

class _FakeAccountAppService implements AccountAppService {
  _FakeAccountAppService({this.exception});

  final Object? exception;
  final createCommands = <CreateAccountCommand>[];
  final editCommands = <EditAccountCommand>[];

  @override
  Future<Account> createAccount(CreateAccountCommand command) async {
    createCommands.add(command);
    _throwIfNeeded();
    return _account('created', name: command.name);
  }

  @override
  Future<void> editAccount(EditAccountCommand command) async {
    editCommands.add(command);
    _throwIfNeeded();
  }

  @override
  Future<void> archiveAccount(ArchiveAccountCommand command) async {
    _throwIfNeeded();
  }

  void _throwIfNeeded() {
    final exception = this.exception;
    if (exception != null) throw exception;
  }
}
