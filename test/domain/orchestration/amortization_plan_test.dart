import 'package:flutter_test/flutter_test.dart';
import 'package:smartflow/core/money/money.dart';
import 'package:smartflow/domain/ledger/valobj/account_amount_allocation.dart';
import 'package:smartflow/domain/orchestration/entity/amortization_plan.dart';
import 'package:smartflow/domain/orchestration/entity/amortization_refund.dart';
import 'package:smartflow/domain/orchestration/valobj/amortization_enums.dart';

void main() {
  test('refund rebases all periods and preserves generated transaction id', () {
    final created = AmortizationPlan.create(
      id: 'plan',
      kind: AmortizationKind.prepaidExpense,
      deferralAccountId: 'deferral',
      fundingAllocations: const [
        AccountAmountAllocation(
          accountId: 'account-c',
          amount: Money(minorUnits: 30000),
        ),
        AccountAmountAllocation(
          accountId: 'account-d',
          amount: Money(minorUnits: 30000),
        ),
      ],
      categoryAllocations: const [
        AccountAmountAllocation(
          accountId: 'category-a',
          amount: Money(minorUnits: 20000),
        ),
        AccountAmountAllocation(
          accountId: 'category-b',
          amount: Money(minorUnits: 40000),
        ),
      ],
      originalAmount: const Money(minorUnits: 60000),
      cadenceUnit: AmortizationCadenceUnit.monthly,
      cadenceInterval: 1,
      firstRecognitionAt: DateTime(2026, 1, 31),
      recognitionCount: 4,
      initialTransactionId: 'initial',
    );
    final plan = created.withPeriods([
      created.periods.first.posted('recognition-1'),
      ...created.periods.skip(1),
    ]);

    final updated = plan.withRefund(
      AmortizationRefund(
        id: 'refund',
        planId: plan.id,
        categoryAllocations: const [
          AccountAmountAllocation(
            accountId: 'category-a',
            amount: Money(minorUnits: 10000),
          ),
          AccountAmountAllocation(
            accountId: 'category-b',
            amount: Money(minorUnits: 20000),
          ),
        ],
        settlementAllocations: const [
          AccountAmountAllocation(
            accountId: 'account-c',
            amount: Money(minorUnits: 20000),
          ),
          AccountAmountAllocation(
            accountId: 'account-d',
            amount: Money(minorUnits: 10000),
          ),
        ],
        transferTransactionId: 'refund-transfer',
      ),
    );

    expect(updated.netAmount, const Money(minorUnits: 30000));
    expect(updated.periods.map((period) => period.amount.minorUnits), [
      7500,
      7500,
      7500,
      7500,
    ]);
    expect(
      updated.periods.first.categoryAllocations
          .map(
            (allocation) =>
                (allocation.accountId, allocation.amount.minorUnits),
          )
          .toList(),
      [('category-a', 2500), ('category-b', 5000)],
    );
    expect(updated.periods.first.transactionId, 'recognition-1');
    expect(updated.refunds.single.amount, const Money(minorUnits: 30000));
  });

  test('full refund completes the plan without positive periods', () {
    final created = AmortizationPlan.create(
      id: 'plan',
      kind: AmortizationKind.prepaidExpense,
      deferralAccountId: 'deferral',
      fundingAllocations: singleAllocation(
        accountId: 'cash',
        amount: const Money(minorUnits: 12000),
      ),
      categoryAllocations: singleAllocation(
        accountId: 'expense',
        amount: const Money(minorUnits: 12000),
      ),
      originalAmount: const Money(minorUnits: 12000),
      cadenceUnit: AmortizationCadenceUnit.monthly,
      cadenceInterval: 1,
      firstRecognitionAt: DateTime(2026, 1, 31),
      recognitionCount: 12,
      initialTransactionId: 'initial',
    );

    final updated = created.withRefund(
      AmortizationRefund(
        id: 'refund',
        planId: created.id,
        categoryAllocations: singleAllocation(
          accountId: 'expense',
          amount: const Money(minorUnits: 12000),
        ),
        settlementAllocations: singleAllocation(
          accountId: 'cash',
          amount: const Money(minorUnits: 12000),
        ),
        transferTransactionId: 'refund-transfer',
      ),
    );

    expect(updated.netAmount, Money.zero());
    expect(
      updated.periods.every((period) => period.amount.minorUnits == 0),
      isTrue,
    );
    expect(updated.periods.every((period) => period.isZero), isTrue);
    expect(updated.status, AmortizationStatus.completed);
  });
}
