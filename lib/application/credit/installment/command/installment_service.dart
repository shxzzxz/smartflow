import 'package:smartflow/application/ledger/ledger_command_api.dart';
import 'package:smartflow/application/shared/transaction_runner.dart';
import 'package:smartflow/core/error/app_exception.dart';
import 'package:smartflow/core/money/money.dart';
import 'package:smartflow/core/patch/patch.dart';
import 'package:smartflow/domain/credit/entity/credit_liability_account.dart';
import 'package:smartflow/domain/credit/entity/installment_schedule.dart';
import 'package:smartflow/domain/credit/port/credit_account_repository.dart';
import 'package:smartflow/domain/credit/port/installment_repository.dart';
import 'package:smartflow/domain/credit/port/repayment_repository.dart';
import 'package:smartflow/domain/credit/service/installment_schedule_generator.dart';
import 'package:smartflow/domain/credit/valobj/bill_period.dart';
import 'package:smartflow/domain/credit/valobj/credit_account_enums.dart';
import 'package:smartflow/domain/credit/valobj/credit_error_code.dart';
import 'package:smartflow/domain/credit/valobj/installment_enums.dart';
import 'package:smartflow/domain/credit/valobj/repayment_enums.dart';

class CreateDisbursementContractCommand {
  const CreateDisbursementContractCommand({
    required this.liabilityAccountId,
    required this.principal,
    required this.totalPeriods,
    required this.borrowingDate,
    required this.firstRepaymentDate,
    required this.repaymentMethod,
    this.lastRepaymentDate,
    this.interestRatePeriod,
    this.interestRatePpm,
    this.interestAccrualMethod = InterestAccrualMethod.daily,
    this.totalFeeMinor = 0,
    this.equalInstallmentOverrideMinor,
    this.disbursementAccountId,
    this.note,
    this.counterpartyName,
  });

  final String liabilityAccountId;

  /// 放款入账账户。为空时用于迁移场景：只创建合同和计划，不创建放款交易。
  final String? disbursementAccountId;
  final Money principal;
  final int totalPeriods;

  /// 借款日期，同时作为放款交易的 occurredAt。
  final DateTime borrowingDate;
  final DateTime firstRepaymentDate;

  /// 末期还款日，缺省时 = 首期 + (期数-1) 月。
  final DateTime? lastRepaymentDate;

  final InstallmentRepaymentMethod repaymentMethod;
  final InterestRatePeriod? interestRatePeriod;
  final int? interestRatePpm;
  final InterestAccrualMethod interestAccrualMethod;
  final int totalFeeMinor;

  /// 等额本息下用户给定的每期还款额 A（前 N-1 期；末期吸误差）。
  /// 仅生成计划期间使用，**不落库**。null 时回落到公式推导。
  final int? equalInstallmentOverrideMinor;

  final String? note;
  final String? counterpartyName;
}

class CreateBillConversionContractCommand {
  const CreateBillConversionContractCommand({
    required this.liabilityAccountId,
    required this.principal,
    required this.totalPeriods,
    required this.borrowingDate,
    required this.firstRepaymentDate,
    required this.repaymentMethod,
    this.lastRepaymentDate,
    this.interestRatePeriod,
    this.interestRatePpm,
    this.interestAccrualMethod = InterestAccrualMethod.daily,
    this.totalFeeMinor = 0,
    this.equalInstallmentOverrideMinor,
    this.note,
  });

  final String liabilityAccountId;
  final Money principal;
  final int totalPeriods;
  final DateTime borrowingDate;
  final DateTime firstRepaymentDate;
  final DateTime? lastRepaymentDate;
  final InstallmentRepaymentMethod repaymentMethod;
  final InterestRatePeriod? interestRatePeriod;
  final int? interestRatePpm;
  final InterestAccrualMethod interestAccrualMethod;
  final int totalFeeMinor;

  /// 等额本息下用户给定的每期还款额 A，仅生成期间使用，**不落库**。
  final int? equalInstallmentOverrideMinor;

  final String? note;
}

class CreateScheduledRepaymentCommand {
  const CreateScheduledRepaymentCommand({
    required this.contractId,
    required this.scheduleId,
    required this.principal,
    required this.paidFromAccountId,
    required this.occurredAt,
    this.interest,
    this.fee,
    this.discount,
    this.note,
    this.counterpartyName,
  });

