import 'package:smartflow/domain/credit/entity/installment_contract.dart';
import 'package:smartflow/domain/credit/entity/installment_schedule.dart';
import 'package:smartflow/domain/credit/port/installment_repository.dart';
import 'package:smartflow/domain/credit/valobj/installment_enums.dart';

import 'installment_read_models.dart';

abstract interface class InstallmentQueryService {
  Future<List<InstallmentContractReadModel>> listContractsByLiabilityAccount(
    String liabilityAccountId,
  );

  Future<InstallmentContractReadModel?> findContract(String contractId);

  Future<List<InstallmentScheduleReadModel>> listSchedules(String contractId);

  /// 该负债账户上所有 active 分期合同的未还本金合计（minor units）。
  Future<int> unpaidInstallmentPrincipalMinor(String liabilityAccountId);
}

class InstallmentQueryServiceImpl implements InstallmentQueryService {
  const InstallmentQueryServiceImpl({required InstallmentRepository repository})
    : _repository = repository;

  final InstallmentRepository _repository;

  @override
  Future<List<InstallmentContractReadModel>> listContractsByLiabilityAccount(
    String liabilityAccountId,
  ) async {
    final values = await _repository.listContractsByLiabilityAccount(
      liabilityAccountId,
    );
    return values.map(_contractReadModel).toList();
  }

  @override
  Future<InstallmentContractReadModel?> findContract(String contractId) async {
    final value = await _repository.findContract(contractId);
    return value == null ? null : _contractReadModel(value);
  }

  @override
  Future<List<InstallmentScheduleReadModel>> listSchedules(
    String contractId,
  ) async {
    final values = await _repository.listSchedules(contractId);
    return values.map(_scheduleReadModel).toList();
  }

  @override
  Future<int> unpaidInstallmentPrincipalMinor(String liabilityAccountId) async {
    final contracts = await _repository.listContractsByLiabilityAccount(
      liabilityAccountId,
    );
    var sum = 0;
    for (final contract in contracts) {
      if (contract.status != InstallmentContractStatus.active) continue;
      final schedules = await _repository.listSchedules(contract.id);
      sum += schedules
          .where(
            (schedule) =>
                schedule.status == InstallmentScheduleStatus.pending ||
                schedule.status == InstallmentScheduleStatus.partiallyPaid,
          )
          .fold<int>(
            0,
            (total, schedule) => total + schedule.expectedPrincipal.minorUnits,
          );
    }
    return sum;
  }

  InstallmentContractReadModel _contractReadModel(InstallmentContract value) {
    return InstallmentContractReadModel(
      id: value.id,
      liabilityAccountId: value.liabilityAccountId,
      sourceType: value.sourceType,
      disbursementAccountId: value.disbursementAccountId,
      disbursementTransactionId: value.disbursementTransactionId,
      sourceRepaymentId: value.sourceRepaymentId,
      principal: value.principal,
      totalPeriods: value.totalPeriods,
      borrowingDate: value.borrowingDate,
      firstRepaymentDate: value.firstRepaymentDate,
      lastRepaymentDate: value.lastRepaymentDate,
      repaymentMethod: value.repaymentMethod,
      interestRatePeriod: value.interestRatePeriod,
      interestRatePpm: value.interestRatePpm,
      interestAccrualMethod: value.interestAccrualMethod,
      totalFeeMinor: value.totalFeeMinor,
      status: value.status,
      note: value.note,
      createdAt: value.createdAt,
    );
  }

  InstallmentScheduleReadModel _scheduleReadModel(InstallmentSchedule value) {
    return InstallmentScheduleReadModel(
      id: value.id,
      contractId: value.contractId,
      periodNo: value.periodNo,
      expectedRepaymentDate: value.expectedRepaymentDate,
      expectedPrincipal: value.expectedPrincipal,
      expectedInterest: value.expectedInterest,
      expectedFee: value.expectedFee,
      status: value.status,
      note: value.note,
      createdAt: value.createdAt,
    );
  }
}
