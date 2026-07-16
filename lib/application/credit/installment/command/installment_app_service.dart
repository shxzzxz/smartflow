import 'package:smartflow/domain/credit/port/credit_ledger_port.dart';
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
import 'package:smartflow/domain/credit/service/installment/installment_origination_service.dart';
import 'package:smartflow/domain/credit/service/installment/installment_prepayment_recalculator.dart';
import 'package:smartflow/domain/credit/service/repayment/repayment_policy_service.dart';
import 'package:smartflow/domain/credit/valobj/bill_enums.dart';
import 'package:smartflow/domain/credit/valobj/credit_error_code.dart';
import 'package:smartflow/domain/credit/valobj/installment_enums.dart';
import 'package:smartflow/domain/credit/valobj/repayment_enums.dart';

import 'installment_command.dart';
import 'installment_status_validation_coordinator.dart';
import '../../settlement/credit_settlement_coordinator.dart';

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

  Future<ContractStatusValidationResult> validateContractStatuses(
    ValidateContractStatusesCommand command,
  );

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
    InstallmentOriginationService origination =
        const InstallmentOriginationService(),
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
       _origination = origination,
       _lifecycle = lifecycle,
       _prepaymentRecalculator = prepaymentRecalculator,
       _repaymentPolicy = repaymentPolicy,
       _statusValidation = InstallmentStatusValidationCoordinator(
         installments: repository,
         bills: bills,
         repayments: repayments,
       ),
       _repaymentSettlement = CreditSettlementCoordinator(
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
  final InstallmentOriginationService _origination;
  final InstallmentLifecycleService _lifecycle;
  final InstallmentPrepaymentRecalculator _prepaymentRecalculator;
  final RepaymentPolicyService _repaymentPolicy;
  final InstallmentStatusValidationCoordinator _statusValidation;
  final CreditSettlementCoordinator _repaymentSettlement;

  @override
  Future<CreateContractResult> createDisbursementContract(
    CreateDisbursementContractCommand command,
  ) async {
    final creditAccount = await _creditAccounts.findByAccountId(
      command.liabilityAccountId,
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
      final now = DateTime.now();
      final contractId = _idGenerator.newId();
      final aggregate = _origination.originateDisbursement(
        contractId: contractId,
        liabilityAccountId: command.liabilityAccountId,
        creditAccount: creditAccount,
        disbursementAccountId: disbursementAccountId,
        disbursementTransactionId: borrowing?.transactionId,
        terms: InstallmentOriginationTerms(
          principal: command.principal,
          totalPeriods: command.totalPeriods,
          borrowingDate: command.borrowingDate,
          firstRepaymentDate: command.firstRepaymentDate,
          lastRepaymentDate: command.lastRepaymentDate,
          repaymentMethod: command.repaymentMethod,
          interestRatePeriod: command.interestRatePeriod,
          interestRatePpm: command.interestRatePpm,
          interestAccrualMethod: command.interestAccrualMethod,
          totalFeeMinor: command.totalFeeMinor,
          equalInstallmentOverrideMinor: command.equalInstallmentOverrideMinor,
          note: command.note,
        ),
        createdAt: now,
        newScheduleId: _idGenerator.newId,
      );
      await _repository.insertAggregate(
        aggregate.contract,
        aggregate.schedules,
      );
      if (borrowing != null) {
        await _ledger.updateOwnership(
          transactionId: borrowing.transactionId,
          ownership: _installmentOwnership(
            contractId,
            InstallmentOwnerRole.disbursement,
          ),
        );
      }
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
    final schedules = await _repository.listSchedules(command.contractId);
    contract.reviseTerms(
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
    );
    contract.reviseSchedules(
      schedules: schedules,
      revisions: [
        for (final patch in command.schedulePatches)
          InstallmentScheduleRevision(
            periodNo: patch.periodNo,
            expectedPrincipal: patch.expectedPrincipal,
            expectedInterest: patch.expectedInterest,
            expectedFee: patch.expectedFee,
            expectedRepaymentDate: patch.expectedRepaymentDate,
          ),
      ],
    );

    await _runner.run<void>(() async {
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

      await _repository.saveAggregate(contract, schedules);
    });
  }

  @override
  Future<List<RecalculatedSchedulePreview>> previewContractRecalculation(
    RecalculateContractSchedulesCommand command,
  ) {
    return _buildPendingRecalculationPreview(command);
  }

  @override
  Future<void> recalculateContractSchedules(
    RecalculateContractSchedulesCommand command,
  ) {
    return _runner.run<void>(() async {
      final preview = await _buildPendingRecalculationPreview(command);
      final contract = await _repository.findContract(command.contractId);
      if (contract == null) {
        throw BusinessException(CreditErrorCode.contractNotFound);
      }
      final schedules = await _repository.listSchedules(command.contractId);
      contract.reviseSchedules(
        schedules: schedules,
        revisions: [
          for (final row in preview)
            InstallmentScheduleRevision(
              periodNo: row.periodNo,
              expectedPrincipal: row.expectedPrincipal,
              expectedInterest: row.expectedInterest,
              expectedFee: row.expectedFee,
              expectedRepaymentDate: row.expectedRepaymentDate,
            ),
        ],
      );
      await _repository.saveAggregate(contract, schedules);
    });
  }

  @override
  Future<void> skipSchedule(SkipInstallmentScheduleCommand command) async {
    final aggregate = await _requireAggregate(command.contractId);
    final schedule = _ownedSchedule(aggregate.schedules, command.scheduleId);
    aggregate.contract.skipSchedule(schedule, schedules: aggregate.schedules);
    await _runner.run<void>(
      () => _repository.saveAggregate(aggregate.contract, aggregate.schedules),
    );
  }

  @override
  Future<void> restoreSchedule(
    RestoreInstallmentScheduleCommand command,
  ) async {
    final aggregate = await _requireAggregate(command.contractId);
    final schedule = _ownedSchedule(aggregate.schedules, command.scheduleId);
    aggregate.contract.restoreSchedule(
      schedule,
      schedules: aggregate.schedules,
    );
    await _runner.run<void>(
      () => _repository.saveAggregate(aggregate.contract, aggregate.schedules),
    );
  }

  @override
  Future<ContractStatusValidationResult> validateContractStatuses(
    ValidateContractStatusesCommand command,
  ) {
    return _runner.run(() => _statusValidation.validate(command.contractId));
  }

  Future<List<RecalculatedSchedulePreview>> _buildPendingRecalculationPreview(
    RecalculateContractSchedulesCommand command,
  ) async {
    final contractId = command.contractId;
    final contract = await _repository.findContract(contractId);
    if (contract == null) {
      throw BusinessException(
        CreditErrorCode.contractNotFound,
        message: 'Installment contract does not exist.',
      );
    }
    contract.ensureEditable();

    final schedules = await _repository.listSchedules(contractId);
    final prepaymentPrincipalMinor = await _prepaymentSumMinor(contractId);
    final calculationContract = _contractForRecalculation(contract, command);
    final recalculations = _prepaymentRecalculator
        .recalculateAllPendingWithRegeneratedDates(
          contract: calculationContract,
          schedules: schedules,
          prepaymentPrincipalMinor: prepaymentPrincipalMinor,
          equalInstallmentOverrideMinor: command.equalInstallmentOverrideMinor,
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

  InstallmentContract _contractForRecalculation(
    InstallmentContract contract,
    RecalculateContractSchedulesCommand command,
  ) {
    final terms = command.terms;
    if (terms == null) return contract;
    return InstallmentContract(
      id: contract.id,
      liabilityAccountId: contract.liabilityAccountId,
      sourceType: contract.sourceType,
      disbursementAccountId: contract.disbursementAccountId,
      disbursementTransactionId: contract.disbursementTransactionId,
      sourceRepaymentId: contract.sourceRepaymentId,
      principal: contract.principal,
      totalPeriods: terms.totalPeriods,
      borrowingDate: contract.borrowingDate,
      firstRepaymentDate: terms.firstRepaymentDate,
      lastRepaymentDate: terms.lastRepaymentDate,
      repaymentMethod: terms.repaymentMethod,
      interestRatePeriod: terms.interestRatePeriod,
      interestRatePpm: terms.interestRatePpm,
      interestAccrualMethod: terms.interestAccrualMethod,
      totalFeeMinor: terms.totalFeeMinor,
      status: contract.status,
      note: contract.note,
      createdAt: contract.createdAt,
    );
  }

  Future<({InstallmentContract contract, List<InstallmentSchedule> schedules})>
  _requireAggregate(String contractId) async {
    final contract = await _repository.findContract(contractId);
    if (contract == null) {
      throw BusinessException(CreditErrorCode.contractNotFound);
    }
    final schedules = await _repository.listSchedules(contractId);
    return (contract: contract, schedules: schedules);
  }

  InstallmentSchedule _ownedSchedule(
    List<InstallmentSchedule> schedules,
    String scheduleId,
  ) {
    for (final schedule in schedules) {
      if (schedule.id == scheduleId) return schedule;
    }
    throw BusinessException(
      CreditErrorCode.scheduleNotFound,
      message: 'Schedule does not belong to the contract.',
    );
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
