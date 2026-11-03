import '../../../../domain/ledger/valobj/transaction_ownership.dart';
import '../../../../domain/orchestration/entity/amortization_plan.dart';
import '../../../../domain/orchestration/valobj/amortization_enums.dart';
import '../../../ledger/transaction/query/transaction_read_models.dart';
import '../../../orchestration/amortization/query/amortization_plan_query_service.dart';
import '../query/port/transaction_detail_owner_query.dart';
import '../query/transaction_detail_context_read_models.dart';

final class AmortizationDetailOwnerQuery
    implements TransactionDetailOwnerQuery {
  const AmortizationDetailOwnerQuery(this._query);

  final AmortizationPlanQueryService _query;

  @override
  Set<String> get supportedOwnerTypes => const {
    orchestrationAmortizationOwnerType,
  };

  @override
  Future<TransactionDetailOwnerContext?> find(
    TransactionOwnership ownership,
    TransactionReadModel anchorTransaction,
  ) async {
    return _map(ownership, await _query.findById(ownership.ownerId));
  }

  @override
  Stream<TransactionDetailOwnerContext?> watch(
    TransactionOwnership ownership,
    TransactionReadModel anchorTransaction,
  ) {
    return _query
        .watchById(ownership.ownerId)
        .map((plan) => _map(ownership, plan));
  }

  TransactionDetailOwnerContext? _map(
    TransactionOwnership ownership,
    AmortizationPlan? plan,
  ) {
    if (plan == null) return null;
    final current = plan.currentPendingPeriod;
    return AmortizationTransactionDetailOwnerContext(
      ownerType: orchestrationAmortizationOwnerType,
      ownerId: ownership.ownerId,
      initialTransactionId: plan.initialTransactionId,
      kind: plan.kind,
      status: plan.status,
      originalAmount: plan.originalAmount,
      recognizedAmount: plan.recognizedAmount,
      remainingAmount: plan.remainingAmount,
      postedPeriodCount: plan.postedPeriodCount,
      totalPeriodCount: plan.periods.length,
      currentPeriodSequence: current?.sequenceNo,
      currentPeriodDueAt: current?.dueAt,
      currentPeriodAmount: current?.amount,
    );
  }
}
