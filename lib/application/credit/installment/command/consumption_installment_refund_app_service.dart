import 'package:smartflow/core/error/app_exception.dart';
import 'package:smartflow/core/id/id_generator.dart';
import 'package:smartflow/core/money/money.dart';
import 'package:smartflow/core/patch/patch.dart';
import 'package:smartflow/domain/credit/entity/installment_contract.dart';
import 'package:smartflow/domain/credit/entity/installment_refund_reduction.dart';
import 'package:smartflow/domain/credit/port/bill_repository.dart';
import 'package:smartflow/domain/credit/port/credit_ledger_port.dart';
import 'package:smartflow/domain/credit/port/installment_refund_reduction_repository.dart';
import 'package:smartflow/domain/credit/port/installment_repository.dart';
import 'package:smartflow/domain/credit/port/repayment_repository.dart';
import 'package:smartflow/domain/credit/service/installment/consumption_installment_refund_policy.dart';
import 'package:smartflow/domain/credit/valobj/credit_error_code.dart';
import 'package:smartflow/domain/credit/valobj/installment_enums.dart';
import 'package:smartflow/domain/credit/valobj/installment_plan_change.dart';
import 'package:smartflow/domain/credit/valobj/repayment_enums.dart';

import '../../../shared/transaction_runner.dart';
import 'installment_command.dart';
import 'installment_plan_app_service.dart';

abstract interface class ConsumptionInstallmentRefundAppService {
  Future<ConsumptionInstallmentRefundResult> create(
    CreateConsumptionInstallmentRefundCommand command,
  );

  Future<ConsumptionInstallmentRefundResult> edit(
    EditConsumptionInstallmentRefundCommand command,
  );

  Future<Money> refundablePrincipal({
    required String contractId,
    required DateTime refundDate,
    String? excludedRefundTransactionId,
  });

  Future<void> delete(DeleteConsumptionInstallmentRefundCommand command);
}

