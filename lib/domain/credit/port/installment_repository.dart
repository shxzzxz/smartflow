import '../entity/installment_contract.dart';
import '../entity/installment_schedule.dart';

abstract interface class InstallmentRepository {
  Future<InstallmentContract?> findContract(String id);

  Future<List<InstallmentContract>> listContractsByLiabilityAccount(
    String liabilityAccountId,
  );

  Future<List<InstallmentSchedule>> listSchedules(String contractId);

  Future<List<InstallmentSchedule>> listSchedulesByLiabilityAccount(
    String liabilityAccountId,
  );

  Future<InstallmentSchedule?> findSchedule(String scheduleId);

  /// 反查：transaction 是否为某合同的放款交易；若是返回该合同，否则返回 null。
  /// 仅 `sourceType == disbursement` 的合同会命中。
  Future<InstallmentContract?> findContractByDisbursementTransaction(
    String transactionId,
  );

  Future<void> saveContract(InstallmentContract contract);

  Future<void> insertAggregate(
    InstallmentContract contract,
    List<InstallmentSchedule> schedules,
  );

  Future<void> saveAggregate(
    InstallmentContract contract,
    List<InstallmentSchedule> schedules,
  );

  /// 物理删除合同及 schedules。来源还款、账单投影和交易由 application 清理。
  Future<void> deleteContract(String contractId);
}
