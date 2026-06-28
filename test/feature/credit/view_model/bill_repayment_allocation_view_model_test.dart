import 'package:flutter_test/flutter_test.dart';
import 'package:smartflow/application/credit/credit_command_api.dart' as credit;
import 'package:smartflow/core/money/money.dart';
import 'package:smartflow/feature/credit/view_model/bill_repayment_allocation_view_model.dart';

void main() {
  test(
    'fifo suggests fee interest principal across installment before consumption',
    () {
      final viewModel = BillRepaymentAllocationViewModel(
        lines: [
          _line(
            'consumption',
            credit.BillItemType.consumption,
            principal: 100,
            interest: 20,
            fee: 20,
          ),
          _line(
            'installment',
            credit.BillItemType.installment,
            principal: 90,
            interest: 40,
            fee: 20,
          ),
        ],
      );

      final review = viewModel.suggest(
        mode: BillRepaymentAllocationMode.fifo,
        amount: _breakdown(principal: 100, interest: 50, fee: 30),
      );

      final byId = _byId(review.allocations);
      expect(byId['installment']!.allocated.fee, const Money(minorUnits: 20));
      expect(byId['consumption']!.allocated.fee, const Money(minorUnits: 10));
      expect(
        byId['installment']!.allocated.interest,
        const Money(minorUnits: 40),
      );
      expect(
        byId['consumption']!.allocated.interest,
        const Money(minorUnits: 10),
      );
      expect(
        byId['installment']!.allocated.principal,
        const Money(minorUnits: 90),
      );
      expect(
        byId['consumption']!.allocated.principal,
        const Money(minorUnits: 10),
      );
      expect(review.hasOverAllocation, false);
    },
  );

  test('equal suggestion splits principal and keeps cent remainder stable', () {
    final viewModel = BillRepaymentAllocationViewModel(
      lines: [
        _line('a', credit.BillItemType.consumption, principal: 100),
        _line('b', credit.BillItemType.consumption, principal: 100),
      ],
    );

    final review = viewModel.suggest(
      mode: BillRepaymentAllocationMode.equal,
      amount: _breakdown(principal: 101),
    );

    final byId = _byId(review.allocations);
    expect(byId['a']!.allocated.principal, const Money(minorUnits: 51));
    expect(byId['b']!.allocated.principal, const Money(minorUnits: 50));
    expect(review.unallocated.principal, Money.zero());
  });

  test('equal suggestion does not over-distribute tiny amounts', () {
    final viewModel = BillRepaymentAllocationViewModel(
      lines: [
        _line('a', credit.BillItemType.consumption, principal: 100),
        _line('b', credit.BillItemType.consumption, principal: 100),
        _line('c', credit.BillItemType.consumption, principal: 100),
      ],
    );

    final review = viewModel.suggest(
      mode: BillRepaymentAllocationMode.equal,
      amount: _breakdown(principal: 2),
    );

    final byId = _byId(review.allocations);
    expect(byId['a']!.allocated.principal, const Money(minorUnits: 1));
    expect(byId['b']!.allocated.principal, const Money(minorUnits: 1));
    expect(byId.containsKey('c'), false);
    expect(review.totalAllocated.principal, const Money(minorUnits: 2));
  });

  test(
    'suggestions cap at remaining amounts and leave overflow unallocated',
    () {
      final viewModel = BillRepaymentAllocationViewModel(
        lines: [
          _line('a', credit.BillItemType.consumption, principal: 100),
          _line('b', credit.BillItemType.consumption, principal: 50),
        ],
      );

      final review = viewModel.suggest(
        mode: BillRepaymentAllocationMode.fifo,
        amount: _breakdown(principal: 500),
      );

      expect(review.totalAllocated.principal, const Money(minorUnits: 150));
      expect(review.unallocated.principal, const Money(minorUnits: 350));
      expect(review.hasOverAllocation, false);
    },
  );

  test('manual mode preserves over-allocation and returns warning', () {
    final viewModel = BillRepaymentAllocationViewModel(
      lines: [_line('a', credit.BillItemType.consumption, principal: 100)],
    );

    final review = viewModel.suggest(
      mode: BillRepaymentAllocationMode.manual,
      amount: _breakdown(principal: 120),
      manualAllocations: [
        credit.BillRepaymentAllocation(
          billItemId: 'a',
          allocated: _breakdown(principal: 120),
        ),
      ],
    );

    expect(
      review.allocations.single.allocated.principal,
      const Money(minorUnits: 120),
    );
    expect(review.hasOverAllocation, true);
    expect(review.warningMessage, isNotNull);
  });
}

BillRepaymentAllocationLine _line(
  String id,
  credit.BillItemType type, {
  int principal = 0,
  int interest = 0,
  int fee = 0,
  credit.RepaymentAmountBreakdown alreadyAllocated =
      credit.RepaymentAmountBreakdown.zero,
}) {
  return BillRepaymentAllocationLine(
    billItemId: id,
    itemType: type,
    expected: _breakdown(principal: principal, interest: interest, fee: fee),
    alreadyAllocated: alreadyAllocated,
  );
}

Map<String, credit.BillRepaymentAllocation> _byId(
  List<credit.BillRepaymentAllocation> allocations,
) {
  return {
    for (final allocation in allocations) allocation.billItemId: allocation,
  };
}

credit.RepaymentAmountBreakdown _breakdown({
  int principal = 0,
  int interest = 0,
  int fee = 0,
  int discount = 0,
}) {
  return credit.RepaymentAmountBreakdown(
    principal: Money(minorUnits: principal),
    interest: Money(minorUnits: interest),
    fee: Money(minorUnits: fee),
    discount: Money(minorUnits: discount),
  );
}
