import 'package:flutter_test/flutter_test.dart';
import 'package:smartflow/core/error/app_exception.dart';
import 'package:smartflow/core/money/money.dart';
import 'package:smartflow/domain/ledger/valobj/account_amount_allocation.dart';
import 'package:smartflow/domain/orchestration/entity/amortization_plan.dart';
import 'package:smartflow/domain/orchestration/entity/amortization_refund.dart';
import 'package:smartflow/domain/orchestration/entity/amortization_termination.dart';
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

  test('editing a refund replaces its facts and keeps posted identities', () {
    final created = _plan(multiCategory: true);
    final refunded = created.withRefund(
      AmortizationRefund(
        id: 'refund',
        planId: created.id,
        categoryAllocations: const [
          AccountAmountAllocation(
            accountId: 'category-a',
            amount: Money(minorUnits: 15000),
          ),
          AccountAmountAllocation(
            accountId: 'category-b',
            amount: Money(minorUnits: 20000),
          ),
        ],
        settlementAllocations: singleAllocation(
          accountId: 'account-c',
          amount: const Money(minorUnits: 35000),
        ),
        transferTransactionId: 'refund-transfer',
      ),
    );
    final posted = refunded.withPeriods([
      refunded.periods.first.posted('recognition-1'),
      ...refunded.periods.skip(1),
    ]);
    final edited = posted.withUpdatedRefund(
      AmortizationRefund(
        id: 'refund',
        planId: posted.id,
        categoryAllocations: const [
          AccountAmountAllocation(
            accountId: 'category-a',
            amount: Money(minorUnits: 15000),
          ),
          AccountAmountAllocation(
            accountId: 'category-b',
            amount: Money(minorUnits: 15000),
          ),
        ],
        settlementAllocations: singleAllocation(
          accountId: 'account-d',
          amount: const Money(minorUnits: 30000),
        ),
        transferTransactionId: 'refund-transfer',
      ),
    );

    expect(edited.refunds.single.id, 'refund');
    expect(edited.periods.first.transactionId, 'recognition-1');
    expect(
      edited.periods.first.categoryAllocations.map(
        (allocation) => allocation.accountId,
      ),
      ['category-a', 'category-b'],
    );
    expect(
      sumAllocations(edited.periods.first.categoryAllocations),
      edited.periods.first.amount,
    );
  });

  test('termination cannot return more than the unrecognized balance', () {
    final created = _plan(recognitionCount: 12, totalMinor: 120000);
    final posted = created.withPeriods([
      for (var index = 0; index < created.periods.length; index++)
        index < 10
            ? created.periods[index].posted('recognition-$index')
            : created.periods[index].canceled(),
    ]);

    expect(
      () => posted.terminatedWith(
        termination: AmortizationTermination(
          id: 'termination',
          planId: posted.id,
          terminatedAt: DateTime(2026, 3, 15),
          categoryReturnAllocations: singleAllocation(
            accountId: 'category-a',
            amount: const Money(minorUnits: 50000),
          ),
          settlementAllocations: singleAllocation(
            accountId: 'account-c',
            amount: const Money(minorUnits: 50000),
          ),
          recognitionTransactionId: 'termination-recognition',
          returnTransactionId: 'termination-return',
        ),
        periods: posted.periods,
      ),
      throwsA(isA<BusinessException>()),
    );
  });

  test(
    'configuration rebuild uses refunds and preserves posted identities',
    () {
      final created = _plan();
      final refunded = created.withRefund(
        AmortizationRefund(
          id: 'refund',
          planId: created.id,
          categoryAllocations: singleAllocation(
            accountId: 'category-a',
            amount: const Money(minorUnits: 10000),
          ),
          settlementAllocations: singleAllocation(
            accountId: 'account-c',
            amount: const Money(minorUnits: 10000),
          ),
          transferTransactionId: 'refund-transfer',
        ),
      );
      final posted = refunded.withPeriods([
        refunded.periods.first.posted('recognition-1'),
        ...refunded.periods.skip(1),
      ]);

      final updated = posted.reconfiguredConfiguration(
        firstRecognitionAt: DateTime(2026, 2, 15),
        cadenceUnit: AmortizationCadenceUnit.yearly,
        cadenceInterval: 1,
        recognitionCount: 2,
      );

      expect(updated.kind, AmortizationKind.prepaidExpense);
      expect(updated.periods, hasLength(2));
      expect(updated.netAmount, const Money(minorUnits: 50000));
      expect(updated.periods.map((period) => period.amount.minorUnits), [
        25000,
        25000,
      ]);
      expect(updated.periods.first.transactionId, 'recognition-1');
      expect(updated.refunds.single.id, 'refund');
    },
  );

  test('termination recognition excludes returned category balances', () {
    final created = _plan(multiCategory: true);
    final posted = created.withPeriods([
      created.periods.first.posted('recognition-1'),
      ...created.periods.skip(1),
    ]);

    final terminated = posted.terminatedWith(
      termination: AmortizationTermination(
        id: 'termination',
        planId: posted.id,
        terminatedAt: DateTime(2026, 2, 1),
        categoryReturnAllocations: const [
          AccountAmountAllocation(
            accountId: 'category-a',
            amount: Money(minorUnits: 15000),
          ),
          AccountAmountAllocation(
            accountId: 'category-b',
            amount: Money(minorUnits: 20000),
          ),
        ],
        settlementAllocations: singleAllocation(
          accountId: 'account-c',
          amount: const Money(minorUnits: 35000),
        ),
        recognitionTransactionId: 'termination-recognition',
        returnTransactionId: 'termination-return',
      ),
      periods: posted.periods,
    );

    expect(
      terminated.terminationRecognitionCategoryAllocations.map(
        (allocation) => (allocation.accountId, allocation.amount.minorUnits),
      ),
      [('category-b', 10000)],
    );
  });

  test('termination recognition is empty when every category is returned', () {
    final created = _plan(multiCategory: true);
    final posted = created.withPeriods([
      created.periods.first.posted('recognition-1'),
      ...created.periods.skip(1),
    ]);

    final terminated = posted.terminatedWith(
      termination: AmortizationTermination(
        id: 'termination',
        planId: posted.id,
        terminatedAt: DateTime(2026, 2, 1),
        categoryReturnAllocations: const [
          AccountAmountAllocation(
            accountId: 'category-a',
            amount: Money(minorUnits: 15000),
          ),
          AccountAmountAllocation(
            accountId: 'category-b',
            amount: Money(minorUnits: 30000),
          ),
        ],
        settlementAllocations: singleAllocation(
          accountId: 'account-c',
          amount: const Money(minorUnits: 45000),
        ),
        returnTransactionId: 'termination-return',
      ),
      periods: posted.periods,
    );

    expect(terminated.terminationRecognitionCategoryAllocations, isEmpty);
  });

  test(
    'termination-date remaining subtracts recognized net-period amounts',
    () {
      final created = _plan(totalMinor: 120000, recognitionCount: 4);
      final refunded = created.withRefund(
        AmortizationRefund(
          id: 'refund',
          planId: created.id,
          categoryAllocations: singleAllocation(
            accountId: 'category-a',
            amount: const Money(minorUnits: 30000),
          ),
          settlementAllocations: singleAllocation(
            accountId: 'account-c',
            amount: const Money(minorUnits: 30000),
          ),
          transferTransactionId: 'refund-transfer',
        ),
      );
      final plan = refunded.withPeriods([
        refunded.periods[0].posted('recognition-1'),
        refunded.periods[1].posted('recognition-2'),
        ...refunded.periods.skip(2),
      ]);

      final remaining = plan.remainingCategoryAllocationsAt(
        DateTime(2026, 3, 1),
      );

      expect(plan.netAmount, const Money(minorUnits: 90000));
      expect(plan.recognizedAmount, const Money(minorUnits: 45000));
      expect(remaining.single.accountId, 'category-a');
      expect(remaining.single.amount, const Money(minorUnits: 45000));
    },
  );
}

