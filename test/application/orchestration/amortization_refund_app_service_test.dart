import 'package:flutter_test/flutter_test.dart';
import 'package:smartflow/application/orchestration/amortization/command/amortization_command.dart';
import 'package:smartflow/application/orchestration/amortization/command/amortization_plan_app_service.dart';
import 'package:smartflow/application/shared/transaction_runner.dart';
import 'package:smartflow/core/money/money.dart';
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
  Future<void> save(AmortizationPlan plan) async {
    _plans[plan.id] = plan;
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
