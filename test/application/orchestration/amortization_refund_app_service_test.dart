import 'package:flutter_test/flutter_test.dart';
import 'package:smartflow/application/orchestration/amortization/command/amortization_command.dart';
import 'package:smartflow/application/orchestration/amortization/command/amortization_plan_app_service.dart';
import 'package:smartflow/application/shared/transaction_runner.dart';
import 'package:smartflow/core/error/app_exception.dart';
import 'package:smartflow/core/money/money.dart';
import 'package:smartflow/core/patch/patch.dart';
import 'package:smartflow/domain/ledger/valobj/account_amount_allocation.dart';
import 'package:smartflow/domain/ledger/valobj/ledger_enum.dart';
import 'package:smartflow/domain/ledger/valobj/transaction_ownership.dart';
import 'package:smartflow/domain/orchestration/entity/amortization_plan.dart';
import 'package:smartflow/domain/orchestration/port/amortization_ledger_port.dart';
import 'package:smartflow/domain/orchestration/port/amortization_repository.dart';
import 'package:smartflow/domain/orchestration/valobj/amortization_enums.dart';

import '../../helper/sequential_id_generator.dart';

void main() {
  test('refund posts a transfer and rewrites generated periods', () async {
    final repository = _MemoryRepository();
    final ledger = _FakeLedger();
    final service = _service(repository, ledger);
    final planId = await service.createPlan(
      CreateAmortizationPlanCommand(
        kind: AmortizationKind.prepaidExpense,
        total: const Money(minorUnits: 60000),
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
        deferralAccountId: 'deferral',
        recognitionAllocations: const [
          AccountAmountAllocation(
            accountId: 'category-a',
            amount: Money(minorUnits: 20000),
          ),
          AccountAmountAllocation(
            accountId: 'category-b',
            amount: Money(minorUnits: 40000),
          ),
        ],
        firstRecognitionAt: DateTime(2026, 1, 31),
        cadenceUnit: AmortizationCadenceUnit.monthly,
        cadenceInterval: 1,
        recognitionCount: 4,
        occurredAt: DateTime(2026, 1, 1),
      ),
    );
    await service.generateDue(DateTime(2026, 1, 31));
    final generatedTransactionId = ledger.expenses.single.transactionId;

    final result = await service.refund(
      CreateAmortizationRefundCommand(
        planId: planId,
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
        occurredAt: DateTime(2026, 2, 1),
      ),
    );

    expect(result.refundTransactionId, 'tx-3');
    expect(ledger.transfers.last.amount, const Money(minorUnits: 30000));
    expect(
      ledger.transfers.last.outgoingAllocations.single.accountId,
      'deferral',
    );
    expect(ledger.rewrites.single.transactionId, generatedTransactionId);
    expect(ledger.rewrites.single.amount, const Money(minorUnits: 7500));
    expect(
      ledger.rewrites.single.categoryAllocations
          .map(
            (allocation) =>
                (allocation.accountId, allocation.amount.minorUnits),
          )
          .toList(),
      [('category-a', 2500), ('category-b', 5000)],
    );

    final plan = (await repository.findById(planId))!;
    expect(plan.netAmount, const Money(minorUnits: 30000));
    expect(plan.periods.map((period) => period.amount.minorUnits), [
      7500,
      7500,
      7500,
      7500,
    ]);
    expect(plan.periods.first.transactionId, generatedTransactionId);
    expect(plan.refunds.single.amount, const Money(minorUnits: 30000));
  });

  test('termination recognizes residual categories and returns cash', () async {
    final repository = _MemoryRepository();
    final ledger = _FakeLedger();
    final service = _service(repository, ledger);
    final planId = await service.createPlan(
      CreateAmortizationPlanCommand(
        kind: AmortizationKind.prepaidExpense,
        total: const Money(minorUnits: 60000),
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
        deferralAccountId: 'deferral',
        recognitionAllocations: const [
          AccountAmountAllocation(
            accountId: 'category-a',
            amount: Money(minorUnits: 20000),
          ),
          AccountAmountAllocation(
            accountId: 'category-b',
            amount: Money(minorUnits: 40000),
          ),
        ],
        firstRecognitionAt: DateTime(2026, 1, 31),
        cadenceUnit: AmortizationCadenceUnit.monthly,
        cadenceInterval: 1,
        recognitionCount: 4,
        occurredAt: DateTime(2026, 1, 1),
      ),
    );
    await service.refund(
      CreateAmortizationRefundCommand(
        planId: planId,
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
        occurredAt: DateTime(2026, 1, 1),
      ),
    );
    await service.generateDue(DateTime(2026, 2, 28));

    final result = await service.terminate(
      TerminateAmortizationPlanCommand(
        planId: planId,
        terminatedAt: DateTime(2026, 3, 15),
        categoryReturnAllocations: const [
          AccountAmountAllocation(
            accountId: 'category-a',
            amount: Money(minorUnits: 4000),
          ),
          AccountAmountAllocation(
            accountId: 'category-b',
            amount: Money(minorUnits: 5000),
          ),
        ],
        settlementAllocations: const [
          AccountAmountAllocation(
            accountId: 'account-c',
            amount: Money(minorUnits: 1000),
          ),
          AccountAmountAllocation(
            accountId: 'account-d',
            amount: Money(minorUnits: 8000),
          ),
        ],
      ),
    );

    expect(result.recognitionTransactionId, 'tx-5');
    expect(result.returnTransactionId, 'tx-6');
    expect(ledger.expenses.last.amount, const Money(minorUnits: 6000));
    expect(
      ledger.expenses.last.categoryAllocations
          .map(
            (allocation) =>
                (allocation.accountId, allocation.amount.minorUnits),
          )
          .toList(),
      [('category-a', 1000), ('category-b', 5000)],
    );
    expect(ledger.transfers.last.amount, const Money(minorUnits: 9000));
    final plan = (await repository.findById(planId))!;
    expect(plan.status, AmortizationStatus.terminated);
    expect(plan.termination!.returnAmount, const Money(minorUnits: 9000));
    expect(plan.periods.take(2).every((period) => period.isPosted), isTrue);
    expect(plan.periods.skip(2).every((period) => period.isCanceled), isTrue);
  });

  test(
    'termination deletes confirmations generated after its natural day',
    () async {
      final repository = _MemoryRepository();
      final ledger = _FakeLedger();
      final service = _service(repository, ledger);
      final planId = await service.createPlan(
        CreateAmortizationPlanCommand(
          kind: AmortizationKind.prepaidExpense,
          total: _money(120000),
          fundingAllocations: singleAllocation(
            accountId: 'account-c',
            amount: _money(120000),
          ),
          deferralAccountId: 'deferral',
          recognitionAllocations: singleAllocation(
            accountId: 'category-a',
            amount: _money(120000),
          ),
          firstRecognitionAt: DateTime(2026, 1, 31),
          cadenceUnit: AmortizationCadenceUnit.monthly,
          cadenceInterval: 1,
          recognitionCount: 4,
          occurredAt: DateTime(2026, 1, 1),
        ),
      );
      await service.generateDue(DateTime(2026, 4, 30));
      final generated = (await repository.findById(
        planId,
      ))!.periods.map((period) => period.transactionId!).toList();

      await service.terminate(
        TerminateAmortizationPlanCommand(
          planId: planId,
          terminatedAt: DateTime(2026, 3, 15),
          categoryReturnAllocations: singleAllocation(
            accountId: 'category-a',
            amount: _money(20000),
          ),
          settlementAllocations: singleAllocation(
            accountId: 'account-c',
            amount: _money(20000),
          ),
        ),
      );

      expect(ledger.deletedTransactionIds, containsAll(generated.skip(2)));
      expect(ledger.deletedTransactionIds, isNot(contains(generated[0])));
      expect(ledger.deletedTransactionIds, isNot(contains(generated[1])));
    },
  );

  test(
    'full refund deletes confirmations and completes with zero periods',
    () async {
      final repository = _MemoryRepository();
      final ledger = _FakeLedger();
      final service = _service(repository, ledger);
      final planId = await service.createPlan(
        CreateAmortizationPlanCommand(
          kind: AmortizationKind.prepaidExpense,
          total: const Money(minorUnits: 12000),
          fundingAllocations: singleAllocation(
            accountId: 'cash',
            amount: const Money(minorUnits: 12000),
          ),
          deferralAccountId: 'deferral',
          recognitionAllocations: singleAllocation(
            accountId: 'category-a',
            amount: const Money(minorUnits: 12000),
          ),
          firstRecognitionAt: DateTime(2026, 1, 31),
          cadenceUnit: AmortizationCadenceUnit.monthly,
          cadenceInterval: 1,
          recognitionCount: 12,
          occurredAt: DateTime(2026, 1, 1),
        ),
      );
      await service.generateDue(DateTime(2026, 1, 31));
      final generatedTransactionId = ledger.expenses.single.transactionId;

      await service.refund(
        CreateAmortizationRefundCommand(
          planId: planId,
          categoryAllocations: singleAllocation(
            accountId: 'category-a',
            amount: const Money(minorUnits: 12000),
          ),
          settlementAllocations: singleAllocation(
            accountId: 'cash',
            amount: const Money(minorUnits: 12000),
          ),
          occurredAt: DateTime(2026, 2, 1),
        ),
      );

      expect(ledger.deletedTransactionIds, contains(generatedTransactionId));
      final plan = (await repository.findById(planId))!;
      expect(plan.status, AmortizationStatus.completed);
      expect(plan.periods.every((period) => period.isZero), isTrue);
    },
  );

  test('completed plan accepts a backfilled refund', () async {
    final repository = _MemoryRepository();
    final ledger = _FakeLedger();
    final service = _service(repository, ledger);
    final planId = await service.createPlan(
      CreateAmortizationPlanCommand(
        kind: AmortizationKind.prepaidExpense,
        total: _money(30000),
        fundingAllocations: singleAllocation(
          accountId: 'cash',
          amount: _money(30000),
        ),
        deferralAccountId: 'deferral',
        recognitionAllocations: singleAllocation(
          accountId: 'category-a',
          amount: _money(30000),
        ),
        firstRecognitionAt: DateTime(2026, 1, 31),
        cadenceUnit: AmortizationCadenceUnit.monthly,
        cadenceInterval: 1,
        recognitionCount: 3,
        occurredAt: DateTime(2026, 1, 1),
      ),
    );
    await service.generateDue(DateTime(2026, 3, 31));
    expect(
      (await repository.findById(planId))!.status,
      AmortizationStatus.completed,
    );

    await service.refund(
      CreateAmortizationRefundCommand(
        planId: planId,
        categoryAllocations: singleAllocation(
          accountId: 'category-a',
          amount: _money(10000),
        ),
        settlementAllocations: singleAllocation(
          accountId: 'cash',
          amount: _money(10000),
        ),
        occurredAt: DateTime(2026, 4, 1),
      ),
    );

    final plan = (await repository.findById(planId))!;
    expect(plan.refunds.single.amount, _money(10000));
    expect(plan.netAmount, _money(20000));
    expect(plan.status, AmortizationStatus.completed);
    expect(ledger.transfers.last.amount, _money(10000));
  });

  test('completed plan accepts a backdated termination', () async {
    final repository = _MemoryRepository();
    final ledger = _FakeLedger();
    final service = _service(repository, ledger);
    final planId = await service.createPlan(
      CreateAmortizationPlanCommand(
        kind: AmortizationKind.prepaidExpense,
        total: _money(30000),
        fundingAllocations: singleAllocation(
          accountId: 'cash',
          amount: _money(30000),
        ),
        deferralAccountId: 'deferral',
        recognitionAllocations: singleAllocation(
          accountId: 'category-a',
          amount: _money(30000),
        ),
        firstRecognitionAt: DateTime(2026, 1, 31),
        cadenceUnit: AmortizationCadenceUnit.monthly,
        cadenceInterval: 1,
        recognitionCount: 3,
        occurredAt: DateTime(2026, 1, 1),
      ),
    );
    await service.generateDue(DateTime(2026, 3, 31));
    expect(
      (await repository.findById(planId))!.status,
      AmortizationStatus.completed,
    );

    await service.terminate(
      TerminateAmortizationPlanCommand(
        planId: planId,
        terminatedAt: DateTime(2026, 2, 15),
        categoryReturnAllocations: singleAllocation(
          accountId: 'category-a',
          amount: _money(5000),
        ),
        settlementAllocations: singleAllocation(
          accountId: 'cash',
          amount: _money(5000),
        ),
      ),
    );

    final plan = (await repository.findById(planId))!;
    expect(plan.status, AmortizationStatus.terminated);
    expect(plan.termination!.returnAmount, _money(5000));
    expect(ledger.transfers.last.amount, _money(5000));
  });

  test('editing a refund rewrites its transfer and rebases periods', () async {
    final repository = _MemoryRepository();
    final ledger = _FakeLedger();
    final service = _service(repository, ledger);
    final planId = await service.createPlan(
      CreateAmortizationPlanCommand(
        kind: AmortizationKind.prepaidExpense,
        total: const Money(minorUnits: 60000),
        fundingAllocations: singleAllocation(
          accountId: 'account-c',
          amount: const Money(minorUnits: 60000),
        ),
        deferralAccountId: 'deferral',
        recognitionAllocations: const [
          AccountAmountAllocation(
            accountId: 'category-a',
            amount: Money(minorUnits: 20000),
          ),
          AccountAmountAllocation(
            accountId: 'category-b',
            amount: Money(minorUnits: 40000),
          ),
        ],
        firstRecognitionAt: DateTime(2026, 1, 31),
        cadenceUnit: AmortizationCadenceUnit.monthly,
        cadenceInterval: 1,
        recognitionCount: 4,
        occurredAt: DateTime(2026, 1, 1),
      ),
    );
    await service.generateDue(DateTime(2026, 1, 31));
    final refund = await service.refund(
      CreateAmortizationRefundCommand(
        planId: planId,
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
        settlementAllocations: singleAllocation(
          accountId: 'account-c',
          amount: const Money(minorUnits: 30000),
        ),
        occurredAt: DateTime(2026, 2, 1),
      ),
    );
    final plan = (await repository.findById(planId))!;

    await service.editRefund(
      EditAmortizationRefundCommand(
        planId: planId,
        refundId: plan.refunds.single.id,
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
        now: DateTime(2026, 2, 1),
      ),
    );

    final updated = (await repository.findById(planId))!;
    expect(ledger.transferRewrites.single.amount, _money(30000));
    expect(
      ledger.transferRewrites.single.outgoingAllocations.single.accountId,
      'deferral',
    );
    expect(
      ledger.transferRewrites.single.incomingAllocations.single.accountId,
      'account-d',
    );
    expect(
      updated.refunds.single.transferTransactionId,
      refund.refundTransactionId,
    );
    expect(
      updated.periods.first.categoryAllocations.map(
        (allocation) => allocation.accountId,
      ),
      ['category-a', 'category-b'],
    );
  });

  test(
    'configuration change rebuilds schedule from existing refunds and periods',
    () async {
      final repository = _MemoryRepository();
      final ledger = _FakeLedger();
      final service = _service(repository, ledger);
      final planId = await service.createPlan(
        _createPlanCommand(totalMinor: 60000, recognitionCount: 3),
      );
      await service.generateDue(DateTime(2026, 1, 31));
      await service.refund(
        CreateAmortizationRefundCommand(
          planId: planId,
          categoryAllocations: singleAllocation(
            accountId: 'category-a',
            amount: _money(10000),
          ),
          settlementAllocations: singleAllocation(
            accountId: 'account-c',
            amount: _money(10000),
          ),
          occurredAt: DateTime(2026, 2, 1),
        ),
      );

      await service.updateConfiguration(
        UpdateAmortizationConfigurationCommand(
          planId: planId,
          firstRecognitionAt: DateTime(2026, 3, 31),
          cadenceUnit: AmortizationCadenceUnit.monthly,
          cadenceInterval: 2,
          recognitionCount: 2,
          now: DateTime(2026, 3, 1),
        ),
      );

      final plan = (await repository.findById(planId))!;
      expect(plan.kind, AmortizationKind.prepaidExpense);
      expect(plan.recognitionCount, 2);
      expect(plan.periods, hasLength(2));
      expect(plan.periods.map((period) => period.amount.minorUnits), [
        25000,
        25000,
      ]);
      expect(plan.periods.first.transactionId, isNotNull);
      expect(ledger.transferRewrites, isEmpty);
      expect(plan.refunds.single.amount, _money(10000));
    },
  );

  test('deleting a refund restores net amount and the full schedule', () async {
    final repository = _MemoryRepository();
    final ledger = _FakeLedger();
    final service = _service(repository, ledger);
    final planId = await service.createPlan(
      _createPlanCommand(totalMinor: 60000, recognitionCount: 3),
    );
    final refund = await service.refund(
      CreateAmortizationRefundCommand(
        planId: planId,
        categoryAllocations: singleAllocation(
          accountId: 'category-a',
          amount: _money(10000),
        ),
        settlementAllocations: singleAllocation(
          accountId: 'account-c',
          amount: _money(10000),
        ),
        occurredAt: DateTime(2026, 2, 1),
      ),
    );

    await service.deleteRefund(
      DeleteAmortizationRefundCommand(
        planId: planId,
        refundId: (await repository.findById(planId))!.refunds.single.id,
        now: DateTime(2026, 2, 1),
      ),
    );

    final plan = (await repository.findById(planId))!;
    expect(plan.refunds, isEmpty);
    expect(plan.netAmount, _money(60000));
    expect(plan.periods.map((period) => period.amount.minorUnits), [
      20000,
      20000,
      20000,
    ]);
    expect(ledger.deletedTransactionIds, [refund.refundTransactionId]);
  });

  test('editing termination replaces both termination transactions', () async {
    final repository = _MemoryRepository();
    final ledger = _FakeLedger();
    final service = _service(repository, ledger);
    final planId = await service.createPlan(
      _createPlanCommand(totalMinor: 60000, recognitionCount: 3),
    );
    final original = await service.terminate(
      TerminateAmortizationPlanCommand(
        planId: planId,
        terminatedAt: DateTime(2026, 1, 15),
        categoryReturnAllocations: singleAllocation(
          accountId: 'category-a',
          amount: _money(10000),
        ),
        settlementAllocations: singleAllocation(
          accountId: 'account-c',
          amount: _money(10000),
        ),
      ),
    );
    final terminationId = (await repository.findById(planId))!.termination!.id;

    final updated = await service.editTermination(
      EditAmortizationTerminationCommand(
        planId: planId,
        terminationId: terminationId,
        terminatedAt: DateTime(2026, 1, 16),
        categoryReturnAllocations: singleAllocation(
          accountId: 'category-a',
          amount: _money(20000),
        ),
        settlementAllocations: singleAllocation(
          accountId: 'account-c',
          amount: _money(20000),
        ),
      ),
    );

    final plan = (await repository.findById(planId))!;
    expect(plan.termination!.returnAmount, _money(20000));
    expect(ledger.deletedTransactionIds, [
      original.recognitionTransactionId,
      original.returnTransactionId,
    ]);
    expect(updated.returnTransactionId, isNot(original.returnTransactionId));
  });

  test('termination commands reject a different activity item', () async {
    final repository = _MemoryRepository();
    final ledger = _FakeLedger();
    final service = _service(repository, ledger);
    final planId = await service.createPlan(
      _createPlanCommand(totalMinor: 60000, recognitionCount: 3),
    );
    await service.terminate(
      TerminateAmortizationPlanCommand(
        planId: planId,
        terminatedAt: DateTime(2026, 1, 15),
        categoryReturnAllocations: singleAllocation(
          accountId: 'category-a',
          amount: _money(10000),
        ),
        settlementAllocations: singleAllocation(
          accountId: 'account-c',
          amount: _money(10000),
        ),
      ),
    );

    await expectLater(
      service.deleteTermination(
        DeleteAmortizationTerminationCommand(
          planId: planId,
          terminationId: 'another-termination',
          now: DateTime(2026, 2, 1),
        ),
      ),
      throwsA(isA<BusinessException>()),
    );

    expect((await repository.findById(planId))!.termination, isNotNull);
    expect(ledger.deletedTransactionIds, isEmpty);
  });

  test(
    'deleting termination reopens canceled periods and catches up dues',
    () async {
      final repository = _MemoryRepository();
      final ledger = _FakeLedger();
      final service = _service(repository, ledger);
      final planId = await service.createPlan(
        CreateAmortizationPlanCommand(
          kind: AmortizationKind.prepaidExpense,
          total: _money(300000),
          fundingAllocations: singleAllocation(
            accountId: 'account-c',
            amount: _money(300000),
          ),
          deferralAccountId: 'deferral',
          recognitionAllocations: singleAllocation(
            accountId: 'category-a',
            amount: _money(300000),
          ),
          firstRecognitionAt: DateTime(2026, 1, 31),
          cadenceUnit: AmortizationCadenceUnit.monthly,
          cadenceInterval: 1,
          recognitionCount: 3,
          occurredAt: DateTime(2026, 1, 1),
        ),
      );
      final result = await service.terminate(
        TerminateAmortizationPlanCommand(
          planId: planId,
          terminatedAt: DateTime(2026, 3, 15),
          categoryReturnAllocations: singleAllocation(
            accountId: 'category-a',
            amount: _money(50000),
          ),
          settlementAllocations: singleAllocation(
            accountId: 'account-c',
            amount: _money(50000),
          ),
        ),
      );
      final terminationId = (await repository.findById(
        planId,
      ))!.termination!.id;

      final generated = await service.deleteTermination(
        DeleteAmortizationTerminationCommand(
          planId: planId,
          terminationId: terminationId,
          now: DateTime(2026, 5, 1),
        ),
      );

      final reopened = (await repository.findById(planId))!;
      expect(generated.generatedCount, 1);
      expect(
        ledger.deletedTransactionIds,
        contains(result.recognitionTransactionId),
      );
      expect(
        ledger.deletedTransactionIds,
        contains(result.returnTransactionId),
      );
      expect(reopened.termination, isNull);
      expect(reopened.periods.map((period) => period.status).toList(), [
        AmortizationPeriodStatus.posted,
        AmortizationPeriodStatus.posted,
        AmortizationPeriodStatus.posted,
      ]);
      expect(reopened.status, AmortizationStatus.completed);
      expect(reopened.periods.every((period) => period.isPosted), isTrue);
    },
  );

  test(
    'deleting a plan removes every owner transaction and its projection',
    () async {
      final repository = _MemoryRepository();
      final ledger = _FakeLedger();
      final service = _service(repository, ledger);
      final planId = await service.createPlan(
        CreateAmortizationPlanCommand(
          kind: AmortizationKind.prepaidExpense,
          total: _money(120000),
          fundingAllocations: singleAllocation(
            accountId: 'account-c',
            amount: _money(120000),
          ),
          deferralAccountId: 'deferral',
          recognitionAllocations: singleAllocation(
            accountId: 'category-a',
            amount: _money(120000),
          ),
          firstRecognitionAt: DateTime(2026, 1, 31),
          cadenceUnit: AmortizationCadenceUnit.monthly,
          cadenceInterval: 1,
          recognitionCount: 3,
          occurredAt: DateTime(2026, 1, 1),
        ),
      );
      await service.generateDue(DateTime(2026, 1, 31));
      final plan = (await repository.findById(planId))!;

      await service.deletePlan(DeleteAmortizationPlanCommand(planId: planId));

      expect(await repository.findById(planId), isNull);
      expect(
        ledger.deletedTransactionIds,
        containsAll([
          plan.initialTransactionId,
          plan.periods.first.transactionId!,
        ]),
      );
    },
  );
}

