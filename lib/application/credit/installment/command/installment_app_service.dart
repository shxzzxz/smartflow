import 'package:smartflow/application/credit/port/credit_ledger_port.dart';
import 'package:smartflow/application/shared/transaction_runner.dart';
import 'package:smartflow/core/error/app_exception.dart';
import 'package:smartflow/core/id/id_generator.dart';
import 'package:smartflow/core/patch/patch.dart';
import 'package:smartflow/domain/credit/entity/installment_contract.dart';
import 'package:smartflow/domain/credit/entity/installment_schedule.dart';
import 'package:smartflow/domain/credit/port/bill_repository.dart';
import 'package:smartflow/domain/credit/port/credit_account_repository.dart';
import 'package:smartflow/domain/credit/port/installment_repository.dart';
import 'package:smartflow/domain/credit/port/repayment_repository.dart';
import 'package:smartflow/domain/credit/service/installment/installment_lifecycle_service.dart';
import 'package:smartflow/domain/credit/service/installment/installment_plan_engine.dart';
import 'package:smartflow/domain/credit/service/installment/installment_prepayment_recalculator.dart';
import 'package:smartflow/domain/credit/service/repayment/repayment_policy_service.dart';
import 'package:smartflow/domain/credit/service/repayment/repayment_settlement_service.dart';
import 'package:smartflow/domain/credit/valobj/bill_enums.dart';
import 'package:smartflow/domain/credit/valobj/credit_error_code.dart';
import 'package:smartflow/domain/credit/valobj/installment_enums.dart';
import 'package:smartflow/domain/credit/valobj/repayment_enums.dart';

import 'installment_command.dart';

abstract interface class InstallmentAppService {
  Future<CreateContractResult> createDisbursementContract(
    CreateDisbursementContractCommand command,
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

  /// 删除合同：仅允许无提前还款且所有计划均未发生还款的合同。
  Future<void> deleteContract(DeleteContractCommand command);
}

class InstallmentAppServiceImpl implements InstallmentAppService {
  InstallmentAppServiceImpl({
    required InstallmentRepository repository,
    required BillRepository bills,
    required CreditAccountRepository creditAccounts,
    required RepaymentRepository repayments,
    required CreditLedgerPort ledger,
    required TransactionRunner transactionRunner,
    required IdGenerator idGenerator,
    InstallmentPlanEngine planEngine = const InstallmentPlanEngine(),
    InstallmentLifecycleService lifecycle = const InstallmentLifecycleService(),
    InstallmentPrepaymentRecalculator prepaymentRecalculator =
        const InstallmentPrepaymentRecalculator(),
    RepaymentPolicyService repaymentPolicy = const RepaymentPolicyService(),
  }) : _repository = repository,
       _bills = bills,
       _creditAccounts = creditAccounts,
       _repayments = repayments,
       _ledger = ledger,
       _runner = transactionRunner,
       _idGenerator = idGenerator,
       _planEngine = planEngine,
       _lifecycle = lifecycle,
       _prepaymentRecalculator = prepaymentRecalculator,
       _repaymentPolicy = repaymentPolicy,
       _repaymentSettlement = RepaymentSettlementService(
         bills: bills,
         repayments: repayments,
         installments: repository,
       );

  final InstallmentRepository _repository;
  final BillRepository _bills;
  final CreditAccountRepository _creditAccounts;
  final RepaymentRepository _repayments;
  final CreditLedgerPort _ledger;
  final TransactionRunner _runner;
  final IdGenerator _idGenerator;
  final InstallmentPlanEngine _planEngine;
  final InstallmentLifecycleService _lifecycle;
  final InstallmentPrepaymentRecalculator _prepaymentRecalculator;
  final RepaymentPolicyService _repaymentPolicy;
  final RepaymentSettlementService _repaymentSettlement;