  final String contractId;
  final String scheduleId;
  final Money principal;
  final Money? interest;
  final Money? fee;
  final Money? discount;
  final String paidFromAccountId;
  final DateTime occurredAt;
  final String? note;
  final String? counterpartyName;
}

class RevertRepaymentCommand {
  const RevertRepaymentCommand({required this.transactionId});

  final String transactionId;
}

class DeleteContractCommand {
  const DeleteContractCommand({required this.contractId});

  final String contractId;
}

class RecalculateContractSchedulesCommand {
  const RecalculateContractSchedulesCommand({
    required this.contractId,
    this.equalInstallmentOverrideMinor,
  });

  final String contractId;

  /// 等额本息下用户给定的每期还款额 A，仅用于本次显式重算，不落库。
  final int? equalInstallmentOverrideMinor;
}

class RecalculatedSchedulePreview {
  const RecalculatedSchedulePreview({
    required this.scheduleId,
    required this.periodNo,
    required this.expectedRepaymentDate,
    required this.expectedPrincipal,
    required this.expectedInterest,
    required this.expectedFee,
  });

  final String scheduleId;
  final int periodNo;
  final DateTime expectedRepaymentDate;
  final Money expectedPrincipal;
  final Money expectedInterest;
  final Money expectedFee;
}

class SkipInstallmentScheduleCommand {
  const SkipInstallmentScheduleCommand({
    required this.contractId,
    required this.scheduleId,
  });

  final String contractId;
  final String scheduleId;
}

class RestoreInstallmentScheduleCommand {
  const RestoreInstallmentScheduleCommand({
    required this.contractId,
    required this.scheduleId,
  });

  final String contractId;
  final String scheduleId;
}

/// pending 期次的单行手工编辑值（不会改 paid / skipped 行）。
class SchedulePendingPatch {
  const SchedulePendingPatch({
    required this.periodNo,
    this.expectedPrincipal,
    this.expectedInterest,
    this.expectedFee,
    this.expectedRepaymentDate,
  });

  final int periodNo;
  final Money? expectedPrincipal;
  final Money? expectedInterest;
  final Money? expectedFee;
  final DateTime? expectedRepaymentDate;
}

/// 合同编辑命令。
///
/// 编辑范围由 service 校验：
/// - 借款日期可以改；若有放款交易，会联动 disbursement 交易的 occurredAt。
/// - 参数字段只写回合同快照，不会自动重算 schedule。
/// - [schedulePatches] 只覆盖对应 pending 行；paid / skipped 行不可编辑。
///
/// Partial update 约定：
/// - 普通 nullable 字段（`T?`）：`null` 表示"不改"，传值表示"设置"。
/// - 三态字段（`Patch<T>?`）：`null`=不改，`Patch.set`=设置，`Patch.clear`=清除。
/// - `disbursementAccountId`：仅对已有放款交易的放款合同有效；业务上禁止清除。
class UpdateContractCommand {
  const UpdateContractCommand({
    required this.contractId,
    this.totalPeriods,
    this.firstRepaymentDate,
    this.lastRepaymentDate,
    this.borrowingDate,
    this.repaymentMethod,
    this.interestRatePeriod,
    this.interestRatePpm,
    this.interestAccrualMethod,
    this.totalFeeMinor,
    this.equalInstallmentOverrideMinor,
    this.disbursementAccountId,
    this.note,
    this.schedulePatches = const [],
  });

  final String contractId;
  final int? totalPeriods;
  final DateTime? firstRepaymentDate;
  final DateTime? lastRepaymentDate;
  final DateTime? borrowingDate;
  final InstallmentRepaymentMethod? repaymentMethod;
  final Patch<InterestRatePeriod>? interestRatePeriod;
  final Patch<int>? interestRatePpm;
  final InterestAccrualMethod? interestAccrualMethod;
  final int? totalFeeMinor;

  /// 等额本息下用户给定的每期还款额 A，仅重算 pending 期次时使用，**不落库**。
  final int? equalInstallmentOverrideMinor;

  /// 放款合同的放款账户。仅对 sourceType=disbursement 的合同有效。
  /// 业务上禁止清除（账单分期合同永远 null，放款合同永远有值）。
  final String? disbursementAccountId;

  final Patch<String>? note;
  final List<SchedulePendingPatch> schedulePatches;
}

