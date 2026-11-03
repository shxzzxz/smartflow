import '../../../../core/money/money.dart';
import '../../../../domain/orchestration/entity/amortization_plan.dart';
import '../../../../domain/orchestration/valobj/amortization_enums.dart';
import 'amortization_plan_query_service.dart';

/// Business facts for one amortization transaction requested by a transaction
/// view. It contains the plan summary needed by the row and the transaction's
/// role within that plan.
final class AmortizationTransactionContext {
  const AmortizationTransactionContext({
    required this.planId,
    required this.transactionId,
    required this.initialTransactionId,
    required this.kind,
    required this.status,
    required this.originalAmount,
    required this.recognizedAmount,
    required this.remainingAmount,
    required this.postedPeriodCount,
    required this.totalPeriodCount,
    required this.categoryAccountIds,
    required this.factKind,
    this.occurrencePeriodSequence,
    this.occurrencePeriodDueAt,
    this.currentPeriodSequence,
    this.currentPeriodDueAt,
    this.currentPeriodAmount,
    this.refundId,
    this.terminationId,
  });

  final String planId;
  final String transactionId;
  final String initialTransactionId;
  final AmortizationKind kind;
  final AmortizationStatus status;
  final Money originalAmount;
  final Money recognizedAmount;
  final Money remainingAmount;
  final int postedPeriodCount;
  final int totalPeriodCount;
  final List<String> categoryAccountIds;
  final int? occurrencePeriodSequence;
  final DateTime? occurrencePeriodDueAt;
  final int? currentPeriodSequence;
  final DateTime? currentPeriodDueAt;
  final Money? currentPeriodAmount;
  final AmortizationTransactionFactKind? factKind;
  final String? refundId;
  final String? terminationId;
}

/// Projects only the amortization transactions requested by a transaction
/// view. Transaction roles and owner-level summaries stay in the amortization
/// application domain.
class AmortizationTransactionContextQueryService {
  const AmortizationTransactionContextQueryService(this._plans);

  final AmortizationPlanQueryService _plans;

  Future<Map<String, AmortizationTransactionContext>> findForTransactions(
    Map<String, Set<String>> transactionIdsByPlanId,
  ) async {
    if (transactionIdsByPlanId.isEmpty) return const {};
    final plans = await _plans.findByIds(transactionIdsByPlanId.keys.toSet());
    return _project(plans, transactionIdsByPlanId);
  }

  Stream<Map<String, AmortizationTransactionContext>> watchForTransactions(
    Map<String, Set<String>> transactionIdsByPlanId,
  ) {
    if (transactionIdsByPlanId.isEmpty) {
      return Stream.value(const {});
    }
    final planIds = transactionIdsByPlanId.keys.toSet();
    return _plans.watchAll().map(
      (plans) => _project(
        plans.where((plan) => planIds.contains(plan.id)),
        transactionIdsByPlanId,
      ),
    );
  }

  Map<String, AmortizationTransactionContext> _project(
    Iterable<AmortizationPlan> plans,
    Map<String, Set<String>> transactionIdsByPlanId,
  ) {
    final contexts = <String, AmortizationTransactionContext>{};
    for (final plan in plans) {
      final transactionIds = transactionIdsByPlanId[plan.id] ?? const {};
      final current = plan.currentPendingPeriod;
      for (final transactionId in transactionIds) {
        final factKind = plan.transactionFactKind(transactionId);
        if (factKind == null) continue;
        final period = plan.periods
            .where((period) => period.transactionId == transactionId)
            .firstOrNull;
        final refund = plan.refunds
            .where((refund) => refund.transferTransactionId == transactionId)
            .firstOrNull;
        final termination = plan.termination;
        contexts[transactionId] = AmortizationTransactionContext(
          planId: plan.id,
          transactionId: transactionId,
          initialTransactionId: plan.initialTransactionId,
          kind: plan.kind,
          status: plan.status,
          originalAmount: plan.originalAmount,
          recognizedAmount: plan.recognizedAmount,
          remainingAmount: plan.remainingAmount,
          postedPeriodCount: plan.postedPeriodCount,
          totalPeriodCount: plan.periods.length,
          categoryAccountIds: [
            for (final allocation in plan.categoryAllocations)
              allocation.accountId,
          ],
          occurrencePeriodSequence: period?.sequenceNo,
          occurrencePeriodDueAt: period?.dueAt,
          currentPeriodSequence: current?.sequenceNo,
          currentPeriodDueAt: current?.dueAt,
          currentPeriodAmount: current?.amount,
          factKind: factKind,
          refundId: refund?.id,
          terminationId:
              factKind ==
                      AmortizationTransactionFactKind.terminationRecognition ||
                  factKind == AmortizationTransactionFactKind.terminationReturn
              ? termination?.id
              : null,
        );
      }
    }
    return contexts;
  }
}
