import '../../../../core/money/money.dart';
import '../../../../domain/ledger/valobj/account_amount_allocation.dart';
import '../../../../domain/ledger/valobj/transaction_ownership.dart';
import '../../../../domain/orchestration/entity/amortization_plan.dart';
import '../../../../domain/orchestration/port/amortization_ledger_port.dart';
import '../../../../domain/orchestration/valobj/amortization_enums.dart';

/// Reconciles persisted amortization transactions with a recalculated plan.
///
/// The plan entity owns the schedule calculation. This service owns the
/// application-side write sequence: rewrite changed plan-level transfers,
/// update or remove posted period transactions, then generate every newly due
/// period. Callers persist the returned plan in the same transaction.
final class AmortizationPlanRecalculator {
  const AmortizationPlanRecalculator(this._ledger);

  final AmortizationLedgerPort _ledger;

  Future<AmortizationPlan> reconcile({
    required AmortizationPlan before,
    required AmortizationPlan after,
    required DateTime now,
    bool rewriteTransfers = true,
  }) async {
    if (rewriteTransfers && _initialTransferChanged(before, after)) {
      final transfer = _initialTransferAllocations(
        kind: after.kind,
        amount: after.originalAmount,
        fundingAllocations: after.fundingAllocations,
        deferralAccountId: after.deferralAccountId,
      );
      await _ledger.rewriteTransfer(
        transactionId: after.initialTransactionId,
        amount: after.originalAmount,
        outgoingAllocations: transfer.outgoing,
        incomingAllocations: transfer.incoming,
      );
    }

    if (rewriteTransfers) {
      await _rewriteChangedRefunds(before, after);
    }
    await _rewriteChangedPeriods(before, after);
    return generateDue(after, now);
  }

  Future<AmortizationPlan> generateDue(
    AmortizationPlan plan,
    DateTime now,
  ) async {
    if (plan.status == AmortizationStatus.terminated) return plan;
    final duePeriods = plan.duePeriods(now);
    if (duePeriods.isEmpty) return plan;

    final generatedBySequence = <int, String>{};
    for (final period in duePeriods) {
      generatedBySequence[period.sequenceNo] = await _postRecognition(
        plan: plan,
        amount: period.amount,
        categoryAllocations: period.categoryAllocations,
        occurredAt: period.dueAt,
      );
    }
    return plan.withPeriods([
      for (final period in plan.periods)
        if (generatedBySequence[period.sequenceNo] case final transactionId?)
          period.posted(transactionId)
        else
          period,
    ]);
  }

  bool _initialTransferChanged(
    AmortizationPlan before,
    AmortizationPlan after,
  ) {
    return before.kind != after.kind ||
        before.deferralAccountId != after.deferralAccountId ||
        before.originalAmount != after.originalAmount ||
        !_sameAllocations(before.fundingAllocations, after.fundingAllocations);
  }

  Future<void> _rewriteChangedRefunds(
    AmortizationPlan before,
    AmortizationPlan after,
  ) async {
    final previousById = {
      for (final refund in before.refunds) refund.id: refund,
    };
    for (final refund in after.refunds) {
      final previous = previousById[refund.id];
      if (previous == null) continue;
      if (before.kind == after.kind &&
          before.deferralAccountId == after.deferralAccountId &&
          previous.amount == refund.amount &&
          _sameAllocations(
            previous.settlementAllocations,
            refund.settlementAllocations,
          )) {
        continue;
      }
      final transfer = _returnTransferAllocations(
        plan: after,
        amount: refund.amount,
        settlementAllocations: refund.settlementAllocations,
      );
      await _ledger.rewriteTransfer(
        transactionId: refund.transferTransactionId,
        amount: refund.amount,
        outgoingAllocations: transfer.outgoing,
        incomingAllocations: transfer.incoming,
      );
    }
  }