/// 受分期管理的还款交易（scheduled / prepayment）的编辑命令。
///
/// 用于把通用 UI 对还款交易的"改账户 / 改时间 / 改备注"统一收口到分期 service。
/// service 内部负责校验该 transaction 确实是分期还款，再委托账务应用服务
/// 完成 basics / metadata 更新；后续若需要联动合同状态可在此处加。
class EditRepaymentCommand {
  const EditRepaymentCommand({
    required this.transactionId,
    this.contractId,
    this.paidFromAccountId,
    this.occurredAt,
    this.note,
  });

  final String transactionId;

  /// 可选——调用方已知合同 id 时传入可省一次反查。
  final String? contractId;

  final String? paidFromAccountId;
  final DateTime? occurredAt;
  final Patch<String?>? note;
}

class CreateContractResult {
  const CreateContractResult({
    required this.contractId,
    this.disbursementTransactionId,
  });

  final String contractId;
  final String? disbursementTransactionId;
}

abstract interface class InstallmentService {
  Future<CreateContractResult> createDisbursementContract(
    CreateDisbursementContractCommand command,
  );

  Future<CreateContractResult> createBillConversionContract(
    CreateBillConversionContractCommand command,
  );

  Future<void> updateContract(UpdateContractCommand command);

  /// 预览按当前合同参数重算后的 pending 金额；日期保持现有 schedule 日期不变。
  Future<List<RecalculatedSchedulePreview>> previewContractRecalculation(
    RecalculateContractSchedulesCommand command,
  );

  /// 确认显式重算：只覆盖 pending 行金额，日期和 paid / skipped 行保持不变。
  Future<void> recalculateContractSchedules(
    RecalculateContractSchedulesCommand command,
  );

  Future<void> skipSchedule(SkipInstallmentScheduleCommand command);

  Future<void> restoreSchedule(RestoreInstallmentScheduleCommand command);

  /// 编辑受分期管理的还款交易（scheduled / prepayment）。
  /// 通用 UI 在还款交易上的 universal 编辑入口；service 内部校验归属、
  /// 再委托账务应用服务完成 transaction 表的写入。
  Future<void> editRepayment(EditRepaymentCommand command);

  Future<PostedTransactionResult> createScheduledRepayment(
    CreateScheduledRepaymentCommand command,
  );

  Future<void> revertRepayment(RevertRepaymentCommand command);

  /// 删除合同：仅允许无关联还款且无放款交易的合同被物理删除。
  Future<void> deleteContract(DeleteContractCommand command);
}

class InstallmentServiceImpl implements InstallmentService {
  InstallmentServiceImpl({
    required InstallmentRepository repository,
    required CreditAccountRepository creditAccounts,
    required RepaymentRepository repayments,
    required TransactionPostingAppService postingService,
    required TransactionCorrectionAppService correctionService,
    required TransactionUpdateAppService updateService,
    required TransactionRunner transactionRunner,
    InstallmentScheduleGenerator generator =
        const InstallmentScheduleGenerator(),
  }) : _repository = repository,
       _creditAccounts = creditAccounts,
       _repayments = repayments,
       _postingService = postingService,
       _correctionService = correctionService,
       _updateService = updateService,
       _runner = transactionRunner,
       _generator = generator;

  final InstallmentRepository _repository;
  final CreditAccountRepository _creditAccounts;
  final RepaymentRepository _repayments;
  final TransactionPostingAppService _postingService;
  final TransactionCorrectionAppService _correctionService;
  final TransactionUpdateAppService _updateService;
  final TransactionRunner _runner;
  final InstallmentScheduleGenerator _generator;

