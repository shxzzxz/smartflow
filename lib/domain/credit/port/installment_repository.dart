import '../../../core/money/money.dart';
import '../../../core/patch/patch.dart';
import '../entity/installment_contract.dart';
import '../entity/installment_schedule.dart';
import '../valobj/installment_enums.dart';

/// 合同字段编辑补丁，仅包含可变字段。
/// 借款日期之外、可变的合同字段都可在此 patch。
///
/// - 普通可空字段使用 `T?`：`null` 表示"不改"。
/// - `note` / 利率两组字段使用 [Patch]：业务允许从"有值"清除为"无值"。
/// - `disbursementAccountId` 用 `String?`，业务上禁止从有值清除（不允许合同跨 sourceType）。
class InstallmentContractPatch {
  const InstallmentContractPatch({
    this.totalPeriods,
    this.firstRepaymentDate,
    this.lastRepaymentDate,
    this.borrowingDate,
    this.repaymentMethod,
    this.interestRatePeriod,
    this.interestRatePpm,
    this.interestAccrualMethod,
    this.totalFeeMinor,
    this.note,
    this.disbursementAccountId,
  });

  final int? totalPeriods;
  final DateTime? firstRepaymentDate;
  final DateTime? lastRepaymentDate;
  final DateTime? borrowingDate;
  final InstallmentRepaymentMethod? repaymentMethod;
  final Patch<InterestRatePeriod>? interestRatePeriod;
  final Patch<int>? interestRatePpm;
  final InterestAccrualMethod? interestAccrualMethod;
  final int? totalFeeMinor;
  final Patch<String>? note;
  final String? disbursementAccountId;
}

class InstallmentSchedulePatch {
  const InstallmentSchedulePatch({
    this.expectedRepaymentDate,
    this.expectedPrincipal,
    this.expectedInterest,
    this.expectedFee,
    this.status,
    this.note,
  });

  final DateTime? expectedRepaymentDate;
  final Money? expectedPrincipal;
  final Money? expectedInterest;
  final Money? expectedFee;
  final InstallmentScheduleStatus? status;
  final Patch<String>? note;
}

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

  Future<void> updateContract(
    String contractId,
    InstallmentContractPatch patch,
  );

  Future<void> replaceSchedules(
    String contractId,
    List<InstallmentSchedule> schedules,
  );

  /// 追加 pending 期次行（不动现有 schedule 行）。
  /// schedules 中的 periodNo 由调用方负责，保证全表 periodNo 唯一。
  Future<void> appendSchedules(
    String contractId,
    List<InstallmentSchedule> schedules,
  );

  Future<void> updateSchedule(
    String scheduleId,
    InstallmentSchedulePatch patch,
  );

  Future<void> updateContractStatus(
    String contractId,
    InstallmentContractStatus status,
  );

  /// 物理删除合同及 schedules。来源还款、账单投影和交易由 application 清理。
  Future<void> deleteContract(String contractId);
}
