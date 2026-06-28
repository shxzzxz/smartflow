import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:smartflow/app/provider.dart';
import 'package:smartflow/application/credit/credit_command_api.dart';
import 'package:smartflow/application/ledger/ledger_command_api.dart';
import 'package:smartflow/core/error/app_exception.dart';
import 'package:smartflow/core/money/money.dart';
import 'package:smartflow/domain/ledger/valobj/ledger_error_code.dart';
import 'package:smartflow/feature/account/view_model/account_form_view_model.dart';
import 'package:smartflow/feature/account/view_model/account_view.dart';
import 'package:smartflow/feature/shared/view_model/ui_action_outcome.dart';
import 'package:smartflow/shared/account_profile/account_profile_kind.dart';

void main() {
  group('AccountFormViewModel', () {
    test('creates fund account command and returns success', () async {
      final service = _FakeAccountAppService();
      final container = _container(service);
      final viewModel = container.read(accountFormViewModelProvider.notifier);

      final outcome = await viewModel.submit(
        nameText: ' Cash ',
        openingBalanceText: '12.34',
        creditLimitText: '',
        noteText: ' daily account ',
      );

      expect(outcome, isA<SubmitSuccess>());
      expect(container.read(accountFormViewModelProvider).submitting, false);
      final command = service.createCommands.single;
      expect(command.name, 'Cash');
      expect(command.type, AccountType.asset);
      expect(command.openingBalance, const Money(minorUnits: 1234));
      expect(command.note, 'daily account');
    });

    test('creates credit account through credit account service', () async {
      final creditService = _FakeCreditAccountService();
      final container = _container(
        _FakeAccountAppService(),
        creditService: creditService,
      );
      final viewModel =
          container.read(accountFormViewModelProvider.notifier)
            ..setKind(AccountProfileKind.credit)
            ..setBillingDay(5)
            ..setRepaymentDay(25)
            ..setBillingStartPeriod(BillPeriod.fromInt(202606));

      final outcome = await viewModel.submit(
        nameText: 'Card',
        openingBalanceText: '0',
        creditLimitText: '1000',
        noteText: '',
      );

      expect(outcome, isA<SubmitSuccess>());
      final command = creditService.createCommands.single;
      expect(command.kind, CreditLiabilityAccountKind.credit);
      expect(command.creditLimit, const Money(minorUnits: 100000));
      expect(command.billingDay, 5);
      expect(command.repaymentDay, 25);
      expect(command.billingStartPeriod, BillPeriod.fromInt(202606));
    });

    test('creates loan account without cycle parameters', () async {
      final creditService = _FakeCreditAccountService();
      final container = _container(
        _FakeAccountAppService(),
        creditService: creditService,
      );
      final viewModel = container.read(accountFormViewModelProvider.notifier)
        ..setKind(AccountProfileKind.loan);

      final outcome = await viewModel.submit(
        nameText: 'Loan',
        openingBalanceText: '0',
        creditLimitText: '3000',
        noteText: '',
      );

      expect(outcome, isA<SubmitSuccess>());
      final command = creditService.createCommands.single;
      expect(command.kind, CreditLiabilityAccountKind.loan);
      expect(command.creditLimit, const Money(minorUnits: 300000));
      expect(command.billingDay, isNull);
      expect(command.repaymentDay, isNull);
      expect(command.billingStartPeriod, isNull);
    });

    test('edits loaded account through edit command', () async {
      final service = _FakeAccountAppService();
      final container = _container(service);
      final viewModel = container.read(accountFormViewModelProvider.notifier);

      viewModel.initializeForEdit(
        AccountView(
          id: 'account-1',
          name: 'Old',
          kind: AccountProfileKind.fund,
          balance: const Money(minorUnits: 1000),
          iconKey: AccountProfileKind.fund.iconKey,
          isArchived: false,
        ),
      );

      final outcome = await viewModel.submit(
        nameText: 'New',
        openingBalanceText: '20',
        creditLimitText: '',
        noteText: '',
        editAccountId: 'account-1',
      );

      expect(outcome, isA<SubmitSuccess>());
      final command = service.editCommands.single;
      expect(command.id, 'account-1');
      expect(command.name, 'New');
      expect(command.targetBalance, const Money(minorUnits: 2000));
    });

    test('maps business exception to submit failure', () async {
      final service = _FakeAccountAppService(
        exception: BusinessException(
          LedgerErrorCode.accountInvalidCommand,
          message: '账户参数不合法。',
        ),
      );
      final container = _container(service);
      final viewModel = container.read(accountFormViewModelProvider.notifier);

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
      expect(container.read(accountFormViewModelProvider).submitting, false);
    });

    test('rethrows unexpected exceptions after resetting submitting', () async {
      final unexpected = StateError('unexpected');
      final service = _FakeAccountAppService(exception: unexpected);
      final container = _container(service);
      final viewModel = container.read(accountFormViewModelProvider.notifier);

      await expectLater(
        () => viewModel.submit(
          nameText: 'Cash',
          openingBalanceText: '0',
          creditLimitText: '',
          noteText: '',
        ),
        throwsA(same(unexpected)),
      );
      expect(container.read(accountFormViewModelProvider).submitting, false);
    });
  });
}

ProviderContainer _container(
  _FakeAccountAppService service, {
  _FakeCreditAccountService? creditService,
}) {
  final container = ProviderContainer(
    overrides: [
      accountAppServiceProvider.overrideWith((ref) => service),
      creditAccountServiceProvider.overrideWith(
        (ref) => creditService ?? _FakeCreditAccountService(),
      ),
    ],
  );
  addTearDown(container.dispose);
  return container;
}

class _FakeCreditAccountService implements CreditAccountService {
  final createCommands = <CreateCreditLiabilityAccountCommand>[];
  final editCommands = <EditCreditLiabilityAccountCommand>[];

  @override
  Future<Account> createAccount(
    CreateCreditLiabilityAccountCommand command,
  ) async {
    createCommands.add(command);
    return Account(
      id: 'credit-created',
      name: command.name,
      type: AccountType.liability,
      balance: const Money(minorUnits: 0),
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
  Future<void> archiveAccount(ArchiveAccountCommand command) async {}

  @override
  Future<void> unarchiveAccount(UnarchiveAccountCommand command) async {}

  void _throwIfNeeded() {
    final exception = this.exception;
    if (exception != null) throw exception;
  }
}