AmortizationPlan _plan({
  int recognitionCount = 4,
  int totalMinor = 60000,
  bool multiCategory = false,
}) {
  return AmortizationPlan.create(
    id: 'plan',
    kind: AmortizationKind.prepaidExpense,
    deferralAccountId: 'deferral',
    fundingAllocations: multiCategory
        ? [
            AccountAmountAllocation(
              accountId: 'account-c',
              amount: Money(minorUnits: totalMinor ~/ 2),
            ),
            AccountAmountAllocation(
              accountId: 'account-d',
              amount: Money(minorUnits: totalMinor - totalMinor ~/ 2),
            ),
          ]
        : singleAllocation(
            accountId: 'account-c',
            amount: Money(minorUnits: totalMinor),
          ),
    categoryAllocations: multiCategory
        ? [
            AccountAmountAllocation(
              accountId: 'category-a',
              amount: Money(minorUnits: totalMinor ~/ 3),
            ),
            AccountAmountAllocation(
              accountId: 'category-b',
              amount: Money(minorUnits: totalMinor - totalMinor ~/ 3),
            ),
          ]
        : singleAllocation(
            accountId: 'category-a',
            amount: Money(minorUnits: totalMinor),
          ),
    originalAmount: Money(minorUnits: totalMinor),
    cadenceUnit: AmortizationCadenceUnit.monthly,
    cadenceInterval: 1,
    firstRecognitionAt: DateTime(2026, 1, 31),
    recognitionCount: recognitionCount,
    initialTransactionId: 'initial',
  );
}
