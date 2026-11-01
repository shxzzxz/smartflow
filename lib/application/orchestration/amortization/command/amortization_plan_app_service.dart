import '../../../../core/error/app_exception.dart';
import '../../../../core/id/id_generator.dart';
import '../../../../core/money/money.dart';
import '../../../../domain/ledger/valobj/account_amount_allocation.dart';
import '../../../../domain/ledger/valobj/transaction_ownership.dart';
import '../../../../domain/orchestration/entity/amortization_entry.dart';
import '../../../../domain/orchestration/entity/amortization_plan.dart';
import '../../../../domain/orchestration/port/amortization_ledger_port.dart';
import '../../../../domain/orchestration/port/amortization_repository.dart';
import '../../../../domain/orchestration/valobj/amortization_enums.dart';
import '../../../../domain/orchestration/valobj/amortization_error_code.dart';
import '../../../shared/transaction_runner.dart';
import 'amortization_command.dart';

class AmortizationGenerationResult {
  const AmortizationGenerationResult({required this.generatedCount});

  final int generatedCount;
}

class AmortizationTerminationResult {
  const AmortizationTerminationResult({
    required this.recognitionTransactionId,
    required this.refundTransactionId,
  });

  final String? recognitionTransactionId;
  final String? refundTransactionId;
}

abstract interface class AmortizationPlanAppService {
  Future<String> createPlan(CreateAmortizationPlanCommand command);

  Future<AmortizationGenerationResult> generateDue(DateTime now);

  Future<AmortizationTerminationResult> terminate(
    TerminateAmortizationPlanCommand command,
  );

  Future<void> updateReportingDefaults(
    UpdateAmortizationReportingDefaultsCommand command,
  );

  Future<void> updateTransactionReporting(
    UpdateAmortizationTransactionReportingCommand command,
  );
}

class AmortizationPlanAppServiceImpl implements AmortizationPlanAppService {
  const AmortizationPlanAppServiceImpl({
    required AmortizationRepository repository,
    required AmortizationLedgerPort ledger,
    required TransactionRunner transactionRunner,
    required IdGenerator idGenerator,
  }) : _repository = repository,
       _ledger = ledger,
       _transactionRunner = transactionRunner,
       _idGenerator = idGenerator;

  final AmortizationRepository _repository;
  final AmortizationLedgerPort _ledger;
  final TransactionRunner _transactionRunner;
  final IdGenerator _idGenerator;

  @override
  Future<String> createPlan(CreateAmortizationPlanCommand command) {
    return _transactionRunner.run(() async {
      await _ledger.validatePlanAccounts(
        kind: command.kind,
        deferralAccountId: command.deferralAccountId,
        categoryAccountIds: command.recognitionAllocations.map(
          (allocation) => allocation.accountId,
        ),
      );
      if (command.kind == AmortizationKind.deferredIncome &&
          command.feeAmount != null &&
          command.feeAmount!.minorUnits > 0) {
        throw _error(
          AmortizationErrorCode.invalidCommand,
          'Deferred-income collection fees must be recorded separately.',
        );
      }
      final planId = _idGenerator.newId();
      final ownership = TransactionOwnership(
        ownerType: orchestrationAmortizationOwnerType,
        ownerId: planId,
      );
      final deferralAllocation = singleAllocation(
        accountId: command.deferralAccountId,
        amount: command.total,
      );
      final outgoingAllocations = switch (command.kind) {
        AmortizationKind.prepaidExpense => command.fundingAllocations,
        AmortizationKind.deferredIncome => deferralAllocation,
      };
      final incomingAllocations = switch (command.kind) {
        AmortizationKind.prepaidExpense => deferralAllocation,
        AmortizationKind.deferredIncome => command.fundingAllocations,
      };
      final initialTransactionId = await _ledger.postTransfer(
        amount: command.total,
        outgoingAllocations: outgoingAllocations,
        incomingAllocations: incomingAllocations,
        occurredAt: command.occurredAt,
        feeAmount: command.feeAmount,
        counterpartyId: command.counterpartyId,
        note: command.note,
        ownership: ownership,
        isExcludedFromStats: command.defaultIsExcludedFromStats,
        isExcludedFromBudget: command.defaultIsExcludedFromBudget,
        tagIds: command.tagIds,
      );
      final plan = AmortizationPlan.create(
        id: planId,
        kind: command.kind,
        deferralAccountId: command.deferralAccountId,
        recognitionAllocations: command.recognitionAllocations,
        total: command.total,
        cadenceUnit: command.cadenceUnit,
        cadenceInterval: command.cadenceInterval,
        firstRecognitionAt: command.firstRecognitionAt,
        recognitionCount: command.recognitionCount,
        defaultIsExcludedFromStats: command.defaultIsExcludedFromStats,
        defaultIsExcludedFromBudget: command.defaultIsExcludedFromBudget,
        initialTransactionId: initialTransactionId,
        counterpartyId: command.counterpartyId,
        note: command.note,
      );
      await _repository.save(plan);
      return planId;
    });
  }