  @override
  Future<CreateContractResult> createDisbursementContract(
    CreateDisbursementContractCommand command,
  ) async {
    final creditAccount = await _creditAccounts.findByAccountId(
      command.liabilityAccountId,
    );
    final cycleDates = _cycleScheduleBoundsForDisbursement(
      creditAccount,
      borrowingDate: command.borrowingDate,
      totalPeriods: command.totalPeriods,
    );
    final firstDate = cycleDates?.first ?? command.firstRepaymentDate;
    final lastDate =
        cycleDates?.last ??
        command.lastRepaymentDate ??
        _defaultLastDate(firstDate, command.totalPeriods);

    _requireValidCreate(
      principal: command.principal,
      totalPeriods: command.totalPeriods,
      firstRepaymentDate: firstDate,
      lastRepaymentDate: lastDate,
    );

    return _runner.run<CreateContractResult>(() async {
      final disbursementAccountId = command.disbursementAccountId;
      final borrowing =
          disbursementAccountId == null
              ? null
              : await _postingService.createBorrowing(
                CreateBorrowingCommand(
                  amount: command.principal,
                  liabilityAccountId: command.liabilityAccountId,
                  occurredAt: command.borrowingDate,
                  receiveAccountId: disbursementAccountId,
                  counterpartyName: command.counterpartyName,
                  note: command.note,
                ),
              );
      final drafts = _generator.generate(
        principal: command.principal,
        borrowingDate: command.borrowingDate,
        firstRepaymentDate: firstDate,
        lastRepaymentDate: lastDate,
        totalPeriods: command.totalPeriods,
        method: command.repaymentMethod,
        accrualMethod: command.interestAccrualMethod,
        ratePeriod: command.interestRatePeriod,
        ratePpm: command.interestRatePpm,
        totalFeeMinor: command.totalFeeMinor,
        equalInstallmentOverrideMinor: command.equalInstallmentOverrideMinor,
      );
      final contractId = await _repository.insertContract(
        InstallmentContractDraft(
          liabilityAccountId: command.liabilityAccountId,
          sourceType: InstallmentSourceType.disbursement,
          disbursementAccountId: disbursementAccountId,
          disbursementTransactionId: borrowing?.transactionId,
          principal: command.principal,
          totalPeriods: command.totalPeriods,
          borrowingDate: command.borrowingDate,
          firstRepaymentDate: firstDate,
          lastRepaymentDate: lastDate,
          repaymentMethod: command.repaymentMethod,
          interestRatePeriod: command.interestRatePeriod,
          interestRatePpm: command.interestRatePpm,
          interestAccrualMethod: command.interestAccrualMethod,
          totalFeeMinor: command.totalFeeMinor,
          status: InstallmentContractStatus.active,
          note: command.note,
        ),
      );
      if (borrowing != null) {
        await _updateService.updateOwnership(
          UpdateTransactionOwnershipCommand(
            transactionId: borrowing.transactionId,
            ownership: _installmentOwnership(
              contractId,
              InstallmentOwnerRole.disbursement,
            ),
          ),
        );
      }
      await _repository.replaceSchedules(contractId, drafts);
      return CreateContractResult(
        contractId: contractId,
        disbursementTransactionId: borrowing?.transactionId,
      );
    });
  }

  @override
  Future<CreateContractResult> createBillConversionContract(
    CreateBillConversionContractCommand command,
  ) async {
    _requireValidCreate(
      principal: command.principal,
      totalPeriods: command.totalPeriods,
      firstRepaymentDate: command.firstRepaymentDate,
      lastRepaymentDate: command.lastRepaymentDate,
    );

    final lastDate =
        command.lastRepaymentDate ??
        _defaultLastDate(command.firstRepaymentDate, command.totalPeriods);

    final drafts = _generator.generate(
      principal: command.principal,
      borrowingDate: command.borrowingDate,
      firstRepaymentDate: command.firstRepaymentDate,
      lastRepaymentDate: lastDate,
      totalPeriods: command.totalPeriods,
      method: command.repaymentMethod,
      accrualMethod: command.interestAccrualMethod,
      ratePeriod: command.interestRatePeriod,
      ratePpm: command.interestRatePpm,
      totalFeeMinor: command.totalFeeMinor,
      equalInstallmentOverrideMinor: command.equalInstallmentOverrideMinor,
    );

    return _runner.run<CreateContractResult>(() async {
      final contractId = await _repository.insertContract(
        InstallmentContractDraft(
          liabilityAccountId: command.liabilityAccountId,
          sourceType: InstallmentSourceType.billConversion,
          principal: command.principal,
          totalPeriods: command.totalPeriods,
          borrowingDate: command.borrowingDate,
          firstRepaymentDate: command.firstRepaymentDate,
          lastRepaymentDate: lastDate,
          repaymentMethod: command.repaymentMethod,
          interestRatePeriod: command.interestRatePeriod,
          interestRatePpm: command.interestRatePpm,
          interestAccrualMethod: command.interestAccrualMethod,
          totalFeeMinor: command.totalFeeMinor,
          status: InstallmentContractStatus.active,
          note: command.note,
        ),
      );
      await _repository.replaceSchedules(contractId, drafts);
      return CreateContractResult(contractId: contractId);
    });
  }

