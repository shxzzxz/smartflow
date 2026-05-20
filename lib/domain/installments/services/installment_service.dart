import '../../../core/errors/failure.dart';
import '../../../core/money/money.dart';
import '../../../core/patch/patch.dart';
import '../../../core/result/result.dart';
import '../entities/installment_contract.dart';
import '../entities/installment_repayment.dart';
import '../entities/installment_schedule.dart';
import '../../accounting/entities/transaction_ownership.dart';
import '../../accounting/enums/accounting_enums.dart';
import '../enums/installment_enums.dart';
import '../repositories/installment_repository.dart';
import '../../accounting/repositories/posting_repository.dart';
import '../../accounting/repositories/transaction_query_repository.dart';
import 'installment_schedule_generator.dart';
import '../../accounting/services/posting_command.dart';
import '../../accounting/services/transaction_service.dart';

class CreateDisbursementContractCommand {
  const CreateDisbursementContractCommand({
    required this.liabilityAccountId,
    required this.disbursementAccountId,
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
    this.counterpartyName,
  });

  final int liabilityAccountId;
  final int disbursementAccountId;
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

  final int liabilityAccountId;
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
    this.interestExpenseAccountId,
    this.feeExpenseAccountId,
    this.note,
    this.counterpartyName,
  });

  final int contractId;
  final int scheduleId;
  final Money principal;
  final Money? interest;
  final Money? fee;
  final Money? discount;
  final int paidFromAccountId;
  final int? interestExpenseAccountId;
  final int? feeExpenseAccountId;
  final DateTime occurredAt;
  final String? note;
  final String? counterpartyName;
}

class CreatePrincipalPrepaymentCommand {
  const CreatePrincipalPrepaymentCommand({
    required this.contractId,
    required this.principal,
    required this.paidFromAccountId,
    required this.occurredAt,
    this.interest,
    this.fee,
    this.interestExpenseAccountId,
    this.feeExpenseAccountId,
    this.note,
    this.counterpartyName,
  });

  final int contractId;
  final Money principal;

  /// 提前还本时一并支付的利息（含截至本日的应计利息）。
  final Money? interest;

  /// 提前还本手续费。
  final Money? fee;

  final int paidFromAccountId;
  final int? interestExpenseAccountId;
  final int? feeExpenseAccountId;
  final DateTime occurredAt;
  final String? note;
  final String? counterpartyName;
}

class CreateEarlySettlementCommand {
  const CreateEarlySettlementCommand({
    required this.contractId,
    required this.principal,
    required this.paidFromAccountId,
    required this.occurredAt,
    this.fee,
    this.interest,
    this.interestExpenseAccountId,
    this.feeExpenseAccountId,
    this.note,
    this.counterpartyName,
  });

  final int contractId;
  final Money principal;
  final Money? interest;
  final Money? fee;
  final int paidFromAccountId;
  final int? interestExpenseAccountId;
  final int? feeExpenseAccountId;
  final DateTime occurredAt;
  final String? note;
  final String? counterpartyName;
}

class RevertRepaymentCommand {
  const RevertRepaymentCommand({required this.transactionId});

  final int transactionId;
}

class DeleteContractCommand {
  const DeleteContractCommand({required this.contractId});

  final int contractId;
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
/// - 借款日期可以改（会触发 schedule 重算 + 联动 disbursement 交易的 occurredAt）。
/// - 若已有 paid 期次，首期还款日不可改（动了会和已发生的 paid 行错位）。
/// - 期数可改，但必须 >= 已 paid 期次数 + 1（保证至少有 1 个 pending 行）。
/// - 末期还款日始终可改（仅影响最后一期）。
/// - method / 利率 / 手续费 可改，重算 pending 金额。
/// - [schedulePatches] 在按配置重算后覆盖到对应 pending 行。
///
/// Partial update 约定：
/// - 普通 nullable 字段（`T?`）：`null` 表示"不改"，传值表示"设置"。
/// - 三态字段（`Patch<T>?`）：`null`=不改，`Patch.set`=设置，`Patch.clear`=清除。
/// - `disbursementAccountId`：仅对放款合同有效；业务上禁止清除（不允许跨 sourceType）。
///
/// 重算触发：任一"重算敏感字段"（totalPeriods / firstRepaymentDate /
/// lastRepaymentDate / borrowingDate / repaymentMethod / 利率 /
/// interestAccrualMethod / totalFeeMinor / equalInstallmentOverrideMinor /
/// schedulePatches）被显式传入时，service 会重算 pending 期次。
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

  final int contractId;
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
  final int? disbursementAccountId;

  final Patch<String>? note;
  final List<SchedulePendingPatch> schedulePatches;
}

/// 受分期管理的还款交易（scheduled / extraPrincipal / earlySettlement）的编辑命令。
///
/// 用于把通用 UI 对还款交易的"改账户 / 改时间 / 改备注"统一收口到分期 service。
/// service 内部负责校验该 transaction 确实是分期还款，再委托 [TransactionService]
/// 完成 basics / metadata 更新；后续若需要联动合同状态可在此处加。
class EditRepaymentCommand {
  const EditRepaymentCommand({
    required this.transactionId,
    this.contractId,
    this.paidFromAccountId,
    this.occurredAt,
    this.note,
  });