  @override
  Future<AmortizationGenerationResult> generateDue(DateTime now) {
    return _transactionRunner.run(() async {
      final plans = await _repository.findAll();
      var generatedCount = 0;
      for (final plan in plans) {
        if (plan.status == AmortizationStatus.terminated) continue;
        final dueEntries = plan.dueEntries(now);
        if (dueEntries.isEmpty) continue;
        final generated = await _generateEntries(plan, entries: dueEntries);
        await _repository.save(plan.withEntries(generated.entries));
        generatedCount += generated.generatedCount;
      }
      return AmortizationGenerationResult(generatedCount: generatedCount);
    });
  }

  @override
  Future<AmortizationTerminationResult> terminate(
    TerminateAmortizationPlanCommand command,
  ) {
    return _transactionRunner.run(() async {
      final plan = await _requirePlan(command.planId);
      if (plan.terminatedAt != null) {
        throw _error(
          AmortizationErrorCode.planTerminated,
          'Amortization plan is already terminated.',
        );
      }
      if (command.refundAmount.minorUnits < 0) {
        throw _error(
          AmortizationErrorCode.invalidCommand,
          'Refund amount cannot be negative.',
        );
      }

      final cutoff = _dateOnly(command.terminatedAt);
      final dueBeforeTermination = [
        for (final entry in plan.entries)
          if (!entry.isGenerated &&
              !entry.isCanceled &&
              !_dateOnly(entry.dueAt).isAfter(cutoff))
            entry,
      ];
      var normalized = await _generateEntries(
        plan,
        entries: dueBeforeTermination,
      );

      for (final entry in normalized.entries) {
        if (entry.transactionId == null || entry.isCanceled) continue;
        if (_dateOnly(entry.dueAt).isAfter(cutoff)) {
          await _ledger.deleteTransaction(entry.transactionId!);
        }
      }
      normalized = (
        entries: [
          for (final entry in normalized.entries)
            if (_dateOnly(entry.dueAt).isAfter(cutoff))
              entry.canceled(command.terminatedAt)
            else
              entry,
        ],
        generatedCount: normalized.generatedCount,
      );

      final beforeTermination = plan.withEntries(normalized.entries);
      final remaining = beforeTermination.remainingAmount;
      if (command.refundAmount.minorUnits > remaining.minorUnits) {
        throw _error(
          AmortizationErrorCode.refundExceedsRemaining,
          'Refund cannot exceed the plan remaining balance.',
        );
      }
      final recognitionAmount = remaining - command.refundAmount;
      final recognitionAllocations =
          command.recognitionCategoryAccountId == null
          ? _proportionalAllocations(
              allocations: beforeTermination.remainingCategoryAllocations,
              amount: recognitionAmount,
            )
          : singleAllocation(
              accountId: command.recognitionCategoryAccountId!,
              amount: recognitionAmount,
            );
      final recognitionTransactionId = recognitionAmount.minorUnits > 0
          ? await _postRecognition(
              plan: plan,
              amount: recognitionAmount,
              categoryAllocations: recognitionAllocations,
              occurredAt: command.terminatedAt,
              note: command.note ?? plan.note,
            )
          : null;
      final refundTransactionId = command.refundAmount.minorUnits > 0
          ? await _postTransfer(
              plan: plan,
              amount: command.refundAmount,
              occurredAt: command.terminatedAt,
              accountId: command.refundAccountId,
              fromDeferralAccount: plan.kind == AmortizationKind.prepaidExpense,
              feeAmount: command.refundFeeAmount,
              note: command.note ?? plan.note,
            )
          : null;

      final terminated = beforeTermination.terminated(
        terminatedAt: command.terminatedAt,
        refundAmount: command.refundAmount,
        entries: normalized.entries,
        recognitionTransactionId: recognitionTransactionId,
        refundTransactionId: refundTransactionId,
      );
      await _repository.save(terminated);
      return AmortizationTerminationResult(
        recognitionTransactionId: recognitionTransactionId,
        refundTransactionId: refundTransactionId,
      );
    });
  }