  @override
  Future<void> updateContract(UpdateContractCommand command) async {
    final contract = await _repository.findContract(command.contractId);
    if (contract == null) {
      throw BusinessException(
        CreditErrorCode.contractNotFound,
        message: 'Installment contract does not exist.',
      );
    }
    if (contract.status != InstallmentContractStatus.active) {
      throw BusinessException(
        CreditErrorCode.contractNotActive,
        message: 'Only active contracts can be edited.',
      );
    }

    // disbursementAccountId 仅对放款合同有效，账单分期不允许携带该字段。
    if (command.disbursementAccountId != null &&
        contract.sourceType != InstallmentSourceType.disbursement) {
      throw BusinessException(
        CreditErrorCode.contractInvalidCommand,
        message: 'Only disbursement contracts carry a disbursement account.',
      );
    }
    if (command.disbursementAccountId != null &&
        contract.disbursementTransactionId == null) {
      throw BusinessException(
        CreditErrorCode.contractInvalidCommand,
        message:
            'A contract without a disbursement transaction cannot carry a disbursement account.',
      );
    }

    // 解析 effective 值：command 显式传入则用 command，否则维持合同当前值。
    final effectiveTotalPeriods = command.totalPeriods ?? contract.totalPeriods;
    final effectiveFirstRepaymentDate =
        command.firstRepaymentDate ?? contract.firstRepaymentDate;
    final effectiveLastRepaymentDate =
        command.lastRepaymentDate ?? contract.lastRepaymentDate;

    if (effectiveTotalPeriods <= 0) {
      throw BusinessException(
        CreditErrorCode.contractInvalidCommand,
        message: 'Total periods must be greater than zero.',
      );
    }
    if (effectiveTotalPeriods > 1 &&
        !effectiveLastRepaymentDate.isAfter(effectiveFirstRepaymentDate)) {
      throw BusinessException(
        CreditErrorCode.contractInvalidCommand,
        message: 'Last repayment date must be after first.',
      );
    }

    await _runner.run<void>(() async {
      await _applyPendingSchedulePatches(
        command.contractId,
        command.schedulePatches,
      );

      // 联动放款交易（仅对放款合同存在 disbursement transaction）。
      if (contract.sourceType == InstallmentSourceType.disbursement) {
        final txId = contract.disbursementTransactionId;
        if (txId != null) {
          if (command.disbursementAccountId != null ||
              command.borrowingDate != null) {
            await _correctionService.correctBorrowing(
              CorrectBorrowingCommand(
                transactionId: txId,
                receiveAccountId: command.disbursementAccountId,
                occurredAt: command.borrowingDate,
              ),
            );
          }
          if (command.note != null) {
            await _updateService.updateBasicInfo(
              UpdateTransactionBasicInfoCommand(
                transactionId: txId,
                note: _nullableStringPatch(command.note),
              ),
            );
          }
        }
      }

      // 写合同行（partial：只动 command 显式提供的字段）。
      await _repository.updateContract(
        command.contractId,
        InstallmentContractPatch(
          totalPeriods: command.totalPeriods,
          firstRepaymentDate: command.firstRepaymentDate,
          lastRepaymentDate: command.lastRepaymentDate,
          borrowingDate: command.borrowingDate,
          repaymentMethod: command.repaymentMethod,
          interestRatePeriod: command.interestRatePeriod,
          interestRatePpm: command.interestRatePpm,
          interestAccrualMethod: command.interestAccrualMethod,
          totalFeeMinor: command.totalFeeMinor,
          note: command.note,
          disbursementAccountId: command.disbursementAccountId,
        ),
      );
    });
  }

  @override
  Future<List<RecalculatedSchedulePreview>> previewContractRecalculation(
    RecalculateContractSchedulesCommand command,
  ) {
    return _buildPendingRecalculationPreview(
      command.contractId,
      equalInstallmentOverrideMinor: command.equalInstallmentOverrideMinor,
    );
  }

  @override
  Future<void> recalculateContractSchedules(
    RecalculateContractSchedulesCommand command,
  ) {
    return _runner.run<void>(() async {
      final preview = await _buildPendingRecalculationPreview(
        command.contractId,
        equalInstallmentOverrideMinor: command.equalInstallmentOverrideMinor,
      );
      for (final row in preview) {
        await _repository.updateSchedule(
          row.scheduleId,
          InstallmentSchedulePatch(
            expectedPrincipal: row.expectedPrincipal,
            expectedInterest: row.expectedInterest,
            expectedFee: row.expectedFee,
          ),
        );
      }
    });
  }