AmortizationPlanAppService _service(
  _MemoryRepository repository,
  _FakeLedger ledger,
) {
  return AmortizationPlanAppServiceImpl(
    repository: repository,
    ledger: ledger,
    transactionRunner: const _Runner(),
    idGenerator: SequentialIdGenerator(prefix: 'plan'),
  );
}

Money _money(int minorUnits) => Money(minorUnits: minorUnits);

CreateAmortizationPlanCommand _createPlanCommand({
  required int totalMinor,
  required int recognitionCount,
}) {
  return CreateAmortizationPlanCommand(
    kind: AmortizationKind.prepaidExpense,
    total: _money(totalMinor),
    fundingAllocations: singleAllocation(
      accountId: 'account-c',
      amount: _money(totalMinor),
    ),
    deferralAccountId: 'deferral',
    recognitionAllocations: singleAllocation(
      accountId: 'category-a',
      amount: _money(totalMinor),
    ),
    firstRecognitionAt: DateTime(2026, 1, 31),
    cadenceUnit: AmortizationCadenceUnit.monthly,
    cadenceInterval: 1,
    recognitionCount: recognitionCount,
    occurredAt: DateTime(2026, 1, 1),
  );
}

class _Runner implements TransactionRunner {
  const _Runner();

  @override
  Future<T> run<T>(Future<T> Function() body) => body();
}