  @override
  Future<void> updateReportingDefaults(
    UpdateAmortizationReportingDefaultsCommand command,
  ) {
    return _transactionRunner.run(() async {
      final plan = await _requirePlan(command.planId);
      final updated = plan.withDefaults(
        isExcludedFromStats: command.isExcludedFromStats,
        isExcludedFromBudget: command.isExcludedFromBudget,
      );
      await _repository.save(updated);
      if (command.scope == AmortizationReportingScope.all) {
        for (final transactionId in _transactionIds(updated)) {
          await _ledger.updateReportingFlags(
            transactionId: transactionId,
            isExcludedFromStats: command.isExcludedFromStats,
            isExcludedFromBudget: command.isExcludedFromBudget,
          );
        }
      }
    });
  }

  @override
  Future<void> updateTransactionReporting(
    UpdateAmortizationTransactionReportingCommand command,
  ) async {
    final plan = await _requirePlan(command.planId);
    final ownership = TransactionOwnership(
      ownerType: orchestrationAmortizationOwnerType,
      ownerId: plan.id,
    );
    if (!_transactionIds(plan).contains(command.transactionId)) {
      throw _error(
        AmortizationErrorCode.invalidCommand,
        'Transaction does not belong to this amortization plan.',
      );
    }
    if (!await _ledger.isOwnedBy(
      transactionId: command.transactionId,
      ownership: ownership,
    )) {
      throw _error(
        AmortizationErrorCode.invalidCommand,
        'Transaction ownership does not match this amortization plan.',
      );
    }
    await _ledger.updateReportingFlags(
      transactionId: command.transactionId,
      isExcludedFromStats: command.isExcludedFromStats,
      isExcludedFromBudget: command.isExcludedFromBudget,
    );
  }

  Future<({List<AmortizationEntry> entries, int generatedCount})>
  _generateEntries(
    AmortizationPlan plan, {
    required Iterable<AmortizationEntry> entries,
  }) async {
    final generatedBySequence = <int, String>{};
    for (final entry in entries) {
      generatedBySequence[entry.sequenceNo] = await _postRecognition(
        plan: plan,
        amount: entry.amount,
        categoryAllocations: entry.categoryAllocations,
        occurredAt: entry.dueAt,
        note: plan.note,
      );
    }
    return (
      entries: [
        for (final entry in plan.entries)
          if (generatedBySequence[entry.sequenceNo] case final transactionId?)
            entry.generated(transactionId)
          else
            entry,
      ],
      generatedCount: generatedBySequence.length,
    );
  }

