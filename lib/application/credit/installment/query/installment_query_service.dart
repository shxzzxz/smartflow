import 'package:smartflow/domain/credit/entity/installment_contract.dart';
import 'package:smartflow/domain/credit/entity/installment_schedule.dart';
import 'package:smartflow/domain/credit/port/installment_repository.dart';
import '../../../../domain/credit/port/installment_repricing_repository.dart';
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
  const InstallmentQueryServiceImpl({
    required InstallmentRepository repository,
    required InstallmentRepricingRepository repricings,
  }) : _repository = repository,
       _repricings = repricings;

  final InstallmentRepository _repository;
  final InstallmentRepricingRepository _repricings;

  @override
  Future<List<InstallmentContractReadModel>> listContractsByLiabilityAccount(
    String liabilityAccountId,
  ) async {
    final values = await _repository.listContractsByLiabilityAccount(
      liabilityAccountId,
    );
    return Future.wait(values.map(_contractReadModel));
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

  Future<InstallmentContractReadModel> _contractReadModel(
    InstallmentContract value,
  ) async {
    final repricings = await _repricings.list(value.id);
    return InstallmentContractReadModel(
      id: value.id,
      name: value.name,
      liabilityAccountId: value.liabilityAccountId,
      sourceType: value.sourceType,
      disbursementAccountId: value.disbursementAccountId,
      disbursementTransactionId: value.disbursementTransactionId,
      sourceRepaymentId: value.sourceRepaymentId,
      principal: value.principal,
      borrowingDate: value.borrowingDate,
      status: value.status,
      note: value.note,
      createdAt: value.createdAt,
      stageTerms: value.stageTerms,
      repricingConfigurations: List.unmodifiable([
        for (final config in value.repricingConfigurations)
          InstallmentRepricingConfigurationReadModel(
            id: config.id,
            stageId: config.stageId,
            effectiveFrom: config.effectiveFrom,
            rule: config.rule,
          ),
      ]),
      repricings: List.unmodifiable([
        for (final record in value.repricings)
          InstallmentRepricingReadModel(
            id: record.id,
            stageId: record.stageId,
            change: record.change,
            status: record.status,
          ),
      ]),
      interestAdjustments: List.unmodifiable([
        for (final record in value.interestAdjustments)
          InstallmentInterestAdjustmentReadModel(
            id: record.id,
            adjustment: record.adjustment,
          ),
      ]),
      unconfirmedRepricingIds: List.unmodifiable([
        for (final record in repricings)
          if (record.status == InstallmentRepricingStatus.applied) record.id,
      ]),
    );
  }

  InstallmentScheduleReadModel _scheduleReadModel(InstallmentSchedule value) {
    return InstallmentScheduleReadModel(
      id: value.id,
      contractId: value.contractId,
      stageId: value.stageId,
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
