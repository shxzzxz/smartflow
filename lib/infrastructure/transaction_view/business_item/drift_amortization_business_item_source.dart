import 'package:drift/drift.dart';

import '../../../application/transaction_view/transaction_view_query_port_api.dart';
import '../../../core/money/money.dart';
import '../../../domain/orchestration/valobj/amortization_enums.dart';
import '../../database/app_database.dart';
import 'business_item_query_support.dart';

final class DriftAmortizationBusinessItemSource implements BusinessItemSource {
  const DriftAmortizationBusinessItemSource(this._db);

  final AppDatabase _db;

  @override
  String get sourceKey => 'amortization';

  @override
  Future<BusinessItemSourcePage> findAnchorPage(
    BusinessItemPageQuery query,
  ) async {
    return businessItemSourcePageFromRows(
      await _select(query).get(),
      limit: query.limit,
    );
  }

  @override
  Stream<BusinessItemSourcePage> watchAnchorPage(BusinessItemPageQuery query) {
    return _select(query).watch().map(
      (rows) => businessItemSourcePageFromRows(rows, limit: query.limit),
    );
  }

  @override
  Future<Map<BusinessItemKey, BusinessItemSummary>> findSummaries(
    Set<BusinessItemKey> itemKeys,
  ) async {
    final planIds = {
      for (final key in itemKeys)
        if (key.type == orchestrationAmortizationOwnerType) key.id,
    };
    if (planIds.isEmpty) return const {};

    final variables = businessItemStringVariables(planIds);
    final placeholders = businessItemPlaceholders(variables.length);
    final results = await Future.wait([
      _db.customSelect('''
SELECT id, kind, total_amount_minor
FROM amortization_plans
WHERE id IN ($placeholders)
''', variables: variables).get(),
      _db.customSelect('''
SELECT plan_id, sequence_no, due_at, amount_minor, status
FROM amortization_periods
WHERE plan_id IN ($placeholders)
ORDER BY plan_id, sequence_no
''', variables: variables).get(),
      _db.customSelect('''
SELECT refund.plan_id, COALESCE(SUM(allocation.amount_minor), 0)
  AS refunded_amount
FROM amortization_refunds refund
JOIN amortization_allocations allocation
  ON allocation.subject_type = 'refund'
  AND allocation.subject_id = refund.id
  AND allocation.dimension = 'category'
WHERE refund.plan_id IN ($placeholders)
GROUP BY refund.plan_id
''', variables: variables).get(),
      _db.customSelect('''
SELECT DISTINCT plan_id
FROM amortization_terminations
WHERE plan_id IN ($placeholders)
''', variables: variables).get(),
    ]);

    final periodsByPlan = <String, List<QueryRow>>{};
    for (final row in results[1]) {
      periodsByPlan.putIfAbsent(row.read<String>('plan_id'), () => []).add(row);
    }
    final refundsByPlan = {
      for (final row in results[2])
        row.read<String>('plan_id'): row.read<int>('refunded_amount'),
    };
    final terminatedPlanIds = {
      for (final row in results[3]) row.read<String>('plan_id'),
    };

    return {
      for (final row in results[0])
        BusinessItemKey(
          type: orchestrationAmortizationOwnerType,
          id: row.read<String>('id'),
        ): _summaryFromRows(
          row,
          periods: periodsByPlan[row.read<String>('id')] ?? const [],
          refundedAmount: refundsByPlan[row.read<String>('id')] ?? 0,
          isTerminated: terminatedPlanIds.contains(row.read<String>('id')),
        ),
    };
  }

  BusinessItemSummary _summaryFromRows(
    QueryRow plan, {
    required List<QueryRow> periods,
    required int refundedAmount,
    required bool isTerminated,
  }) {
    final originalAmount = plan.read<int>('total_amount_minor');
    final netAmount = originalAmount - refundedAmount;
    final postedPeriods = [
      for (final period in periods)
        if (period.read<String>('status') ==
            AmortizationPeriodStatus.posted.name)
          period,
    ];
    final recognizedAmount = postedPeriods.fold<int>(
      0,
      (total, period) => total + period.read<int>('amount_minor'),
    );
    final pendingPeriods = [
      for (final period in periods)
        if (period.read<String>('status') ==
                AmortizationPeriodStatus.pending.name &&
            period.read<int>('amount_minor') > 0)
          period,
    ];
    final status = isTerminated
        ? AmortizationStatus.terminated
        : pendingPeriods.isEmpty || netAmount == 0
        ? AmortizationStatus.completed
        : AmortizationStatus.active;
    final current = pendingPeriods.isEmpty ? null : pendingPeriods.first;

    return AmortizationBusinessItemSummary(
      kind: AmortizationKind.values.byName(plan.read<String>('kind')),
      status: status,
      originalAmount: Money(minorUnits: originalAmount),
      recognizedAmount: Money(minorUnits: recognizedAmount),
      remainingAmount: Money(
        minorUnits: status == AmortizationStatus.terminated
            ? 0
            : netAmount - recognizedAmount,
      ),
      postedPeriodCount: postedPeriods.length,
      totalPeriodCount: periods.length,
      currentPeriodSequence: current?.read<int>('sequence_no'),
      currentPeriodDueAt: current?.read<DateTime>('due_at'),
      currentPeriodAmount: current == null
          ? null
          : Money(minorUnits: current.read<int>('amount_minor')),
    );
  }

  Selectable<QueryRow> _select(BusinessItemPageQuery query) {
    final sql = BusinessItemAnchorSql(
      transactionAlias: 'anchor',
      itemType: orchestrationAmortizationOwnerType,
      itemIdExpression: 'plan.id',
      amortizationPlanAlias: 'plan',
    )..apply(query);
    return _db.customSelect(
      '''
SELECT
  anchor.id AS anchor_transaction_id,
  anchor.occurred_at AS anchor_at,
  '$orchestrationAmortizationOwnerType' AS item_type,
  plan.id AS item_id
FROM amortization_plans plan
JOIN transactions anchor ON anchor.id = plan.initial_transaction_id
WHERE anchor.parent_transaction_id IS NULL
  AND anchor.owner_type = '$orchestrationAmortizationOwnerType'
  AND anchor.owner_id = plan.id
  AND ${sql.whereClause}
ORDER BY anchor.occurred_at DESC, plan.id DESC
LIMIT ?
''',
      variables: [...sql.variables, Variable<int>(query.limit + 1)],
      readsFrom: {
        _db.transactions,
        _db.transactionLines,
        _db.transactionTags,
        _db.amortizationPlans,
        _db.amortizationPeriods,
        _db.amortizationRefunds,
        _db.amortizationTerminations,
        _db.amortizationAllocations,
      },
    );
  }
}
