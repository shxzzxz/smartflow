import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:smartflow/app/provider.dart';
import 'package:smartflow/application/credit/credit_command_api.dart';
import 'package:smartflow/core/error/app_exception.dart';
import 'package:smartflow/core/money/money.dart';
import 'package:smartflow/core/patch/patch.dart';
import 'package:smartflow/feature/credit/provider/installment_query_providers.dart';
import 'package:smartflow/feature/credit/view_model/installment_contract_edit_state.dart';
import 'package:smartflow/feature/credit/view_model/installment_contract_edit_view_model.dart';
import 'package:smartflow/feature/shared/view_model/ui_action_outcome.dart';

void main() {
  group('InstallmentContractEditViewModel', () {
    test('loads contract and schedules into draft state', () async {
      final service = _FakeInstallmentAppService(
        contract: _contract(),
        schedules: [_schedule(1), _schedule(2)],
      );
      final container = _container(service);

      final state = await _readState(container);

      final loaded = state as InstallmentContractEditLoaded;
      expect(loaded.contract.id, 'contract-1');
      expect(loaded.paidCount, 0);
      expect(loaded.draft.map((row) => row.periodNo), [1, 2]);
      expect(loaded.ratePeriod, InterestRatePeriod.monthly);
    });

    test(
      'recalculates existing pending rows and marks them for submit',
      () async {
        final service = _FakeInstallmentAppService(
          contract: _contract(),
          schedules: [_schedule(1), _schedule(2)],
        );
        final container = _container(service);
        final viewModel = container.read(
          installmentContractEditViewModelProvider('contract-1').notifier,
        );
        await _readState(container);
        viewModel.applyAmount(
          _scheduleRow(container, 1),
          InstallmentAmountField.fee,
          const Money(minorUnits: 100),
        );

        final outcome = viewModel.recalculate(
          totalPeriodsText: '3',
          rateText: '12',
          feeText: '',
          overrideInstallmentText: '',
        );

        expect(outcome, isA<UiActionSuccess<void>>());
        final loaded =
            container
                    .read(
                      installmentContractEditViewModelProvider('contract-1'),
                    )
                    .value!
                as InstallmentContractEditLoaded;
        expect(loaded.draft.length, 2);
        expect(loaded.draft.map((row) => row.date), [
          DateTime(2026, 2, 1),
          DateTime(2026, 3, 1),
        ]);
        expect(loaded.manualPatchedPeriodNos, {1, 2});
      },
    );

    test('edits draft row amount and date', () async {
      final service = _FakeInstallmentAppService(
        contract: _contract(),
        schedules: [_schedule(1)],
      );
      final container = _container(service);
      final viewModel = container.read(
        installmentContractEditViewModelProvider('contract-1').notifier,
      );
      await _readState(container);

      viewModel
        ..applyAmount(
          _scheduleRow(container, 1),
          InstallmentAmountField.principal,
          const Money(minorUnits: 6000),
        )
        ..editScheduleDate(_scheduleRow(container, 1), DateTime(2026, 2, 2));

      final row = _scheduleRow(container, 1);
      expect(row.principal, const Money(minorUnits: 6000));
      expect(row.date, DateTime(2026, 2, 2));
      final loaded =
          container
                  .read(installmentContractEditViewModelProvider('contract-1'))
                  .value!
              as InstallmentContractEditLoaded;
      expect(loaded.manualPatchedPeriodNos, {1});
    });

    test('submits update command and returns success', () async {
      final service = _FakeInstallmentAppService(
        contract: _contract(),
        schedules: [_schedule(1), _schedule(2)],
      );
      final container = _container(service);
      final viewModel = container.read(
        installmentContractEditViewModelProvider('contract-1').notifier,
      );
      await _readState(container);
      viewModel
        ..setMethod(InstallmentRepaymentMethod.equalInstallment)
        ..applyAmount(
          _scheduleRow(container, 2),
          InstallmentAmountField.interest,
          const Money(minorUnits: 88),
        );

      final outcome = await viewModel.submit(
        totalPeriodsText: '2',
        rateText: '7.2',
        feeText: '',
        overrideInstallmentText: '55',
      );

      expect(outcome, isA<SubmitSuccess>());
      final command = service.updateCommands.single;
      expect(command.contractId, 'contract-1');
      expect(command.totalPeriods, 2);
      expect(
        command.repaymentMethod,
        InstallmentRepaymentMethod.equalInstallment,
      );
      expect(command.interestRatePpm, isA<PatchSet<int>>());
      expect(command.equalInstallmentOverrideMinor, 5500);
      expect(command.schedulePatches.single.periodNo, 2);
      expect(
        command.schedulePatches.single.expectedInterest,
        const Money(minorUnits: 88),
      );
      final loaded =
          container
                  .read(installmentContractEditViewModelProvider('contract-1'))
                  .value!
              as InstallmentContractEditLoaded;
      expect(loaded.submitting, false);
    });

    test('maps business exception to submit failure', () async {
      final service = _FakeInstallmentAppService(
        contract: _contract(),
        schedules: [_schedule(1)],
        updateException: BusinessException(
          CreditErrorCode.contractPersistenceConflict,
          message: '合同数据已变化，请刷新后重试。',
        ),
      );
      final container = _container(service);
      final viewModel = container.read(
        installmentContractEditViewModelProvider('contract-1').notifier,
      );
      await _readState(container);

      final outcome = await viewModel.submit(
        totalPeriodsText: '1',
        rateText: '',
        feeText: '',
        overrideInstallmentText: '',
      );

      expect(outcome, isA<SubmitFailure>());
      final failure = outcome as SubmitFailure;
      expect(
        failure.error.code,
        CreditErrorCode.contractPersistenceConflict.code,
      );
      expect(failure.error.message, '合同数据已变化，请刷新后重试。');
    });

    test('maps regular exception to unknown submit failure', () async {
      final service = _FakeInstallmentAppService(
        contract: _contract(),
        schedules: [_schedule(1)],
        updateException: Exception('database failed'),
      );
      final container = _container(service);
      final viewModel = container.read(
        installmentContractEditViewModelProvider('contract-1').notifier,
      );
      await _readState(container);

      final outcome = await viewModel.submit(
        totalPeriodsText: '1',
        rateText: '',
        feeText: '',
        overrideInstallmentText: '',
      );

      expect(outcome, isA<SubmitFailure>());
      final failure = outcome as SubmitFailure;
      expect(failure.error.code, 'unknown');
      expect(failure.error.message, '未知错误，请稍后重试。');
      final loaded =
          container
                  .read(installmentContractEditViewModelProvider('contract-1'))
                  .value!
              as InstallmentContractEditLoaded;
      expect(loaded.submitting, false);
    });

    test('rethrows unexpected exception after resetting submitting', () async {
      final unexpected = StateError('unexpected');
      final service = _FakeInstallmentAppService(
        contract: _contract(),
        schedules: [_schedule(1)],
        updateException: unexpected,
      );
      final container = _container(service);
      final viewModel = container.read(
        installmentContractEditViewModelProvider('contract-1').notifier,
      );
      await _readState(container);

      await expectLater(
        () => viewModel.submit(
          totalPeriodsText: '1',
          rateText: '',
          feeText: '',
          overrideInstallmentText: '',
        ),
        throwsA(same(unexpected)),
      );
      final loaded =
          container
                  .read(installmentContractEditViewModelProvider('contract-1'))
                  .value!
              as InstallmentContractEditLoaded;
      expect(loaded.submitting, false);
    });
  });
}

