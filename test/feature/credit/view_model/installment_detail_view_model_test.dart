import 'package:smartflow/domain/credit/valobj/installment_contract_terms.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:smartflow/app/provider.dart';
import 'package:smartflow/application/credit/credit_command_api.dart';
import 'package:smartflow/application/credit/credit_query_api.dart';
import 'package:smartflow/core/error/app_exception.dart';
import 'package:smartflow/core/money/money.dart';
import 'package:smartflow/feature/credit/provider/installment_query_providers.dart';
import 'package:smartflow/feature/credit/view_model/installment_detail_view_model.dart';
import 'package:smartflow/feature/shared/view_model/ui_action_outcome.dart';

void main() {
  group('InstallmentDetailViewModel', () {
    test('loads contract detail and computes summary amounts', () async {
      final container = _container(
        contract: _contract(),
        schedules: [
          _schedule(1, status: InstallmentScheduleStatus.paid),
          _schedule(2, principal: const Money(minorUnits: 6000)),
        ],
        activities: [_repaymentActivity(), _refundReductionActivity()],
      );

      final state = await container.read(
        installmentDetailViewModelProvider('contract-1').future,
      );

      final loaded = state as InstallmentDetailLoaded;
      expect(loaded.contract.id, 'contract-1');
      expect(loaded.remainingPrincipalMinor, 6000);
      expect(loaded.paidInterestMinor, 200);
      expect(loaded.paidFeeMinor, 30);
    });

    test('derives schedule actions for contract detail rows', () async {
      final container = _container(
        contract: _contract(),
        schedules: [
          _schedule(1),
          _schedule(2, status: InstallmentScheduleStatus.skipped),
          _schedule(3, status: InstallmentScheduleStatus.paid),
        ],
      );

      final state = await container.read(
        installmentDetailViewModelProvider('contract-1').future,
      );

      final loaded = state as InstallmentDetailLoaded;
      expect(loaded.scheduleItems.map((item) => item.action), [
        InstallmentScheduleAction.skip,
        InstallmentScheduleAction.restore,
        null,
      ]);
    });

    test('returns not found state when contract is missing', () async {
      final container = _container(contract: null);

      final state = await container.read(
        installmentDetailViewModelProvider('contract-1').future,
      );

      expect(state, isA<InstallmentDetailNotFound>());
    });

    test('delete delegates to command service', () async {
      final disbursement = _FakeDisbursementInstallmentAppService();
      final container = _container(
        contract: _contract(),
        disbursement: disbursement,
      );
      await container.read(
        installmentDetailViewModelProvider('contract-1').future,
      );

      final outcome = await container
          .read(installmentDetailViewModelProvider('contract-1').notifier)
          .deleteInstallment();

      expect(outcome, isA<UiActionSuccess<void>>());
      expect(disbursement.deleteCommands.single.contractId, 'contract-1');
    });

    test('purchase installment deletion uses the consumption module', () async {
      final consumption = _FakeConsumptionInstallmentAppService();
      final container = _container(
        contract: _contract(
          type: InstallmentType.purchase,
          sourceRefId: 'purchase-tx',
        ),
        consumption: consumption,
      );
      await container.read(
        installmentDetailViewModelProvider('contract-1').future,
      );

      final outcome = await container
          .read(installmentDetailViewModelProvider('contract-1').notifier)
          .deleteInstallment();

      expect(outcome, isA<UiActionSuccess<void>>());
      expect(consumption.deleteCommands.single.contractId, 'contract-1');
    });

    test('bill installment deletion keeps the repayment bridge', () async {
      final contracts = _FakeInstallmentContractAppService();
      final container = _container(
        contract: _contract(
          type: InstallmentType.billConversion,
          sourceRefId: 'repayment-1',
        ),
        service: contracts,
      );
      await container.read(
        installmentDetailViewModelProvider('contract-1').future,
      );

      final outcome = await container
          .read(installmentDetailViewModelProvider('contract-1').notifier)
          .deleteInstallment();

      expect(outcome, isA<UiActionSuccess<void>>());
      expect(contracts.deleteCommands.single.contractId, 'contract-1');
    });

    test('revert delegates to command service', () async {
      final repaymentAppService = _FakeRepaymentAppService();
      final container = _container(
        contract: _contract(),
        activities: [_repaymentActivity()],
        repaymentAppService: repaymentAppService,
      );
      await container.read(
        installmentDetailViewModelProvider('contract-1').future,
      );

      final outcome = await container
          .read(installmentDetailViewModelProvider('contract-1').notifier)
          .revertRepayment('repayment-1');

      expect(outcome, isA<UiActionSuccess<void>>());
      expect(
        repaymentAppService.deleteCommands.single.repaymentId,
        'repayment-1',
      );
    });

    test('skip pending schedule delegates to command service', () async {
      final service = _FakeInstallmentContractAppService();
      final container = _container(
        contract: _contract(),
        schedules: [_schedule(1)],
        service: service,
      );
      await container.read(
        installmentDetailViewModelProvider('contract-1').future,
      );

      final outcome = await container
          .read(installmentDetailViewModelProvider('contract-1').notifier)
          .skipSchedule('schedule-1');

      expect(outcome, isA<UiActionSuccess<void>>());
      expect(service.skipCommands.single.contractId, 'contract-1');
      expect(service.skipCommands.single.scheduleId, 'schedule-1');
    });

    test('restore skipped schedule delegates to command service', () async {
      final service = _FakeInstallmentContractAppService();
      final container = _container(
        contract: _contract(),
        schedules: [_schedule(1, status: InstallmentScheduleStatus.skipped)],
        service: service,
      );
      await container.read(
        installmentDetailViewModelProvider('contract-1').future,
      );

      final outcome = await container
          .read(installmentDetailViewModelProvider('contract-1').notifier)
          .restoreSchedule('schedule-1');

      expect(outcome, isA<UiActionSuccess<void>>());
      expect(service.restoreCommands.single.contractId, 'contract-1');
      expect(service.restoreCommands.single.scheduleId, 'schedule-1');
    });

    test('status validation delegates to the status repair use case', () async {
      const result = ContractStatusValidationResult(
        repairedScheduleCount: 2,
        contractStatusChanged: true,
      );
      final repair = _FakeStatusRepairAppService(validationResult: result);
      final container = _container(contract: _contract(), statusRepair: repair);
      await container.read(
        installmentDetailViewModelProvider('contract-1').future,
      );

      final outcome = await container
          .read(installmentDetailViewModelProvider('contract-1').notifier)
          .validateContractStatuses();

      expect(outcome, isA<UiActionSuccess<ContractStatusValidationResult>>());
      expect(
        (outcome as UiActionSuccess<ContractStatusValidationResult>).value,
        same(result),
      );
      expect(repair.contractIds.single, 'contract-1');
    });

    test('status repair failures are returned as UI failures', () async {
      final repair = _FakeStatusRepairAppService(
        exception: BusinessException(CreditErrorCode.contractNotFound),
      );
      final container = _container(contract: _contract(), statusRepair: repair);
      await container.read(
        installmentDetailViewModelProvider('contract-1').future,
      );

      final outcome = await container
          .read(installmentDetailViewModelProvider('contract-1').notifier)
          .validateContractStatuses();

      expect(outcome, isA<UiActionFailure<ContractStatusValidationResult>>());
      expect(
        (outcome as UiActionFailure<ContractStatusValidationResult>).error.code,
        CreditErrorCode.contractNotFound.code,
      );
    });

    test('maps AppException to UI failure', () async {
      final disbursement = _FakeDisbursementInstallmentAppService(
        deleteException: BusinessException(
          CreditErrorCode.contractPersistenceConflict,
          message: '合同数据已变化，请刷新后重试。',
        ),
      );
      final container = _container(
        contract: _contract(),
        disbursement: disbursement,
      );
      await container.read(
        installmentDetailViewModelProvider('contract-1').future,
      );

      final outcome = await container
          .read(installmentDetailViewModelProvider('contract-1').notifier)
          .deleteInstallment();

      expect(outcome, isA<UiActionFailure<void>>());
      final failure = outcome as UiActionFailure<void>;
      expect(
        failure.error.code,
        CreditErrorCode.contractPersistenceConflict.code,
      );
      expect(failure.error.message, '合同数据已变化，请刷新后重试。');
    });

    test('maps regular Exception to unknown UI failure', () async {
      final repaymentAppService = _FakeRepaymentAppService(
        deleteException: Exception('database failed'),
      );
      final container = _container(
        contract: _contract(),
        activities: [_repaymentActivity()],
        repaymentAppService: repaymentAppService,
      );
      await container.read(
        installmentDetailViewModelProvider('contract-1').future,
      );

      final outcome = await container
          .read(installmentDetailViewModelProvider('contract-1').notifier)
          .revertRepayment('repayment-1');

      expect(outcome, isA<UiActionFailure<void>>());
      expect((outcome as UiActionFailure<void>).error.code, 'unknown');
    });
  });
}