class _MemoryRepository implements AmortizationRepository {
  final _plans = <String, AmortizationPlan>{};

  @override
  Future<AmortizationPlan?> findById(String id) async => _plans[id];

  @override
  Future<List<AmortizationPlan>> findByIds(Set<String> ids) async {
    return [for (final id in ids) ?_plans[id]];
  }

  @override
  Future<List<AmortizationPlan>> findAll({String? deferralAccountId}) async {
    return [
      for (final plan in _plans.values)
        if (deferralAccountId == null ||
            plan.deferralAccountId == deferralAccountId)
          plan,
    ];
  }

  @override
  Stream<List<AmortizationPlan>> watchAll({String? deferralAccountId}) {
    return Stream.fromFuture(findAll(deferralAccountId: deferralAccountId));
  }

  @override
  Stream<List<AmortizationPlan>> watchByIds(Set<String> ids) => watchAll().map(
    (plans) => [
      for (final plan in plans)
        if (ids.contains(plan.id)) plan,
    ],
  );

  @override
  Future<void> save(AmortizationPlan plan) async {
    _plans[plan.id] = plan;
  }

  @override
  Future<void> deleteById(String id) async {
    _plans.remove(id);
  }
}

class _TransferRequest {
  const _TransferRequest({
    required this.amount,
    required this.outgoingAllocations,
    required this.incomingAllocations,
    required this.ownership,
  });

