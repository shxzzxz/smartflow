import 'package:drift/drift.dart';

import '../../../core/money/money.dart';
import '../../../domain/credit/entity/bill.dart';
import '../../../domain/credit/port/bill_repository.dart';
import '../../../domain/credit/valobj/bill_enums.dart';
import '../../../domain/credit/valobj/bill_period.dart';
import '../../../domain/credit/valobj/bill_window.dart';
import '../../database/app_database.dart';

class DriftBillRepository implements BillRepository {
  DriftBillRepository(this._database);

  final AppDatabase _database;

  @override
  Future<Bill?> findBill(String billId) async {
    final row =
        await (_database.select(_database.bills)
          ..where((bill) => bill.id.equals(billId))).getSingleOrNull();
    if (row == null) return null;
    final items = await _listItems({row.id});
    return _mapBill(row, items[row.id] ?? const []);
  }

  @override
  Future<Bill?> findByAccountAndPeriod(
    String accountId,
    BillPeriod period,
  ) async {
    final row =
        await (_database.select(_database.bills)..where(
          (bill) =>
              bill.accountId.equals(accountId) &
              bill.period.equals(period.toInt()),
        )).getSingleOrNull();
    if (row == null) return null;
    final items = await _listItems({row.id});
    return _mapBill(row, items[row.id] ?? const []);
  }

  @override
  Future<List<Bill>> listBillsByAccount(String accountId) async {
    final rows =
        await (_database.select(_database.bills)
              ..where((bill) => bill.accountId.equals(accountId))
              ..orderBy([
                (bill) => OrderingTerm.desc(bill.period),
                (bill) => OrderingTerm.desc(bill.createdAt),
              ]))
            .get();
    final items = await _listItems(rows.map((row) => row.id).toSet());
    return [for (final row in rows) _mapBill(row, items[row.id] ?? const [])];
  }

  @override
  Future<Bill> saveBill(Bill bill) async {
    final now = DateTime.now();
    await _database
        .into(_database.bills)
        .insert(_billCompanion(bill, now), mode: InsertMode.insertOrIgnore);
    return (await findByAccountAndPeriod(bill.accountId, bill.period))!;
  }

  @override
  Future<void> updateBill(Bill bill) async {
    await (_database.update(_database.bills)
      ..where((row) => row.id.equals(bill.id))).write(
      BillsCompanion(
        startDate: Value(bill.window?.startDate),
        billingDate: Value(bill.window?.billingDate),
        repaymentDate: Value(bill.window?.repaymentDate),
        status: Value(bill.status),
        updatedAt: Value(DateTime.now()),
      ),
    );
  }

  @override
  Future<void> replaceBillItems(String billId, List<BillItem> items) async {
    final now = DateTime.now();
    await (_database.delete(_database.billItems)
      ..where((item) => item.billId.equals(billId))).go();
    await _database.batch((batch) {
      for (final item in items) {
        batch.insert(_database.billItems, _itemCompanion(item, now));
      }
    });
  }

  @override
  Future<void> deleteBill(String billId) async {
    await _database.transaction(() async {
      await (_database.delete(_database.billItems)
        ..where((item) => item.billId.equals(billId))).go();
      await (_database.delete(_database.bills)
        ..where((bill) => bill.id.equals(billId))).go();
    });
  }

  @override
  Future<bool> hasUnsettledItems(String accountId) async {
    final countExpr = _database.billItems.id.count();
    final row =
        await (_database.selectOnly(_database.billItems).join([
                innerJoin(
                  _database.bills,
                  _database.bills.id.equalsExp(_database.billItems.billId),
                ),
              ])
              ..addColumns([countExpr])
              ..where(_database.bills.accountId.equals(accountId))
              ..where(
                _database.billItems.status.isInValues({
                  BillItemStatus.pending,
                  BillItemStatus.partiallyPaid,
                }),
              ))
            .getSingle();
    return (row.read(countExpr) ?? 0) > 0;
  }

  Future<Map<String, List<BillItem>>> _listItems(Set<String> billIds) async {
    if (billIds.isEmpty) return const {};
    final rows =
        await (_database.select(_database.billItems)
              ..where((item) => item.billId.isIn(billIds))
              ..orderBy([
                (item) => OrderingTerm.asc(item.repaymentDate),
                (item) => OrderingTerm.asc(item.itemType),
                (item) => OrderingTerm.asc(item.id),
              ]))
            .get();
    final result = <String, List<BillItem>>{};
    for (final row in rows) {
      result.putIfAbsent(row.billId, () => <BillItem>[]).add(_mapItem(row));
    }
    return result;
  }

  BillsCompanion _billCompanion(Bill bill, DateTime now) {
    return BillsCompanion.insert(
      id: bill.id,
      accountId: bill.accountId,
      period: bill.period.toInt(),
      startDate: Value(bill.window?.startDate),
      billingDate: Value(bill.window?.billingDate),
      repaymentDate: Value(bill.window?.repaymentDate),
      status: bill.status,
      createdAt: Value(now),
      updatedAt: Value(now),
    );
  }

  BillItemsCompanion _itemCompanion(BillItem item, DateTime now) {
    return BillItemsCompanion.insert(
      id: item.id,
      billId: item.billId,
      itemType: item.itemType,
      contractId: Value(item.contractId),
      scheduleId: Value(item.scheduleId),
      repaymentDate: item.repaymentDate,
      expectedPrincipalMinor: item.expectedPrincipal.minorUnits,
      expectedInterestMinor: item.expectedInterest.minorUnits,
      expectedFeeMinor: item.expectedFee.minorUnits,
      status: item.status,
      createdAt: Value(item.createdAt ?? now),
      updatedAt: Value(now),
    );
  }

  Bill _mapBill(BillRow row, List<BillItem> items) {
    final period = BillPeriod.fromInt(row.period);
    final hasWindow =
        row.startDate != null &&
        row.billingDate != null &&
        row.repaymentDate != null;
    return Bill(
      id: row.id,
      accountId: row.accountId,
      period: period,
      window:
          hasWindow
              ? BillWindow(
                period: period,
                startDate: row.startDate!,
                billingDate: row.billingDate!,
                repaymentDate: row.repaymentDate!,
              )
              : null,
      status: row.status,
      items: List.unmodifiable(items),
      createdAt: row.createdAt,
    );
  }

  BillItem _mapItem(BillItemRow row) {
    return BillItem(
      id: row.id,
      billId: row.billId,
      itemType: row.itemType,
      contractId: row.contractId,
      scheduleId: row.scheduleId,
      repaymentDate: row.repaymentDate,
      expectedPrincipal: Money(minorUnits: row.expectedPrincipalMinor),
      expectedInterest: Money(minorUnits: row.expectedInterestMinor),
      expectedFee: Money(minorUnits: row.expectedFeeMinor),
      status: row.status,
      createdAt: row.createdAt,
    );
  }
}
