import 'package:drift/drift.dart';

import '../../../core/money/money.dart';
import '../../../domain/ledger/valobj/account_amount_allocation.dart';
import '../../../domain/orchestration/entity/amortization_period.dart';
import '../../../domain/orchestration/entity/amortization_plan.dart';
import '../../../domain/orchestration/entity/amortization_refund.dart';
import '../../../domain/orchestration/entity/amortization_termination.dart';
import '../../../domain/orchestration/port/amortization_repository.dart';
import '../../../domain/orchestration/valobj/amortization_enums.dart';
import '../../database/app_database.dart';

class DriftAmortizationRepository implements AmortizationRepository {
  const DriftAmortizationRepository(this._database);

  final AppDatabase _database;

  @override
  Future<AmortizationPlan?> findById(String id) async {
    return (await findByIds({id})).firstOrNull;
  }

  @override
  Future<List<AmortizationPlan>> findByIds(Set<String> ids) async {
    if (ids.isEmpty) return const [];
    final rows = await (_database.select(
      _database.amortizationPlans,
    )..where((table) => table.id.isIn(ids))).get();
    return _loadPlans(rows);
  }

  @override
  Future<List<AmortizationPlan>> findAll({String? deferralAccountId}) async {
    final query = _database.select(_database.amortizationPlans)
      ..orderBy([(table) => OrderingTerm.desc(table.updatedAt)]);
    if (deferralAccountId != null) {
      query.where((table) => table.deferralAccountId.equals(deferralAccountId));
    }
    return _loadPlans(await query.get());
  }

  @override
  Stream<List<AmortizationPlan>> watchAll({String? deferralAccountId}) {
    final query = _database.select(_database.amortizationPlans)
      ..orderBy([(table) => OrderingTerm.desc(table.updatedAt)]);
    if (deferralAccountId != null) {
      query.where((table) => table.deferralAccountId.equals(deferralAccountId));
    }
    return _database
        .customSelect(
          'SELECT 1',
          readsFrom: {
            _database.amortizationPlans,
            _database.amortizationPeriods,
            _database.amortizationRefunds,
            _database.amortizationTerminations,
            _database.amortizationAllocations,
          },
        )
        .watch()
        .asyncMap((_) async => _loadPlans(await query.get()));
  }

