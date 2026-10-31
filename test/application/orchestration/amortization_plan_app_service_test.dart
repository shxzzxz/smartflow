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
  test(
    'creates a deferred-income transfer with plan ownership and flags',
    () async {
      final repository = _MemoryRepository();
      final ledger = _FakeLedger();
      final service = _service(repository, ledger);

      final planId = await service.createPlan(
        CreateAmortizationPlanCommand(
          kind: AmortizationKind.deferredIncome,
          total: _money(300000),
          fundingAccountId: 'bank',
          deferralAccountId: 'deferred',
          categoryAccountId: 'rent-income',
          firstRecognitionAt: DateTime(2026, 9, 30),
          cadenceUnit: AmortizationCadenceUnit.monthly,
          cadenceInterval: 1,
          recognitionCount: 3,
          occurredAt: DateTime(2026, 9, 1),
          defaultIsExcludedFromStats: true,
          defaultIsExcludedFromBudget: true,
        ),
      );

      final transfer = ledger.transfers.single;
      expect(transfer.fromAccountId, 'deferred');
      expect(transfer.toAccountId, 'bank');
      expect(transfer.ownership.ownerType, orchestrationAmortizationOwnerType);
      expect(transfer.ownership.ownerId, planId);
      expect(transfer.isExcludedFromStats, isTrue);
      expect(transfer.isExcludedFromBudget, isTrue);
      expect((await repository.findById(planId))!.entries, hasLength(3));
    },
  );

  test('catch-up generation is idempotent', () async {
    final repository = _MemoryRepository();
    final ledger = _FakeLedger();
    final service = _service(repository, ledger);
    final planId = await _createPrepaidPlan(service);

    final first = await service.generateDue(DateTime(2026, 2, 28));
    final second = await service.generateDue(DateTime(2026, 2, 28));

    expect(first.generatedCount, 2);
    expect(second.generatedCount, 0);
    expect(ledger.expenses, hasLength(2));
    final plan = (await repository.findById(planId))!;
    expect(plan.recognizedAmount, _money(200000));
    expect(plan.remainingAmount, _money(100000));
  });

  test(
    'late termination removes later generated entries and splits refund',
    () async {
      final repository = _MemoryRepository();
      final ledger = _FakeLedger();
      final service = _service(repository, ledger);
      final planId = await _createPrepaidPlan(service);

      await service.generateDue(DateTime(2026, 3, 31));
      expect(ledger.expenses, hasLength(3));
      expect(ledger.expenseOwnerships.last.ownerId, planId);

      final result = await service.terminate(
        TerminateAmortizationPlanCommand(
          planId: planId,
          terminatedAt: DateTime(2026, 3, 15),
          refundAccountId: 'bank',
          refundAmount: _money(50000),
        ),
      );

      expect(ledger.deletedTransactionIds, ['tx-4']);
      expect(ledger.expenses.last, _money(50000));
      expect(ledger.transfers.last.amount, _money(50000));
      expect(result.recognitionTransactionId, 'tx-5');
      expect(result.refundTransactionId, 'tx-6');

      final plan = (await repository.findById(planId))!;
      expect(plan.status, AmortizationStatus.terminated);
      expect(plan.remainingAmount, _money(0));
      expect(plan.entries.last.isCanceled, isTrue);
    },
  );

  test('reporting defaults can be applied to all plan transactions', () async {
    final repository = _MemoryRepository();
    final ledger = _FakeLedger();
    final service = _service(repository, ledger);
    final planId = await _createPrepaidPlan(service);
    await service.generateDue(DateTime(2026, 1, 31));

    await service.updateReportingDefaults(
      UpdateAmortizationReportingDefaultsCommand(
        planId: planId,
        isExcludedFromStats: true,
        isExcludedFromBudget: true,
        scope: AmortizationReportingScope.all,
      ),
    );

    expect(ledger.reportingUpdates.keys, containsAll(['tx-1', 'tx-2']));
    expect(
      (await repository.findById(planId))!.defaultIsExcludedFromStats,
      isTrue,
    );
  });
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

Future<String> _createPrepaidPlan(AmortizationPlanAppService service) {
  return service.createPlan(
    CreateAmortizationPlanCommand(
      kind: AmortizationKind.prepaidExpense,
      total: _money(300000),
      fundingAccountId: 'bank',
      deferralAccountId: 'prepaid',
      categoryAccountId: 'rent',
      firstRecognitionAt: DateTime(2026, 1, 31),
      cadenceUnit: AmortizationCadenceUnit.monthly,
      cadenceInterval: 1,
      recognitionCount: 3,
      occurredAt: DateTime(2026, 1, 1),
    ),
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
    required this.fromAccountId,
    required this.toAccountId,
    required this.ownership,
    required this.isExcludedFromStats,
    required this.isExcludedFromBudget,
  });

  final Money amount;
  final String fromAccountId;
  final String toAccountId;
  final TransactionOwnership ownership;
  final bool isExcludedFromStats;
  final bool isExcludedFromBudget;
}

class _FakeLedger implements AmortizationLedgerPort {
  int _nextTransaction = 1;
  final transfers = <_TransferRequest>[];
  final expenses = <Money>[];
  final expenseOwnerships = <TransactionOwnership>[];
  final incomes = <Money>[];
  final deletedTransactionIds = <String>[];
  final reportingUpdates =
      <String, ({bool isExcludedFromStats, bool isExcludedFromBudget})>{};

  @override
  Future<void> validatePlanAccounts({
    required AmortizationKind kind,
    required String deferralAccountId,
    required String categoryAccountId,
  }) async {}

  @override
  Future<String> postTransfer({
    required Money amount,
    required String fromAccountId,
    required String toAccountId,
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
        fromAccountId: fromAccountId,
        toAccountId: toAccountId,
        ownership: ownership,
        isExcludedFromStats: isExcludedFromStats,
        isExcludedFromBudget: isExcludedFromBudget,
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
    expenses.add(amount);
    expenseOwnerships.add(ownership);
    return 'tx-${_nextTransaction++}';
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
    incomes.add(amount);
    return 'tx-${_nextTransaction++}';
  }

  @override
  Future<void> deleteTransaction(String transactionId) async {
    deletedTransactionIds.add(transactionId);
  }

  @override
  Future<void> updateReportingFlags({
    required String transactionId,
    required bool isExcludedFromStats,
    required bool isExcludedFromBudget,
  }) async {
    reportingUpdates[transactionId] = (
      isExcludedFromStats: isExcludedFromStats,
      isExcludedFromBudget: isExcludedFromBudget,
    );
  }

  @override
  Future<bool> isOwnedBy({
    required String transactionId,
    required TransactionOwnership ownership,
  }) async => true;
}

Money _money(int minorUnits) => Money(minorUnits: minorUnits);
