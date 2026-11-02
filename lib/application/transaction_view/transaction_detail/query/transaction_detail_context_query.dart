import 'dart:async';

import '../../../../core/money/money.dart';
import '../../../../domain/credit/port/repayment_repository.dart';
import '../../../../domain/credit/valobj/installment_enums.dart';
import '../../../../domain/credit/valobj/repayment_enums.dart';
import '../../../../domain/ledger/valobj/transaction_ownership.dart';
import '../../../../domain/orchestration/valobj/advance_enums.dart';
import '../../../../domain/orchestration/valobj/amortization_enums.dart';
import '../../../credit/installment/query/installment_query_service.dart';
import '../../../ledger/transaction/query/transaction_query_service.dart';
import '../../../ledger/transaction/query/transaction_read_models.dart';
import '../../../orchestration/advance/query/advance_case_query_service.dart';
import '../../../orchestration/amortization/query/amortization_plan_query_service.dart';
import 'transaction_detail_context_read_models.dart';

/// Loads all ledger and owner facts needed to compose a transaction detail.
///
/// Feature code observes this query only. It must not reconstruct business
/// state by combining owner-specific query providers.
abstract interface class TransactionDetailContextQuery {
  Future<TransactionDetailContext?> findById(String transactionId);

  Stream<TransactionDetailContext?> watchById(String transactionId);
}