  @override
  Future<void> save(AmortizationPlan plan) async {
    plan.validate();
    final existingPeriods = await (_database.select(
      _database.amortizationPeriods,
    )..where((table) => table.planId.equals(plan.id))).get();
    final existingRefunds = await (_database.select(
      _database.amortizationRefunds,
    )..where((table) => table.planId.equals(plan.id))).get();
    final existingTerminations = await (_database.select(
      _database.amortizationTerminations,
    )..where((table) => table.planId.equals(plan.id))).get();
    final allocationSubjectIds = {
      plan.id,
      for (final row in existingPeriods) row.id,
      for (final row in existingRefunds) row.id,
      for (final row in existingTerminations) row.id,
    };

    if (allocationSubjectIds.isNotEmpty) {
      await (_database.delete(
        _database.amortizationAllocations,
      )..where((table) => table.subjectId.isIn(allocationSubjectIds))).go();
    }
    await (_database.delete(
      _database.amortizationPeriods,
    )..where((table) => table.planId.equals(plan.id))).go();
    await (_database.delete(
      _database.amortizationRefunds,
    )..where((table) => table.planId.equals(plan.id))).go();
    await (_database.delete(
      _database.amortizationTerminations,
    )..where((table) => table.planId.equals(plan.id))).go();

    await _database
        .into(_database.amortizationPlans)
        .insertOnConflictUpdate(
          AmortizationPlansCompanion.insert(
            id: plan.id,
            kind: plan.kind,
            deferralAccountId: plan.deferralAccountId,
            totalAmountMinor: plan.originalAmount.minorUnits,
            cadenceUnit: plan.cadenceUnit,
            cadenceInterval: plan.cadenceInterval,
            firstRecognitionAt: plan.firstRecognitionAt,
            recognitionCount: plan.recognitionCount,
            initialTransactionId: plan.initialTransactionId,
            updatedAt: Value(DateTime.now()),
          ),
        );

    await _database.batch((batch) {
      batch.insertAll(_database.amortizationPeriods, [
        for (final period in plan.periods)
          AmortizationPeriodsCompanion.insert(
            id: period.id,
            planId: period.planId,
            sequenceNo: period.sequenceNo,
            dueAt: period.dueAt,
            amountMinor: period.amount.minorUnits,
            transactionId: Value(period.transactionId),
            status: period.status,
            updatedAt: Value(DateTime.now()),
          ),
      ]);
      batch.insertAll(_database.amortizationRefunds, [
        for (final refund in plan.refunds)
          AmortizationRefundsCompanion.insert(
            id: refund.id,
            planId: refund.planId,
            transferTransactionId: refund.transferTransactionId,
            updatedAt: Value(DateTime.now()),
          ),
      ]);
      final termination = plan.termination;
      if (termination != null) {
        batch.insert(
          _database.amortizationTerminations,
          AmortizationTerminationsCompanion.insert(
            id: termination.id,
            planId: termination.planId,
            terminatedAt: termination.terminatedAt,
            recognitionTransactionId: Value(
              termination.recognitionTransactionId,
            ),
            returnTransactionId: Value(termination.returnTransactionId),
            updatedAt: Value(DateTime.now()),
          ),
        );
      }
      batch.insertAll(_database.amortizationAllocations, [
        ..._planAllocationRows(plan),
        for (final period in plan.periods)
          ..._allocationRows(
            subjectType: AmortizationSubjectType.period,
            subjectId: period.id,
            dimension: AmortizationAllocationDimension.category,
            allocations: period.categoryAllocations,
          ),
        for (final refund in plan.refunds) ...[
          ..._allocationRows(
            subjectType: AmortizationSubjectType.refund,
            subjectId: refund.id,
            dimension: AmortizationAllocationDimension.category,
            allocations: refund.categoryAllocations,
          ),
          ..._allocationRows(
            subjectType: AmortizationSubjectType.refund,
            subjectId: refund.id,
            dimension: AmortizationAllocationDimension.settlement,
            allocations: refund.settlementAllocations,
          ),
        ],
        if (termination != null) ...[
          ..._allocationRows(
            subjectType: AmortizationSubjectType.termination,
            subjectId: termination.id,
            dimension: AmortizationAllocationDimension.category,
            allocations: termination.categoryReturnAllocations,
          ),
          ..._allocationRows(
            subjectType: AmortizationSubjectType.termination,
            subjectId: termination.id,
            dimension: AmortizationAllocationDimension.settlement,
            allocations: termination.settlementAllocations,
          ),
        ],
      ]);
    });
  }

  @override
  Future<void> deleteById(String id) async {
    final periodRows = await (_database.select(
      _database.amortizationPeriods,
    )..where((table) => table.planId.equals(id))).get();
    final refundRows = await (_database.select(
      _database.amortizationRefunds,
    )..where((table) => table.planId.equals(id))).get();
    final terminationRows = await (_database.select(
      _database.amortizationTerminations,
    )..where((table) => table.planId.equals(id))).get();
    final subjectIds = {
      id,
      for (final period in periodRows) period.id,
      for (final refund in refundRows) refund.id,
      for (final termination in terminationRows) termination.id,
    };

    if (subjectIds.isNotEmpty) {
      await (_database.delete(
        _database.amortizationAllocations,
      )..where((table) => table.subjectId.isIn(subjectIds))).go();
    }
    await (_database.delete(
      _database.amortizationPeriods,
    )..where((table) => table.planId.equals(id))).go();
    await (_database.delete(
      _database.amortizationRefunds,
    )..where((table) => table.planId.equals(id))).go();
    await (_database.delete(
      _database.amortizationTerminations,
    )..where((table) => table.planId.equals(id))).go();
    await (_database.delete(
      _database.amortizationPlans,
    )..where((table) => table.id.equals(id))).go();
  }

