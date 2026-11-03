import '../../../../core/error/app_exception.dart';
import '../../../../core/id/id_generator.dart';
import '../../../../core/money/money.dart';
import '../../../../domain/ledger/valobj/account_amount_allocation.dart';
import '../../../../domain/ledger/valobj/ledger_enum.dart';
import '../../../../domain/ledger/valobj/transaction_ownership.dart';
import '../../../../domain/orchestration/entity/amortization_period.dart';
import '../../../../domain/orchestration/entity/amortization_plan.dart';
import '../../../../domain/orchestration/entity/amortization_refund.dart';
import '../../../../domain/orchestration/entity/amortization_termination.dart';
import '../../../../domain/orchestration/port/amortization_ledger_port.dart';
import '../../../../domain/orchestration/port/amortization_repository.dart';
import '../../../../domain/orchestration/valobj/amortization_enums.dart';
import '../../../../domain/orchestration/valobj/amortization_error_code.dart';
import '../../../shared/transaction_runner.dart';
import 'amortization_command.dart';
import '../service/amortization_plan_recalculator.dart';

class AmortizationGenerationResult {
  const AmortizationGenerationResult({required this.generatedCount});

  final int generatedCount;
}

class AmortizationRefundResult {
  const AmortizationRefundResult({required this.refundTransactionId});

  final String refundTransactionId;
}

class AmortizationTerminationResult {
  const AmortizationTerminationResult({
    required this.recognitionTransactionId,
    required this.returnTransactionId,
  });

  final String? recognitionTransactionId;
  final String? returnTransactionId;
}

abstract interface class AmortizationPlanAppService {
  Future<String> createPlan(CreateAmortizationPlanCommand command);

  Future<void> updatePlan(UpdateAmortizationPlanCommand command);

  Future<void> updateConfiguration(
    UpdateAmortizationConfigurationCommand command,
  );

  Future<AmortizationGenerationResult> generateDue(DateTime now);

  Future<AmortizationRefundResult> refund(
    CreateAmortizationRefundCommand command,
  );

  Future<void> editRefund(EditAmortizationRefundCommand command);

  Future<void> deleteRefund(DeleteAmortizationRefundCommand command);

  Future<AmortizationTerminationResult> terminate(
    TerminateAmortizationPlanCommand command,
  );

  Future<AmortizationTerminationResult> editTermination(
    EditAmortizationTerminationCommand command,
  );

  Future<AmortizationGenerationResult> deleteTermination(
    DeleteAmortizationTerminationCommand command,
  );

  Future<void> deletePlan(DeleteAmortizationPlanCommand command);
}

class AmortizationPlanAppServiceImpl implements AmortizationPlanAppService {
  AmortizationPlanAppServiceImpl({
    required AmortizationRepository repository,
    required AmortizationLedgerPort ledger,
    required TransactionRunner transactionRunner,
    required IdGenerator idGenerator,
  }) : _repository = repository,
       _ledger = ledger,
       _recalculator = AmortizationPlanRecalculator(ledger),
       _transactionRunner = transactionRunner,
       _idGenerator = idGenerator;