  Future<String> _postRecognition({
    required AmortizationPlan plan,
    required Money amount,
    required List<AccountAmountAllocation> categoryAllocations,
    required DateTime occurredAt,
    String? note,
  }) {
    final ownership = TransactionOwnership(
      ownerType: orchestrationAmortizationOwnerType,
      ownerId: plan.id,
    );
    final settlement = singleAllocation(
      accountId: plan.deferralAccountId,
      amount: amount,
    );
    return switch (plan.kind) {
      AmortizationKind.prepaidExpense => _ledger.postExpense(
        amount: amount,
        categoryAllocations: categoryAllocations,
        settlementAllocations: settlement,
        occurredAt: occurredAt,
        counterpartyId: plan.counterpartyId,
        note: note,
        ownership: ownership,
        isExcludedFromStats: plan.defaultIsExcludedFromStats,
        isExcludedFromBudget: plan.defaultIsExcludedFromBudget,
      ),
      AmortizationKind.deferredIncome => _ledger.postIncome(
        amount: amount,
        categoryAllocations: categoryAllocations,
        settlementAllocations: settlement,
        occurredAt: occurredAt,
        counterpartyId: plan.counterpartyId,
        note: note,
        ownership: ownership,
        isExcludedFromStats: plan.defaultIsExcludedFromStats,
        isExcludedFromBudget: plan.defaultIsExcludedFromBudget,
      ),
    };
  }

  Future<String> _postTransfer({
    required AmortizationPlan plan,
    required Money amount,
    required DateTime occurredAt,
    required String accountId,
    required bool fromDeferralAccount,
    Money? feeAmount,
    String? note,
  }) {
    return _ledger.postTransfer(
      amount: amount,
      outgoingAllocations: singleAllocation(
        accountId: fromDeferralAccount ? plan.deferralAccountId : accountId,
        amount: amount,
      ),
      incomingAllocations: singleAllocation(
        accountId: fromDeferralAccount ? accountId : plan.deferralAccountId,
        amount: amount,
      ),
      occurredAt: occurredAt,
      feeAmount: feeAmount,
      counterpartyId: plan.counterpartyId,
      note: note,
      ownership: TransactionOwnership(
        ownerType: orchestrationAmortizationOwnerType,
        ownerId: plan.id,
      ),
      isExcludedFromStats: plan.defaultIsExcludedFromStats,
      isExcludedFromBudget: plan.defaultIsExcludedFromBudget,
    );
  }

  Set<String> _transactionIds(AmortizationPlan plan) => {
    plan.initialTransactionId,
    for (final entry in plan.entries)
      if (entry.transactionId != null && !entry.isCanceled)
        entry.transactionId!,
    ?plan.terminationRecognitionTransactionId,
    ?plan.refundTransactionId,
  };

  Future<AmortizationPlan> _requirePlan(String planId) async {
    final plan = await _repository.findById(planId);
    if (plan == null) {
      throw _error(
        AmortizationErrorCode.planNotFound,
        'Amortization plan not found.',
      );
    }
    return plan;
  }

  static DateTime _dateOnly(DateTime value) =>
      DateTime(value.year, value.month, value.day);

  static List<AccountAmountAllocation> _proportionalAllocations({
    required List<AccountAmountAllocation> allocations,
    required Money amount,
  }) {
    if (amount.minorUnits == 0) return const [];
    final total = sumAllocations(allocations);
    if (total == amount) return allocations;
    if (allocations.isEmpty || amount.minorUnits > total.minorUnits) {
      throw _error(
        AmortizationErrorCode.invalidCommand,
        'Termination allocation exceeds the remaining category balance.',
      );
    }
    final allocated = <int>[];
    final remainders = <int>[];
    for (final allocation in allocations) {
      final numerator = amount.minorUnits * allocation.amount.minorUnits;
      allocated.add(numerator ~/ total.minorUnits);
      remainders.add(numerator % total.minorUnits);
    }
    var remainingMinor =
        amount.minorUnits - allocated.fold(0, (sum, value) => sum + value);
    final order =
        [for (var index = 0; index < allocations.length; index++) index]
          ..sort((left, right) {
            final byRemainder = remainders[right].compareTo(remainders[left]);
            return byRemainder != 0 ? byRemainder : left.compareTo(right);
          });
    for (final index in order) {
      if (remainingMinor == 0) break;
      allocated[index]++;
      remainingMinor--;
    }
    return [
      for (var index = 0; index < allocations.length; index++)
        if (allocated[index] > 0)
          allocations[index].copyWith(
            amount: Money(minorUnits: allocated[index]),
          ),
    ];
  }

  static BusinessException _error(AmortizationErrorCode code, String message) =>
      BusinessException(code, message: message);
}
