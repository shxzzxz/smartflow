import 'package:flutter_test/flutter_test.dart';
import 'package:smartflow/application/credit/credit_query_api.dart';
import 'package:smartflow/core/money/money.dart';
import 'package:smartflow/feature/credit/presentation/bill_item_presentation.dart';

void main() {
  test('installment bill item opens contract detail', () {
    final item = BillItemReadModel(
      id: 'item-1',
      itemType: BillItemType.installment,
      status: BillItemStatus.pending,
      repaymentDate: DateTime(2026, 7, 20),
      expectedPrincipal: const Money(minorUnits: 10000),
      expectedInterest: Money.zero(),
      expectedFee: Money.zero(),
      allocated: RepaymentAmountDto.zero,
      isOverdue: false,
      contractId: 'contract-1',
      scheduleId: 'schedule-1',
    );

    expect(billItemDestination(item), '/installments/contract-1');
  });

  test('consumption bill item has no navigation target', () {
    final item = BillItemReadModel(
      id: 'item-1',
      itemType: BillItemType.consumption,
      status: BillItemStatus.pending,
      repaymentDate: DateTime(2026, 7, 20),
      expectedPrincipal: const Money(minorUnits: 10000),
      expectedInterest: Money.zero(),
      expectedFee: Money.zero(),
      allocated: RepaymentAmountDto.zero,
      isOverdue: false,
      contractId: 'unexpected-contract',
    );

    expect(billItemDestination(item), isNull);
  });

  test('bill item remaining total includes interest and fee', () {
    final item = BillItemReadModel(
      id: 'item-1',
      itemType: BillItemType.consumption,
      status: BillItemStatus.partiallyPaid,
      repaymentDate: DateTime(2026, 7, 20),
      expectedPrincipal: const Money(minorUnits: 10000),
      expectedInterest: const Money(minorUnits: 500),
      expectedFee: const Money(minorUnits: 200),
      allocated: const RepaymentAmountDto(
        principal: Money(minorUnits: 3000),
        interest: Money(minorUnits: 100),
        fee: Money(minorUnits: 50),
        discount: Money(minorUnits: 0),
      ),
      isOverdue: false,
    );

    expect(item.remainingTotal, const Money(minorUnits: 7550));
  });
}