ProviderContainer _container({
  required InstallmentContractReadModel? contract,
  List<InstallmentScheduleReadModel> schedules = const [],
  List<ContractActivity> activities = const [],
  _FakeInstallmentContractAppService? service,
  _FakeDisbursementInstallmentAppService? disbursement,
  _FakeConsumptionInstallmentAppService? consumption,
  _FakeRepaymentAppService? repaymentAppService,
  _FakeStatusRepairAppService? statusRepair,
}) {
  final planService = service?.planService ?? _FakeInstallmentPlanAppService();
  final container = ProviderContainer(
    overrides: [
      installmentStatusRepairAppServiceProvider.overrideWithValue(
        statusRepair ?? _FakeStatusRepairAppService(),
      ),
      installmentContractProvider.overrideWith(
        (ref, contractId) async => contract,
      ),
      installmentSchedulesProvider.overrideWith(
        (ref, contractId) async => schedules,
      ),
      installmentActivitiesProvider.overrideWith(
        (ref, contractId) async => activities,
      ),
      installmentContractAppServiceProvider.overrideWithValue(
        service ?? _FakeInstallmentContractAppService(),
      ),
      disbursementInstallmentAppServiceProvider.overrideWithValue(
        disbursement ?? _FakeDisbursementInstallmentAppService(),
      ),
      consumptionInstallmentAppServiceProvider.overrideWithValue(
        consumption ?? _FakeConsumptionInstallmentAppService(),
      ),
      installmentPlanAppServiceProvider.overrideWithValue(planService),
      installmentPrepaymentAppServiceProvider.overrideWithValue(
        repaymentAppService ?? _FakeRepaymentAppService(),
      ),
    ],
  );
  addTearDown(container.dispose);
  return container;
}