  Future<void> _rewriteChangedPeriods(
    AmortizationPlan before,
    AmortizationPlan after,
  ) async {
    final afterBySequence = {
      for (final period in after.periods) period.sequenceNo: period,
    };
    for (final previous in before.periods.where((period) => period.isPosted)) {
      final next = afterBySequence[previous.sequenceNo];
      if (next == null || !next.isPosted) {
        await _ledger.deleteTransaction(previous.transactionId!);
        continue;
      }
      final nextSettlement = singleAllocation(
        accountId: after.deferralAccountId,
        amount: next.amount,
      );
      final previousSettlement = singleAllocation(
        accountId: before.deferralAccountId,
        amount: previous.amount,
      );
      if (before.kind == after.kind &&
          next.amount == previous.amount &&
          _sameAllocations(
            next.categoryAllocations,
            previous.categoryAllocations,
          ) &&
          nextSettlement.single.accountId ==
              previousSettlement.single.accountId) {
        continue;
      }
      switch (after.kind) {
        case AmortizationKind.prepaidExpense:
          await _ledger.rewriteExpense(
            transactionId: next.transactionId!,
            amount: next.amount,
            categoryAllocations: next.categoryAllocations,
            settlementAllocations: nextSettlement,
          );
        case AmortizationKind.deferredIncome:
          await _ledger.rewriteIncome(
            transactionId: next.transactionId!,
            amount: next.amount,
            categoryAllocations: next.categoryAllocations,
            settlementAllocations: nextSettlement,
          );
      }
    }
  }

  Future<String> _postRecognition({
    required AmortizationPlan plan,
    required Money amount,
    required List<AccountAmountAllocation> categoryAllocations,
    required DateTime occurredAt,
  }) {
    final ownership = TransactionOwnership(
      ownerType: orchestrationAmortizationOwnerType,
      ownerId: plan.id,
    );
    final settlement = singleAllocation(
      accountId: plan.deferralAccountId,
      amount: amount,
    );
    return switch (plan.kind) {
      AmortizationKind.prepaidExpense => _ledger.postExpense(
        amount: amount,
        categoryAllocations: categoryAllocations,
        settlementAllocations: settlement,
        occurredAt: occurredAt,
        ownership: ownership,
        isExcludedFromStats: false,
        isExcludedFromBudget: false,
      ),
      AmortizationKind.deferredIncome => _ledger.postIncome(
        amount: amount,
        categoryAllocations: categoryAllocations,
        settlementAllocations: settlement,
        occurredAt: occurredAt,
        ownership: ownership,
        isExcludedFromStats: false,
        isExcludedFromBudget: false,
      ),
    };
  }

  ({
    List<AccountAmountAllocation> outgoing,
    List<AccountAmountAllocation> incoming,
  })
  _initialTransferAllocations({
    required AmortizationKind kind,
    required Money amount,
    required List<AccountAmountAllocation> fundingAllocations,
    required String deferralAccountId,
  }) {
    final deferralAllocation = singleAllocation(
      accountId: deferralAccountId,
      amount: amount,
    );
    return (
      outgoing: kind == AmortizationKind.prepaidExpense
          ? fundingAllocations
          : deferralAllocation,
      incoming: kind == AmortizationKind.prepaidExpense
          ? deferralAllocation
          : fundingAllocations,
    );
  }

  ({
    List<AccountAmountAllocation> outgoing,
    List<AccountAmountAllocation> incoming,
  })
  _returnTransferAllocations({
    required AmortizationPlan plan,
    required Money amount,
    required List<AccountAmountAllocation> settlementAllocations,
  }) {
    final deferralAllocation = singleAllocation(
      accountId: plan.deferralAccountId,
      amount: amount,
    );
    return (
      outgoing: plan.kind == AmortizationKind.prepaidExpense
          ? deferralAllocation
          : settlementAllocations,
      incoming: plan.kind == AmortizationKind.prepaidExpense
          ? settlementAllocations
          : deferralAllocation,
    );
  }

  static bool _sameAllocations(
    Iterable<AccountAmountAllocation> left,
    Iterable<AccountAmountAllocation> right,
  ) {
    final leftList = left.toList(growable: false);
    final rightList = right.toList(growable: false);
    if (leftList.length != rightList.length) return false;
    for (var index = 0; index < leftList.length; index++) {
      if (leftList[index].accountId != rightList[index].accountId ||
          leftList[index].amount != rightList[index].amount) {
        return false;
      }
    }
    return true;
  }
}
