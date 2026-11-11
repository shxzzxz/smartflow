import 'package:flutter_test/flutter_test.dart';
import 'package:smartflow/application/credit/credit_query_api.dart';
import 'package:smartflow/core/money/money.dart';
import 'package:smartflow/design_system/widget/app_status_badge.dart';
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

  test('installment bill item uses contract name and current period', () {
    for (final installmentType in InstallmentType.values) {
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
        installmentType: installmentType,
        contractName: '借呗',
        periodNo: 3,
      );

      expect(billItemTitle(item), '借呗 第3期');
      expect(billItemCompactName(item), '借呗');
      expect(billItemRowPresentation(item).title, '借呗 第3期');
    }
  });

  test('consumption bill item uses current-period name', () {
    final item = BillItemReadModel(
      id: 'item-1',
      itemType: BillItemType.consumption,
      status: BillItemStatus.pending,
      repaymentDate: DateTime(2026, 7, 20),
      startInclusive: DateTime(2026, 11, 8),
      endInclusive: DateTime(2026, 12, 7),
      expectedPrincipal: const Money(minorUnits: 10000),
      expectedInterest: Money.zero(),
      expectedFee: Money.zero(),
      allocated: RepaymentAmountDto.zero,
      isOverdue: false,
    );

    expect(billItemTitle(item), '本期消费');
    expect(billItemCompactName(item), '本期消费');
    final presentation = billItemRowPresentation(item);
    expect(presentation.title, '本期消费');
    expect(
      presentation.supportingTexts.map((text) => text.text),
      contains('统计 11-08 - 12-07'),
    );
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

  test('maps bill item statuses to badge presentations', () {
    expect(
      billItemStatusPresentation(
        status: BillItemStatus.pending,
        isOverdue: false,
      ),
      const AppStatusBadgePresentation(
        label: '待还',
        tone: AppStatusTone.warning,
      ),
    );
    expect(
      billItemStatusPresentation(
        status: BillItemStatus.partiallyPaid,
        isOverdue: false,
      ),
      const AppStatusBadgePresentation(
        label: '部分已还',
        tone: AppStatusTone.warning,
      ),
    );
    expect(
      billItemStatusPresentation(status: BillItemStatus.paid, isOverdue: false),
      const AppStatusBadgePresentation(
        label: '已核销',
        tone: AppStatusTone.success,
      ),
    );
    expect(
      billItemStatusPresentation(
        status: BillItemStatus.skipped,
        isOverdue: false,
      ),
      const AppStatusBadgePresentation(
        label: '已跳过',
        tone: AppStatusTone.neutral,
      ),
    );
  });

  test('overdue takes precedence over the persisted item status', () {
    expect(
      billItemStatusPresentation(status: BillItemStatus.paid, isOverdue: true),
      const AppStatusBadgePresentation(
        label: '已逾期',
        tone: AppStatusTone.danger,
      ),
    );
  });
}