InstallmentContractReadModel _contract({
  InstallmentType type = InstallmentType.disbursement,
  String? sourceRefId,
}) {
  return InstallmentContractReadModel(
    id: 'contract-1',
    liabilityAccountId: 'loan',
    installmentType: type,
    sourceRefId: sourceRefId,
    disbursementAccountId: type == InstallmentType.disbursement ? 'cash' : null,
    principal: const Money(minorUnits: 10000),
    borrowingDate: DateTime(2026, 1, 1),
    status: InstallmentContractStatus.active,
    createdAt: DateTime(2026, 1, 1),
    stageTerms: InstallmentContractTerms.singleStage(
      id: 'contract-1:stage:1',
      totalPeriods: 2,
      firstDate: DateTime(2026, 2, 1),
      lastDate: DateTime(2026, 3, 1),
      method: InstallmentRepaymentMethod.equalPrincipal,
      accrual: InterestAccrualMethod.daily,
      feeMinor: 0,
    ),
  );
}

InstallmentScheduleReadModel _schedule(
  int periodNo, {
  Money principal = const Money(minorUnits: 4000),
  InstallmentScheduleStatus status = InstallmentScheduleStatus.pending,
}) {
  return InstallmentScheduleReadModel(
    id: 'schedule-$periodNo',
    contractId: 'contract-1',
    periodNo: periodNo,
    expectedRepaymentDate: DateTime(2026, periodNo + 1, 1),
    expectedPrincipal: principal,
    expectedInterest: const Money(minorUnits: 50),
    expectedFee: Money.zero(),
    status: status,
    createdAt: DateTime(2026, 1, 1),
  );
}

