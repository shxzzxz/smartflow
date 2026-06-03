import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:smartflow/app/provider.dart';
import 'package:smartflow/application/ledger/ledger_command_api.dart';
import 'package:smartflow/core/error/app_exception.dart';
import 'package:smartflow/core/money/money.dart';
import 'package:smartflow/domain/ledger/valobj/ledger_error_code.dart';
import 'package:smartflow/feature/account/view_model/account_form_view_model.dart';
import 'package:smartflow/feature/shared/view_model/ui_action_outcome.dart';

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

    test('edits loaded account through edit command', () async {
      final service = _FakeAccountAppService();
      final container = _container(service);
      final viewModel = container.read(accountFormViewModelProvider.notifier);

      viewModel.initializeForEdit(
        _account(
          'account-1',
          name: 'Old',
          balance: const Money(minorUnits: 1000),
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

ProviderContainer _container(_FakeAccountAppService service) {
  final container = ProviderContainer(
    overrides: [accountAppServiceProvider.overrideWith((ref) => service)],
  );
  addTearDown(container.dispose);
  return container;
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

  void _throwIfNeeded() {
    final exception = this.exception;
    if (exception != null) throw exception;
  }
}