  final Money amount;
  final List<AccountAmountAllocation> outgoingAllocations;
  final List<AccountAmountAllocation> incomingAllocations;
  final TransactionOwnership ownership;
}

class _RecognitionRequest {
  const _RecognitionRequest({
    required this.transactionId,
    required this.amount,
    required this.categoryAllocations,
  });

  final String transactionId;
  final Money amount;
  final List<AccountAmountAllocation> categoryAllocations;
}

class _FakeLedger implements AmortizationLedgerPort {
  int _nextTransaction = 1;
  final transfers = <_TransferRequest>[];
  final transferRewrites = <_TransferRequest>[];
  final expenses = <_RecognitionRequest>[];
  final incomes = <_RecognitionRequest>[];
  final rewrites = <_RecognitionRequest>[];
  final deletedTransactionIds = <String>[];

  @override
  Future<void> validatePlanAccounts({
    required AmortizationKind kind,
    required String deferralAccountId,
    required Iterable<String> categoryAccountIds,
  }) async {}

  @override
  Future<void> validateRefundAccounts({
    required AmortizationKind kind,
    required Iterable<String> categoryAccountIds,
    required Iterable<String> settlementAccountIds,
  }) async {}

  @override
  Future<String> postTransfer({
    required Money amount,
    required List<AccountAmountAllocation> outgoingAllocations,
    required List<AccountAmountAllocation> incomingAllocations,
    required DateTime occurredAt,
    DateTime? postedAt,
    Money? feeAmount,
    String? counterpartyId,
    String? note,
    required TransactionOwnership ownership,
    required bool isExcludedFromStats,
    required bool isExcludedFromBudget,
    SourceKind sourceKind = SourceKind.manual,
    Set<String> tagIds = const {},
  }) async {
    transfers.add(
      _TransferRequest(
        amount: amount,
        outgoingAllocations: outgoingAllocations,
        incomingAllocations: incomingAllocations,
        ownership: ownership,
      ),
    );
    return 'tx-${_nextTransaction++}';
  }

