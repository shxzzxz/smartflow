import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:smartflow/core/money/money.dart';
import 'package:smartflow/domain/orchestration/entity/amortization_plan.dart';
import 'package:smartflow/domain/orchestration/valobj/amortization_enums.dart';
import 'package:smartflow/infrastructure/database/app_database.dart';
import 'package:smartflow/infrastructure/orchestration/repository/drift_amortization_repository.dart';

void main() {
  test('persists plan, generated entry and termination facts', () async {
    final database = AppDatabase(NativeDatabase.memory());
    addTearDown(database.close);
    final repository = DriftAmortizationRepository(database);
    final plan = AmortizationPlan.create(
      id: 'plan',
      kind: AmortizationKind.prepaidExpense,
      deferralAccountId: 'prepaid',
      categoryAccountId: 'rent',
      total: const Money(minorUnits: 300000),
      cadenceUnit: AmortizationCadenceUnit.monthly,
      cadenceInterval: 1,
      firstRecognitionAt: DateTime(2026, 1, 31),
      recognitionCount: 3,
      defaultIsExcludedFromStats: true,
      defaultIsExcludedFromBudget: false,
      initialTransactionId: 'initial',
    );
    final generated = plan.withEntries([
      plan.entries.first.generated('recognition-1'),
      ...plan.entries.skip(1),
    ]);
    await repository.save(generated);

    final loaded = await repository.findById('plan');
    expect(loaded, isNotNull);
    expect(loaded!.entries.first.transactionId, 'recognition-1');
    expect(loaded.defaultIsExcludedFromStats, isTrue);
    expect(loaded.remainingAmount, const Money(minorUnits: 200000));

    final terminated = loaded.terminated(
      terminatedAt: DateTime(2026, 2, 15),
      refundAmount: const Money(minorUnits: 150000),
      entries: [
        ...loaded.entries.take(1),
        loaded.entries[1].canceled(DateTime(2026, 2, 15)),
        loaded.entries[2].canceled(DateTime(2026, 2, 15)),
      ],
      refundTransactionId: 'refund',
    );
    await repository.save(terminated);

    final reread = await repository.findById('plan');
    expect(reread!.status, AmortizationStatus.terminated);
    expect(reread.refundTransactionId, 'refund');
    expect(reread.refundAmount, const Money(minorUnits: 150000));
    expect(
      (await repository.findAll(deferralAccountId: 'prepaid')).single.id,
      'plan',
    );
  });
}
