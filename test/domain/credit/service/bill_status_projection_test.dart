import 'package:flutter_test/flutter_test.dart';
import 'package:smartflow/core/money/money.dart';
import 'package:smartflow/domain/credit/entity/bill.dart';
import 'package:smartflow/domain/credit/service/settlement/settlement_judgement_service.dart';
import 'package:smartflow/domain/credit/valobj/bill_enums.dart';
import 'package:smartflow/domain/credit/valobj/bill_period.dart';

void main() {
  test('an open consumption projection keeps a bill open after settlement', () {
    final bill = _bill(
      status: BillStatus.open,
      billingState: BillItemBillingState.open,
      itemStatus: BillItemStatus.paid,
    );

    bill.recalculateStatusFromItems();

    expect(bill.status, BillStatus.open);
  });

  test('an overpaid open consumption projection remains open', () {
    final bill = _bill(
      status: BillStatus.open,
      billingState: BillItemBillingState.open,
      itemStatus: BillItemStatus.overpaid,
    );

    bill.recalculateStatusFromItems();

    expect(bill.status, BillStatus.open);
  });

  test('closed item projections derive billed and settled states', () {
    final service = const SettlementJudgementService();
    expect(
      service.projectBillStatus(BillStatus.open, const [
        BillItemStatus.pending,
      ]),
      BillStatus.billed,
    );
    expect(
      service.projectBillStatus(BillStatus.billed, const [
        BillItemStatus.paid,
        BillItemStatus.overpaid,
      ]),
      BillStatus.settled,
    );
  });
}

Bill _bill({
  required BillStatus status,
  required BillItemBillingState billingState,
  required BillItemStatus itemStatus,
}) {
  return Bill(
    id: 'bill',
    accountId: 'account',
    period: BillPeriod(year: 2026, month: 7),
    status: status,
    items: [
      BillItem(
        id: 'item',
        billId: 'bill',
        itemType: BillItemType.consumption,
        billingState: billingState,
        repaymentDate: DateTime(2026, 8, 3),
        expectedPrincipal: Money.zero(),
        expectedInterest: Money.zero(),
        expectedFee: Money.zero(),
        status: itemStatus,
      ),
    ],
  );
}