  @override
  Future<void> skipSchedule(SkipInstallmentScheduleCommand command) async {
    final schedule = await _requireOwnedSchedule(
      command.contractId,
      command.scheduleId,
    );
    if (schedule.status != InstallmentScheduleStatus.pending) {
      throw BusinessException(
        CreditErrorCode.scheduleNotPending,
        message: 'Only pending schedules can be skipped.',
      );
    }

    await _runner.run<void>(() async {
      await _repository.updateSchedule(
        command.scheduleId,
        const InstallmentSchedulePatch(
          status: InstallmentScheduleStatus.skipped,
        ),
      );
      await _maybeMarkContractSettled(command.contractId);
    });
  }

  @override
  Future<void> restoreSchedule(
    RestoreInstallmentScheduleCommand command,
  ) async {
    final schedule = await _requireOwnedSchedule(
      command.contractId,
      command.scheduleId,
    );
    if (schedule.status != InstallmentScheduleStatus.skipped) {
      throw BusinessException(
        CreditErrorCode.contractInvalidCommand,
        message: 'Only skipped schedules can be restored.',
      );
    }

    await _runner.run<void>(() async {
      await _repository.updateSchedule(
        command.scheduleId,
        const InstallmentSchedulePatch(
          status: InstallmentScheduleStatus.pending,
        ),
      );
      await _maybeUnmarkContractSettled(command.contractId);
    });
  }

  Future<void> _applyPendingSchedulePatches(
    String contractId,
    List<SchedulePendingPatch> patches,
  ) async {
    if (patches.isEmpty) return;
    final schedules = await _repository.listSchedules(contractId);
    final byPeriod = {for (final s in schedules) s.periodNo: s};
    for (final patch in patches) {
      final target = byPeriod[patch.periodNo];
      if (target == null) {
        throw BusinessException(
          CreditErrorCode.scheduleNotFound,
          message: 'Schedule period does not belong to the contract.',
        );
      }
      if (target.status != InstallmentScheduleStatus.pending) {
        throw BusinessException(
          CreditErrorCode.scheduleNotPending,
          message: 'Only pending schedules can be edited.',
        );
      }
      await _repository.updateSchedule(
        target.id,
        InstallmentSchedulePatch(
          expectedPrincipal: patch.expectedPrincipal,
          expectedInterest: patch.expectedInterest,
          expectedFee: patch.expectedFee,
          expectedRepaymentDate: patch.expectedRepaymentDate,
        ),
      );
    }
  }

  Future<List<RecalculatedSchedulePreview>> _buildPendingRecalculationPreview(
    String contractId, {
    int? equalInstallmentOverrideMinor,
  }) async {
    final contract = await _repository.findContract(contractId);
    if (contract == null) {
      throw BusinessException(
        CreditErrorCode.contractNotFound,
        message: 'Installment contract does not exist.',
      );
    }
    if (contract.status != InstallmentContractStatus.active) {
      throw BusinessException(
        CreditErrorCode.contractNotActive,
        message: 'Only active contracts can be recalculated.',
      );
    }

    final schedules = await _repository.listSchedules(contractId);
    final paid =
        schedules
            .where((s) => s.status == InstallmentScheduleStatus.paid)
            .toList()
          ..sort((a, b) => a.periodNo.compareTo(b.periodNo));
    final pending =
        schedules
            .where((s) => s.status == InstallmentScheduleStatus.pending)
            .toList()
          ..sort((a, b) => a.periodNo.compareTo(b.periodNo));
    if (pending.isEmpty) return const [];

    final paidPrincipalMinor = paid.fold<int>(
      0,
      (acc, s) => acc + s.expectedPrincipal.minorUnits,
    );
    final prepaymentPrincipalMinor = await _prepaymentSumMinor(contractId);
    final remainingMinor =
        contract.principal.minorUnits -
        paidPrincipalMinor -
        prepaymentPrincipalMinor;
    if (remainingMinor < 0) {
      throw BusinessException(
        CreditErrorCode.contractInvalidCommand,
        message: 'Remaining principal would be negative.',
      );
    }

    final paidFeeMinor = paid.fold<int>(
      0,
      (acc, s) => acc + s.expectedFee.minorUnits,
    );
    final remainingFeeMinor = contract.totalFeeMinor - paidFeeMinor;
    final anchorDate =
        paid.isEmpty ? contract.borrowingDate : paid.last.expectedRepaymentDate;
    final allocations = _generator.allocate(
      remainingPrincipal: Money(minorUnits: remainingMinor),
      anchorDate: anchorDate,
      pendingDates: [for (final p in pending) p.expectedRepaymentDate],
      method: contract.repaymentMethod,
      accrualMethod: contract.interestAccrualMethod,
      ratePeriod: contract.interestRatePeriod,
      ratePpm: contract.interestRatePpm,
      remainingFeeMinor: remainingFeeMinor < 0 ? 0 : remainingFeeMinor,
      equalInstallmentOverrideMinor: equalInstallmentOverrideMinor,
    );

    return [
      for (var i = 0; i < pending.length; i++)
        RecalculatedSchedulePreview(
          scheduleId: pending[i].id,
          periodNo: pending[i].periodNo,
          expectedRepaymentDate: pending[i].expectedRepaymentDate,
          expectedPrincipal: allocations[i].principal,
          expectedInterest: allocations[i].interest,
          expectedFee: allocations[i].fee,
        ),
    ];
  }