  @override
  Future<CreateContractResult> createDisbursementContract(
    CreateDisbursementContractCommand command,
  ) async {
    final creditAccount = await _creditAccounts.findByAccountId(
      command.liabilityAccountId,
    );
    final cycleDates = _lifecycle.cycleScheduleBoundsForDisbursement(
      creditAccount,
      borrowingDate: command.borrowingDate,
      totalPeriods: command.totalPeriods,
    );
    final firstDate = cycleDates?.first ?? command.firstRepaymentDate;
    final lastDate =
        cycleDates?.last ??
        command.lastRepaymentDate ??
        _lifecycle.defaultLastDate(firstDate, command.totalPeriods);

    _lifecycle.validateCreate(
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
              : await _ledger.postBorrowing(
                CreditLedgerPostBorrowingCommand(
                  amount: command.principal,
                  liabilityAccountId: command.liabilityAccountId,
                  occurredAt: command.borrowingDate,
                  receiveAccountId: disbursementAccountId,
                  counterpartyName: command.counterpartyName,
                  note: command.note,
                ),
              );
      final entries = _planEngine.generate(
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
      final now = DateTime.now();
      final contractId = _idGenerator.newId();
      final contract = InstallmentContract(
        id: contractId,
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
        createdAt: now,
      );
      await _repository.saveContract(contract);
      if (borrowing != null) {
        await _ledger.updateOwnership(
          transactionId: borrowing.transactionId,
          ownership: _installmentOwnership(
            contractId,
            InstallmentOwnerRole.disbursement,
          ),
        );
      }
      await _repository.replaceSchedules(
        contractId,
        _lifecycle.schedulesFromEntries(
          contractId: contractId,
          entries: entries,
          createdAt: now,
          newId: _idGenerator.newId,
        ),
      );
      return CreateContractResult(
        contractId: contractId,
        disbursementTransactionId: borrowing?.transactionId,
      );
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
            await _ledger.correctBorrowing(
              CreditLedgerCorrectBorrowingCommand(
                transactionId: txId,
                receiveAccountId: command.disbursementAccountId,
                occurredAt: command.borrowingDate,
              ),
            );
          }
          if (command.note != null) {
            await _ledger.updateBasicInfo(
              CreditLedgerUpdateBasicInfoCommand(
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
    schedule.skip();

    await _runner.run<void>(() async {
      await _repository.updateSchedule(
        command.scheduleId,
        InstallmentSchedulePatch(status: schedule.status),
      );
      await _refreshContractStatus(command.contractId);
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
    schedule.restore();

    await _runner.run<void>(() async {
      await _repository.updateSchedule(
        command.scheduleId,
        InstallmentSchedulePatch(status: schedule.status),
      );
      await _refreshContractStatus(command.contractId);
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
      target.reviseExpectation(
        expectedPrincipal: patch.expectedPrincipal,
        expectedInterest: patch.expectedInterest,
        expectedFee: patch.expectedFee,
        expectedRepaymentDate: patch.expectedRepaymentDate,
      );
      await _repository.updateSchedule(
        target.id,
        InstallmentSchedulePatch(
          expectedPrincipal: target.expectedPrincipal,
          expectedInterest: target.expectedInterest,
          expectedFee: target.expectedFee,
          expectedRepaymentDate: target.expectedRepaymentDate,
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
    final prepaymentPrincipalMinor = await _prepaymentSumMinor(contractId);
    final recalculations = _prepaymentRecalculator.recalculateAllPending(
      contract: contract,
      schedules: schedules,
      prepaymentPrincipalMinor: prepaymentPrincipalMinor,
      equalInstallmentOverrideMinor: equalInstallmentOverrideMinor,
    );

    return [
      for (final recalculation in recalculations)
        RecalculatedSchedulePreview(
          scheduleId: recalculation.scheduleId,
          periodNo: recalculation.periodNo,
          expectedRepaymentDate: recalculation.expectedRepaymentDate,
          expectedPrincipal: recalculation.expectedPrincipal,
          expectedInterest: recalculation.expectedInterest,
          expectedFee: recalculation.expectedFee,
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

  Patch<String?>? _nullableStringPatch(Patch<String>? patch) {
    return switch (patch) {
      null => null,
      PatchSet<String>(:final value) => Patch<String?>.set(value),
      PatchClear<String>() => const Patch<String?>.clear(),
    };
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
    final schedules = await _repository.listSchedules(command.contractId);
    _lifecycle.validateDelete(repayments: repayments, schedules: schedules);

    return _runner.run<void>(() async {
      final sourceRepaymentId = contract.sourceRepaymentId;
      if (sourceRepaymentId != null) {
        final sourceRepayment = await _repayments.findRepayment(
          sourceRepaymentId,
        );
        if (sourceRepayment != null) {
          final sourceBill = await _bills.findBill(sourceRepayment.targetId);
          if (sourceBill == null) {
            throw BusinessException(CreditErrorCode.billNotFound);
          }
          final allocations = _repaymentPolicy.allocationsFromItems(
            sourceRepayment.items,
          );
          await _repayments.deleteRepayment(sourceRepayment.id);
          await _repaymentSettlement.refreshBillStatuses(
            sourceBill,
            allocations,
          );
        }
      }
      final disbursementTransactionId = contract.disbursementTransactionId;
      if (disbursementTransactionId != null) {
        await _ledger.deleteTransaction(disbursementTransactionId);
      }
      await _removeContractBillItems(contract);
      await _repository.deleteContract(command.contractId);
    });
  }

  Future<void> _removeContractBillItems(InstallmentContract contract) async {
    final bills = await _bills.listBillsByAccount(contract.liabilityAccountId);
    for (final bill in bills) {
      final retained = [
        for (final item in bill.items)
          if (item.contractId != contract.id) item,
      ];
      if (retained.length == bill.items.length) continue;
      await _bills.replaceBillItems(bill.id, retained);
      if (bill.status == BillStatus.open) {
        bill.refreshOpenProjection(window: bill.window!, sourceItems: retained);
      } else {
        bill.synchronizeBilledItems(retained);
      }
      await _bills.updateBill(bill);
    }
  }

  Future<void> _refreshContractStatus(String contractId) async {
    final contract = await _repository.findContract(contractId);
    if (contract == null) return;
    final schedules = await _repository.listSchedules(contractId);
    final currentStatus = contract.status;
    final nextStatus = _lifecycle.projectContractStatus(
      contract: contract,
      schedules: schedules,
    );
    if (nextStatus != currentStatus) {
      await _repository.updateContractStatus(contractId, nextStatus);
    }
  }

  Future<int> _prepaymentSumMinor(String contractId) async {
    final repayments = await _repayments.listByTarget(
      RepaymentTargetType.contract,
      contractId,
    );
    return _lifecycle.prepaymentPrincipalMinor(repayments);
  }

  CreditLedgerOwnership _installmentOwnership(
    String contractId,
    InstallmentOwnerRole role,
  ) {
    return CreditLedgerOwnership(
      ownerType: installmentOwnerType,
      ownerId: contractId,
      ownerRole: role.wireValue,
    );
  }
}