ContractRepaymentActivity _repaymentActivity() {
  return ContractRepaymentActivity(
    id: 'repayment-1',
    transactionId: 'tx-repay',
    repaymentType: RepaymentType.prepayment,
    occurredAt: DateTime(2026, 2, 1),
    principal: const Money(minorUnits: 4000),
    interest: const Money(minorUnits: 200),
    fee: const Money(minorUnits: 30),
  );
}

ContractRefundReductionActivity _refundReductionActivity() {
  return ContractRefundReductionActivity(
    id: 'refund-reduction-1',
    occurredAt: DateTime(2026, 3, 1),
    principal: const Money(minorUnits: 3000),
    refundTransactionId: 'tx-refund',
  );
}

class _FakeInstallmentContractAppService
    implements InstallmentContractAppService {
  _FakeInstallmentContractAppService();
  final planService = _FakeInstallmentPlanAppService();
  List<SkipInstallmentScheduleCommand> get skipCommands =>
      planService.skipCommands;
  List<RestoreInstallmentScheduleCommand> get restoreCommands =>
      planService.restoreCommands;
  final deleteCommands = <DeleteContractCommand>[];

  @override
  Future<void> deleteContract(DeleteContractCommand command) async {
    deleteCommands.add(command);
  }

  Future<void> skipSchedule(SkipInstallmentScheduleCommand command) async {
    skipCommands.add(command);
  }

  Future<void> restoreSchedule(
    RestoreInstallmentScheduleCommand command,
  ) async {
    restoreCommands.add(command);
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _FakeDisbursementInstallmentAppService
    implements DisbursementInstallmentAppService {
  _FakeDisbursementInstallmentAppService({this.deleteException});

  final Object? deleteException;
  final deleteCommands = <DeleteInstallmentCommand>[];

  @override
  Future<void> delete(DeleteInstallmentCommand command) async {
    deleteCommands.add(command);
    final exception = deleteException;
    if (exception != null) throw exception;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) =>
      throw UnimplementedError('${invocation.memberName}');
}

class _FakeConsumptionInstallmentAppService
    implements ConsumptionInstallmentAppService {
  final deleteCommands = <DeleteInstallmentCommand>[];

  @override
  Future<void> delete(DeleteInstallmentCommand command) async {
    deleteCommands.add(command);
  }

  @override
  dynamic noSuchMethod(Invocation invocation) =>
      throw UnimplementedError('${invocation.memberName}');
}

class _FakeInstallmentPlanAppService implements InstallmentPlanAppService {
  final skipCommands = <SkipInstallmentScheduleCommand>[];
  final restoreCommands = <RestoreInstallmentScheduleCommand>[];

  @override
  Future<void> skipSchedule(SkipInstallmentScheduleCommand command) async {
    skipCommands.add(command);
  }

  @override
  Future<void> restoreSchedule(
    RestoreInstallmentScheduleCommand command,
  ) async {
    restoreCommands.add(command);
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _FakeRepaymentAppService implements InstallmentPrepaymentAppService {
  _FakeRepaymentAppService({this.deleteException});

  final Object? deleteException;
  final deleteCommands = <DeleteCreditRepaymentCommand>[];

  @override
  Future<void> deleteRepayment(DeleteCreditRepaymentCommand command) async {
    deleteCommands.add(command);
    final exception = deleteException;
    if (exception != null) throw exception;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _FakeStatusRepairAppService implements InstallmentStatusRepairAppService {
  _FakeStatusRepairAppService({
    this.validationResult = const ContractStatusValidationResult(
      repairedScheduleCount: 0,
      contractStatusChanged: false,
    ),
    this.exception,
  });

  final ContractStatusValidationResult validationResult;
  final Object? exception;
  final contractIds = <String>[];

  @override
  Future<ContractStatusValidationResult> validateAndRepair(
    String contractId,
  ) async {
    contractIds.add(contractId);
    final error = exception;
    if (error != null) throw error;
    return validationResult;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
