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
  }) : _installments = installments,
       _refundReductions = refundReductions,
       _bills = bills,
       _repayments = repayments,
       _ledger = ledger,
       _plans = plans,
       _runner = runner,
       _ids = idGenerator;

  final InstallmentRepository _installments;
  final InstallmentRefundReductionRepository _refundReductions;
  final BillRepository _bills;
  final RepaymentRepository _repayments;
  final CreditLedgerPort _ledger;
  final InstallmentPlanAppService _plans;
  final TransactionRunner _runner;
  final IdGenerator _ids;

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
    final adjusted = await _capLiabilityAllocation(
      contract: contract,
      amount: command.amount,
      allocations: command.settlementAllocations,
      remaining: remaining,
      overflowAccountId: command.overflowAccountId,
    );
    final refund = await _ledger.postRefund(
      CreditLedgerPostRefundCommand(
        parentTransactionId: command.parentTransactionId,
        amount: command.amount,
        categoryAllocations: _toLedger(command.categoryAllocations),
        settlementAllocations: _toLedger(adjusted.allocations),
        occurredAt: command.occurredAt,
        postedAt: command.postedAt,
        counterpartyId: command.counterpartyId,
        note: command.note,
      ),
    );
    if (adjusted.principal.minorUnits > 0) {
      await _refundReductions.save(
        InstallmentRefundReduction(
          id: _ids.newId(),
          contractId: contract.id,
          refundTransactionId: refund.transactionId,
          principal: adjusted.principal,
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
        hasRemainingPrincipal:
            remaining.minorUnits > adjusted.principal.minorUnits,
      );
    }
    return ConsumptionInstallmentRefundResult(
      refundTransactionId: refund.transactionId,
      principalReduction: adjusted.principal,
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
    final remaining = await _remainingPrincipal(
      contract.id,
      excludedRefundTransactionId: command.transactionId,
    );
    final adjusted = await _capLiabilityAllocation(
      contract: contract,
      amount: command.amount,
      allocations: command.settlementAllocations,
      remaining: remaining,
      overflowAccountId: command.overflowAccountId,
    );
    await _ledger.editRefund(
      CreditLedgerEditRefundCommand(
        transactionId: command.transactionId,
        amount: command.amount,
        categoryAllocations: _toLedger(command.categoryAllocations),
        settlementAllocations: _toLedger(adjusted.allocations),
        occurredAt: command.occurredAt,
        counterpartyId: command.counterpartyId == null
            ? null
            : Patch<String?>.set(command.counterpartyId),
        note: command.note == null ? null : Patch<String?>.set(command.note),
      ),
    );
    final previousPrincipal = existing?.principal ?? Money.zero();
    final changesPlan =
        previousPrincipal != adjusted.principal ||
        existing?.occurredAt != null &&
            existing!.occurredAt != command.occurredAt;
    if (adjusted.principal.minorUnits > 0) {
      await _refundReductions.save(
        InstallmentRefundReduction(
          id: existing?.id ?? _ids.newId(),
          contractId: contract.id,
          refundTransactionId: command.transactionId,
          principal: adjusted.principal,
          occurredAt: command.occurredAt,
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
        hasRemainingPrincipal:
            remaining.minorUnits > adjusted.principal.minorUnits,
      );
    }
    return ConsumptionInstallmentRefundResult(
      refundTransactionId: command.transactionId,
      principalReduction: adjusted.principal,
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

  Future<_AdjustedRefundAllocations> _capLiabilityAllocation({
    required InstallmentContract contract,
    required Money amount,
    required List<ConsumptionInstallmentAllocation> allocations,
    required Money remaining,
    required String? overflowAccountId,
  }) async {
    if (allocations.any((allocation) => allocation.amount.minorUnits <= 0)) {
      throw BusinessException(
        CreditErrorCode.contractInvalidCommand,
        message: '退款分配金额必须大于零',
      );
    }
    final liabilityMinor = allocations
        .where(
          (allocation) => allocation.accountId == contract.liabilityAccountId,
        )
        .fold<int>(0, (sum, allocation) => sum + allocation.amount.minorUnits);
    final principalMinor = liabilityMinor < remaining.minorUnits
        ? liabilityMinor
        : remaining.minorUnits;
    final overflowMinor = liabilityMinor - principalMinor;
    final overflowDestination =
        allocations
            .where(
              (allocation) =>
                  allocation.accountId != contract.liabilityAccountId,
            )
            .map((allocation) => allocation.accountId)
            .firstOrNull ??
        overflowAccountId;
    if (overflowMinor > 0 &&
        (overflowDestination == null ||
            overflowDestination == contract.liabilityAccountId)) {
      throw BusinessException(
        CreditErrorCode.contractInvalidCommand,
        message: '退款超过剩余本金，请选择资产到账账户',
      );
    }
    if (overflowMinor > 0) {
      final account = await _ledger.findAccount(overflowDestination!);
      if (account == null ||
          account.isArchived ||
          account.kind != CreditLedgerAccountKind.asset) {
        throw BusinessException(
          CreditErrorCode.contractInvalidCommand,
          message: '退款溢出只能退回到资产账户',
        );
      }
    }
    final amounts = <String, int>{};
    for (final allocation in allocations) {
      if (allocation.accountId == contract.liabilityAccountId) continue;
      amounts.update(
        allocation.accountId,
        (current) => current + allocation.amount.minorUnits,
        ifAbsent: () => allocation.amount.minorUnits,
      );
    }
    if (principalMinor > 0) {
      amounts.update(
        contract.liabilityAccountId,
        (current) => current + principalMinor,
        ifAbsent: () => principalMinor,
      );
    }
    if (overflowMinor > 0) {
      amounts.update(
        overflowDestination!,
        (current) => current + overflowMinor,
        ifAbsent: () => overflowMinor,
      );
    }
    final adjusted = [
      for (final entry in amounts.entries)
        ConsumptionInstallmentAllocation(
          accountId: entry.key,
          amount: Money(minorUnits: entry.value),
        ),
    ];
    final total = adjusted.fold<int>(
      0,
      (sum, allocation) => sum + allocation.amount.minorUnits,
    );
    if (total != amount.minorUnits) {
      throw BusinessException(
        CreditErrorCode.contractInvalidCommand,
        message: '退款到账分配合计必须等于退款金额',
      );
    }
    return _AdjustedRefundAllocations(
      allocations: adjusted,
      principal: Money(minorUnits: principalMinor),
    );
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

class _AdjustedRefundAllocations {
  const _AdjustedRefundAllocations({
    required this.allocations,
    required this.principal,
  });

  final List<ConsumptionInstallmentAllocation> allocations;
  final Money principal;
}
