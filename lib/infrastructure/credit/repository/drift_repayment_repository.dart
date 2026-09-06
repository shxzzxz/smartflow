import 'package:drift/drift.dart';

import '../../../core/error/app_exception.dart';
import '../../../core/money/money.dart';
import '../../../domain/credit/entity/repayment.dart';
import '../../../domain/credit/port/repayment_repository.dart';
import '../../../domain/credit/valobj/credit_error_code.dart';
import '../../../domain/credit/valobj/repayment_amount_breakdown.dart';
import '../../../domain/credit/valobj/repayment_enums.dart';
import '../../database/app_database.dart';

class DriftRepaymentRepository implements RepaymentRepository {
  DriftRepaymentRepository(this._database);

  final AppDatabase _database;

  @override
  Future<Repayment?> findRepayment(String repaymentId) async {
    final row =
        await (_database.select(_database.repayments)
              ..where((repayment) => repayment.id.equals(repaymentId)))
            .getSingleOrNull();
    if (row == null) return null;
    return _mapRepayment(row, await listItems(row.id));
  }

  @override
  Future<Repayment?> findByTransaction(String transactionId) async {
    final row =
        await (_database.select(_database.repayments)..where(
              (repayment) => repayment.transactionId.equals(transactionId),
            ))
            .getSingleOrNull();
    if (row == null) return null;
    return _mapRepayment(row, await listItems(row.id));
  }

  @override
  Future<List<Repayment>> listByTarget(
    RepaymentTargetType targetType,
    String targetId,
  ) async {
    final rows =
        await (_database.select(_database.repayments)
              ..where(
                (repayment) =>
                    repayment.targetType.equals(targetType.code) &
                    repayment.targetId.equals(targetId),
              )
              ..orderBy([
                (repayment) => OrderingTerm.desc(repayment.createdAt),
                (repayment) => OrderingTerm.desc(repayment.id),
              ]))
            .get();
    final items = await _listItemsByRepaymentIds(rows.map((row) => row.id));
    return [
      for (final row in rows) _mapRepayment(row, items[row.id] ?? const []),
    ];
  }

  @override
  Future<List<Repayment>> listByContract(String contractId) async {
    final direct = await listByTarget(RepaymentTargetType.contract, contractId);
    final repaymentRows =
        await (_database.select(_database.repayments).join([
                innerJoin(
                  _database.repaymentItems,
                  _database.repaymentItems.repaymentId.equalsExp(
                    _database.repayments.id,
                  ),
                ),
                innerJoin(
                  _database.billItems,
                  _database.billItems.id.equalsExp(
                    _database.repaymentItems.billItemId,
                  ),
                ),
              ])
              ..where(_database.billItems.contractId.equals(contractId))
              ..where(
                _database.repayments.targetType.equals(
                  RepaymentTargetType.bill.code,
                ),
              )
              ..orderBy([
                OrderingTerm.desc(_database.repayments.createdAt),
                OrderingTerm.desc(_database.repayments.id),
              ]))
            .get();
    final billItemIdsByRepaymentId = <String, Set<String>>{};
    for (final row in repaymentRows) {
      final repaymentId = row.readTable(_database.repayments).id;
      final billItemId = row.readTable(_database.billItems).id;
      billItemIdsByRepaymentId
          .putIfAbsent(repaymentId, () => <String>{})
          .add(billItemId);
    }
    final billRepaymentIds = {
      for (final row in repaymentRows) row.readTable(_database.repayments).id,
    };
    if (billRepaymentIds.isEmpty) return direct;

    final rows =
        await (_database.select(_database.repayments)
              ..where((repayment) => repayment.id.isIn(billRepaymentIds))
              ..orderBy([
                (repayment) => OrderingTerm.desc(repayment.createdAt),
                (repayment) => OrderingTerm.desc(repayment.id),
              ]))
            .get();
    final items = await _listItemsByRepaymentIds(rows.map((row) => row.id));
    final billRepayments = [
      for (final row in rows)
        _mapRepayment(
          row,
          (items[row.id] ?? const [])
              .where(
                (item) =>
                    billItemIdsByRepaymentId[row.id]!.contains(item.billItemId),
              )
              .toList(),
        ),
    ];
    return [...direct, ...billRepayments];
  }

  @override
  Future<List<RepaymentItem>> listItems(String repaymentId) async {
    final rows =
        await (_database.select(_database.repaymentItems)
              ..where((item) => item.repaymentId.equals(repaymentId))
              ..orderBy([
                (item) => OrderingTerm.asc(item.createdAt),
                (item) => OrderingTerm.asc(item.id),
              ]))
            .get();
    return rows.map(_mapItem).toList();
  }

  @override
  Future<List<RepaymentItem>> listItemsByBillItem(String billItemId) async {
    final rows =
        await (_database.select(_database.repaymentItems)
              ..where((item) => item.billItemId.equals(billItemId))
              ..orderBy([
                (item) => OrderingTerm.asc(item.createdAt),
                (item) => OrderingTerm.asc(item.id),
              ]))
            .get();
    return rows.map(_mapItem).toList();
  }