  Future<InstallmentSchedule> _requireOwnedSchedule(
    String contractId,
    String scheduleId,
  ) async {
    final schedule = await _repository.findSchedule(scheduleId);
    if (schedule == null || schedule.contractId != contractId) {
      throw BusinessException(
        CreditErrorCode.scheduleNotFound,
        message: 'Schedule does not belong to the contract.',
      );
    }
    return schedule;
  }

  @override
  Future<void> editRepayment(EditRepaymentCommand command) async {
    if (command.paidFromAccountId == null &&
        command.occurredAt == null &&
        command.note == null) {
      return;
    }

    return _runner.run<void>(() async {
      if (command.paidFromAccountId != null || command.occurredAt != null) {
        await _correctionService.correctRepayment(
          CorrectRepaymentCommand(
            transactionId: command.transactionId,
            paidFromAccountId: command.paidFromAccountId,
            occurredAt: command.occurredAt,
          ),
        );
      }

      if (command.note != null) {
        await _updateService.updateBasicInfo(
          UpdateTransactionBasicInfoCommand(
            transactionId: command.transactionId,
            note: command.note,
          ),
        );
      }
    });
  }

  Patch<String?>? _nullableStringPatch(Patch<String>? patch) {
    return switch (patch) {
      null => null,
      PatchSet<String>(:final value) => Patch<String?>.set(value),
      PatchClear<String>() => const Patch<String?>.clear(),
    };
  }

  @override
  Future<PostedTransactionResult> createScheduledRepayment(
    CreateScheduledRepaymentCommand command,
  ) async {
    throw BusinessException(
      CreditErrorCode.repaymentNotEditable,
      message: 'Scheduled installment repayment must be handled from bills.',
    );
  }

  @override
  Future<void> revertRepayment(RevertRepaymentCommand command) async {
    throw BusinessException(
      CreditErrorCode.repaymentNotEditable,
      message: 'Credit repayments are reverted by RepaymentService.',
    );
  }

  @override
  Future<void> deleteContract(DeleteContractCommand command) async {
    final contract = await _repository.findContract(command.contractId);
    if (contract == null) {
      throw BusinessException(
        CreditErrorCode.contractNotFound,
        message: 'Installment contract does not exist.',
      );
    }

    final repayments = await _repayments.listByTarget(
      RepaymentTargetType.contract,
      command.contractId,
    );
    if (repayments.isNotEmpty) {
      throw BusinessException(
        CreditErrorCode.contractInvalidCommand,
        message:
            'Contracts with repayments cannot be deleted directly; settle early or revert repayments first.',
      );
    }
    if (contract.disbursementTransactionId != null) {
      throw BusinessException(
        CreditErrorCode.contractInvalidCommand,
        message:
            'Contracts with a disbursement transaction cannot be deleted directly.',
      );
    }

    return _runner.run<void>(() async {
      await _repository.deleteContract(command.contractId);
    });
  }

