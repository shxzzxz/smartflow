import 'package:smartflow/core/money/money.dart';
import 'package:smartflow/domain/ledger/valobj/account_amount_allocation.dart';
import 'package:smartflow/domain/orchestration/entity/amortization_plan.dart';
import 'package:smartflow/domain/orchestration/valobj/amortization_enums.dart';
import 'package:test/test.dart';

void main() {
  test('plan derives recognition, remaining balance and completion', () {
    final plan = _plan();
    final first = plan.entries.first;
    final next = plan.withEntries([
      first.generated('transaction-1'),
      ...plan.entries.skip(1),
    ]);

    expect(next.recognizedAmount, const Money(minorUnits: 100000));
    expect(next.remainingAmount, const Money(minorUnits: 200000));
    expect(next.status, AmortizationStatus.active);
    expect(next.dueEntries(DateTime(2026, 2, 28)).single.id, 'plan:2');

    final completed = next.withEntries([
      for (final entry in next.entries)
        entry.generated('transaction-${entry.sequenceNo}'),
    ]);
    expect(completed.status, AmortizationStatus.completed);
  });

  test('plan rejects mismatched entries', () {
    final plan = _plan();
    expect(
      () => plan.withEntries(plan.entries.take(2)),
      throwsA(isA<Exception>()),
    );
  });

  test('plan materializes category allocations onto every entry', () {
    final plan = _plan(
      recognitionAllocations: const [
        AccountAmountAllocation(
          accountId: 'rent',
          amount: Money(minorUnits: 200000),
        ),
        AccountAmountAllocation(
          accountId: 'utilities',
          amount: Money(minorUnits: 100000),
        ),
      ],
    );

    for (final entry in plan.entries) {
      expect(
        entry.categoryAllocations.fold(
          Money.zero(),
          (total, allocation) => total + allocation.amount,
        ),
        entry.amount,
      );
    }
    expect(
      plan.entries
          .expand((entry) => entry.categoryAllocations)
          .where((allocation) => allocation.accountId == 'rent')
          .fold(Money.zero(), (total, allocation) => total + allocation.amount),
      const Money(minorUnits: 200000),
    );
  });

  test('small category allocations remain valid when an entry has no line', () {
    final plan = AmortizationPlan.create(
      id: 'small',
      kind: AmortizationKind.prepaidExpense,
      deferralAccountId: 'prepaid',
      recognitionAllocations: const [
        AccountAmountAllocation(
          accountId: 'tiny',
          amount: Money(minorUnits: 1),
        ),
        AccountAmountAllocation(
          accountId: 'main',
          amount: Money(minorUnits: 100),
        ),
      ],
      total: const Money(minorUnits: 101),
      cadenceUnit: AmortizationCadenceUnit.monthly,
      cadenceInterval: 1,
      firstRecognitionAt: DateTime(2026, 1, 31),
      recognitionCount: 2,
      defaultIsExcludedFromStats: false,
      defaultIsExcludedFromBudget: false,
      initialTransactionId: 'initial',
    );

    expect(plan.entries.first.categoryAllocations.single.accountId, 'main');
    expect(
      plan.entries.last.categoryAllocations.map(
        (allocation) => allocation.accountId,
      ),
      contains('tiny'),
    );
  });
}

AmortizationPlan _plan({
  List<AccountAmountAllocation> recognitionAllocations = const [
    AccountAmountAllocation(
      accountId: 'rent',
      amount: Money(minorUnits: 300000),
    ),
  ],
}) {
  return AmortizationPlan.create(
    id: 'plan',
    kind: AmortizationKind.prepaidExpense,
    deferralAccountId: 'prepaid',
    recognitionAllocations: recognitionAllocations,
    total: const Money(minorUnits: 300000),
    cadenceUnit: AmortizationCadenceUnit.monthly,
    cadenceInterval: 1,
    firstRecognitionAt: DateTime(2026, 1, 31),
    recognitionCount: 3,
    defaultIsExcludedFromStats: false,
    defaultIsExcludedFromBudget: false,
    initialTransactionId: 'initial',
  );
}