  @override
  Future<String> postExpense({
    required Money amount,
    required List<AccountAmountAllocation> categoryAllocations,
    required List<AccountAmountAllocation> settlementAllocations,
    required DateTime occurredAt,
    String? counterpartyId,
    String? note,
    required TransactionOwnership ownership,
    required bool isExcludedFromStats,
    required bool isExcludedFromBudget,
    SourceKind sourceKind = SourceKind.auto,
    Set<String> tagIds = const {},
  }) async {
    final transactionId = 'tx-${_nextTransaction++}';
    expenses.add(
      _RecognitionRequest(
        transactionId: transactionId,
        amount: amount,
        categoryAllocations: categoryAllocations,
      ),
    );
    return transactionId;
  }

  @override
  Future<String> postIncome({
    required Money amount,
    required List<AccountAmountAllocation> categoryAllocations,
    required List<AccountAmountAllocation> settlementAllocations,
    required DateTime occurredAt,
    String? counterpartyId,
    String? note,
    required TransactionOwnership ownership,
    required bool isExcludedFromStats,
    required bool isExcludedFromBudget,
    SourceKind sourceKind = SourceKind.auto,
    Set<String> tagIds = const {},
  }) async {
    final transactionId = 'tx-${_nextTransaction++}';
    incomes.add(
      _RecognitionRequest(
        transactionId: transactionId,
        amount: amount,
        categoryAllocations: categoryAllocations,
      ),
    );
    return transactionId;
  }