  final AmortizationRepository _repository;
  final AmortizationLedgerPort _ledger;
  final AmortizationPlanRecalculator _recalculator;
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
      final initialTransfer = _initialTransferAllocations(
        kind: command.kind,
        amount: command.total,
        fundingAllocations: command.fundingAllocations,
        deferralAccountId: command.deferralAccountId,
      );
      final initialTransactionId = await _ledger.postTransfer(
        amount: command.total,
        outgoingAllocations: initialTransfer.outgoing,
        incomingAllocations: initialTransfer.incoming,
        occurredAt: command.occurredAt,
        feeAmount: command.feeAmount,
        counterpartyId: command.initialCounterpartyId,
        note: command.initialNote,
        ownership: ownership,
        isExcludedFromStats: command.initialIsExcludedFromStats,
        isExcludedFromBudget: command.initialIsExcludedFromBudget,
        tagIds: command.tagIds,
      );
      final plan = AmortizationPlan.create(
        id: planId,
        kind: command.kind,
        deferralAccountId: command.deferralAccountId,
        fundingAllocations: command.fundingAllocations,
        categoryAllocations: command.recognitionAllocations,
        originalAmount: command.total,
        cadenceUnit: command.cadenceUnit,
        cadenceInterval: command.cadenceInterval,
        firstRecognitionAt: command.firstRecognitionAt,
        recognitionCount: command.recognitionCount,
        initialTransactionId: initialTransactionId,
      );
      await _repository.save(plan);
      return planId;
    });
  }

  @override
  Future<void> updatePlan(UpdateAmortizationPlanCommand command) {
    return _transactionRunner.run(() async {
      final current = await _requirePlan(command.planId);
      if (current.status == AmortizationStatus.terminated) {
        throw _error(
          AmortizationErrorCode.planTerminated,
          'Undo the amortization termination before editing the plan.',
        );
      }
      await _ledger.validatePlanAccounts(
        kind: current.kind,
        deferralAccountId: command.deferralAccountId,
        categoryAccountIds: command.recognitionAllocations.map(
          (allocation) => allocation.accountId,
        ),
      );
      if (current.kind == AmortizationKind.deferredIncome &&
          command.feeAmount != null &&
          command.feeAmount!.minorUnits > 0) {
        throw _error(
          AmortizationErrorCode.invalidCommand,
          'Deferred-income collection fees must be recorded separately.',
        );
      }

      final updated = current.reconfigured(
        deferralAccountId: command.deferralAccountId,
        originalAmount: command.total,
        fundingAllocations: command.fundingAllocations,
        categoryAllocations: command.recognitionAllocations,
        cadenceUnit: command.cadenceUnit,
        cadenceInterval: command.cadenceInterval,
        firstRecognitionAt: command.firstRecognitionAt,
        recognitionCount: command.recognitionCount,
      );
      final initialTransfer = _initialTransferAllocations(
        kind: updated.kind,
        amount: updated.originalAmount,
        fundingAllocations: updated.fundingAllocations,
        deferralAccountId: updated.deferralAccountId,
      );
      await _ledger.rewriteTransfer(
        transactionId: updated.initialTransactionId,
        amount: updated.originalAmount,
        outgoingAllocations: initialTransfer.outgoing,
        incomingAllocations: initialTransfer.incoming,
        occurredAt: command.occurredAt,
        feeAmount: command.feeAmount ?? Money.zero(),
        note: command.note,
        counterpartyId: command.counterpartyId,
        tagIds: command.tagIds,
        isExcludedFromStats: command.initialIsExcludedFromStats,
        isExcludedFromBudget: command.initialIsExcludedFromBudget,
      );

      for (final refund in updated.refunds) {
        final transfer = _returnTransferAllocations(
          plan: updated,
          amount: refund.amount,
          settlementAllocations: refund.settlementAllocations,
        );
        await _ledger.rewriteTransfer(
          transactionId: refund.transferTransactionId,
          amount: refund.amount,
          outgoingAllocations: transfer.outgoing,
          incomingAllocations: transfer.incoming,
        );
      }

      final reconciled = await _recalculator.reconcile(
        before: current,
        after: updated,
        now: command.now,
        rewriteTransfers: false,
      );
      await _repository.save(reconciled);
    });
  }

  @override
  Future<void> updateConfiguration(
    UpdateAmortizationConfigurationCommand command,
  ) {
    return _transactionRunner.run(() async {
      final current = await _requirePlan(command.planId);
      final updated = current.reconfiguredConfiguration(
        cadenceUnit: command.cadenceUnit,
        cadenceInterval: command.cadenceInterval,
        firstRecognitionAt: command.firstRecognitionAt,
        recognitionCount: command.recognitionCount,
      );
      final reconciled = await _recalculator.reconcile(
        before: current,
        after: updated,
        now: command.now,
      );
      await _repository.save(reconciled);
    });
  }

  @override
  Future<AmortizationGenerationResult> generateDue(DateTime now) {
    return _transactionRunner.run(() async {
      final plans = await _repository.findAll();
      var generatedCount = 0;
      for (final plan in plans) {
        if (plan.status == AmortizationStatus.terminated) continue;
        final reconciled = await _recalculator.generateDue(plan, now);
        generatedCount += reconciled.postedPeriodCount - plan.postedPeriodCount;
        if (reconciled != plan) {
          await _repository.save(reconciled);
        }
      }
      return AmortizationGenerationResult(generatedCount: generatedCount);
    });
  }

  @override
  Future<AmortizationRefundResult> refund(
    CreateAmortizationRefundCommand command,
  ) {
    return _transactionRunner.run(() async {
      final plan = await _requirePlan(command.planId);
      if (plan.status == AmortizationStatus.terminated) {
        throw _error(
          AmortizationErrorCode.planTerminated,
          'A terminated amortization plan cannot be refunded.',
        );
      }
      _validateDimension(command.categoryAllocations, 'refund categories');
      _validateDimension(command.settlementAllocations, 'refund settlements');
      final refundAmount = sumAllocations(command.categoryAllocations);
      if (refundAmount.minorUnits <= 0 ||
          refundAmount != sumAllocations(command.settlementAllocations)) {
        throw _error(
          AmortizationErrorCode.invalidCommand,
          'Refund category and settlement totals must match and be positive.',
        );
      }
      if (refundAmount.minorUnits > plan.netAmount.minorUnits ||
          !allocationsFitAvailable(
            requested: command.categoryAllocations,
            available: plan.currentCategoryAllocations,
          )) {
        throw _error(
          AmortizationErrorCode.refundExceedsRemaining,
          'Refund exceeds the current amortization balance.',
        );
      }
      await _ledger.validateRefundAccounts(
        kind: plan.kind,
        categoryAccountIds: command.categoryAllocations.map(
          (allocation) => allocation.accountId,
        ),
        settlementAccountIds: command.settlementAllocations.map(
          (allocation) => allocation.accountId,
        ),
      );
      final transferTransactionId = await _postReturnTransfer(
        plan: plan,
        amount: refundAmount,
        settlementAllocations: command.settlementAllocations,
        occurredAt: command.occurredAt,
        postedAt: command.postedAt,
        note: command.note,
      );
      final refund = AmortizationRefund(
        id: _idGenerator.newId(),
        planId: plan.id,
        categoryAllocations: command.categoryAllocations,
        settlementAllocations: command.settlementAllocations,
        transferTransactionId: transferTransactionId,
      );
      final updated = plan.withRefund(refund);
      final reconciled = await _recalculator.reconcile(
        before: plan,
        after: updated,
        now: command.occurredAt,
        rewriteTransfers: false,
      );
      await _repository.save(reconciled);
      return AmortizationRefundResult(
        refundTransactionId: transferTransactionId,
      );
    });
  }

  @override
  Future<void> editRefund(EditAmortizationRefundCommand command) {
    return _transactionRunner.run(() async {
      final plan = await _requirePlan(command.planId);
      if (plan.status == AmortizationStatus.terminated) {
        throw _error(
          AmortizationErrorCode.planTerminated,
          'A terminated amortization plan cannot be refunded.',
        );
      }
      final current = plan.refunds
          .where((refund) => refund.id == command.refundId)
          .firstOrNull;
      if (current == null) {
        throw _error(
          AmortizationErrorCode.refundNotFound,
          'Amortization refund not found.',
        );
      }
      _validateDimension(command.categoryAllocations, 'refund categories');
      _validateDimension(command.settlementAllocations, 'refund settlements');
      final refundAmount = sumAllocations(command.categoryAllocations);
      if (refundAmount.minorUnits <= 0 ||
          refundAmount != sumAllocations(command.settlementAllocations)) {
        throw _error(
          AmortizationErrorCode.invalidCommand,
          'Refund category and settlement totals must match and be positive.',
        );
      }
      if (!allocationsFitAvailable(
        requested: command.categoryAllocations,
        available: plan.categoryAllocationsExcludingRefund(current.id),
      )) {
        throw _error(
          AmortizationErrorCode.refundExceedsRemaining,
          'Refund exceeds the current amortization balance.',
        );
      }
      await _ledger.validateRefundAccounts(
        kind: plan.kind,
        categoryAccountIds: command.categoryAllocations.map(
          (allocation) => allocation.accountId,
        ),
        settlementAccountIds: command.settlementAllocations.map(
          (allocation) => allocation.accountId,
        ),
      );
      final updated = plan.withUpdatedRefund(
        AmortizationRefund(
          id: current.id,
          planId: plan.id,
          categoryAllocations: command.categoryAllocations,
          settlementAllocations: command.settlementAllocations,
          transferTransactionId: current.transferTransactionId,
        ),
      );
      final transfer = _returnTransferAllocations(
        plan: updated,
        amount: refundAmount,
        settlementAllocations: command.settlementAllocations,
      );
      await _ledger.rewriteTransfer(
        transactionId: current.transferTransactionId,
        amount: refundAmount,
        outgoingAllocations: transfer.outgoing,
        incomingAllocations: transfer.incoming,
        occurredAt: command.occurredAt,
        note: command.note,
      );
      final reconciled = await _recalculator.reconcile(
        before: plan,
        after: updated,
        now: command.now,
        rewriteTransfers: false,
      );
      await _repository.save(reconciled);
    });
  }

  @override
  Future<void> deleteRefund(DeleteAmortizationRefundCommand command) {
    return _transactionRunner.run(() async {
      final plan = await _requirePlan(command.planId);
      final refund = plan.refunds
          .where((item) => item.id == command.refundId)
          .firstOrNull;
      if (refund == null) {
        throw _error(
          AmortizationErrorCode.refundNotFound,
          'Amortization refund not found.',
        );
      }
      final updated = plan.withoutRefund(refund.id);
      await _ledger.deleteTransaction(refund.transferTransactionId);
      final reconciled = await _recalculator.reconcile(
        before: plan,
        after: updated,
        now: command.now,
        rewriteTransfers: false,
      );
      await _repository.save(reconciled);
    });
  }

  @override
  Future<AmortizationTerminationResult> terminate(
    TerminateAmortizationPlanCommand command,
  ) {
    return _transactionRunner.run(() async {
      final plan = await _requirePlan(command.planId);
      if (plan.status == AmortizationStatus.terminated) {
        throw _error(
          AmortizationErrorCode.planTerminated,
          'Amortization plan is already terminated.',
        );
      }
      return _applyTermination(plan, command);
    });
  }

  @override
  Future<AmortizationTerminationResult> editTermination(
    EditAmortizationTerminationCommand command,
  ) {
    return _transactionRunner.run(() async {
      final plan = await _requirePlan(command.planId);
      final termination = plan.termination;
      if (termination == null) {
        throw _error(
          AmortizationErrorCode.terminationNotActive,
          'Amortization plan is not terminated.',
        );
      }
      for (final transactionId in {
        ?termination.recognitionTransactionId,
        ?termination.returnTransactionId,
      }) {
        await _ledger.deleteTransaction(transactionId);
      }
      final reopened = plan.withoutTermination([
        for (final period in plan.periods)
          if (period.isCanceled) period.reopened() else period,
      ]);
      return _applyTermination(
        reopened,
        TerminateAmortizationPlanCommand(
          planId: command.planId,
          terminatedAt: command.terminatedAt,
          categoryReturnAllocations: command.categoryReturnAllocations,
          settlementAllocations: command.settlementAllocations,
        ),
      );
    });
  }

  @override
  Future<AmortizationGenerationResult> deleteTermination(
    DeleteAmortizationTerminationCommand command,
  ) {
    return _transactionRunner.run(() async {
      final plan = await _requirePlan(command.planId);
      final termination = plan.termination;
      if (termination == null) {
        throw _error(
          AmortizationErrorCode.terminationNotActive,
          'Amortization plan is not terminated.',
        );
      }
      for (final transactionId in {
        ?termination.recognitionTransactionId,
        ?termination.returnTransactionId,
      }) {
        await _ledger.deleteTransaction(transactionId);
      }
      final reopened = plan.withoutTermination([
        for (final period in plan.periods)
          if (period.isCanceled) period.reopened() else period,
      ]);
      final duePeriods = reopened.duePeriods(command.now);
      final generated = await _postPeriods(reopened, duePeriods);
      await _repository.save(reopened.withPeriods(generated.periods));
      return AmortizationGenerationResult(
        generatedCount: generated.generatedCount,
      );
    });
  }

  Future<AmortizationTerminationResult> _applyTermination(
    AmortizationPlan plan,
    TerminateAmortizationPlanCommand command,
  ) async {
    _validateDimension(
      command.categoryReturnAllocations,
      'termination category returns',
    );
    _validateDimension(
      command.settlementAllocations,
      'termination settlements',
    );
    final returnAmount = sumAllocations(command.categoryReturnAllocations);
    if (returnAmount != sumAllocations(command.settlementAllocations)) {
      throw _error(
        AmortizationErrorCode.invalidCommand,
        'Termination category and settlement totals must match.',
      );
    }
    await _ledger.validateRefundAccounts(
      kind: plan.kind,
      categoryAccountIds: command.categoryReturnAllocations.map(
        (allocation) => allocation.accountId,
      ),
      settlementAccountIds: command.settlementAllocations.map(
        (allocation) => allocation.accountId,
      ),
    );

    final cutoff = _dateOnly(command.terminatedAt);
    final dueBeforeTermination = [
      for (final period in plan.periods)
        if (period.isPending &&
            period.amount.minorUnits > 0 &&
            !_dateOnly(period.dueAt).isAfter(cutoff))
          period,
    ];
    final generated = await _postPeriods(plan, dueBeforeTermination);
    var normalized = plan.withPeriods(generated.periods);

    for (final period in normalized.periods) {
      if (!period.isPosted || !_dateOnly(period.dueAt).isAfter(cutoff)) {
        continue;
      }
      await _ledger.deleteTransaction(period.transactionId!);
    }
    normalized = normalized.withPeriods([
      for (final period in normalized.periods)
        if (_dateOnly(period.dueAt).isAfter(cutoff) && period.isPosted)
          AmortizationPeriod(
            id: period.id,
            planId: period.planId,
            sequenceNo: period.sequenceNo,
            dueAt: period.dueAt,
            amount: period.amount,
            categoryAllocations: period.categoryAllocations,
            status: AmortizationPeriodStatus.canceled,
          )
        else
          period,
    ]);

    final remainingCategories = normalized.remainingCategoryAllocations;
    if (!allocationsFitAvailable(
      requested: command.categoryReturnAllocations,
      available: remainingCategories,
    )) {
      throw _error(
        AmortizationErrorCode.refundExceedsRemaining,
        'Termination return exceeds the remaining category balance.',
      );
    }
    final recognitionAllocations = subtractAllocations(
      base: remainingCategories,
      reductions: command.categoryReturnAllocations,
    );
    final recognitionAmount = sumAllocations(recognitionAllocations);
    if (recognitionAmount.minorUnits == 0 && returnAmount.minorUnits == 0) {
      throw _error(
        AmortizationErrorCode.invalidCommand,
        'There is no remaining amortization amount to terminate.',
      );
    }

    final recognitionTransactionId = recognitionAmount.minorUnits > 0
        ? await _postRecognition(
            plan: normalized,
            amount: recognitionAmount,
            categoryAllocations: recognitionAllocations,
            occurredAt: command.terminatedAt,
          )
        : null;
    final returnTransactionId = returnAmount.minorUnits > 0
        ? await _postReturnTransfer(
            plan: normalized,
            amount: returnAmount,
            settlementAllocations: command.settlementAllocations,
            occurredAt: command.terminatedAt,
          )
        : null;
    final termination = AmortizationTermination(
      id: _idGenerator.newId(),
      planId: normalized.id,
      terminatedAt: command.terminatedAt,
      categoryReturnAllocations: command.categoryReturnAllocations,
      settlementAllocations: command.settlementAllocations,
      recognitionTransactionId: recognitionTransactionId,
      returnTransactionId: returnTransactionId,
    );
    final terminated = normalized.terminatedWith(
      termination: termination,
      periods: [
        for (final period in normalized.periods)
          if (period.isPosted || period.isZero)
            period
          else
            AmortizationPeriod(
              id: period.id,
              planId: period.planId,
              sequenceNo: period.sequenceNo,
              dueAt: period.dueAt,
              amount: period.amount,
              categoryAllocations: period.categoryAllocations,
              status: AmortizationPeriodStatus.canceled,
            ),
      ],
    );
    await _repository.save(terminated);
    return AmortizationTerminationResult(
      recognitionTransactionId: recognitionTransactionId,
      returnTransactionId: returnTransactionId,
    );
  }

  @override
  Future<void> deletePlan(DeleteAmortizationPlanCommand command) {
    return _transactionRunner.run(() async {
      final plan = await _requirePlan(command.planId);
      final transactionIds = {
        plan.initialTransactionId,
        for (final period in plan.periods) ?period.transactionId,
        for (final refund in plan.refunds) refund.transferTransactionId,
        if (plan.termination case final termination?) ...[
          ?termination.recognitionTransactionId,
          ?termination.returnTransactionId,
        ],
      };
      for (final transactionId in transactionIds) {
        await _ledger.deleteTransaction(transactionId);
      }
      await _repository.deleteById(plan.id);
    });
  }

  Future<({List<AmortizationPeriod> periods, int generatedCount})> _postPeriods(
    AmortizationPlan plan,
    Iterable<AmortizationPeriod> periods,
  ) async {
    final generatedBySequence = <int, String>{};
    for (final period in periods) {
      if (period.amount.minorUnits <= 0) continue;
      generatedBySequence[period.sequenceNo] = await _postRecognition(
        plan: plan,
        amount: period.amount,
        categoryAllocations: period.categoryAllocations,
        occurredAt: period.dueAt,
      );
    }
    return (
      periods: [
        for (final period in plan.periods)
          if (generatedBySequence[period.sequenceNo] case final transactionId?)
            period.posted(transactionId)
          else
            period,
      ],
      generatedCount: generatedBySequence.length,
    );
  }

  Future<String> _postRecognition({
    required AmortizationPlan plan,
    required Money amount,
    required List<AccountAmountAllocation> categoryAllocations,
    required DateTime occurredAt,
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
        ownership: ownership,
        isExcludedFromStats: false,
        isExcludedFromBudget: false,
      ),
      AmortizationKind.deferredIncome => _ledger.postIncome(
        amount: amount,
        categoryAllocations: categoryAllocations,
        settlementAllocations: settlement,
        occurredAt: occurredAt,
        ownership: ownership,
        isExcludedFromStats: false,
        isExcludedFromBudget: false,
      ),
    };
  }

  Future<String> _postReturnTransfer({
    required AmortizationPlan plan,
    required Money amount,
    required List<AccountAmountAllocation> settlementAllocations,
    required DateTime occurredAt,
    DateTime? postedAt,
    String? note,
  }) {
    final transfer = _returnTransferAllocations(
      plan: plan,
      amount: amount,
      settlementAllocations: settlementAllocations,
    );
    return _ledger.postTransfer(
      amount: amount,
      outgoingAllocations: transfer.outgoing,
      incomingAllocations: transfer.incoming,
      occurredAt: occurredAt,
      postedAt: postedAt,
      note: note,
      ownership: TransactionOwnership(
        ownerType: orchestrationAmortizationOwnerType,
        ownerId: plan.id,
      ),
      isExcludedFromStats: false,
      isExcludedFromBudget: false,
      sourceKind: SourceKind.auto,
    );
  }

  ({
    List<AccountAmountAllocation> outgoing,
    List<AccountAmountAllocation> incoming,
  })
  _initialTransferAllocations({
    required AmortizationKind kind,
    required Money amount,
    required List<AccountAmountAllocation> fundingAllocations,
    required String deferralAccountId,
  }) {
    final deferralAllocation = singleAllocation(
      accountId: deferralAccountId,
      amount: amount,
    );
    return (
      outgoing: kind == AmortizationKind.prepaidExpense
          ? fundingAllocations
          : deferralAllocation,
      incoming: kind == AmortizationKind.prepaidExpense
          ? deferralAllocation
          : fundingAllocations,
    );
  }

  ({
    List<AccountAmountAllocation> outgoing,
    List<AccountAmountAllocation> incoming,
  })
  _returnTransferAllocations({
    required AmortizationPlan plan,
    required Money amount,
    required List<AccountAmountAllocation> settlementAllocations,
  }) {
    final deferralAllocation = singleAllocation(
      accountId: plan.deferralAccountId,
      amount: amount,
    );
    return (
      outgoing: plan.kind == AmortizationKind.prepaidExpense
          ? deferralAllocation
          : settlementAllocations,
      incoming: plan.kind == AmortizationKind.prepaidExpense
          ? settlementAllocations
          : deferralAllocation,
    );
  }

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

  static void _validateDimension(
    List<AccountAmountAllocation> allocations,
    String field,
  ) {
    if (allocations.isEmpty) {
      if (field == 'termination category returns' ||
          field == 'termination settlements') {
        return;
      }
      throw _error(
        AmortizationErrorCode.invalidCommand,
        'Refund allocations cannot be empty.',
      );
    }
    final accountIds = <String>{};
    for (final allocation in allocations) {
      if (allocation.amount.minorUnits <= 0 ||
          !accountIds.add(allocation.accountId)) {
        throw _error(
          AmortizationErrorCode.invalidCommand,
          '$field must be positive and unique by account.',
        );
      }
    }
  }

  static DateTime _dateOnly(DateTime value) =>
      DateTime(value.year, value.month, value.day);

  static BusinessException _error(AmortizationErrorCode code, String message) =>
      BusinessException(code, message: message);
}
