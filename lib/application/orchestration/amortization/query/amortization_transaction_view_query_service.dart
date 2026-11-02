import '../../../../domain/orchestration/entity/amortization_plan.dart';
import '../../../../domain/orchestration/valobj/amortization_enums.dart';
import 'amortization_plan_query_service.dart';
import 'amortization_transaction_view_read_models.dart';
import 'port/amortization_transaction_view_source.dart';

abstract interface class AmortizationTransactionViewQueryService {
  Future<AmortizationTransactionViewAnchorPage> findAnchorPage(
    AmortizationTransactionViewQuery query,
  );

  Stream<AmortizationTransactionViewAnchorPage> watchAnchorPage(
    AmortizationTransactionViewQuery query,
  );

  Future<Map<String, AmortizationTransactionViewSummary>> findSummaries(
    Set<String> planIds,
  );

  Stream<AmortizationTransactionViewSummary?> watchSummary(String planId);
}

final class AmortizationTransactionViewQueryServiceImpl
    implements AmortizationTransactionViewQueryService {
  const AmortizationTransactionViewQueryServiceImpl({
    required AmortizationTransactionViewSource source,
    required AmortizationPlanQueryService plans,
  }) : _source = source,
       _plans = plans;

  final AmortizationTransactionViewSource _source;
  final AmortizationPlanQueryService _plans;

  @override
  Future<AmortizationTransactionViewAnchorPage> findAnchorPage(
    AmortizationTransactionViewQuery query,
  ) => _source.findAnchorPage(query);

  @override
  Stream<AmortizationTransactionViewAnchorPage> watchAnchorPage(
    AmortizationTransactionViewQuery query,
  ) => _source.watchAnchorPage(query);

  @override
  Future<Map<String, AmortizationTransactionViewSummary>> findSummaries(
    Set<String> planIds,
  ) async {
    final plans = await _plans.findByIds(planIds);
    return {for (final plan in plans) plan.id: _project(plan)};
  }

  @override
  Stream<AmortizationTransactionViewSummary?> watchSummary(String planId) {
    return _plans.watchById(planId).map((plan) {
      return plan == null ? null : _project(plan);
    });
  }

  AmortizationTransactionViewSummary _project(AmortizationPlan plan) {
    final postedPeriods = plan.periods.where((period) => period.isPosted);
    final pendingPeriods = plan.periods.where(
      (period) => period.isPending && period.amount.minorUnits > 0,
    );
    final current = plan.status == AmortizationStatus.terminated
        ? null
        : pendingPeriods.firstOrNull;
    return AmortizationTransactionViewSummary(
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
