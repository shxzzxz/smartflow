import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:logging/logging.dart';
import 'package:smartflow/app/provider.dart';
import 'package:smartflow/application/credit/credit_command_api.dart';
import 'package:smartflow/application/credit/credit_query_api.dart';
import 'package:smartflow/application/ledger/ledger_command_api.dart';
import 'package:smartflow/application/ledger/ledger_query_api.dart';
import 'package:smartflow/core/error/app_exception.dart';
import 'package:smartflow/core/money/money.dart';
import 'package:smartflow/domain/credit/valobj/installment_stage_rule.dart';
import 'package:smartflow/feature/credit/provider/credit_account_query_providers.dart';
import 'package:smartflow/feature/credit/view_model/installment_form_view_model.dart';
import 'package:smartflow/feature/credit/view_model/installment_terms_draft.dart';
import 'package:smartflow/feature/shared/provider/ledger_query_providers.dart';
import 'package:smartflow/feature/shared/view_model/ui_action_outcome.dart';
import 'package:smartflow/shared/account_profile/account_profile_kind.dart';
import 'package:smartflow/shared/account_profile/account_selection_purpose.dart';

void main() {
  group('InstallmentFormViewModel', () {
    test('loads liability and defaults loan account to disbursement', () async {
      final container = _container();
      final state = await _readState(container, _args('loan'));

      final loaded = state as InstallmentFormLoaded;
      expect(loaded.liability.id, 'loan');
      expect(loaded.isDisbursement, isTrue);
      expect(loaded.fundAccounts.map((account) => account.id), ['cash']);
    });

    test(
      'credit account keeps billing-cycle capabilities and rejects arbitrary preview',
      () async {
        final container = _container();
        final args = _args('card');
        final loaded =
            await _readState(container, args) as InstallmentFormLoaded;
        expect(loaded.usesBillingCycle, isTrue);
        expect(loaded.canChooseProduct, isFalse);
        expect(
          await container
              .read(installmentFormViewModelProvider(args).notifier)
              .preview('100'),
          isA<UiActionFailure<LoanCalculation>>(),
        );
      },
    );

    test('submits disbursement contract command', () async {
      final service = _FakeInstallmentAppService();
      final args = _args('loan');
      final container = _container(service: service);
      await _readState(container, args);
      final viewModel = container.read(
        installmentFormViewModelProvider(args).notifier,
      );
      viewModel.setDisbursementAccountId('cash');
      viewModel.setTermsDraft(
        InstallmentTermsDraft(
          stages: [
            InstallmentStageDraft(
              id: 'test',
              firstDate: DateTime(2026, 8, 12),
              lastDate: DateTime(2027, 7, 12),
              algorithm: InstallmentAmountAlgorithm.fixed,
              inputs: const {
                StageInput.periods: '12',
                StageInput.interval: '1',
                StageInput.rate: '7.2',
                StageInput.fixedAmount: '4.56',
              },
            ),
          ],
        ),
      );

      final outcome = await viewModel.submit(
        principalText: '12.34',

        noteText: ' note ',
      );

      expect(outcome, isA<UiActionSuccess<String>>());
      expect((outcome as UiActionSuccess<String>).value, 'contract-created');
      final command = service.disbursementCommands.single;
      expect(command.liabilityAccountId, 'loan');
      expect(command.disbursementAccountId, 'cash');
      expect(command.principal, const Money(minorUnits: 1234));
      expect(command.stageTerms.totalPeriods, 12);
      expect(command.stageTerms.firstDate, DateTime(2026, 8, 12));
      expect(command.stageTerms.lastDate, DateTime(2027, 7, 12));
      expect(command.stageTerms.repayments.first.rate?.ppm, 72000);
      expect(
        (command.stageTerms.repayments.single.installmentAmount
                as FixedInstallmentAmount)
            .amount
            .minorUnits,
        456,
      );
      expect(command.note, 'note');
    });

    test(
      'submits migration contract without disbursement transaction',
      () async {
        final service = _FakeInstallmentAppService();
        final queryService = _FakeCreditAccountQueryService();
        final args = _args('loan');
        final container = _container(
          service: service,
          creditQueryService: queryService,
        );
        final overviewSubscription = container.listen(
          creditAccountOverviewProvider('loan'),
          (_, _) {},
        );
        addTearDown(overviewSubscription.close);
        await container.read(creditAccountOverviewProvider('loan').future);
        await _readState(container, args);
        final viewModel = container.read(
          installmentFormViewModelProvider(args).notifier,
        );
        viewModel.setCreateDisbursementTransaction(false);

        final outcome = await viewModel.submit(
          principalText: '100',

          noteText: '',
        );

        expect(outcome, isA<UiActionSuccess<String>>());
        expect(
          service.disbursementCommands.single.disbursementAccountId,
          isNull,
        );
        await container.read(creditAccountOverviewProvider('loan').future);
        expect(queryService.findOverviewCalls, 2);
      },
    );

    test(
      'submits credit account installment as disbursement command',
      () async {
        final service = _FakeInstallmentAppService();
        final args = _args(
          'card',
          lockedSourceType: InstallmentSourceType.billConversion,
        );
        final container = _container(service: service);
        await _readState(container, args);
        container
            .read(installmentFormViewModelProvider(args).notifier)
            .setDisbursementAccountId('cash');

        final cardState =
            container.read(installmentFormViewModelProvider(args)).requireValue
                as InstallmentFormLoaded;
        container
            .read(installmentFormViewModelProvider(args).notifier)
            .setTermsDraft(
              cardState.termsDraft.replace(
                cardState.termsDraft.stages.single.setInput(
                  StageInput.fee,
                  '3',
                ),
              ),
            );
        final outcome = await container
            .read(installmentFormViewModelProvider(args).notifier)
            .submit(principalText: '100', noteText: '');

        expect(outcome, isA<UiActionSuccess<String>>());
        final command = service.disbursementCommands.single;
        expect(command.liabilityAccountId, 'card');
        expect(command.disbursementAccountId, 'cash');
        expect(command.principal, const Money(minorUnits: 10000));
        expect(command.stageTerms.totalFeeMinor, 300);
        expect(
          command.stageTerms.repayments.first.rate?.period,
          InterestRatePeriod.annual,
        );
        expect(command.stageTerms.repayments.first.rate?.ppm, 0);
      },
    );

    test(
      'rejects a multi-period contract whose last date is not later',
      () async {
        final service = _FakeInstallmentAppService();
        final args = _args('loan');
        final container = _container(service: service);
        await _readState(container, args);
        final viewModel = container.read(
          installmentFormViewModelProvider(args).notifier,
        );
        viewModel.setDisbursementAccountId('cash');
        viewModel.setTermsDraft(
          InstallmentTermsDraft(
            stages: [
              InstallmentStageDraft(
                id: 'test',
                firstDate: DateTime(2026, 8, 12),
                lastDate: DateTime(2026, 8, 12),
                inputs: const {
                  StageInput.periods: '12',
                  StageInput.interval: '1',
                },
              ),
            ],
          ),
        );

        final outcome = await viewModel.submit(
          principalText: '100',

          noteText: '',
        );

        expect(outcome, isA<UiActionFailure<String>>());
        expect(
          (outcome as UiActionFailure<String>).error.message,
          contains('日期'),
        );
        expect(service.disbursementCommands, isEmpty);
      },
    );

    test('maps AppException to UI failure', () async {
      final service = _FakeInstallmentAppService(
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
          .submit(principalText: '10', noteText: '');

      expect(outcome, isA<UiActionFailure<String>>());
      final failure = outcome as UiActionFailure<String>;
      expect(failure.error.code, CreditErrorCode.contractInvalidCommand.code);
      expect(failure.error.message, '合同参数无效');
    });

    test('maps regular Exception to unknown UI failure', () async {
      final records = <LogRecord>[];
      final subscription = Logger.root.onRecord.listen(records.add);
      addTearDown(subscription.cancel);
      final service = _FakeInstallmentAppService(
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
          .submit(principalText: '10', noteText: '');

      expect(outcome, isA<UiActionFailure<String>>());
      expect((outcome as UiActionFailure<String>).error.code, 'unknown');
      final formRecords = records.where(
        (record) => record.loggerName == 'feature.credit.installment_form',
      );
      expect(formRecords, hasLength(1));
      final record = formRecords.single;
      expect(record.level, Level.SEVERE);
      expect(record.message, 'Create staged installment failed unexpectedly.');
      expect(record.error, isA<Exception>());
      expect(record.stackTrace, isNotNull);
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

ProviderContainer _container({
  _FakeInstallmentAppService? service,
  _FakeCreditAccountQueryService? creditQueryService,
}) {
  final liabilities = [
    _account(
      'loan',
      AccountType.liability,
      profileKey: AccountProfileKind.loan.key,
    ),
    _account(
      'card',
      AccountType.liability,
      profileKey: AccountProfileKind.credit.key,
    ),
  ];
  final funds = [_account('cash', AccountType.asset)];
  final container = ProviderContainer(
    overrides: [
      accountsForSelectionPurposeProvider.overrideWith(
        (ref, purpose) => Stream.value(switch (purpose) {
          AccountSelectionPurpose.repaymentTarget => liabilities,
          AccountSelectionPurpose.fund => funds,
          _ => const <Account>[],
        }),
      ),
      installmentAppServiceProvider.overrideWithValue(
        service ?? _FakeInstallmentAppService(),
      ),
      if (creditQueryService != null)
        creditAccountQueryServiceProvider.overrideWithValue(creditQueryService),
    ],
  );
  addTearDown(container.dispose);
  return container;
}

class _FakeCreditAccountQueryService implements CreditAccountQueryService {
  int findOverviewCalls = 0;

  @override
  Future<CreditAccountOverviewReadModel?> findOverview(String accountId) async {
    findOverviewCalls++;
    return null;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

Account _account(
  String id,
  AccountType type, {
  AccountSubtype? subtype,
  String? profileKey,
}) {
  return Account(
    id: id,
    name: id,
    type: type,
    subtype: subtype,
    profileKey: profileKey,
    balance: Money.zero(),
  );
}

class _FakeInstallmentAppService implements InstallmentAppService {
  _FakeInstallmentAppService({this.createException});

  final Object? createException;
  final disbursementCommands = <CreateDisbursementContractCommand>[];

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
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
