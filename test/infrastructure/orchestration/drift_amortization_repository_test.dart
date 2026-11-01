import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:smartflow/core/money/money.dart';
import 'package:smartflow/domain/ledger/valobj/account_amount_allocation.dart';
import 'package:smartflow/domain/orchestration/entity/amortization_plan.dart';
import 'package:smartflow/domain/orchestration/entity/amortization_refund.dart';
import 'package:smartflow/domain/orchestration/valobj/amortization_enums.dart';
import 'package:smartflow/infrastructure/database/app_database.dart';
import 'package:smartflow/infrastructure/orchestration/repository/drift_amortization_repository.dart';

void main() {
  test('round-trips plan, periods and refund allocations', () async {
    final database = AppDatabase(NativeDatabase.memory());
    addTearDown(database.close);
    final repository = DriftAmortizationRepository(database);
    final created = AmortizationPlan.create(
      id: 'plan',
      kind: AmortizationKind.prepaidExpense,
      deferralAccountId: 'prepaid',
      fundingAllocations: const [
        AccountAmountAllocation(
          accountId: 'cash',
          amount: Money(minorUnits: 200000),
        ),
        AccountAmountAllocation(
          accountId: 'bank',
          amount: Money(minorUnits: 100000),
        ),
      ],
      categoryAllocations: const [
        AccountAmountAllocation(
          accountId: 'rent',
          amount: Money(minorUnits: 200000),
        ),
        AccountAmountAllocation(
          accountId: 'utilities',
          amount: Money(minorUnits: 100000),
        ),
      ],
      originalAmount: const Money(minorUnits: 300000),
      cadenceUnit: AmortizationCadenceUnit.monthly,
      cadenceInterval: 1,
      firstRecognitionAt: DateTime(2026, 1, 31),
      recognitionCount: 3,
      initialTransactionId: 'initial',
    );
    final generated = created.withPeriods([
      created.periods.first.posted('recognition-1'),
      ...created.periods.skip(1),
    ]);
    final refunded = generated.withRefund(
      AmortizationRefund(
        id: 'refund',
        planId: generated.id,
        categoryAllocations: const [
          AccountAmountAllocation(
            accountId: 'rent',
            amount: Money(minorUnits: 50000),
          ),
          AccountAmountAllocation(
            accountId: 'utilities',
            amount: Money(minorUnits: 25000),
          ),
        ],
        settlementAllocations: const [
          AccountAmountAllocation(
            accountId: 'cash',
            amount: Money(minorUnits: 50000),
          ),
          AccountAmountAllocation(
            accountId: 'bank',
            amount: Money(minorUnits: 25000),
          ),
        ],
        transferTransactionId: 'refund-transfer',
      ),
    );
    await repository.save(refunded);

    final loaded = await repository.findById('plan');
    expect(loaded, isNotNull);
    expect(loaded!.originalAmount, const Money(minorUnits: 300000));
    expect(loaded.netAmount, const Money(minorUnits: 225000));
    expect(loaded.fundingAllocations, hasLength(2));
    expect(loaded.categoryAllocations, hasLength(2));
    expect(loaded.periods.first.transactionId, 'recognition-1');
    expect(
      loaded.periods.first.categoryAllocations
          .map(
            (allocation) =>
                (allocation.accountId, allocation.amount.minorUnits),
          )
          .toList(),
      [('rent', 50000), ('utilities', 25000)],
    );
    expect(loaded.refunds.single.amount, const Money(minorUnits: 75000));
    expect(
      loaded.refunds.single.settlementAllocations
          .map(
            (allocation) =>
                (allocation.accountId, allocation.amount.minorUnits),
          )
          .toList(),
      [('cash', 50000), ('bank', 25000)],
    );
    expect(
      (await repository.findAll(deferralAccountId: 'prepaid')).single.id,
      'plan',
    );
  });
}