  Future<List<AmortizationPlan>> _loadPlans(
    List<AmortizationPlanRow> rows,
  ) async {
    if (rows.isEmpty) return const [];
    final planIds = {for (final row in rows) row.id};
    final (periodRows, refundRows, terminationRows) = await (
      (_database.select(_database.amortizationPeriods)
            ..where((table) => table.planId.isIn(planIds))
            ..orderBy([
              (table) => OrderingTerm.asc(table.planId),
              (table) => OrderingTerm.asc(table.sequenceNo),
            ]))
          .get(),
      (_database.select(_database.amortizationRefunds)
            ..where((table) => table.planId.isIn(planIds))
            ..orderBy([
              (table) => OrderingTerm.asc(table.planId),
              (table) => OrderingTerm.asc(table.createdAt),
            ]))
          .get(),
      (_database.select(
        _database.amortizationTerminations,
      )..where((table) => table.planId.isIn(planIds))).get(),
    ).wait;
    final periodsByPlan = _groupByPlan(periodRows);
    final refundsByPlan = _groupByPlan(refundRows);
    final terminationsByPlan = _groupByPlan(terminationRows);
    final subjectIds = {
      ...planIds,
      for (final period in periodRows) period.id,
      for (final refund in refundRows) refund.id,
      for (final termination in terminationRows) termination.id,
    };
    final allocationRows = subjectIds.isEmpty
        ? const <AmortizationAllocationRow>[]
        : await (_database.select(_database.amortizationAllocations)
                ..where((table) => table.subjectId.isIn(subjectIds))
                ..orderBy([
                  (table) => OrderingTerm.asc(table.subjectType),
                  (table) => OrderingTerm.asc(table.subjectId),
                  (table) => OrderingTerm.asc(table.dimension),
                  (table) => OrderingTerm.asc(table.lineNo),
                ]))
              .get();
    final allocations = _groupAllocations(allocationRows);
    return [
      for (final row in rows)
        _mapPlan(
          row,
          periodRows: periodsByPlan[row.id] ?? const [],
          refundRows: refundsByPlan[row.id] ?? const [],
          terminationRows: terminationsByPlan[row.id] ?? const [],
          allocations: allocations,
        ),
    ];
  }

  AmortizationPlan _mapPlan(
    AmortizationPlanRow row, {
    required List<AmortizationPeriodRow> periodRows,
    required List<AmortizationRefundRow> refundRows,
    required List<AmortizationTerminationRow> terminationRows,
    required Map<
      (AmortizationSubjectType, String, AmortizationAllocationDimension),
      List<AccountAmountAllocation>
    >
    allocations,
  }) {
    final planFunding =
        allocations[(
          AmortizationSubjectType.plan,
          row.id,
          AmortizationAllocationDimension.funding,
        )] ??
        const [];
    final planCategories =
        allocations[(
          AmortizationSubjectType.plan,
          row.id,
          AmortizationAllocationDimension.category,
        )] ??
        const [];

    final periods = [
      for (final period in periodRows)
        AmortizationPeriod(
          id: period.id,
          planId: period.planId,
          sequenceNo: period.sequenceNo,
          dueAt: period.dueAt,
          amount: Money(minorUnits: period.amountMinor),
          categoryAllocations:
              allocations[(
                AmortizationSubjectType.period,
                period.id,
                AmortizationAllocationDimension.category,
              )] ??
              const [],
          transactionId: period.transactionId,
          status: period.status,
        ),
    ];
    final refunds = [
      for (final refund in refundRows)
        AmortizationRefund(
          id: refund.id,
          planId: refund.planId,
          categoryAllocations:
              allocations[(
                AmortizationSubjectType.refund,
                refund.id,
                AmortizationAllocationDimension.category,
              )] ??
              const [],
          settlementAllocations:
              allocations[(
                AmortizationSubjectType.refund,
                refund.id,
                AmortizationAllocationDimension.settlement,
              )] ??
              const [],
          transferTransactionId: refund.transferTransactionId,
        ),
    ];
    final termination = terminationRows.isEmpty
        ? null
        : AmortizationTermination(
            id: terminationRows.single.id,
            planId: terminationRows.single.planId,
            terminatedAt: terminationRows.single.terminatedAt,
            categoryReturnAllocations:
                allocations[(
                  AmortizationSubjectType.termination,
                  terminationRows.single.id,
                  AmortizationAllocationDimension.category,
                )] ??
                const [],
            settlementAllocations:
                allocations[(
                  AmortizationSubjectType.termination,
                  terminationRows.single.id,
                  AmortizationAllocationDimension.settlement,
                )] ??
                const [],
            recognitionTransactionId:
                terminationRows.single.recognitionTransactionId,
            returnTransactionId: terminationRows.single.returnTransactionId,
          );
    return AmortizationPlan(
      id: row.id,
      kind: row.kind,
      deferralAccountId: row.deferralAccountId,
      originalAmount: Money(minorUnits: row.totalAmountMinor),
      fundingAllocations: planFunding,
      categoryAllocations: planCategories,
      cadenceUnit: row.cadenceUnit,
      cadenceInterval: row.cadenceInterval,
      firstRecognitionAt: row.firstRecognitionAt,
      recognitionCount: row.recognitionCount,
      initialTransactionId: row.initialTransactionId,
      periods: periods,
      refunds: refunds,
      termination: termination,
    );
  }

