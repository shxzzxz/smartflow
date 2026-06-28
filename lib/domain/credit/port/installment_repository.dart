import '../../../core/money/money.dart';
import '../../../core/patch/patch.dart';
import '../entity/installment_contract.dart';
import '../entity/installment_repayment.dart';
import '../entity/installment_schedule.dart';
import '../valobj/installment_enums.dart';
import '../service/installment_schedule_generator.dart';

class InstallmentContractDraft {
  const InstallmentContractDraft({
    required this.liabilityAccountId,
    required this.sourceType,
    required this.principal,
    required this.totalPeriods,
    required this.borrowingDate,
    required this.firstRepaymentDate,
    required this.lastRepaymentDate,
    required this.repaymentMethod,
    required this.interestAccrualMethod,
    required this.status,
    this.disbursementAccountId,
    this.disbursementTransactionId,
    this.sourceRepaymentId,
    this.interestRatePeriod,
    this.interestRatePpm,
    this.totalFeeMinor = 0,
    this.note,
  });

  final String liabilityAccountId;
  final InstallmentSourceType sourceType;
  final String? disbursementAccountId;
  final String? disbursementTransactionId;
  final String? sourceRepaymentId;
  final Money principal;
  final int totalPeriods;
  final DateTime borrowingDate;
  final DateTime firstRepaymentDate;
  final DateTime lastRepaymentDate;
  final InstallmentRepaymentMethod repaymentMethod;
  final InterestRatePeriod? interestRatePeriod;
  final int? interestRatePpm;
  final InterestAccrualMethod interestAccrualMethod;
  final int totalFeeMinor;
  final InstallmentContractStatus status;
  final String? note;
}

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

class InstallmentRepaymentDraft {
  const InstallmentRepaymentDraft({
    required this.contractId,
    required this.repaymentType,
    required this.transactionId,
    this.scheduleId,
  });

  final String contractId;
  final InstallmentRepaymentType repaymentType;
  final String? scheduleId;
  final String transactionId;
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

  Future<List<InstallmentRepayment>> listRepayments(String contractId);

  Future<InstallmentRepayment?> findRepaymentByTransaction(
    String transactionId,
  );

  /// 反查：transaction 是否为某合同的放款交易；若是返回该合同，否则返回 null。
  /// 仅 `sourceType == disbursement` 的合同会命中。
  Future<InstallmentContract?> findContractByDisbursementTransaction(
    String transactionId,
  );

  Future<String> insertContract(InstallmentContractDraft draft);

  Future<void> updateContract(
    String contractId,
    InstallmentContractPatch patch,
  );

  Future<void> replaceSchedules(
    String contractId,
    List<InstallmentScheduleDraft> drafts,
  );

  /// 追加 pending 期次行（不动现有 schedule 行）。
  /// drafts 中的 periodNo 由调用方负责，保证全表 periodNo 唯一。
  Future<void> appendSchedules(
    String contractId,
    List<InstallmentScheduleDraft> drafts,
  );

  Future<void> updateSchedule(
    String scheduleId,
    InstallmentSchedulePatch patch,
  );

  Future<String> insertRepayment(InstallmentRepaymentDraft draft);

  Future<void> deleteRepayment(String repaymentId);

  Future<void> updateContractStatus(
    String contractId,
    InstallmentContractStatus status,
  );

  /// 物理删除合同：连同 schedules 与 repayments 一并清理。
  /// 调用方负责确保合同无关联还款且无放款交易，本方法不动 transaction 表。
  Future<void> deleteContract(String contractId);
}