  Future<void> _maybeMarkContractSettled(String contractId) async {
    final schedules = await _repository.listSchedules(contractId);
    final allDone = schedules.every(
      (s) =>
          s.status == InstallmentScheduleStatus.paid ||
          s.status == InstallmentScheduleStatus.skipped,
    );
    if (allDone && schedules.isNotEmpty) {
      await _repository.updateContractStatus(
        contractId,
        InstallmentContractStatus.settled,
      );
    }
  }

  Future<void> _maybeUnmarkContractSettled(String contractId) async {
    final contract = await _repository.findContract(contractId);
    if (contract == null) return;
    if (contract.status == InstallmentContractStatus.settled) {
      await _repository.updateContractStatus(
        contractId,
        InstallmentContractStatus.active,
      );
    }
  }

  Future<int> _prepaymentSumMinor(String contractId) async {
    final repayments = await _repayments.listByTarget(
      RepaymentTargetType.contract,
      contractId,
    );
    return repayments
        .where((r) => r.repaymentType == RepaymentType.prepayment)
        .fold<int>(
          0,
          (sum, repayment) =>
              sum + repayment.totalAllocated().principal.minorUnits,
        );
  }

  void _requireValidCreate({
    required Money principal,
    required int totalPeriods,
    required DateTime firstRepaymentDate,
    DateTime? lastRepaymentDate,
  }) {
    if (principal.minorUnits <= 0) {
      throw BusinessException(
        CreditErrorCode.contractInvalidCommand,
        message: 'Installment principal must be positive.',
      );
    }
    if (totalPeriods <= 0) {
      throw BusinessException(
        CreditErrorCode.contractInvalidCommand,
        message: 'Total periods must be greater than zero.',
      );
    }
    if (lastRepaymentDate != null &&
        totalPeriods > 1 &&
        !lastRepaymentDate.isAfter(firstRepaymentDate)) {
      throw BusinessException(
        CreditErrorCode.contractInvalidCommand,
        message: 'Last repayment date must be after first.',
      );
    }
  }

  DateTime _defaultLastDate(DateTime firstDate, int totalPeriods) {
    return DateTime(
      firstDate.year,
      firstDate.month + totalPeriods - 1,
      firstDate.day,
    );
  }

  ({DateTime first, DateTime last})? _cycleScheduleBoundsForDisbursement(
    CreditLiabilityAccount? account, {
    required DateTime borrowingDate,
    required int totalPeriods,
  }) {
    if (account == null || account.kind != CreditLiabilityAccountKind.credit) {
      return null;
    }
    final billingDay = account.billingDay;
    final repaymentDay = account.repaymentDay;
    if (billingDay == null || repaymentDay == null) return null;

    final currentPeriod = _creditPeriodForDate(
      borrowingDate,
      billingDay: billingDay,
      billingDayToNext: account.billingDayToNext,
    );
    final firstPeriod = currentPeriod.next();
    final lastPeriod = _advancePeriod(firstPeriod, totalPeriods - 1);
    return (
      first: _creditRepaymentDateForPeriod(
        firstPeriod,
        billingDay: billingDay,
        repaymentDay: repaymentDay,
      ),
      last: _creditRepaymentDateForPeriod(
        lastPeriod,
        billingDay: billingDay,
        repaymentDay: repaymentDay,
      ),
    );
  }

  BillPeriod _creditPeriodForDate(
    DateTime date, {
    required int billingDay,
    required bool billingDayToNext,
  }) {
    final day = date.day;
    if (day < billingDay || (!billingDayToNext && day == billingDay)) {
      return BillPeriod(year: date.year, month: date.month);
    }
    final next = DateTime(date.year, date.month + 1);
    return BillPeriod(year: next.year, month: next.month);
  }

  BillPeriod _advancePeriod(BillPeriod period, int months) {
    var result = period;
    for (var i = 0; i < months; i++) {
      result = result.next();
    }
    return result;
  }

  DateTime _creditRepaymentDateForPeriod(
    BillPeriod period, {
    required int billingDay,
    required int repaymentDay,
  }) {
    final repaymentPeriod = repaymentDay > billingDay ? period : period.next();
    return DateTime(repaymentPeriod.year, repaymentPeriod.month, repaymentDay);
  }

  TransactionOwnership _installmentOwnership(
    String contractId,
    InstallmentOwnerRole role,
  ) {
    return TransactionOwnership(
      ownerType: installmentOwnerType,
      ownerId: contractId,
      ownerRole: role.wireValue,
    );
  }
}