final class TransactionDetailContextQueryImpl
    implements TransactionDetailContextQuery {
  const TransactionDetailContextQueryImpl({
    required TransactionQueryService transactions,
    required AdvanceCaseQueryService advances,
    required InstallmentQueryService installments,
    required AmortizationPlanQueryService amortizations,
    required RepaymentRepository repaymentRepository,
  }) : _transactions = transactions,
       _advances = advances,
       _installments = installments,
       _amortizations = amortizations,
       _repaymentRepository = repaymentRepository;

  final TransactionQueryService _transactions;
  final AdvanceCaseQueryService _advances;
  final InstallmentQueryService _installments;
  final AmortizationPlanQueryService _amortizations;
  final RepaymentRepository _repaymentRepository;

  @override
  Future<TransactionDetailContext?> findById(String transactionId) async {
    final transaction = await _transactions.findTransactionDetail(
      transactionId,
    );
    return transaction == null ? null : _assemble(transaction);
  }

  @override
  Stream<TransactionDetailContext?> watchById(String transactionId) {
    return _transactions.watchTransactionDetail(transactionId).asyncMap((
      transaction,
    ) {
      if (transaction == null) return null;
      return _assemble(transaction);
    });
  }

  Future<TransactionDetailContext> _assemble(
    TransactionReadModel transaction,
  ) async {
    final parent = transaction.parentTransactionId == null
        ? null
        : await _transactions.findTransactionDetail(
            transaction.parentTransactionId!,
          );
    final currentGroup = parent == null
        ? TransactionDetailGroup(
            anchor: transaction,
            children: transaction.children,
          )
        : TransactionDetailGroup(anchor: parent, children: parent.children);

    final ownership = transaction.ownership ?? currentGroup.anchor.ownership;
    final owner = await _loadOwner(currentGroup.anchor, ownership);
    final anchorId = switch (owner) {
      AmortizationTransactionDetailOwnerContext(:final initialTransactionId) =>
        initialTransactionId,
      _ => currentGroup.anchor.id,
    };
    final anchorGroup = anchorId == currentGroup.anchor.id
        ? currentGroup
        : await _loadAnchorGroup(anchorId);
    return TransactionDetailContext(
      transaction: transaction,
      parentTransaction: parent,
      currentGroup: currentGroup,
      anchorGroup: anchorGroup,
      owner: owner,
    );
  }

  Future<TransactionDetailGroup> _loadAnchorGroup(String anchorId) async {
    final anchor = await _transactions.findTransactionDetail(anchorId);
    if (anchor == null) {
      throw StateError(
        'Transaction detail anchor $anchorId could not be loaded.',
      );
    }
    if (anchor.parentTransactionId != null) {
      throw StateError(
        'Transaction detail anchor $anchorId is not a top-level transaction.',
      );
    }
    return TransactionDetailGroup(anchor: anchor, children: anchor.children);
  }

  Future<TransactionDetailOwnerContext?> _loadOwner(
    TransactionReadModel anchor,
    TransactionOwnership? ownership,
  ) async {
    if (ownership == null) return null;
    final loaded = await switch (ownership.ownerType) {
      orchestrationAdvanceOwnerType => _loadAdvance(anchor, ownership),
      installmentOwnerType => _loadInstallment(ownership.ownerId),
      creditRepaymentOwnerType => _loadRepayment(ownership.ownerId),
      orchestrationAmortizationOwnerType => _loadAmortization(
        ownership.ownerId,
      ),
      _ => Future<TransactionDetailOwnerContext?>.value(null),
    };
    return loaded ??
        UnknownTransactionDetailOwnerContext(
          ownerType: ownership.ownerType,
          ownerId: ownership.ownerId,
        );
  }

  Future<TransactionDetailOwnerContext?> _loadAdvance(
    TransactionReadModel anchor,
    TransactionOwnership ownership,
  ) async {
    final advance = await _advances.findById(ownership.ownerId);
    if (advance == null) return null;
    final summary = anchor.advanceSummary;
    return AdvanceTransactionDetailOwnerContext(
      ownerType: ownership.ownerType,
      ownerId: ownership.ownerId,
      scenario: advance.scenario,
      trackingMode: advance.trackingMode,
      advanceAmount: summary?.advanceAmount ?? anchor.primaryAmount,
      receivedAmount: summary?.receivedAmount ?? Money.zero(),
      outstanding: summary?.outstanding ?? anchor.primaryAmount,
      isClosed: summary?.isClosed ?? false,
      aaPeopleCount: advance.aaPeopleCount,
    );
  }

  Future<TransactionDetailOwnerContext?> _loadInstallment(
    String contractId,
  ) async {
    final contractFuture = _installments.findContract(contractId);
    final schedulesFuture = _installments.listSchedules(contractId);
    final contract = await contractFuture;
    if (contract == null) return null;
    final schedules = await schedulesFuture;
    final paidPeriodCount = schedules
        .where((schedule) => schedule.status == InstallmentScheduleStatus.paid)
        .length;
    var remainingPrincipalMinor = 0;
    for (final schedule in schedules) {
      if (schedule.status == InstallmentScheduleStatus.pending ||
          schedule.status == InstallmentScheduleStatus.partiallyPaid) {
        remainingPrincipalMinor += schedule.expectedPrincipal.minorUnits;
      }
    }
    return InstallmentTransactionDetailOwnerContext(
      ownerType: installmentOwnerType,
      ownerId: contractId,
      installmentType: contract.installmentType,
      status: contract.status,
      principal: contract.principal,
      remainingPrincipal: Money(minorUnits: remainingPrincipalMinor),
      paidPeriodCount: paidPeriodCount,
      totalPeriodCount: schedules.length,
    );
  }

  Future<TransactionDetailOwnerContext?> _loadRepayment(
    String repaymentId,
  ) async {
    final repayment = await _repaymentRepository.findRepayment(repaymentId);
    if (repayment == null) return null;
    return RepaymentTransactionDetailOwnerContext(
      ownerType: creditRepaymentOwnerType,
      ownerId: repaymentId,
      repaymentType: repayment.repaymentType,
      targetType: repayment.targetType,
      targetId: repayment.targetId,
    );
  }

  Future<TransactionDetailOwnerContext?> _loadAmortization(
    String planId,
  ) async {
    final plan = await _amortizations.findById(planId);
    if (plan == null) return null;
    final postedPeriods = plan.periods.where((period) => period.isPosted);
    final pendingPeriods = plan.periods.where(
      (period) => period.isPending && period.amount.minorUnits > 0,
    );
    final current = plan.status == AmortizationStatus.terminated
        ? null
        : pendingPeriods.firstOrNull;
    return AmortizationTransactionDetailOwnerContext(
      ownerType: orchestrationAmortizationOwnerType,
      ownerId: plan.id,
      initialTransactionId: plan.initialTransactionId,
      kind: plan.kind,
      status: plan.status,
      originalAmount: plan.originalAmount,
      recognizedAmount: plan.recognizedAmount,
      remainingAmount: plan.remainingAmount,
      postedPeriodCount: postedPeriods.length,
      totalPeriodCount: plan.periods.length,
      currentPeriodSequence: current?.sequenceNo,
      currentPeriodDueAt: current?.dueAt,
      currentPeriodAmount: current?.amount,
    );
  }
}
