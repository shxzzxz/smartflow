import 'package:flutter_test/flutter_test.dart';
import 'package:drift/drift.dart' show Value;
import 'package:smartflow/core/money/money.dart';
import 'package:smartflow/domain/credit/entity/repayment.dart';
import 'package:smartflow/domain/credit/valobj/repayment_amount_breakdown.dart';
import 'package:smartflow/domain/credit/valobj/repayment_enums.dart';
import 'package:smartflow/domain/credit/valobj/bill_enums.dart';
import 'package:smartflow/infrastructure/credit/repository/drift_repayment_repository.dart';
import 'package:smartflow/infrastructure/database/app_database.dart';

import '../../../helper/test_app_database.dart';

void main() {
  group('DriftRepaymentRepository', () {
    test('persists repayment aggregate with stable enum codes', () async {
      final database = createTestDatabase();
      addTearDown(database.close);
      final repository = DriftRepaymentRepository(database);
      final repayment = Repayment(
        id: 'repayment-1',
        repaymentType: RepaymentType.bill,
        targetType: RepaymentTargetType.bill,
        targetId: 'bill-1',
        transactionId: 'tx-root-1',
        repaymentDate: DateTime(2026, 1, 1),
        items: [
          _item(
            id: 'item-1',
            repaymentId: 'repayment-1',
            billItemId: 'bill-item-1',
            principal: 1000,
            interest: 100,
          ),
          _item(
            id: 'item-2',
            repaymentId: 'repayment-1',
            billItemId: 'bill-item-2',
            principal: 500,
            fee: 50,
            discount: 20,
          ),
        ],
      );

      await repository.saveRepayment(repayment);

      final row = await database.select(database.repayments).getSingle();
      expect(row.repaymentType, 'BILL');
      expect(row.targetType, 'BILL');
      expect(row.transactionId, 'tx-root-1');

      final byId = await repository.findRepayment('repayment-1');
      expect(byId, isNotNull);
      expect(byId!.repaymentType, RepaymentType.bill);
      expect(byId.totalAllocated().principal, const Money(minorUnits: 1500));
      expect(byId.totalAllocated().discount, const Money(minorUnits: 20));

      final byRoot = await repository.findByTransaction('tx-root-1');
      expect(byRoot?.id, 'repayment-1');

      final byTarget = await repository.listByTarget(
        RepaymentTargetType.bill,
        'bill-1',
      );
      expect(byTarget.map((repayment) => repayment.id), ['repayment-1']);

      final billItemAllocations = await repository.listItemsByBillItem(
        'bill-item-2',
      );
      expect(
        billItemAllocations.single.allocated.fee,
        const Money(minorUnits: 50),
      );

      final aggregated = await repository.aggregateItemsByBillItemIds([
        'bill-item-1',
        'bill-item-2',
        'missing',
      ]);
      expect(aggregated.keys, {'bill-item-1', 'bill-item-2'});
      expect(
        aggregated['bill-item-1'],
        const RepaymentAmountBreakdown(
          principal: Money(minorUnits: 1000),
          interest: Money(minorUnits: 100),
          fee: Money(minorUnits: 0),
          discount: Money(minorUnits: 0),
        ),
      );
      expect(
        aggregated['bill-item-2'],
        const RepaymentAmountBreakdown(
          principal: Money(minorUnits: 500),
          interest: Money(minorUnits: 0),
          fee: Money(minorUnits: 50),
          discount: Money(minorUnits: 20),
        ),
      );
    });

    test('replaces and deletes repayment items with the aggregate', () async {
      final database = createTestDatabase();
      addTearDown(database.close);
      final repository = DriftRepaymentRepository(database);
      await repository.saveRepayment(
        Repayment(
          id: 'repayment-1',
          repaymentType: RepaymentType.unattributed,
          targetType: RepaymentTargetType.account,
          targetId: 'account-1',
          transactionId: 'tx-root-1',
          repaymentDate: DateTime(2026, 1, 1),
          items: [
            _item(id: 'item-1', repaymentId: 'repayment-1', principal: 1000),
          ],
        ),
      );

      final repayment = (await repository.findRepayment('repayment-1'))!;
      repayment.replaceItems([
        _item(id: 'item-2', repaymentId: 'repayment-1', principal: 300),
      ]);
      await repository.updateRepayment(repayment);

      final replaced = await repository.findRepayment('repayment-1');
      expect(replaced!.items.map((item) => item.id), ['item-2']);
      expect(replaced.totalAllocated().principal, const Money(minorUnits: 300));

      await repository.deleteRepayment('repayment-1');

      expect(await repository.findRepayment('repayment-1'), isNull);
      expect(await database.select(database.repaymentItems).get(), isEmpty);
    });

    test('lists bill repayments allocated to a contract', () async {
      final database = createTestDatabase();
      addTearDown(database.close);
      final repository = DriftRepaymentRepository(database);

      await database
          .into(database.bills)
          .insert(
            BillsCompanion.insert(
              id: 'bill-1',
              accountId: 'account-1',
              period: 202602,
              status: BillStatus.billed,
            ),
          );
      await database
          .into(database.billItems)
          .insert(
            BillItemsCompanion.insert(
              id: 'bill-item-1',
              billId: 'bill-1',
              itemType: BillItemType.installment,
              contractId: const Value('contract-1'),
              scheduleId: const Value('schedule-1'),
              repaymentDate: DateTime(2026, 2, 1),
              expectedPrincipalMinor: 1000,
              expectedInterestMinor: 50,
              expectedFeeMinor: 10,
              status: BillItemStatus.paid,
            ),
          );
      await database
          .into(database.billItems)
          .insert(
            BillItemsCompanion.insert(
              id: 'bill-item-2',
              billId: 'bill-1',
              itemType: BillItemType.installment,
              contractId: const Value('contract-2'),
              scheduleId: const Value('schedule-2'),
              repaymentDate: DateTime(2026, 2, 1),
              expectedPrincipalMinor: 2000,
              expectedInterestMinor: 70,
              expectedFeeMinor: 20,
              status: BillItemStatus.paid,
            ),
          );
      await repository.saveRepayment(
        Repayment(
          id: 'repayment-1',
          repaymentType: RepaymentType.installment,
          targetType: RepaymentTargetType.bill,
          targetId: 'bill-1',
          repaymentDate: DateTime(2026, 2, 5),
          items: [
            _item(
              id: 'item-1',
              repaymentId: 'repayment-1',
              billItemId: 'bill-item-1',
              principal: 1000,
              interest: 50,
              fee: 10,
            ),
            _item(
              id: 'item-2',
              repaymentId: 'repayment-1',
              billItemId: 'bill-item-2',
              principal: 2000,
              interest: 70,
              fee: 20,
            ),
          ],
        ),
      );

      final result = await repository.listByContract('contract-1');

      expect(result.map((repayment) => repayment.id), ['repayment-1']);
      expect(result.single.repaymentDate, DateTime(2026, 2, 5));
      expect(
        result.single.totalAllocated().interest,
        const Money(minorUnits: 50),
      );
      expect(
        result.single.totalAllocated().principal,
        const Money(minorUnits: 1000),
      );
      expect(result.single.items.map((item) => item.billItemId), [
        'bill-item-1',
      ]);
    });
  });
}

RepaymentItem _item({
  required String id,
  required String repaymentId,
  String? billItemId,
  int principal = 0,
  int interest = 0,
  int fee = 0,
  int discount = 0,
}) {
  return RepaymentItem(
    id: id,
    repaymentId: repaymentId,
    billItemId: billItemId,
    allocated: RepaymentAmountBreakdown(
      principal: Money(minorUnits: principal),
      interest: Money(minorUnits: interest),
      fee: Money(minorUnits: fee),
      discount: Money(minorUnits: discount),
    ),
  );
}