ProviderContainer _container(_FakeInstallmentAppService service) {
  final container = ProviderContainer(
    overrides: [
      installmentContractProvider.overrideWith(
        (ref, contractId) async => service.contract,
      ),
      installmentSchedulesProvider.overrideWith(
        (ref, contractId) async => service.schedules,
      ),
      installmentAppServiceProvider.overrideWithValue(service),
    ],
  );
  addTearDown(container.dispose);
  return container;
}

Future<InstallmentContractEditState> _readState(ProviderContainer container) {
  final subscription = container.listen(
    installmentContractEditViewModelProvider('contract-1'),
    (_, _) {},
  );
  addTearDown(subscription.close);
  return container.read(
    installmentContractEditViewModelProvider('contract-1').future,
  );
}

InstallmentContractDraftRow _scheduleRow(
  ProviderContainer container,
  int periodNo,
) {
  final loaded =
      container
              .read(installmentContractEditViewModelProvider('contract-1'))
              .value!
          as InstallmentContractEditLoaded;
  return loaded.draft.singleWhere((row) => row.periodNo == periodNo);
}

InstallmentContract _contract() {
  return InstallmentContract(
    id: 'contract-1',
    liabilityAccountId: 'loan',
    sourceType: InstallmentSourceType.disbursement,
    disbursementAccountId: 'bank',
    disbursementTransactionId: 'tx-disbursement',
    principal: const Money(minorUnits: 10000),
    totalPeriods: 2,
    borrowingDate: DateTime(2026, 1, 1),
    firstRepaymentDate: DateTime(2026, 2, 1),
    lastRepaymentDate: DateTime(2026, 3, 1),
    repaymentMethod: InstallmentRepaymentMethod.equalPrincipal,
    interestRatePeriod: InterestRatePeriod.monthly,
    interestRatePpm: 10000,
    interestAccrualMethod: InterestAccrualMethod.daily,
    totalFeeMinor: 0,
    status: InstallmentContractStatus.active,
    createdAt: DateTime(2026, 1, 1),
  );
}