  @override
  Future<Map<String, RepaymentAmountBreakdown>> aggregateItemsByBillItemIds(
    Iterable<String> billItemIds,
  ) async {
    final ids = billItemIds.toSet();
    if (ids.isEmpty) return const {};

    final item = _database.repaymentItems;
    final principal = item.allocatedPrincipalMinor.sum();
    final interest = item.allocatedInterestMinor.sum();
    final fee = item.allocatedFeeMinor.sum();
    final discount = item.allocatedDiscountMinor.sum();
    final query = _database.selectOnly(item)
      ..addColumns([item.billItemId, principal, interest, fee, discount])
      ..where(item.billItemId.isIn(ids))
      ..groupBy([item.billItemId]);
    final rows = await query.get();
    return {
      for (final row in rows)
        if (row.read(item.billItemId) case final String billItemId)
          billItemId: RepaymentAmountBreakdown(
            principal: Money(minorUnits: row.read(principal) ?? 0),
            interest: Money(minorUnits: row.read(interest) ?? 0),
            fee: Money(minorUnits: row.read(fee) ?? 0),
            discount: Money(minorUnits: row.read(discount) ?? 0),
          ),
    };
  }

  @override
  Future<void> saveRepayment(Repayment repayment) async {
    repayment.validateTarget();
    final now = DateTime.now();
    await _database
        .into(_database.repayments)
        .insert(_repaymentCompanion(repayment, now));
    await _insertItems(repayment.items, now);
  }

  @override
  Future<void> updateRepayment(Repayment repayment) async {
    final now = DateTime.now();
    final updated =
        await (_database.update(
          _database.repayments,
        )..where((row) => row.id.equals(repayment.id))).write(
          RepaymentsCompanion(
            transactionId: Value(repayment.transactionId),
            repaymentDate: Value(repayment.repaymentDate),
            updatedAt: Value(now),
          ),
        );
    if (updated == 0) {
      throw BusinessException(CreditErrorCode.repaymentNotFound);
    }
    await (_database.delete(
      _database.repaymentItems,
    )..where((item) => item.repaymentId.equals(repayment.id))).go();
    await _insertItems(repayment.items, now);
  }

  @override
  Future<void> deleteRepayment(String repaymentId) async {
    await (_database.delete(
      _database.repaymentItems,
    )..where((item) => item.repaymentId.equals(repaymentId))).go();
    await (_database.delete(
      _database.repayments,
    )..where((repayment) => repayment.id.equals(repaymentId))).go();
  }

  Future<void> _insertItems(List<RepaymentItem> items, DateTime now) async {
    await _database.batch((batch) {
      for (final item in items) {
        batch.insert(_database.repaymentItems, _itemCompanion(item, now));
      }
    });
  }

  Future<Map<String, List<RepaymentItem>>> _listItemsByRepaymentIds(
    Iterable<String> repaymentIds,
  ) async {
    final ids = repaymentIds.toSet();
    if (ids.isEmpty) return const {};
    final rows =
        await (_database.select(_database.repaymentItems)
              ..where((item) => item.repaymentId.isIn(ids))
              ..orderBy([
                (item) => OrderingTerm.asc(item.createdAt),
                (item) => OrderingTerm.asc(item.id),
              ]))
            .get();
    final result = <String, List<RepaymentItem>>{};
    for (final row in rows) {
      result
          .putIfAbsent(row.repaymentId, () => <RepaymentItem>[])
          .add(_mapItem(row));
    }
    return result;
  }

  RepaymentsCompanion _repaymentCompanion(Repayment repayment, DateTime now) {
    return RepaymentsCompanion.insert(
      id: repayment.id,
      repaymentType: repayment.repaymentType.code,
      targetType: repayment.targetType.code,
      targetId: repayment.targetId,
      transactionId: Value(repayment.transactionId),
      repaymentDate: repayment.repaymentDate,
      createdAt: Value(repayment.createdAt ?? now),
      updatedAt: Value(now),
    );
  }

  RepaymentItemsCompanion _itemCompanion(RepaymentItem item, DateTime now) {
    return RepaymentItemsCompanion.insert(
      id: item.id,
      repaymentId: item.repaymentId,
      billItemId: Value(item.billItemId),
      allocatedPrincipalMinor: item.allocated.principal.minorUnits,
      allocatedInterestMinor: item.allocated.interest.minorUnits,
      allocatedFeeMinor: item.allocated.fee.minorUnits,
      allocatedDiscountMinor: item.allocated.discount.minorUnits,
      createdAt: Value(item.createdAt ?? now),
      updatedAt: Value(now),
    );
  }

  Repayment _mapRepayment(RepaymentRow row, List<RepaymentItem> items) {
    return Repayment(
      id: row.id,
      repaymentType: RepaymentType.fromCode(row.repaymentType),
      targetType: RepaymentTargetType.fromCode(row.targetType),
      targetId: row.targetId,
      transactionId: row.transactionId,
      repaymentDate: row.repaymentDate,
      items: items,
      createdAt: row.createdAt,
    );
  }

  RepaymentItem _mapItem(RepaymentItemRow row) {
    return RepaymentItem(
      id: row.id,
      repaymentId: row.repaymentId,
      billItemId: row.billItemId,
      allocated: RepaymentAmountBreakdown(
        principal: Money(minorUnits: row.allocatedPrincipalMinor),
        interest: Money(minorUnits: row.allocatedInterestMinor),
        fee: Money(minorUnits: row.allocatedFeeMinor),
        discount: Money(minorUnits: row.allocatedDiscountMinor),
      ),
      createdAt: row.createdAt,
    );
  }
}
