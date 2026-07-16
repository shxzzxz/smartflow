import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:smartflow/app/provider.dart';
import 'package:smartflow/application/credit/credit_command_api.dart';
import 'package:smartflow/application/credit/credit_query_api.dart';
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
      'uses application preview to recalculate pending rows for submit',
      () async {
        final service = _FakeInstallmentAppService(
          contract: _contract(),
          schedules: [_schedule(1), _schedule(2)],
          previewResults: [
            RecalculatedSchedulePreview(
              scheduleId: 'schedule-1',
              periodNo: 1,
              expectedRepaymentDate: DateTime(2026, 2, 1),
              expectedPrincipal: const Money(minorUnits: 4000),
              expectedInterest: const Money(minorUnits: 120),
              expectedFee: const Money(minorUnits: 10),
            ),
            RecalculatedSchedulePreview(
              scheduleId: 'schedule-2',
              periodNo: 2,
              expectedRepaymentDate: DateTime(2026, 3, 1),
              expectedPrincipal: const Money(minorUnits: 6000),
              expectedInterest: const Money(minorUnits: 80),
              expectedFee: const Money(minorUnits: 20),
            ),
          ],
        );
        final container = _container(service);
        final viewModel = container.read(
          installmentContractEditViewModelProvider('contract-1').notifier,
        );
        await _readState(container);
        viewModel
          ..setFirstRepaymentDate(DateTime(2026, 3, 1))
          ..setLastRepaymentDate(DateTime(2026, 5, 1));

        final outcome = await viewModel.recalculate(
          totalPeriodsText: '3',
          rateText: '12',
          feeText: '0.30',
          overrideInstallmentText: '',
        );

        expect(outcome, isA<UiActionSuccess<void>>());
        expect(service.previewCommands, hasLength(1));
        final previewCommand = service.previewCommands.single;
        expect(previewCommand.terms!.totalPeriods, 3);
        expect(previewCommand.terms!.firstRepaymentDate, DateTime(2026, 3, 1));
        expect(previewCommand.terms!.lastRepaymentDate, DateTime(2026, 5, 1));
        expect(previewCommand.terms!.interestRatePpm, 120000);
        expect(previewCommand.terms!.totalFeeMinor, 30);
        final loaded =
            container
                    .read(
                      installmentContractEditViewModelProvider('contract-1'),
                    )
                    .value!
                as InstallmentContractEditLoaded;
        expect(loaded.draft.length, 2);
        expect(loaded.draft.map((row) => row.principal.minorUnits), [
          4000,
          6000,
        ]);
        expect(loaded.draft.map((row) => row.interest.minorUnits), [120, 80]);
        expect(loaded.draft.map((row) => row.fee.minorUnits), [10, 20]);
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

InstallmentContractReadModel _contract() {
  return InstallmentContractReadModel(
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

InstallmentScheduleReadModel _schedule(
  int periodNo, {
  InstallmentScheduleStatus status = InstallmentScheduleStatus.pending,
}) {
  return InstallmentScheduleReadModel(
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
    this.previewResults = const [],
  });

  final InstallmentContractReadModel? contract;
  final List<InstallmentScheduleReadModel> schedules;
  final Object? updateException;
  final List<RecalculatedSchedulePreview> previewResults;
  final updateCommands = <UpdateContractCommand>[];
  final previewCommands = <RecalculateContractSchedulesCommand>[];

  @override
  Future<void> updateContract(UpdateContractCommand command) async {
    updateCommands.add(command);
    final exception = updateException;
    if (exception != null) throw exception;
  }

  @override
  Future<List<RecalculatedSchedulePreview>> previewContractRecalculation(
    RecalculateContractSchedulesCommand command,
  ) async {
    previewCommands.add(command);
    return previewResults;
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
  Future<ContractStatusValidationResult> validateContractStatuses(
    ValidateContractStatusesCommand command,
  ) async {
    return const ContractStatusValidationResult(
      repairedScheduleCount: 0,
      contractStatusChanged: false,
    );
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