InstallmentSchedule _schedule(
  int periodNo, {
  InstallmentScheduleStatus status = InstallmentScheduleStatus.pending,
}) {
  return InstallmentSchedule(
    id: 'schedule-$periodNo',
    contractId: 'contract-1',
    periodNo: periodNo,
    expectedRepaymentDate: DateTime(2026, periodNo + 1, 1),
    expectedPrincipal: const Money(minorUnits: 5000),
    expectedInterest: const Money(minorUnits: 50),
    expectedFee: Money.zero(),
    status: status,
    createdAt: DateTime(2026, 1, 1),
  );
}

class _FakeInstallmentAppService implements InstallmentAppService {
  _FakeInstallmentAppService({
    required this.contract,
    required this.schedules,
    this.updateException,
  });

  final InstallmentContract? contract;
  final List<InstallmentSchedule> schedules;
  final Object? updateException;
  final updateCommands = <UpdateContractCommand>[];

  @override
  Future<void> updateContract(UpdateContractCommand command) async {
    updateCommands.add(command);
    final exception = updateException;
    if (exception != null) throw exception;
  }

  @override
  Future<List<RecalculatedSchedulePreview>> previewContractRecalculation(
    RecalculateContractSchedulesCommand command,
  ) {
    throw UnimplementedError();
  }

  @override
  Future<void> recalculateContractSchedules(
    RecalculateContractSchedulesCommand command,
  ) {
    throw UnimplementedError();
  }

  @override
  Future<void> skipSchedule(SkipInstallmentScheduleCommand command) {
    throw UnimplementedError();
  }

  @override
  Future<void> restoreSchedule(RestoreInstallmentScheduleCommand command) {
    throw UnimplementedError();
  }

  @override
  Future<CreateContractResult> createDisbursementContract(
    CreateDisbursementContractCommand command,
  ) {
    throw UnimplementedError();
  }

  @override
  Future<void> deleteContract(DeleteContractCommand command) {
    throw UnimplementedError();
  }
}