  @override
  Future<void> rewriteTransfer({
    required String transactionId,
    required Money amount,
    required List<AccountAmountAllocation> outgoingAllocations,
    required List<AccountAmountAllocation> incomingAllocations,
    DateTime? occurredAt,
    Money? feeAmount,
    Patch<String?>? note,
    Patch<String?>? counterpartyId,
    Set<String>? tagIds,
    bool? isExcludedFromStats,
    bool? isExcludedFromBudget,
  }) async {
    transferRewrites.add(
      _TransferRequest(
        amount: amount,
        outgoingAllocations: outgoingAllocations,
        incomingAllocations: incomingAllocations,
        ownership: const TransactionOwnership(
          ownerType: orchestrationAmortizationOwnerType,
          ownerId: 'rewritten',
        ),
      ),
    );
  }

  @override
  Future<void> rewriteExpense({
    required String transactionId,
    required Money amount,
    required List<AccountAmountAllocation> categoryAllocations,
    required List<AccountAmountAllocation> settlementAllocations,
  }) async {
    rewrites.add(
      _RecognitionRequest(
        transactionId: transactionId,
        amount: amount,
        categoryAllocations: categoryAllocations,
      ),
    );
  }

  @override
  Future<void> rewriteIncome({
    required String transactionId,
    required Money amount,
    required List<AccountAmountAllocation> categoryAllocations,
    required List<AccountAmountAllocation> settlementAllocations,
  }) async {
    rewrites.add(
      _RecognitionRequest(
        transactionId: transactionId,
        amount: amount,
        categoryAllocations: categoryAllocations,
      ),
    );
  }

  @override
  Future<void> deleteTransaction(String transactionId) async {
    deletedTransactionIds.add(transactionId);
  }
}