class ConsumptionInstallmentRefundAppServiceImpl
    implements ConsumptionInstallmentRefundAppService {
  ConsumptionInstallmentRefundAppServiceImpl({
    required InstallmentRepository installments,
    required InstallmentRefundReductionRepository refundReductions,
    required BillRepository bills,
    required RepaymentRepository repayments,
    required CreditLedgerPort ledger,
    required InstallmentPlanAppService plans,
    required TransactionRunner runner,
    required IdGenerator idGenerator,
    ConsumptionInstallmentRefundPolicy policy =
        const ConsumptionInstallmentRefundPolicy(),
  }) : _installments = installments,
       _refundReductions = refundReductions,
       _bills = bills,
       _repayments = repayments,
       _ledger = ledger,
       _plans = plans,
       _runner = runner,
       _ids = idGenerator,
       _policy = policy;

  final InstallmentRepository _installments;
  final InstallmentRefundReductionRepository _refundReductions;
  final BillRepository _bills;
  final RepaymentRepository _repayments;
  final CreditLedgerPort _ledger;
  final InstallmentPlanAppService _plans;
  final TransactionRunner _runner;
  final IdGenerator _ids;
  final ConsumptionInstallmentRefundPolicy _policy;

  @override
  Future<ConsumptionInstallmentRefundResult> create(
    CreateConsumptionInstallmentRefundCommand command,
  ) => _runner.run(() async {
    final contract = await _requirePurchaseContract(command.contractId);
    if (contract.purchaseTransactionId != command.parentTransactionId) {
      throw BusinessException(
        CreditErrorCode.contractInvalidCommand,
        message: '退款必须指向消费分期对应的购买交易',
      );
    }
    _validateAllocationTotal(
      command.categoryAllocations,
      command.amount,
      '退款分类分配合计必须等于退款金额',
    );
    _validateAllocationTotal(
      command.settlementAllocations,
      command.amount,
      '退款到账分配合计必须等于退款金额',
    );
    final remaining = await _remainingPrincipal(contract.id);
    final refundable = await refundablePrincipal(
      contractId: contract.id,
      refundDate: command.occurredAt,
    );
    final principal = _liabilityPrincipal(
      contract,
      command.settlementAllocations,
    );
    _validateRefundablePrincipal(principal, refundable);
    final refund = await _ledger.postRefund(
      CreditLedgerPostRefundCommand(
        parentTransactionId: command.parentTransactionId,
        amount: command.amount,
        categoryAllocations: _toLedger(command.categoryAllocations),
        settlementAllocations: _toLedger(command.settlementAllocations),
        occurredAt: command.occurredAt,
        postedAt: command.postedAt,
        counterpartyId: command.counterpartyId,
        note: command.note,
      ),
    );
    if (principal.minorUnits > 0) {
      await _refundReductions.save(
        InstallmentRefundReduction(
          id: _ids.newId(),
          contractId: contract.id,
          refundTransactionId: refund.transactionId,
          principal: principal,
          occurredAt: command.occurredAt,
          createdAt: DateTime.now(),
        ),
      );
      await _plans.applyAutomaticChange(
        contract.id,
        const RecalculateFromOperations(),
      );
      await _refreshContractStatus(
        contract.id,
        hasRemainingPrincipal: remaining.minorUnits > principal.minorUnits,
      );
    }
    return ConsumptionInstallmentRefundResult(
      refundTransactionId: refund.transactionId,
      principalReduction: principal,
    );
  });

  @override
  Future<ConsumptionInstallmentRefundResult> edit(
    EditConsumptionInstallmentRefundCommand command,
  ) => _runner.run(() async {
    final existing = await _refundReductions.findByRefundTransaction(
      command.transactionId,
    );
    final contract = await _requirePurchaseContract(command.contractId);
    if (contract.purchaseTransactionId != command.parentTransactionId) {
      throw BusinessException(
        CreditErrorCode.contractInvalidCommand,
        message: '退款必须指向消费分期对应的购买交易',
      );
    }

    if (!command.hasFinancialEdit) {
      if (command.postedAt == null &&
          command.counterpartyId == null &&
          command.note == null) {
        throw BusinessException(
          CreditErrorCode.contractInvalidCommand,
          message: '请提供需要修改的退款信息',
        );
      }
      await _ledger.editRefund(
        CreditLedgerEditRefundCommand(
          transactionId: command.transactionId,
          postedAt: command.postedAt,
          counterpartyId: command.counterpartyId == null
              ? null
              : Patch<String?>.set(command.counterpartyId),
          note: command.note == null ? null : Patch<String?>.set(command.note),
        ),
      );
      return ConsumptionInstallmentRefundResult(
        refundTransactionId: command.transactionId,
        principalReduction: existing?.principal ?? Money.zero(),
      );
    }

    final amount = command.amount;
    final categoryAllocations = command.categoryAllocations;
    final settlementAllocations = command.settlementAllocations;
    final occurredAt = command.occurredAt;
    if (amount == null ||
        categoryAllocations == null ||
        settlementAllocations == null ||
        occurredAt == null) {
      throw BusinessException(
        CreditErrorCode.contractInvalidCommand,
        message: '退款财务字段必须完整提供',
      );
    }
    _validateAllocationTotal(categoryAllocations, amount, '退款分类分配合计必须等于退款金额');
    _validateAllocationTotal(settlementAllocations, amount, '退款到账分配合计必须等于退款金额');
    final remaining = await _remainingPrincipal(
      contract.id,
      excludedRefundTransactionId: command.transactionId,
    );
    final refundable = await refundablePrincipal(
      contractId: contract.id,
      refundDate: occurredAt,
      excludedRefundTransactionId: command.transactionId,
    );
    final principal = _liabilityPrincipal(contract, settlementAllocations);
    _validateRefundablePrincipal(principal, refundable);
    await _ledger.editRefund(
      CreditLedgerEditRefundCommand(
        transactionId: command.transactionId,
        amount: amount,
        categoryAllocations: _toLedger(categoryAllocations),
        settlementAllocations: _toLedger(settlementAllocations),
        occurredAt: occurredAt,
        postedAt: command.postedAt,
        counterpartyId: command.counterpartyId == null
            ? null
            : Patch<String?>.set(command.counterpartyId),
        note: command.note == null ? null : Patch<String?>.set(command.note),
      ),
    );
    final previousPrincipal = existing?.principal ?? Money.zero();
    final changesPlan =
        previousPrincipal != principal ||
        existing?.occurredAt != null && existing!.occurredAt != occurredAt;
    if (principal.minorUnits > 0) {
      await _refundReductions.save(
        InstallmentRefundReduction(
          id: existing?.id ?? _ids.newId(),
          contractId: contract.id,
          refundTransactionId: command.transactionId,
          principal: principal,
          occurredAt: occurredAt,
          createdAt: existing?.createdAt ?? DateTime.now(),
        ),
      );
    } else {
      await _refundReductions.deleteByRefundTransaction(command.transactionId);
    }
    if (changesPlan) {
      await _plans.applyAutomaticChange(
        contract.id,
        const RecalculateFromOperations(),
      );
      await _refreshContractStatus(
        contract.id,
        hasRemainingPrincipal: remaining.minorUnits > principal.minorUnits,
      );
    }
    return ConsumptionInstallmentRefundResult(
      refundTransactionId: command.transactionId,
      principalReduction: principal,
    );
  });

  @override
  Future<void> delete(DeleteConsumptionInstallmentRefundCommand command) =>
      _runner.run(() async {
        final existing = await _refundReductions.findByRefundTransaction(
          command.transactionId,
        );
        if (existing == null) {
          await _ledger.deleteTransaction(command.transactionId);
          return;
        }
        await _ledger.deleteTransaction(command.transactionId);
        await _refundReductions.deleteByRefundTransaction(
          command.transactionId,
        );
        await _plans.applyAutomaticChange(
          existing.contractId,
          const RecalculateFromOperations(),
        );
        final remaining = await _remainingPrincipal(existing.contractId);
        await _refreshContractStatus(
          existing.contractId,
          hasRemainingPrincipal: remaining.minorUnits > 0,
        );
      });

  Future<InstallmentContract> _requirePurchaseContract(String id) async {
    final contract = await _installments.findContract(id);
    if (contract == null) {
      throw BusinessException(CreditErrorCode.contractNotFound);
    }
    if (contract.sourceType != InstallmentSourceType.purchase) {
      throw BusinessException(
        CreditErrorCode.contractInvalidCommand,
        message: '只有消费分期支持退款还本',
      );
    }
    return contract;
  }

  @override
  Future<Money> refundablePrincipal({
    required String contractId,
    required DateTime refundDate,
    String? excludedRefundTransactionId,
  }) async {
    final contract = await _requirePurchaseContract(contractId);
    final rows = await _plans.calculateCurrentRows(
      contract.id,
      excludedRefundTransactionId: excludedRefundTransactionId,
    );
    final paidBySchedule = await _paidPrincipalByScheduleId(contract);
    return _policy.refundablePrincipal(
      refundDate: refundDate,
      rows: rows,
      paidPrincipalByScheduleId: paidBySchedule,
    );
  }

  Future<Map<String, Money>> _paidPrincipalByScheduleId(
    InstallmentContract contract,
  ) async {
    final bills = await _bills.listBillsByAccount(contract.liabilityAccountId);
    final scheduleByItemId = <String, String>{};
    for (final bill in bills) {
      for (final item in bill.items) {
        final scheduleId = item.scheduleId;
        if (item.contractId == contract.id && scheduleId != null) {
          scheduleByItemId[item.id] = scheduleId;
        }
      }
    }
    final allocated = await _repayments.aggregateItemsByBillItemIds(
      scheduleByItemId.keys.toSet(),
    );
    final paidBySchedule = <String, Money>{};
    for (final entry in allocated.entries) {
      final scheduleId = scheduleByItemId[entry.key];
      if (scheduleId == null) continue;
      paidBySchedule.update(
        scheduleId,
        (current) => current + entry.value.principal,
        ifAbsent: () => entry.value.principal,
      );
    }
    return paidBySchedule;
  }

  Future<Money> _remainingPrincipal(
    String contractId, {
    String? excludedRefundTransactionId,
  }) async {
    final contract = await _installments.findContract(contractId);
    if (contract == null) {
      throw BusinessException(CreditErrorCode.contractNotFound);
    }
    final bills = await _bills.listBillsByAccount(contract.liabilityAccountId);
    final itemIds = {
      for (final bill in bills)
        for (final item in bill.items)
          if (item.contractId == contractId) item.id,
    };
    final allocated = await _repayments.aggregateItemsByBillItemIds(itemIds);
    final paidPrincipal = allocated.values.fold<Money>(
      Money.zero(),
      (sum, amount) => sum + amount.principal,
    );
    final prepayments = await _repayments.listByTarget(
      RepaymentTargetType.contract,
      contractId,
    );
    final prepaymentPrincipal = prepayments
        .where(
          (repayment) => repayment.repaymentType == RepaymentType.prepayment,
        )
        .fold<Money>(
          Money.zero(),
          (sum, repayment) => sum + repayment.totalAllocated().principal,
        );
    final refunds = await _refundReductions.listByContract(contractId);
    final refundPrincipal = refunds
        .where(
          (reduction) =>
              reduction.refundTransactionId != excludedRefundTransactionId,
        )
        .fold<Money>(
          Money.zero(),
          (sum, reduction) => sum + reduction.principal,
        );
    final remaining =
        contract.principal -
        paidPrincipal -
        prepaymentPrincipal -
        refundPrincipal;
    return remaining.minorUnits < 0 ? Money.zero() : remaining;
  }

  Money _liabilityPrincipal(
    InstallmentContract contract,
    List<ConsumptionInstallmentAllocation> allocations,
  ) {
    return Money(
      minorUnits: allocations
          .where(
            (allocation) => allocation.accountId == contract.liabilityAccountId,
          )
          .fold<int>(
            0,
            (sum, allocation) => sum + allocation.amount.minorUnits,
          ),
    );
  }

  void _validateRefundablePrincipal(Money principal, Money refundable) {
    if (principal.minorUnits > refundable.minorUnits) {
      throw BusinessException(
        CreditErrorCode.contractInvalidCommand,
        message: '分期账户退款金额不能超过退款日之后的待还本金',
      );
    }
  }

  void _validateAllocationTotal(
    List<ConsumptionInstallmentAllocation> allocations,
    Money amount,
    String message,
  ) {
    if (allocations.any((allocation) => allocation.amount.minorUnits <= 0)) {
      throw BusinessException(
        CreditErrorCode.contractInvalidCommand,
        message: '退款分配金额必须大于零',
      );
    }
    final total = allocations.fold<int>(
      0,
      (sum, allocation) => sum + allocation.amount.minorUnits,
    );
    if (total != amount.minorUnits) {
      throw BusinessException(
        CreditErrorCode.contractInvalidCommand,
        message: message,
      );
    }
  }

  List<CreditLedgerExpenseAllocation> _toLedger(
    List<ConsumptionInstallmentAllocation> allocations,
  ) => [
    for (final allocation in allocations)
      CreditLedgerExpenseAllocation(
        accountId: allocation.accountId,
        amount: allocation.amount,
      ),
  ];

  Future<void> _refreshContractStatus(
    String contractId, {
    required bool hasRemainingPrincipal,
  }) async {
    final contract = await _installments.findContract(contractId);
    if (contract == null) return;
    final schedules = await _installments.listSchedules(contractId);
    contract.refreshStatusFromPrincipal(
      hasRemainingPrincipal: hasRemainingPrincipal,
    );
    await _installments.saveAggregate(contract, schedules);
  }
}
