import 'package:smartflow/core/money/money.dart';
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
}

AmortizationPlan _plan() {
  return AmortizationPlan.create(
    id: 'plan',
    kind: AmortizationKind.prepaidExpense,
    deferralAccountId: 'prepaid',
    categoryAccountId: 'rent',
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