  Map<String, List<T>> _groupByPlan<T>(List<T> rows) {
    final result = <String, List<T>>{};
    for (final row in rows) {
      final planId = switch (row) {
        AmortizationPeriodRow value => value.planId,
        AmortizationRefundRow value => value.planId,
        AmortizationTerminationRow value => value.planId,
        _ => throw ArgumentError.value(row, 'row', 'Unknown amortization row'),
      };
      result.putIfAbsent(planId, () => []).add(row);
    }
    return result;
  }

  List<AmortizationAllocationsCompanion> _planAllocationRows(
    AmortizationPlan plan,
  ) {
    return [
      ..._allocationRows(
        subjectType: AmortizationSubjectType.plan,
        subjectId: plan.id,
        dimension: AmortizationAllocationDimension.funding,
        allocations: plan.fundingAllocations,
      ),
      ..._allocationRows(
        subjectType: AmortizationSubjectType.plan,
        subjectId: plan.id,
        dimension: AmortizationAllocationDimension.category,
        allocations: plan.categoryAllocations,
      ),
    ];
  }

  List<AmortizationAllocationsCompanion> _allocationRows({
    required AmortizationSubjectType subjectType,
    required String subjectId,
    required AmortizationAllocationDimension dimension,
    required Iterable<AccountAmountAllocation> allocations,
  }) {
    return [
      for (var index = 0; index < allocations.length; index++)
        AmortizationAllocationsCompanion.insert(
          id: '${subjectType.name}:$subjectId:${dimension.name}:${index + 1}',
          subjectType: subjectType,
          subjectId: subjectId,
          dimension: dimension,
          lineNo: index + 1,
          accountId: allocations.elementAt(index).accountId,
          amountMinor: allocations.elementAt(index).amount.minorUnits,
          updatedAt: Value(DateTime.now()),
        ),
    ];
  }

  Map<
    (AmortizationSubjectType, String, AmortizationAllocationDimension),
    List<AccountAmountAllocation>
  >
  _groupAllocations(List<AmortizationAllocationRow> rows) {
    final result =
        <
          (AmortizationSubjectType, String, AmortizationAllocationDimension),
          List<AccountAmountAllocation>
        >{};
    for (final row in rows) {
      result
          .putIfAbsent((
            row.subjectType,
            row.subjectId,
            row.dimension,
          ), () => [])
          .add(
            AccountAmountAllocation(
              accountId: row.accountId,
              amount: Money(minorUnits: row.amountMinor),
            ),
          );
    }
    return result;
  }
}
