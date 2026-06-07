import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:smartflow/app/provider.dart';
import 'package:smartflow/application/credit/credit_command_api.dart';
import 'package:smartflow/application/ledger/ledger_command_api.dart';
import 'package:smartflow/application/ledger/ledger_query_api.dart';
import 'package:smartflow/core/error/app_exception.dart';
import 'package:smartflow/core/money/money.dart';
import 'package:smartflow/feature/credit/view_model/installment_form_view_model.dart';
import 'package:smartflow/feature/shared/provider/ledger_query_providers.dart';
import 'package:smartflow/feature/shared/view_model/ui_action_outcome.dart';

void main() {
  group('InstallmentFormViewModel', () {
    test('loads liability and defaults loan account to disbursement', () async {
      final container = _container();
      final state = await _readState(container, _args('loan'));

      final loaded = state as InstallmentFormLoaded;
      expect(loaded.liability.id, 'loan');
      expect(loaded.sourceType, InstallmentSourceType.disbursement);
      expect(loaded.fundAccounts.map((account) => account.id), ['cash']);
    });

    test('submits disbursement contract command', () async {
      final service = _FakeInstallmentService();
      final args = _args('loan');
      final container = _container(service: service);
      await _readState(container, args);
      final viewModel = container.read(
        installmentFormViewModelProvider(args).notifier,
      );
      viewModel.setDisbursementAccountId('cash');

      final outcome = await viewModel.submit(
        principalText: '12.34',
        totalPeriodsText: '3',
        rateText: '7.2',
        totalFeeText: '',
        overrideInstallmentText: '4.56',
        noteText: ' note ',
      );

      expect(outcome, isA<UiActionSuccess<String>>());
      expect((outcome as UiActionSuccess<String>).value, 'contract-created');
      final command = service.disbursementCommands.single;
      expect(command.liabilityAccountId, 'loan');
      expect(command.disbursementAccountId, 'cash');
      expect(command.principal, const Money(minorUnits: 1234));
      expect(command.totalPeriods, 3);
      expect(command.interestRatePpm, 72000);
      expect(command.equalInstallmentOverrideMinor, 456);
      expect(command.note, 'note');
    });

    test('submits bill conversion contract command', () async {
      final service = _FakeInstallmentService();
      final args = _args(
        'card',
        lockedSourceType: InstallmentSourceType.billConversion,
      );
      final container = _container(service: service);
      await _readState(container, args);

      final outcome = await container
          .read(installmentFormViewModelProvider(args).notifier)
          .submit(
            principalText: '100',
            totalPeriodsText: '6',
            rateText: '',
            totalFeeText: '3',
            overrideInstallmentText: '',
            noteText: '',
          );

      expect(outcome, isA<UiActionSuccess<String>>());
      final command = service.billConversionCommands.single;
      expect(command.liabilityAccountId, 'card');
      expect(command.principal, const Money(minorUnits: 10000));
      expect(command.totalFeeMinor, 300);
      expect(command.interestRatePeriod, isNull);
    });

    test('maps AppException to UI failure', () async {
      final service = _FakeInstallmentService(
        createException: BusinessException(
          CreditErrorCode.contractInvalidCommand,
          message: '合同参数无效',
        ),
      );
      final args = _args('loan');
      final container = _container(service: service);
      await _readState(container, args);
      container
          .read(installmentFormViewModelProvider(args).notifier)
          .setDisbursementAccountId('cash');

      final outcome = await container
          .read(installmentFormViewModelProvider(args).notifier)
          .submit(
            principalText: '10',
            totalPeriodsText: '1',
            rateText: '',
            totalFeeText: '',
            overrideInstallmentText: '',
            noteText: '',
          );

      expect(outcome, isA<UiActionFailure<String>>());
      final failure = outcome as UiActionFailure<String>;
      expect(failure.error.code, CreditErrorCode.contractInvalidCommand.code);
      expect(failure.error.message, '合同参数无效');
    });

    test('maps regular Exception to unknown UI failure', () async {
      final service = _FakeInstallmentService(
        createException: Exception('database failed'),
      );
      final args = _args('loan');
      final container = _container(service: service);
      await _readState(container, args);
      container
          .read(installmentFormViewModelProvider(args).notifier)
          .setDisbursementAccountId('cash');

      final outcome = await container
          .read(installmentFormViewModelProvider(args).notifier)
          .submit(
            principalText: '10',
            totalPeriodsText: '1',
            rateText: '',
            totalFeeText: '',
            overrideInstallmentText: '',
            noteText: '',
          );

      expect(outcome, isA<UiActionFailure<String>>());
      expect((outcome as UiActionFailure<String>).error.code, 'unknown');
    });
  });
}

Future<InstallmentFormState> _readState(
  ProviderContainer container,
  InstallmentFormArgs args,
) {
  final subscription = container.listen(
    installmentFormViewModelProvider(args),
    (_, _) {},
  );
  addTearDown(subscription.close);
  return container.read(installmentFormViewModelProvider(args).future);
}

InstallmentFormArgs _args(
  String liabilityAccountId, {
  InstallmentSourceType? lockedSourceType,
}) {
  return InstallmentFormArgs(
    liabilityAccountId: liabilityAccountId,
    lockedSourceType: lockedSourceType,
  );
}

ProviderContainer _container({_FakeInstallmentService? service}) {
  final liabilities = [
    _account('loan', AccountType.liability, subtype: AccountSubtype.loan),
    _account('card', AccountType.liability),
  ];
  final funds = [_account('cash', AccountType.asset)];
  final container = ProviderContainer(
    overrides: [
      accountsForUsageProvider.overrideWith(
        (ref, usage) => Stream.value(switch (usage) {
          AccountUsage.repaymentTarget => liabilities,
          AccountUsage.fund => funds,
          _ => const <Account>[],
        }),
      ),
      installmentServiceProvider.overrideWithValue(
        service ?? _FakeInstallmentService(),
      ),
    ],
  );
  addTearDown(container.dispose);
  return container;
}

Account _account(String id, AccountType type, {AccountSubtype? subtype}) {
  return Account(
    id: id,
    name: id,
    type: type,
    subtype: subtype,
    balance: Money.zero(),
  );
}

class _FakeInstallmentService implements InstallmentService {
  _FakeInstallmentService({this.createException});

  final Object? createException;
  final disbursementCommands = <CreateDisbursementContractCommand>[];
  final billConversionCommands = <CreateBillConversionContractCommand>[];

  @override
  Future<CreateContractResult> createDisbursementContract(
    CreateDisbursementContractCommand command,
  ) async {
    disbursementCommands.add(command);
    final exception = createException;
    if (exception != null) throw exception;
    return const CreateContractResult(contractId: 'contract-created');
  }

  @override
  Future<CreateContractResult> createBillConversionContract(
    CreateBillConversionContractCommand command,
  ) async {
    billConversionCommands.add(command);
    final exception = createException;
    if (exception != null) throw exception;
    return const CreateContractResult(contractId: 'contract-created');
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