  final int transactionId;

  /// 可选——调用方已知合同 id 时传入可省一次反查。
  final int? contractId;

  final int? paidFromAccountId;
  final DateTime? occurredAt;
  final Patch<String>? note;
}

class CreateContractResult {
  const CreateContractResult({
    required this.contractId,
    this.disbursementTransactionId,
  });

  final int contractId;
  final int? disbursementTransactionId;
}

abstract interface class InstallmentService {
  Future<Result<CreateContractResult>> createDisbursementContract(
    CreateDisbursementContractCommand command,
  );

  Future<Result<CreateContractResult>> createBillConversionContract(
    CreateBillConversionContractCommand command,
  );

  Future<Result<void>> updateContract(UpdateContractCommand command);

  /// 编辑受分期管理的还款交易（scheduled / extraPrincipal / earlySettlement）。
  /// 通用 UI 在还款交易上的 universal 编辑入口；service 内部校验归属、
  /// 再委托 [TransactionService] 完成 transactions 表的写入。
  Future<Result<void>> editRepayment(EditRepaymentCommand command);

  Future<Result<PostTransactionResult>> createScheduledRepayment(
    CreateScheduledRepaymentCommand command,
  );

  Future<Result<PostTransactionResult>> createPrincipalPrepayment(
    CreatePrincipalPrepaymentCommand command,
  );

  Future<Result<PostTransactionResult>> createEarlySettlement(
    CreateEarlySettlementCommand command,
  );

  Future<Result<void>> revertRepayment(RevertRepaymentCommand command);

  /// 该负债账户上所有 active 分期合同的"未还本金合计"（minor units）。
  /// 计算依据：Σ(contract.principal − 已 paid 期次本金 − extraPrincipal 还本) over active contracts。
  /// credit 域据此推算"非分期合同还款"的可用额度。
  Future<int> unpaidInstallmentPrincipalMinor(int liabilityAccountId);

  /// 删除合同：先回滚已发生的还款交易与放款交易，再级联删除 schedules / repayments / contract。
  Future<Result<void>> deleteContract(DeleteContractCommand command);

  Future<List<InstallmentContract>> listContractsByLiabilityAccount(
    int liabilityAccountId,
  );

  Future<InstallmentContract?> findContract(int contractId);

  Future<List<InstallmentSchedule>> listSchedules(int contractId);

  Future<List<InstallmentRepayment>> listRepayments(int contractId);

  /// 反查交易是否被分期模块持有。
  /// 命中放款侧返回 disbursement；命中还款侧返回 repayment；否则 null。
  Future<InstallmentLink?> findLinkByTransaction(int transactionId);
}

/// 分期模块对某 transaction 的"所有权"指针。
sealed class InstallmentLink {
  const InstallmentLink({required this.contractId});

  final int contractId;
}

class InstallmentDisbursementLink extends InstallmentLink {
  const InstallmentDisbursementLink({required super.contractId});
}

class InstallmentRepaymentLink extends InstallmentLink {
  const InstallmentRepaymentLink({
    required super.contractId,
    required this.repaymentType,
  });

  final InstallmentRepaymentType repaymentType;
}

class InstallmentServiceImpl implements InstallmentService {
  InstallmentServiceImpl({
    required InstallmentRepository repository,
    required PostingRepository postingRepository,
    required TransactionService transactionService,
    required TransactionQueryRepository queryRepository,
    InstallmentScheduleGenerator generator =
        const InstallmentScheduleGenerator(),
  }) : _repository = repository,
       _postingRepository = postingRepository,
       _transactionService = transactionService,
       _queryRepository = queryRepository,
       _generator = generator;

  final InstallmentRepository _repository;
  final PostingRepository _postingRepository;
  final TransactionService _transactionService;
  final TransactionQueryRepository _queryRepository;
  final InstallmentScheduleGenerator _generator;

