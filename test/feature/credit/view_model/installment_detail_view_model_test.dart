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
        cashflows: [_cashflow()],
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

    test('returns not found state when contract is missing', () async {
      final container = _container(contract: null);

      final state = await container.read(
        installmentDetailViewModelProvider('contract-1').future,
      );

      expect(state, isA<InstallmentDetailNotFound>());
    });

    test('delete delegates to command service', () async {
      final service = _FakeInstallmentAppService();
      final container = _container(contract: _contract(), service: service);
      await container.read(
        installmentDetailViewModelProvider('contract-1').future,
      );

      final outcome =
          await container
              .read(installmentDetailViewModelProvider('contract-1').notifier)
              .deleteContract();

      expect(outcome, isA<UiActionSuccess<void>>());
      expect(service.deleteCommands.single.contractId, 'contract-1');
    });

    test('revert delegates to command service', () async {
      final repaymentAppService = _FakeRepaymentAppService();
      final container = _container(
        contract: _contract(),
        repaymentAppService: repaymentAppService,
      );
      await container.read(
        installmentDetailViewModelProvider('contract-1').future,
      );

      final outcome = await container
          .read(installmentDetailViewModelProvider('contract-1').notifier)
          .revertRepayment('tx-repay');

      expect(outcome, isA<UiActionSuccess<void>>());
      expect(repaymentAppService.deleteCommands.single.repaymentId, 'tx-repay');
    });

    test('maps AppException to UI failure', () async {
      final service = _FakeInstallmentAppService(
        deleteException: BusinessException(
          CreditErrorCode.contractPersistenceConflict,
          message: '合同数据已变化，请刷新后重试。',
        ),
      );
      final container = _container(contract: _contract(), service: service);
      await container.read(
        installmentDetailViewModelProvider('contract-1').future,
      );

      final outcome =
          await container
              .read(installmentDetailViewModelProvider('contract-1').notifier)
              .deleteContract();

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
        repaymentAppService: repaymentAppService,
      );
      await container.read(
        installmentDetailViewModelProvider('contract-1').future,
      );

      final outcome = await container
          .read(installmentDetailViewModelProvider('contract-1').notifier)
          .revertRepayment('tx-repay');

      expect(outcome, isA<UiActionFailure<void>>());
      expect((outcome as UiActionFailure<void>).error.code, 'unknown');
    });
  });
}

ProviderContainer _container({
  required InstallmentContract? contract,
  List<InstallmentSchedule> schedules = const [],
  List<RepaymentCashflow> cashflows = const [],
  _FakeInstallmentAppService? service,
  _FakeRepaymentAppService? repaymentAppService,
}) {
  final container = ProviderContainer(
    overrides: [
      installmentContractProvider.overrideWith(
        (ref, contractId) async => contract,
      ),
      installmentSchedulesProvider.overrideWith(
        (ref, contractId) async => schedules,
      ),
      installmentRepaymentCashflowsProvider.overrideWith(
        (ref, contractId) async => cashflows,
      ),
      installmentAppServiceProvider.overrideWithValue(
        service ?? _FakeInstallmentAppService(),
      ),
      repaymentAppServiceProvider.overrideWithValue(
        repaymentAppService ?? _FakeRepaymentAppService(),
      ),
    ],
  );
  addTearDown(container.dispose);
  return container;
}

InstallmentContract _contract() {
  return InstallmentContract(
    id: 'contract-1',
    liabilityAccountId: 'loan',
    sourceType: InstallmentSourceType.disbursement,
    disbursementAccountId: 'cash',
    principal: const Money(minorUnits: 10000),
    totalPeriods: 2,
    borrowingDate: DateTime(2026, 1, 1),
    firstRepaymentDate: DateTime(2026, 2, 1),
    lastRepaymentDate: DateTime(2026, 3, 1),
    repaymentMethod: InstallmentRepaymentMethod.equalPrincipal,
    interestAccrualMethod: InterestAccrualMethod.daily,
    totalFeeMinor: 0,
    status: InstallmentContractStatus.active,
    createdAt: DateTime(2026, 1, 1),
  );
}

InstallmentSchedule _schedule(
  int periodNo, {
  Money principal = const Money(minorUnits: 4000),
  InstallmentScheduleStatus status = InstallmentScheduleStatus.pending,
}) {
  return InstallmentSchedule(
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

RepaymentCashflow _cashflow() {
  return RepaymentCashflow(
    id: 'repayment-1',
    transactionId: 'tx-repay',
    repaymentType: RepaymentType.prepayment,
    occurredAt: DateTime(2026, 2, 1),
    principal: const Money(minorUnits: 4000),
    interest: const Money(minorUnits: 200),
    fee: const Money(minorUnits: 30),
  );
}

class _FakeInstallmentAppService implements InstallmentAppService {
  _FakeInstallmentAppService({this.deleteException});

  final Object? deleteException;
  final deleteCommands = <DeleteContractCommand>[];

  @override
  Future<void> deleteContract(DeleteContractCommand command) async {
    deleteCommands.add(command);
    final exception = deleteException;
    if (exception != null) throw exception;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _FakeRepaymentAppService implements RepaymentAppService {
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
