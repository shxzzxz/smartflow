import 'package:drift/drift.dart';

import '../../../domain/orchestration/entity/amortization_entry.dart';
import '../../../domain/orchestration/entity/amortization_plan.dart';
import '../../../domain/orchestration/port/amortization_repository.dart';
import '../../../core/money/money.dart';
import '../../database/app_database.dart';

class DriftAmortizationRepository implements AmortizationRepository {
  const DriftAmortizationRepository(this._database);

  final AppDatabase _database;

  @override
  Future<AmortizationPlan?> findById(String id) async {
    final row = await (_database.select(
      _database.amortizationPlans,
    )..where((table) => table.id.equals(id))).getSingleOrNull();
    if (row == null) return null;
    final entries = await _entriesFor(id);
    return _toDomain(row, entries);
  }

  @override
  Future<List<AmortizationPlan>> findAll({String? deferralAccountId}) async {
    final query = _database.select(_database.amortizationPlans)
      ..orderBy([(table) => OrderingTerm.desc(table.updatedAt)]);
    if (deferralAccountId != null) {
      query.where((table) => table.deferralAccountId.equals(deferralAccountId));
    }
    final rows = await query.get();
    return _loadPlans(rows);
  }

  @override
  Stream<List<AmortizationPlan>> watchAll({String? deferralAccountId}) {
    final query = _database.select(_database.amortizationPlans)
      ..orderBy([(table) => OrderingTerm.desc(table.updatedAt)]);
    if (deferralAccountId != null) {
      query.where((table) => table.deferralAccountId.equals(deferralAccountId));
    }
    return query.watch().asyncMap(_loadPlans);
  }

  @override
  Future<void> save(AmortizationPlan plan) async {
    plan.validate();
    await _database
        .into(_database.amortizationPlans)
        .insertOnConflictUpdate(
          AmortizationPlansCompanion.insert(
            id: plan.id,
            kind: plan.kind,
            deferralAccountId: plan.deferralAccountId,
            categoryAccountId: plan.categoryAccountId,
            totalAmountMinor: plan.total.minorUnits,
            cadenceUnit: plan.cadenceUnit,
            cadenceInterval: plan.cadenceInterval,
            firstRecognitionAt: plan.firstRecognitionAt,
            recognitionCount: plan.recognitionCount,
            defaultIsExcludedFromStats: Value(plan.defaultIsExcludedFromStats),
            defaultIsExcludedFromBudget: Value(
              plan.defaultIsExcludedFromBudget,
            ),
            initialTransactionId: plan.initialTransactionId,
            counterpartyId: Value(plan.counterpartyId),
            note: Value(plan.note),
            terminatedAt: Value(plan.terminatedAt),
            terminationRecognitionTransactionId: Value(
              plan.terminationRecognitionTransactionId,
            ),
            refundTransactionId: Value(plan.refundTransactionId),
            refundAmountMinor: Value(plan.refundAmount?.minorUnits),
            updatedAt: Value(DateTime.now()),
          ),
        );
    await _database.batch((batch) {
      batch.insertAllOnConflictUpdate(_database.amortizationEntries, [
        for (final entry in plan.entries)
          AmortizationEntriesCompanion.insert(
            id: entry.id,
            planId: entry.planId,
            sequenceNo: entry.sequenceNo,
            dueAt: entry.dueAt,
            amountMinor: entry.amount.minorUnits,
            transactionId: Value(entry.transactionId),
            canceledAt: Value(entry.canceledAt),
            updatedAt: Value(DateTime.now()),
          ),
      ]);
    });
  }

  Future<List<AmortizationPlan>> _loadPlans(
    List<AmortizationPlanRow> rows,
  ) async {
    return [for (final row in rows) _toDomain(row, await _entriesFor(row.id))];
  }

  Future<List<AmortizationEntry>> _entriesFor(String planId) async {
    final rows =
        await (_database.select(_database.amortizationEntries)
              ..where((table) => table.planId.equals(planId))
              ..orderBy([(table) => OrderingTerm.asc(table.sequenceNo)]))
            .get();
    return [
      for (final row in rows)
        AmortizationEntry(
          id: row.id,
          planId: row.planId,
          sequenceNo: row.sequenceNo,
          dueAt: row.dueAt,
          amount: Money(minorUnits: row.amountMinor),
          transactionId: row.transactionId,
          canceledAt: row.canceledAt,
        ),
    ];
  }

  AmortizationPlan _toDomain(
    AmortizationPlanRow row,
    List<AmortizationEntry> entries,
  ) {
    return AmortizationPlan(
      id: row.id,
      kind: row.kind,
      deferralAccountId: row.deferralAccountId,
      categoryAccountId: row.categoryAccountId,
      total: Money(minorUnits: row.totalAmountMinor),
      cadenceUnit: row.cadenceUnit,
      cadenceInterval: row.cadenceInterval,
      firstRecognitionAt: row.firstRecognitionAt,
      recognitionCount: row.recognitionCount,
      defaultIsExcludedFromStats: row.defaultIsExcludedFromStats,
      defaultIsExcludedFromBudget: row.defaultIsExcludedFromBudget,
      initialTransactionId: row.initialTransactionId,
      counterpartyId: row.counterpartyId,
      note: row.note,
      terminatedAt: row.terminatedAt,
      terminationRecognitionTransactionId:
          row.terminationRecognitionTransactionId,
      refundTransactionId: row.refundTransactionId,
      refundAmount: row.refundAmountMinor == null
          ? null
          : Money(minorUnits: row.refundAmountMinor!),
      entries: entries,
    );
  }
}