  @override
  Future<Result<CreateContractResult>> createDisbursementContract(
    CreateDisbursementContractCommand command,
  ) async {
    final preValidation = _validateCreate(
      principal: command.principal,
      totalPeriods: command.totalPeriods,
      firstRepaymentDate: command.firstRepaymentDate,
      lastRepaymentDate: command.lastRepaymentDate,
    );
    if (preValidation != null) return Result.failure(preValidation);

    final lastDate =
        command.lastRepaymentDate ??
        _defaultLastDate(command.firstRepaymentDate, command.totalPeriods);

    final borrowingResult = await _transactionService.createBorrowing(
      CreateBorrowingCommand(
        amount: command.principal,
        liabilityAccountId: command.liabilityAccountId,
        occurredAt: command.borrowingDate,
        receiveAccountId: command.disbursementAccountId,
        counterpartyName: command.counterpartyName,
        note: command.note,
      ),
    );
    return borrowingResult.when(
      failure: Result.failure,
      success: (borrowing) async {
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
        final contractId = await _repository.insertContract(
          InstallmentContractDraft(
            liabilityAccountId: command.liabilityAccountId,
            sourceType: InstallmentSourceType.disbursement,
            disbursementAccountId: command.disbursementAccountId,
            disbursementTransactionId: borrowing.transactionId,
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
        await _postingRepository.updateTransactionOwnership(
          transactionId: borrowing.transactionId,
          ownership: _installmentOwnership(
            contractId,
            InstallmentOwnerRole.disbursement,
          ),
        );
        await _repository.replaceSchedules(contractId, drafts);
        return Result.success(
          CreateContractResult(
            contractId: contractId,
            disbursementTransactionId: borrowing.transactionId,
          ),
        );
      },
    );
  }

  @override
  Future<Result<CreateContractResult>> createBillConversionContract(
    CreateBillConversionContractCommand command,
  ) async {
    final preValidation = _validateCreate(
      principal: command.principal,
      totalPeriods: command.totalPeriods,
      firstRepaymentDate: command.firstRepaymentDate,
      lastRepaymentDate: command.lastRepaymentDate,
    );
    if (preValidation != null) return Result.failure(preValidation);

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
    return Result.success(CreateContractResult(contractId: contractId));
  }

  @override
  Future<Result<void>> updateContract(UpdateContractCommand command) async {
    final contract = await _repository.findContract(command.contractId);
    if (contract == null) {
      return const Result.failure(
        Failure(
          code: 'installment_contract_not_found',
          message: 'Installment contract does not exist.',
        ),
      );
    }
    if (contract.status != InstallmentContractStatus.active) {
      return const Result.failure(
        Failure(
          code: 'installment_contract_not_active',
          message: 'Only active contracts can be edited.',
        ),
      );
    }

    // disbursementAccountId 仅对放款合同有效，账单分期不允许携带该字段。
    if (command.disbursementAccountId != null &&
        contract.sourceType != InstallmentSourceType.disbursement) {
      return const Result.failure(
        Failure(
          code: 'installment_contract_not_disbursement',
          message: 'Only disbursement contracts carry a disbursement account.',
        ),
      );
    }

    // 解析 effective 值：command 显式传入则用 command，否则维持合同当前值。
    final effectiveTotalPeriods =
        command.totalPeriods ?? contract.totalPeriods;
    final effectiveFirstRepaymentDate =
        command.firstRepaymentDate ?? contract.firstRepaymentDate;
    final effectiveLastRepaymentDate =
        command.lastRepaymentDate ?? contract.lastRepaymentDate;
    final effectiveBorrowingDate =
        command.borrowingDate ?? contract.borrowingDate;
    final effectiveRepaymentMethod =
        command.repaymentMethod ?? contract.repaymentMethod;
    final effectiveAccrualMethod =
        command.interestAccrualMethod ?? contract.interestAccrualMethod;
    final effectiveTotalFeeMinor =
        command.totalFeeMinor ?? contract.totalFeeMinor;
    final effectiveRatePeriod =
        _resolvePatch(command.interestRatePeriod, contract.interestRatePeriod);
    final effectiveRatePpm =
        _resolvePatch(command.interestRatePpm, contract.interestRatePpm);

    if (effectiveTotalPeriods <= 0) {
      return const Result.failure(
        Failure(
          code: 'installment_total_periods_invalid',
          message: 'Total periods must be greater than zero.',
        ),
      );
    }
    if (effectiveTotalPeriods > 1 &&
        !effectiveLastRepaymentDate.isAfter(effectiveFirstRepaymentDate)) {
      return const Result.failure(
        Failure(
          code: 'installment_dates_invalid',
          message: 'Last repayment date must be after first.',
        ),
      );
    }

    // 重算敏感字段：任一被显式传入都要重算 pending 期次。
    final needsRecalc = command.totalPeriods != null ||
        command.firstRepaymentDate != null ||
        command.lastRepaymentDate != null ||
        command.borrowingDate != null ||
        command.repaymentMethod != null ||
        command.interestRatePeriod != null ||
        command.interestRatePpm != null ||
        command.interestAccrualMethod != null ||
        command.totalFeeMinor != null ||
        command.equalInstallmentOverrideMinor != null ||
        command.schedulePatches.isNotEmpty;

    if (needsRecalc) {
      final recalcFailure = await _recalculateForUpdate(
        command: command,
        contract: contract,
        effectiveTotalPeriods: effectiveTotalPeriods,
        effectiveFirstRepaymentDate: effectiveFirstRepaymentDate,
        effectiveLastRepaymentDate: effectiveLastRepaymentDate,
        effectiveBorrowingDate: effectiveBorrowingDate,
        effectiveRepaymentMethod: effectiveRepaymentMethod,
        effectiveAccrualMethod: effectiveAccrualMethod,
        effectiveTotalFeeMinor: effectiveTotalFeeMinor,
        effectiveRatePeriod: effectiveRatePeriod,
        effectiveRatePpm: effectiveRatePpm,
      );
      if (recalcFailure != null) {
        return Result.failure(recalcFailure);
      }
    }

    // 联动放款交易（仅对放款合同存在 disbursement transaction）。
    if (contract.sourceType == InstallmentSourceType.disbursement) {
      final txId = contract.disbursementTransactionId;
      if (txId != null) {
        if (command.disbursementAccountId != null ||
            command.borrowingDate != null) {
          final basicsResult =
              await _transactionService.updateTransactionBasics(
            UpdateTransactionBasicsCommand(
              transactionId: txId,
              settlementAccountId: command.disbursementAccountId,
              occurredAt: command.borrowingDate,
            ),
          );
          if (basicsResult case FailureResult(:final failure)) {
            return Result.failure(failure);
          }
        }
        if (command.note != null) {
          final metadataResult =
              await _transactionService.updateTransactionMetadata(
            UpdateTransactionMetadataCommand(
              transactionId: txId,
              note: command.note,
            ),
          );
          if (metadataResult case FailureResult(:final failure)) {
            return Result.failure(failure);
          }
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

    return const Result.success(null);
  }

  Future<Failure?> _recalculateForUpdate({
    required UpdateContractCommand command,
    required InstallmentContract contract,
    required int effectiveTotalPeriods,
    required DateTime effectiveFirstRepaymentDate,
    required DateTime effectiveLastRepaymentDate,
    required DateTime effectiveBorrowingDate,
    required InstallmentRepaymentMethod effectiveRepaymentMethod,
    required InterestAccrualMethod effectiveAccrualMethod,
    required int effectiveTotalFeeMinor,
    required InterestRatePeriod? effectiveRatePeriod,
    required int? effectiveRatePpm,
  }) async {
    final schedules = await _repository.listSchedules(command.contractId);
    final paid =
        schedules
            .where((s) => s.status == InstallmentScheduleStatus.paid)
            .toList()
          ..sort((a, b) => a.periodNo.compareTo(b.periodNo));
    final paidCount = paid.length;

    if (paidCount > 0 &&
        effectiveFirstRepaymentDate != contract.firstRepaymentDate) {
      return const Failure(
        code: 'installment_first_date_locked',
        message:
            'First repayment date cannot change after any period is paid.',
      );
    }
    if (effectiveTotalPeriods < paidCount + 1) {
      return const Failure(
        code: 'installment_periods_too_few',
        message: 'Total periods must be at least paidCount + 1.',
      );
    }

    // 计算 pending 期次的目标日期。
    final allDates = _generator.generateDates(
      firstRepaymentDate: effectiveFirstRepaymentDate,
      lastRepaymentDate: effectiveLastRepaymentDate,
      totalPeriods: effectiveTotalPeriods,
    );
    final pendingDates = allDates.sublist(paidCount);

    // 剩余本金 = 总本金 − 已 paid 本金合计 − 已 extraPrincipal 合计
    final paidPrincipalMinor = paid.fold<int>(
      0,
      (acc, s) => acc + s.expectedPrincipal.minorUnits,
    );
    final extraPrincipalMinor =
        await _extraPrincipalSumMinor(command.contractId);
    final remainingMinor = contract.principal.minorUnits -
        paidPrincipalMinor -
        extraPrincipalMinor;
    if (remainingMinor < 0) {
      return const Failure(
        code: 'installment_principal_imbalance',
        message: 'Remaining principal would be negative.',
      );
    }

    final paidFeeMinor = paid.fold<int>(
      0,
      (acc, s) => acc + s.expectedFee.minorUnits,
    );
    final remainingFeeMinor = effectiveTotalFeeMinor - paidFeeMinor;

    final anchorDate = paid.isEmpty
        ? effectiveBorrowingDate
        : paid.last.expectedRepaymentDate;

    final allocations = _generator.allocate(
      remainingPrincipal: Money(
        minorUnits: remainingMinor,
        currency: contract.principal.currency,
      ),
      anchorDate: anchorDate,
      pendingDates: pendingDates,
      method: effectiveRepaymentMethod,
      accrualMethod: effectiveAccrualMethod,
      ratePeriod: effectiveRatePeriod,
      ratePpm: effectiveRatePpm,
      remainingFeeMinor: remainingFeeMinor < 0 ? 0 : remainingFeeMinor,
      equalInstallmentOverrideMinor: command.equalInstallmentOverrideMinor,
    );

    final pendingSchedules =
        schedules
            .where((s) => s.status == InstallmentScheduleStatus.pending)
            .toList()
          ..sort((a, b) => a.periodNo.compareTo(b.periodNo));

    final desiredPendingCount = effectiveTotalPeriods - paidCount;

    if (pendingSchedules.length > desiredPendingCount) {
      for (var i = desiredPendingCount; i < pendingSchedules.length; i++) {
        final s = pendingSchedules[i];
        await _repository.updateSchedule(
          s.id,
          InstallmentSchedulePatch(
            expectedPrincipal: Money.zero(
              currency: contract.principal.currency,
            ),
            expectedInterest: Money.zero(currency: contract.principal.currency),
            expectedFee: Money.zero(currency: contract.principal.currency),
            status: InstallmentScheduleStatus.skipped,
          ),
        );
      }
    }

    final usableLen = pendingSchedules.length < desiredPendingCount
        ? pendingSchedules.length
        : desiredPendingCount;
    for (var i = 0; i < usableLen; i++) {
      final s = pendingSchedules[i];
      final alloc = allocations[i];
      final date = pendingDates[i];
      await _repository.updateSchedule(
        s.id,
        InstallmentSchedulePatch(
          expectedRepaymentDate: date,
          expectedPrincipal: alloc.principal,
          expectedInterest: alloc.interest,
          expectedFee: alloc.fee,
        ),
      );
    }
    if (pendingSchedules.length < desiredPendingCount) {
      await _rebuildSchedulesPreservingPaid(
        contractId: command.contractId,
        contract: contract,
        paid: paid,
        pendingDates: pendingDates,
        allocations: allocations,
      );
    }

    if (command.schedulePatches.isNotEmpty) {
      final refreshed = await _repository.listSchedules(command.contractId);
      final byPeriod = {for (final s in refreshed) s.periodNo: s};
      for (final patch in command.schedulePatches) {
        final target = byPeriod[patch.periodNo];
        if (target == null) continue;
        if (target.status != InstallmentScheduleStatus.pending) continue;
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

    return null;
  }

  @override
  Future<Result<void>> editRepayment(EditRepaymentCommand command) async {
    if (command.paidFromAccountId == null &&
        command.occurredAt == null &&
        command.note == null) {
      return const Result.success(null);
    }

    final repayment =
        await _repository.findRepaymentByTransaction(command.transactionId);
    if (repayment == null) {
      return const Result.failure(
        Failure(
          code: 'installment_repayment_not_found',
          message: 'No installment repayment is linked to this transaction.',
        ),
      );
    }
    if (command.contractId != null &&
        command.contractId != repayment.contractId) {
      return const Result.failure(
        Failure(
          code: 'installment_repayment_contract_mismatch',
          message: 'Provided contract id does not match the repayment owner.',
        ),
      );
    }

    if (command.paidFromAccountId != null || command.occurredAt != null) {
      final basicsResult = await _transactionService.updateTransactionBasics(
        UpdateTransactionBasicsCommand(
          transactionId: command.transactionId,
          settlementAccountId: command.paidFromAccountId,
          occurredAt: command.occurredAt,
        ),
      );
      if (basicsResult case FailureResult(:final failure)) {
        return Result.failure(failure);
      }
    }

    if (command.note != null) {
      final metadataResult =
          await _transactionService.updateTransactionMetadata(
        UpdateTransactionMetadataCommand(
          transactionId: command.transactionId,
          note: command.note,
        ),
      );
      if (metadataResult case FailureResult(:final failure)) {
        return Result.failure(failure);
      }
    }

    return const Result.success(null);
  }

  T? _resolvePatch<T>(Patch<T>? patch, T? current) {
    return switch (patch) {
      null => current,
      PatchSet<T>(:final value) => value,
      PatchClear<T>() => null,
    };
  }

  @override
  Future<Result<PostTransactionResult>> createScheduledRepayment(
    CreateScheduledRepaymentCommand command,
  ) async {
    final contract = await _repository.findContract(command.contractId);
    if (contract == null) {
      return const Result.failure(
        Failure(
          code: 'installment_contract_not_found',
          message: 'Installment contract does not exist.',
        ),
      );
    }
    final schedule = await _repository.findSchedule(command.scheduleId);
    if (schedule == null || schedule.contractId != command.contractId) {
      return const Result.failure(
        Failure(
          code: 'installment_schedule_not_found',
          message: 'Schedule does not belong to the contract.',
        ),
      );
    }
    if (schedule.status != InstallmentScheduleStatus.pending) {
      return const Result.failure(
        Failure(
          code: 'installment_schedule_not_pending',
          message: 'Schedule is not pending.',
        ),
      );
    }

    final result = await _transactionService.createRepayment(
      CreateRepaymentCommand(
        principal: command.principal,
        interest: command.interest,
        fee: command.fee,
        discount: command.discount,
        liabilityAccountId: contract.liabilityAccountId,
        paidFromAccountId: command.paidFromAccountId,
        interestExpenseAccountId: command.interestExpenseAccountId,
        feeExpenseAccountId: command.feeExpenseAccountId,
        occurredAt: command.occurredAt,
        counterpartyName: command.counterpartyName,
        note: command.note,
        ownership: _installmentOwnership(
          command.contractId,
          InstallmentOwnerRole.scheduledRepayment,
        ),
      ),
    );
    return result.when(
      failure: Result.failure,
      success: (post) async {
        await _repository.insertRepayment(
          InstallmentRepaymentDraft(
            contractId: command.contractId,
            repaymentType: InstallmentRepaymentType.scheduled,
            scheduleId: command.scheduleId,
            transactionId: post.transactionId,
          ),
        );
        await _repository.updateSchedule(
          command.scheduleId,
          const InstallmentSchedulePatch(
            status: InstallmentScheduleStatus.paid,
          ),
        );
        await _maybeMarkContractSettled(command.contractId);
        return Result.success(post);
      },
    );
  }

  @override
  Future<Result<PostTransactionResult>> createPrincipalPrepayment(
    CreatePrincipalPrepaymentCommand command,
  ) async {
    final contract = await _repository.findContract(command.contractId);
    if (contract == null) {
      return const Result.failure(
        Failure(
          code: 'installment_contract_not_found',
          message: 'Installment contract does not exist.',
        ),
      );
    }
    if (contract.status != InstallmentContractStatus.active) {
      return const Result.failure(
        Failure(
          code: 'installment_contract_not_active',
          message: 'Only active contracts allow extra principal repayment.',
        ),
      );
    }

    final result = await _transactionService.createRepayment(
      CreateRepaymentCommand(
        principal: command.principal,
        interest: command.interest,
        fee: command.fee,
        liabilityAccountId: contract.liabilityAccountId,
        paidFromAccountId: command.paidFromAccountId,
        interestExpenseAccountId: command.interestExpenseAccountId,
        feeExpenseAccountId: command.feeExpenseAccountId,
        occurredAt: command.occurredAt,
        counterpartyName: command.counterpartyName,
        note: command.note,
        ownership: _installmentOwnership(
          command.contractId,
          InstallmentOwnerRole.extraPrincipal,
        ),
      ),
    );
    return result.when(
      failure: Result.failure,
      success: (post) async {
        await _repository.insertRepayment(
          InstallmentRepaymentDraft(
            contractId: command.contractId,
            repaymentType: InstallmentRepaymentType.extraPrincipal,
            transactionId: post.transactionId,
          ),
        );
        await _recalculatePendingSchedules(command.contractId);
        return Result.success(post);
      },
    );
  }

  @override
  Future<Result<PostTransactionResult>> createEarlySettlement(
    CreateEarlySettlementCommand command,
  ) async {
    final contract = await _repository.findContract(command.contractId);
    if (contract == null) {
      return const Result.failure(
        Failure(
          code: 'installment_contract_not_found',
          message: 'Installment contract does not exist.',
        ),
      );
    }
    if (contract.status != InstallmentContractStatus.active) {
      return const Result.failure(
        Failure(
          code: 'installment_contract_not_active',
          message: 'Only active contracts can be settled early.',
        ),
      );
    }

    final result = await _transactionService.createRepayment(
      CreateRepaymentCommand(
        principal: command.principal,
        interest: command.interest,
        fee: command.fee,
        liabilityAccountId: contract.liabilityAccountId,
        paidFromAccountId: command.paidFromAccountId,
        interestExpenseAccountId: command.interestExpenseAccountId,
        feeExpenseAccountId: command.feeExpenseAccountId,
        occurredAt: command.occurredAt,
        counterpartyName: command.counterpartyName,
        note: command.note,
        ownership: _installmentOwnership(
          command.contractId,
          InstallmentOwnerRole.earlySettlement,
        ),
      ),
    );
    return result.when(
      failure: Result.failure,
      success: (post) async {
        await _repository.insertRepayment(
          InstallmentRepaymentDraft(
            contractId: command.contractId,
            repaymentType: InstallmentRepaymentType.earlySettlement,
            transactionId: post.transactionId,
          ),
        );
        final schedules = await _repository.listSchedules(command.contractId);
        for (final s in schedules) {
          if (s.status == InstallmentScheduleStatus.pending) {
            await _repository.updateSchedule(
              s.id,
              const InstallmentSchedulePatch(
                status: InstallmentScheduleStatus.skipped,
              ),
            );
          }
        }
        await _repository.updateContractStatus(
          command.contractId,
          InstallmentContractStatus.closed,
        );
        return Result.success(post);
      },
    );
  }

  @override
  Future<Result<void>> revertRepayment(RevertRepaymentCommand command) async {
    final repayment = await _repository.findRepaymentByTransaction(
      command.transactionId,
    );
    if (repayment == null) {
      return const Result.failure(
        Failure(
          code: 'installment_repayment_not_found',
          message: 'No installment repayment is linked to this transaction.',
        ),
      );
    }

    final deleteResult = await _transactionService.deleteTransaction(
      DeleteTransactionCommand(transactionId: command.transactionId),
    );
    return deleteResult.when(
      failure: Result.failure,
      success: (_) async {
        await _repository.deleteRepayment(repayment.id);
        switch (repayment.repaymentType) {
          case InstallmentRepaymentType.scheduled:
            if (repayment.scheduleId != null) {
              await _repository.updateSchedule(
                repayment.scheduleId!,
                const InstallmentSchedulePatch(
                  status: InstallmentScheduleStatus.pending,
                ),
              );
            }
            await _maybeUnmarkContractSettled(repayment.contractId);
          case InstallmentRepaymentType.extraPrincipal:
            await _recalculatePendingSchedules(repayment.contractId);
          case InstallmentRepaymentType.earlySettlement:
            final schedules = await _repository.listSchedules(
              repayment.contractId,
            );
            for (final s in schedules) {
              if (s.status == InstallmentScheduleStatus.skipped) {
                await _repository.updateSchedule(
                  s.id,
                  const InstallmentSchedulePatch(
                    status: InstallmentScheduleStatus.pending,
                  ),
                );
              }
            }
            await _repository.updateContractStatus(
              repayment.contractId,
              InstallmentContractStatus.active,
            );
        }
        return const Result.success(null);
      },
    );
  }

  @override
  Future<int> unpaidInstallmentPrincipalMinor(int liabilityAccountId) async {
    final contracts =
        await _repository.listContractsByLiabilityAccount(liabilityAccountId);
    var sum = 0;
    for (final c in contracts) {
      if (c.status != InstallmentContractStatus.active) continue;
      final paid = await _paidPrincipalForContract(c.id);
      final unpaid = c.principal.minorUnits - paid;
      if (unpaid > 0) sum += unpaid;
    }
    return sum;
  }

  Future<int> _paidPrincipalForContract(int contractId) async {
    final repayments = await _repository.listRepayments(contractId);
    var sum = 0;
    for (final r in repayments) {
      final view =
          await _queryRepository.watchTransactionDetail(r.transactionId).first;
      if (view == null) continue;
      if (view.transaction.businessState != BusinessState.current) continue;
      for (final d in view.details) {
        if (d.type == TransactionDetailType.repaymentPrincipal) {
          sum += d.amount.minorUnits;
        }
      }
    }
    return sum;
  }

  @override
  Future<Result<void>> deleteContract(DeleteContractCommand command) async {
    final contract = await _repository.findContract(command.contractId);
    if (contract == null) {
      return const Result.failure(
        Failure(
          code: 'installment_contract_not_found',
          message: 'Installment contract does not exist.',
        ),
      );
    }

    // 1. 回滚每一笔还款交易（按时间倒序更稳妥：晚于放款的先撤）。
    final repayments = await _repository.listRepayments(command.contractId);
    final sortedRepayments = [...repayments]
      ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
    for (final repayment in sortedRepayments) {
      final result = await _transactionService.deleteTransaction(
        DeleteTransactionCommand(transactionId: repayment.transactionId),
      );
      if (result case FailureResult(:final failure)) {
        return Result.failure(failure);
      }
    }

    // 2. 放款合同需要撤回放款交易；账单分期没有放款交易，跳过。
    final disbursementTxId = contract.disbursementTransactionId;
    if (disbursementTxId != null) {
      final result = await _transactionService.deleteTransaction(
        DeleteTransactionCommand(transactionId: disbursementTxId),
      );
      if (result case FailureResult(:final failure)) {
        return Result.failure(failure);
      }
    }

    // 3. 物理删除合同与子表。
    await _repository.deleteContract(command.contractId);
    return const Result.success(null);
  }

  @override
  Future<List<InstallmentContract>> listContractsByLiabilityAccount(
    int liabilityAccountId,
  ) {
    return _repository.listContractsByLiabilityAccount(liabilityAccountId);
  }

  @override
  Future<InstallmentContract?> findContract(int contractId) {
    return _repository.findContract(contractId);
  }

  @override
  Future<List<InstallmentSchedule>> listSchedules(int contractId) {
    return _repository.listSchedules(contractId);
  }

  @override
  Future<List<InstallmentRepayment>> listRepayments(int contractId) {
    return _repository.listRepayments(contractId);
  }

  @override
  Future<InstallmentLink?> findLinkByTransaction(int transactionId) async {
    final repayment = await _repository.findRepaymentByTransaction(
      transactionId,
    );
    if (repayment != null) {
      return InstallmentRepaymentLink(
        contractId: repayment.contractId,
        repaymentType: repayment.repaymentType,
      );
    }
    final contract = await _repository.findContractByDisbursementTransaction(
      transactionId,
    );
    if (contract != null) {
      return InstallmentDisbursementLink(contractId: contract.id);
    }
    return null;
  }

  Future<void> _maybeMarkContractSettled(int contractId) async {
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

  Future<void> _maybeUnmarkContractSettled(int contractId) async {
    final contract = await _repository.findContract(contractId);
    if (contract == null) return;
    if (contract.status == InstallmentContractStatus.settled) {
      await _repository.updateContractStatus(
        contractId,
        InstallmentContractStatus.active,
      );
    }
  }

  /// 重算 pending 期次的金额（日期保持不变）。提前还本 / 撤销提前还本时调用。
  Future<void> _recalculatePendingSchedules(int contractId) async {
    final contract = await _repository.findContract(contractId);
    if (contract == null) return;

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
    if (pending.isEmpty) return;

    final paidPrincipalMinor = paid.fold<int>(
      0,
      (acc, s) => acc + s.expectedPrincipal.minorUnits,
    );
    final extraPrincipalMinor = await _extraPrincipalSumMinor(contractId);
    final remainingMinor =
        contract.principal.minorUnits -
        paidPrincipalMinor -
        extraPrincipalMinor;

    if (remainingMinor <= 0) {
      // 剩余本金归零 → pending 行清零并标 skipped。
      for (final s in pending) {
        await _repository.updateSchedule(
          s.id,
          InstallmentSchedulePatch(
            expectedPrincipal: Money.zero(
              currency: contract.principal.currency,
            ),
            expectedInterest: Money.zero(currency: contract.principal.currency),
            expectedFee: Money.zero(currency: contract.principal.currency),
            status: InstallmentScheduleStatus.skipped,
          ),
        );
      }
      return;
    }

    final paidFeeMinor = paid.fold<int>(
      0,
      (acc, s) => acc + s.expectedFee.minorUnits,
    );
    final remainingFeeMinor = contract.totalFeeMinor - paidFeeMinor;
    final anchorDate =
        paid.isEmpty ? contract.borrowingDate : paid.last.expectedRepaymentDate;

    final allocations = _generator.allocate(
      remainingPrincipal: Money(
        minorUnits: remainingMinor,
        currency: contract.principal.currency,
      ),
      anchorDate: anchorDate,
      pendingDates: [for (final p in pending) p.expectedRepaymentDate],
      method: contract.repaymentMethod,
      accrualMethod: contract.interestAccrualMethod,
      ratePeriod: contract.interestRatePeriod,
      ratePpm: contract.interestRatePpm,
      remainingFeeMinor: remainingFeeMinor < 0 ? 0 : remainingFeeMinor,
    );
    for (var i = 0; i < pending.length; i++) {
      final s = pending[i];
      final a = allocations[i];
      await _repository.updateSchedule(
        s.id,
        InstallmentSchedulePatch(
          expectedPrincipal: a.principal,
          expectedInterest: a.interest,
          expectedFee: a.fee,
        ),
      );
    }
  }

  /// 当 totalPeriods 增加导致 pending 行不足时，按 paid 不变 + pending 全新分配
  /// 来重建 schedule 表。
  Future<void> _rebuildSchedulesPreservingPaid({
    required int contractId,
    required InstallmentContract contract,
    required List<InstallmentSchedule> paid,
    required List<DateTime> pendingDates,
    required List<InstallmentAmountAllocation> allocations,
  }) async {
    final drafts = <InstallmentScheduleDraft>[];
    for (var i = 0; i < paid.length; i++) {
      final s = paid[i];
      drafts.add(
        InstallmentScheduleDraft(
          periodNo: i + 1,
          expectedRepaymentDate: s.expectedRepaymentDate,
          expectedPrincipal: s.expectedPrincipal,
          expectedInterest: s.expectedInterest,
          expectedFee: s.expectedFee,
        ),
      );
    }
    for (var i = 0; i < pendingDates.length; i++) {
      drafts.add(
        InstallmentScheduleDraft(
          periodNo: paid.length + i + 1,
          expectedRepaymentDate: pendingDates[i],
          expectedPrincipal: allocations[i].principal,
          expectedInterest: allocations[i].interest,
          expectedFee: allocations[i].fee,
        ),
      );
    }
    // replaceSchedules 会先删后插，paid 行需要重新建立和 paid repayment 的关联：
    // 由于 installment_repayments.schedule_id 引用 schedule 的旧 id，
    // 删除会破坏关联。这里采用渐进式 update + insert 而不是 replace。
    // (TODO: 真正的期数增加场景较少且属编辑高级用法；当前实现先保证 paid 不变。)
    // 简化：对已 paid 部分跳过插入，仅追加 pending 行。
    final existingSchedules = await _repository.listSchedules(contractId);
    final maxPeriodNo =
        existingSchedules.isEmpty
            ? 0
            : existingSchedules
                .map((s) => s.periodNo)
                .reduce((a, b) => a > b ? a : b);
    // 计算需要补几行
    final desiredPending = pendingDates.length;
    final existingPending =
        existingSchedules
            .where((s) => s.status == InstallmentScheduleStatus.pending)
            .length;
    final toAdd = desiredPending - existingPending;
    if (toAdd <= 0) return;
    final newDrafts = <InstallmentScheduleDraft>[];
    for (var i = 0; i < toAdd; i++) {
      final allocIdx = existingPending + i;
      newDrafts.add(
        InstallmentScheduleDraft(
          periodNo: maxPeriodNo + i + 1,
          expectedRepaymentDate: pendingDates[allocIdx],
          expectedPrincipal: allocations[allocIdx].principal,
          expectedInterest: allocations[allocIdx].interest,
          expectedFee: allocations[allocIdx].fee,
        ),
      );
    }
    // 用 repository 的批量插入能力 — 改 repository 暴露 appendSchedules。
    await _repository.appendSchedules(contractId, newDrafts);
  }

  Future<int> _extraPrincipalSumMinor(int contractId) async {
    final repayments = await _repository.listRepayments(contractId);
    var sum = 0;
    for (final r in repayments) {
      if (r.repaymentType != InstallmentRepaymentType.extraPrincipal) continue;
      final view =
          await _queryRepository.watchTransactionDetail(r.transactionId).first;
      if (view == null) continue;
      for (final d in view.details) {
        if (d.type == TransactionDetailType.repaymentPrincipal) {
          sum += d.amount.minorUnits;
        }
      }
    }
    return sum;
  }

  Failure? _validateCreate({
    required Money principal,
    required int totalPeriods,
    required DateTime firstRepaymentDate,
    DateTime? lastRepaymentDate,
  }) {
    if (principal.minorUnits <= 0) {
      return const Failure(
        code: 'installment_principal_not_positive',
        message: 'Installment principal must be positive.',
      );
    }
    if (totalPeriods <= 0) {
      return const Failure(
        code: 'installment_total_periods_invalid',
        message: 'Total periods must be greater than zero.',
      );
    }
    if (lastRepaymentDate != null &&
        totalPeriods > 1 &&
        !lastRepaymentDate.isAfter(firstRepaymentDate)) {
      return const Failure(
        code: 'installment_dates_invalid',
        message: 'Last repayment date must be after first.',
      );
    }
    return null;
  }

  DateTime _defaultLastDate(DateTime firstDate, int totalPeriods) {
    return DateTime(
      firstDate.year,
      firstDate.month + totalPeriods - 1,
      firstDate.day,
    );
  }

  TransactionOwnership _installmentOwnership(
    int contractId,
    InstallmentOwnerRole role,
  ) {
    return TransactionOwnership(
      ownerType: installmentOwnerType,
      ownerId: contractId,
      ownerRole: role.wireValue,
    );
  }
}
