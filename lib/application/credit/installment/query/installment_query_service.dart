import 'package:smartflow/domain/credit/entity/installment_contract.dart';
import 'package:smartflow/domain/credit/entity/installment_schedule.dart';
import 'package:smartflow/domain/credit/port/installment_repository.dart';
import 'package:smartflow/domain/credit/valobj/installment_enums.dart';

abstract interface class InstallmentQueryService {
  Future<List<InstallmentContract>> listContractsByLiabilityAccount(
    String liabilityAccountId,
  );

  Future<InstallmentContract?> findContract(String contractId);

  Future<List<InstallmentSchedule>> listSchedules(String contractId);

  /// 该负债账户上所有 active 分期合同的未还本金合计（minor units）。
  Future<int> unpaidInstallmentPrincipalMinor(String liabilityAccountId);
}

class InstallmentQueryServiceImpl implements InstallmentQueryService {
  const InstallmentQueryServiceImpl({required InstallmentRepository repository})
    : _repository = repository;

  final InstallmentRepository _repository;

  @override
  Future<List<InstallmentContract>> listContractsByLiabilityAccount(
    String liabilityAccountId,
  ) {
    return _repository.listContractsByLiabilityAccount(liabilityAccountId);
  }

  @override
  Future<InstallmentContract?> findContract(String contractId) {
    return _repository.findContract(contractId);
  }

  @override
  Future<List<InstallmentSchedule>> listSchedules(String contractId) {
    return _repository.listSchedules(contractId);
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
}
