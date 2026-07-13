import 'package:flutter_test/flutter_test.dart';
import 'package:smartflow/application/credit/installment/query/contract_metrics_query.dart';
import 'package:smartflow/core/money/money.dart';
import 'package:smartflow/domain/credit/entity/installment_contract.dart';
import 'package:smartflow/domain/credit/entity/installment_schedule.dart';
import 'package:smartflow/domain/credit/port/installment_repository.dart';
import 'package:smartflow/domain/credit/valobj/installment_enums.dart';

void main() {
  test(
    'contract metrics query loads only contract and planned cashflows',
    () async {
      final installments = _FakeInstallmentRepository(
        contract: _contract(),
        schedules: [
          _schedule(id: 'one', periodNo: 1, principal: 4000, interest: 100),
          _schedule(id: 'two', periodNo: 2, principal: 3000, interest: 100),
          _schedule(id: 'three', periodNo: 3, principal: 3000, interest: 100),
        ],
      );
      final query = ContractMetricsQueryImpl(installments: installments);

      final result = await query.getContractMetrics('contract');

      expect(result.isAvailable, isTrue);
      expect(result.totalRepayment, const Money(minorUnits: 10300));
      expect(installments.requestedContractId, 'contract');
      expect(installments.requestedSchedulesContractId, 'contract');
    },
  );
}

class _FakeInstallmentRepository implements InstallmentRepository {
  _FakeInstallmentRepository({required this.contract, required this.schedules});

  final InstallmentContract contract;
  final List<InstallmentSchedule> schedules;
  String? requestedContractId;
  String? requestedSchedulesContractId;

  @override
  Future<InstallmentContract?> findContract(String id) async {
    requestedContractId = id;
    return contract;
  }

  @override
  Future<List<InstallmentSchedule>> listSchedules(String contractId) async {
    requestedSchedulesContractId = contractId;
    return schedules;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

InstallmentContract _contract() {
  return InstallmentContract(
    id: 'contract',
    liabilityAccountId: 'liability',
    sourceType: InstallmentSourceType.disbursement,
    principal: const Money(minorUnits: 10000),
    totalPeriods: 3,
    borrowingDate: DateTime(2026, 1, 1),
    firstRepaymentDate: DateTime(2026, 2, 1),
    lastRepaymentDate: DateTime(2026, 4, 1),
    repaymentMethod: InstallmentRepaymentMethod.equalPrincipal,
    interestAccrualMethod: InterestAccrualMethod.monthly,
    totalFeeMinor: 0,
    status: InstallmentContractStatus.active,
    createdAt: DateTime(2026, 1, 1),
  );
}

InstallmentSchedule _schedule({
  required String id,
  required int periodNo,
  required int principal,
  required int interest,
}) {
  return InstallmentSchedule(
    id: id,
    contractId: 'contract',
    periodNo: periodNo,
    expectedRepaymentDate: DateTime(2026, periodNo + 1, 1),
    expectedPrincipal: Money(minorUnits: principal),
    expectedInterest: Money(minorUnits: interest),
    expectedFee: Money.zero(),
    status: InstallmentScheduleStatus.pending,
    createdAt: DateTime(2026, 1, 1),
  );
}
