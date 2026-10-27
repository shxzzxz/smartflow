import 'package:smartflow/application/shared/transaction_runner.dart';
import 'package:smartflow/core/id/id_generator.dart';
import 'package:smartflow/domain/ledger/entity/transaction.dart';
import 'package:smartflow/domain/ledger/entity/transaction_group.dart';
import 'package:smartflow/domain/ledger/valobj/account_amount_allocation.dart';
import 'package:smartflow/domain/ledger/valobj/ledger_enum.dart';
import 'package:smartflow/domain/ledger/valobj/transaction_ownership.dart';
import 'package:smartflow/domain/orchestration/entity/advance_case.dart';
import 'package:smartflow/domain/orchestration/port/advance_case_repository.dart';
import 'package:smartflow/domain/orchestration/port/advance_ledger_port.dart';
import 'package:smartflow/domain/orchestration/service/advance_share_calculator.dart';
import 'package:smartflow/domain/orchestration/valobj/advance_enums.dart';

import 'advance_command.dart';

abstract interface class AdvanceOrchestrationAppService {
  Future<String> createAdvance(CreateAdvanceWorkflowCommand command);

  Future<String> editAdvance(EditAdvanceWorkflowCommand command);

  Future<String> createCollection(
    CreateAdvanceCollectionWorkflowCommand command,
  );

  Future<String> createSettlement(
    CreateAdvanceSettlementWorkflowCommand command,
  );

  Future<String> editCollection(EditAdvanceCollectionWorkflowCommand command);

  Future<String> editSettlement(EditAdvanceSettlementWorkflowCommand command);

  Future<String> createRefund(CreateAdvanceRefundWorkflowCommand command);

  Future<String> editRefund(EditAdvanceRefundWorkflowCommand command);

  Future<AdvanceCase?> findCase(String id);

  Future<AdvanceCase?> findCaseForTransaction(String transactionId);
}

class AdvanceOrchestrationAppServiceImpl
    implements AdvanceOrchestrationAppService {
  AdvanceOrchestrationAppServiceImpl({
    required AdvanceCaseRepository cases,
    required AdvanceLedgerPort ledger,
    required TransactionRunner transactionRunner,
    required IdGenerator idGenerator,
    AdvanceSharePolicy sharePolicy = const AdvanceShareCalculator(),
  }) : _cases = cases,
       _ledger = ledger,
       _transactionRunner = transactionRunner,
       _idGenerator = idGenerator,
       _sharePolicy = sharePolicy;

  final AdvanceCaseRepository _cases;
  final AdvanceLedgerPort _ledger;
  final TransactionRunner _transactionRunner;
  final IdGenerator _idGenerator;
  final AdvanceSharePolicy _sharePolicy;

  @override
  Future<String> createAdvance(CreateAdvanceWorkflowCommand command) {
    return _transactionRunner.run(() async {
      final advanceCase = await _caseForCreate(
        scenario: command.scenario,
        trackingMode: command.trackingMode,
        receivableAccountId: command.receivableAccountId,
        aaPeopleCount: command.aaPeopleCount,
      );
      final split = _sharePolicy.splitForEntry(
        scenario: command.scenario,
        total: command.amount,
        aaPeopleCount: command.aaPeopleCount,
        categoryAllocations: command.categoryAllocations,
      );
      return _ledger.postAdvance(
        amount: command.amount,
        advanceAmount: split.advanceAmount,
        receivableAccountId: command.receivableAccountId,
        categoryAllocations: command.categoryAllocations,
        selfBorneAllocations: split.selfBorneAllocations,
        settlementAllocations: command.settlementAllocations,
        ownership: _ownership(advanceCase),
        occurredAt: command.occurredAt,
        postedAt: command.postedAt,
        counterpartyId: command.counterpartyId,
        note: command.note,
        isExcludedFromStats: command.isExcludedFromStats,
        isExcludedFromBudget: command.isExcludedFromBudget,
        sourceKind: command.sourceKind,
        tagIds: command.tagIds,
      );
    });
  }

  @override
  Future<String> editAdvance(EditAdvanceWorkflowCommand command) {
    return _transactionRunner.run(() async {
      final group = await _requireGroup(command.transactionId);
      final parent = group.parentTransaction;
      if (parent.id != command.transactionId ||
          parent.businessPurpose != BusinessPurpose.advance) {
        throw StateError('Target transaction is not an advance parent.');
      }
      final currentCase = await _requireCaseForGroup(group);
      final amount = command.amount ?? parent.primaryAmount;
      final categoryAllocations =
          command.categoryAllocations ??
          parent.accountAllocationsOf(TransactionRole.advanceExpenseCategory);
      final settlementAllocations =
          command.settlementAllocations ??
          parent.accountAllocationsOf(TransactionRole.settlementOut);
      final receivableAccountId =
          command.receivableAccountId ??
          parent.accountOf(TransactionRole.receivable);
      if (receivableAccountId == null) {
        throw StateError('Advance receivable account is required.');
      }
      final aaPeopleCount =
          command.aaPeopleCount ??
          (command.scenario == AdvanceScenario.aa
              ? _sharePolicy.inferAaPeopleCount(
                  total: amount,
                  advanceAmount:
                      parent.amountOf(TransactionRole.receivable) ??
                      parent.primaryAmount,
                )
              : 2);
      final split = _sharePolicy.splitForEntry(
        scenario: command.scenario,
        total: amount,
        aaPeopleCount: aaPeopleCount,
        categoryAllocations: categoryAllocations,
      );
      final nextCase = await _caseForEdit(
        current: currentCase,
        scenario: command.scenario,
        receivableAccountId: receivableAccountId,
        aaPeopleCount: aaPeopleCount,
      );
      final refundSelfBorne = <String, List<AccountAmountAllocation>>{};
      for (final child in group.childTransactions.where(
        (transaction) => transaction.businessPurpose == BusinessPurpose.refund,
      )) {
        final refundAmount =
            child.amountOf(TransactionRole.settlementIn) ?? child.primaryAmount;
        final refundCategories = group.refundCategoryAllocations(child);
        final refundSplit = _sharePolicy.splitForRefund(
          scenario: command.scenario,
          group: group,
          refundAmount: refundAmount,
          refundCategoryAllocations: refundCategories,
          parentTotal: amount,
          advanceAmount: split.advanceAmount,
          aaPeopleCount: split.aaPeopleCount,
          excludingRefundTransactionId: child.id,
        );
        refundSelfBorne[child.id] = refundSplit.selfBorneAllocations;
      }
      return _ledger.rewriteAdvance(
        transactionId: command.transactionId,
        amount: amount,
        advanceAmount: split.advanceAmount,
        receivableAccountId: receivableAccountId,
        categoryAllocations: categoryAllocations,
        selfBorneAllocations: split.selfBorneAllocations,
        settlementAllocations: settlementAllocations,
        ownership: _ownership(nextCase),
        refundSelfBorneAllocations: refundSelfBorne,
        occurredAt: command.occurredAt ?? parent.occurredAt,
        counterpartyId: command.counterpartyId,
        note: command.note,
        isExcludedFromStats: command.isExcludedFromStats,
        isExcludedFromBudget: command.isExcludedFromBudget,
        tagIds: command.tagIds,
      );
    });
  }

  @override
  Future<String> createCollection(
    CreateAdvanceCollectionWorkflowCommand command,
  ) {
    return _transactionRunner.run(() async {
      final ownership = await _ownershipForTransactionOrAccount(
        advanceTransactionId: command.advanceTransactionId,
        receivableAccountId: command.receivableAccountId,
        scenario: command.scenario,
      );
      return _ledger.postAdvanceCollection(
        amount: command.amount,
        advanceTransactionId: command.advanceTransactionId,
        receivableAccountId: command.receivableAccountId,
        settlementAllocations: command.settlementAllocations,
        ownership: ownership,
        occurredAt: command.occurredAt,
        postedAt: command.postedAt,
        counterpartyId: command.counterpartyId,
        note: command.note,
      );
    });
  }

  @override
  Future<String> createSettlement(
    CreateAdvanceSettlementWorkflowCommand command,
  ) {
    return _transactionRunner.run(() async {
      final ownership = await _ownershipForTransactionOrAccount(
        advanceTransactionId: command.advanceTransactionId,
        receivableAccountId: command.receivableAccountId,
        scenario: command.scenario,
      );
      return _ledger.postAdvanceSettlement(
        actualReceivedAmount: command.actualReceivedAmount,
        advanceTransactionId: command.advanceTransactionId,
        receivableAccountId: command.receivableAccountId,
        settlementAllocations: command.settlementAllocations,
        gapExpenseAllocations: command.gapExpenseAllocations,
        shortfallKind: command.shortfallKind,
        ownership: ownership,
        occurredAt: command.occurredAt,
        postedAt: command.postedAt,
        counterpartyId: command.counterpartyId,
        note: command.note,
      );
    });
  }

  @override
  Future<String> editCollection(EditAdvanceCollectionWorkflowCommand command) {
    return _transactionRunner.run(() async {
      final group = await _requireGroup(command.transactionId);
      final transaction = _requireTransaction(group, command.transactionId);
      final currentCase = await _requireCaseForGroup(group);
      final receivableAccountId =
          command.receivableAccountId ??
          transaction.accountOf(TransactionRole.receivable)!;
      final ownership = _ownership(
        await _caseForEdit(
          current: currentCase,
          scenario: currentCase.scenario,
          receivableAccountId: receivableAccountId,
          aaPeopleCount: currentCase.aaPeopleCount ?? 2,
        ),
      );
      return _ledger.rewriteAdvanceCollection(
        transactionId: command.transactionId,
        amount: command.amount ?? transaction.primaryAmount,
        receivableAccountId: receivableAccountId,
        settlementAllocations:
            command.settlementAllocations ??
            transaction.accountAllocationsOf(TransactionRole.settlementIn),
        ownership: ownership,
        occurredAt: command.occurredAt ?? transaction.occurredAt,
        counterpartyId: command.counterpartyId,
        note: command.note,
      );
    });
  }

  @override
  Future<String> editSettlement(EditAdvanceSettlementWorkflowCommand command) {
    return _transactionRunner.run(() async {
      final group = await _ledger.findGroup(command.transactionId);
      if (group == null) {
        throw StateError('Advance settlement not found.');
      }
      final transaction = _requireTransaction(group, command.transactionId);
      final currentCase = await _requireCaseForGroup(group);
      final receivableAccountId =
          command.receivableAccountId ??
          transaction.accountOf(TransactionRole.receivable)!;
      final ownership = _ownership(
        await _caseForEdit(
          current: currentCase,
          scenario: currentCase.scenario,
          receivableAccountId: receivableAccountId,
          aaPeopleCount: currentCase.aaPeopleCount ?? 2,
        ),
      );
      final hasBadDebt =
          (transaction
                  .amountOf(TransactionRole.advanceBadDebtExpense)
                  ?.minorUnits ??
              0) >
          0;
      return _ledger.rewriteAdvanceSettlement(
        transactionId: command.transactionId,
        actualReceivedAmount:
            command.actualReceivedAmount ?? transaction.primaryAmount,
        receivableAccountId: receivableAccountId,
        settlementAllocations:
            command.settlementAllocations ??
            transaction.accountAllocationsOf(TransactionRole.settlementIn),
        gapExpenseAllocations:
            command.gapExpenseAllocations ??
            transaction.accountAllocationsOf(TransactionRole.advanceSelfBorne),
        shortfallKind:
            command.shortfallKind ??
            (hasBadDebt
                ? AdvanceShortfallKind.badDebt
                : AdvanceShortfallKind.selfBorne),
        ownership: ownership,
        occurredAt: command.occurredAt ?? transaction.occurredAt,
        counterpartyId: command.counterpartyId,
        note: command.note,
      );
    });
  }

  @override
  Future<String> createRefund(CreateAdvanceRefundWorkflowCommand command) {
    return _transactionRunner.run(() async {
      final group = await _requireGroup(command.parentTransactionId);
      final advanceCase = await _requireCaseForGroup(group);
      final split = _sharePolicy.splitForRefund(
        scenario: advanceCase.scenario,
        group: group,
        refundAmount: command.amount,
        refundCategoryAllocations: command.categoryAllocations,
        aaPeopleCount: advanceCase.aaPeopleCount,
      );
      return _ledger.postRefund(
        parentTransactionId: command.parentTransactionId,
        amount: command.amount,
        categoryAllocations: command.categoryAllocations,
        selfBorneAllocations: split.selfBorneAllocations,
        settlementAllocations: command.settlementAllocations,
        occurredAt: command.occurredAt,
        postedAt: command.postedAt,
        counterpartyId: command.counterpartyId,
        note: command.note,
      );
    });
  }

  @override
  Future<String> editRefund(EditAdvanceRefundWorkflowCommand command) {
    return _transactionRunner.run(() async {
      final group = await _requireGroup(command.transactionId);
      final refund = _requireTransaction(group, command.transactionId);
      if (refund.id == group.parentTransaction.id ||
          refund.businessPurpose != BusinessPurpose.refund) {
        throw StateError('Target transaction is not an advance refund.');
      }
      final advanceCase = await _requireCaseForGroup(group);
      final split = _sharePolicy.splitForRefund(
        scenario: advanceCase.scenario,
        group: group,
        refundAmount: command.amount,
        refundCategoryAllocations: command.categoryAllocations,
        aaPeopleCount: advanceCase.aaPeopleCount,
        excludingRefundTransactionId: command.transactionId,
      );
      return _ledger.rewriteRefund(
        transactionId: command.transactionId,
        amount: command.amount,
        categoryAllocations: command.categoryAllocations,
        selfBorneAllocations: split.selfBorneAllocations,
        settlementAllocations: command.settlementAllocations,
        occurredAt: command.occurredAt,
        counterpartyId: command.counterpartyId,
        note: command.note,
      );
    });
  }

  @override
  Future<AdvanceCase?> findCase(String id) => _cases.findById(id);

  @override
  Future<AdvanceCase?> findCaseForTransaction(String transactionId) async {
    final group = await _ledger.findGroup(transactionId);
    return group == null ? null : _caseForGroup(group);
  }

  Future<AdvanceCase> _caseForCreate({
    required AdvanceScenario scenario,
    required AdvanceTrackingMode trackingMode,
    required String receivableAccountId,
    required int aaPeopleCount,
  }) async {
    final existing = trackingMode == AdvanceTrackingMode.account
        ? await _cases.findAccountCase(
            receivableAccountId: receivableAccountId,
            scenario: scenario,
          )
        : null;
    final advanceCase =
        existing ??
        AdvanceCase(
          id: _idGenerator.newId(),
          scenario: scenario,
          trackingMode: trackingMode,
          receivableAccountId: trackingMode == AdvanceTrackingMode.account
              ? receivableAccountId
              : null,
          aaPeopleCount:
              scenario == AdvanceScenario.aa &&
                  trackingMode == AdvanceTrackingMode.itemized
              ? aaPeopleCount
              : null,
        );
    advanceCase.validate();
    if (existing == null) await _cases.save(advanceCase);
    return advanceCase;
  }

  Future<AdvanceCase> _caseForEdit({
    required AdvanceCase current,
    required AdvanceScenario scenario,
    required String receivableAccountId,
    required int aaPeopleCount,
  }) async {
    if (current.trackingMode == AdvanceTrackingMode.itemized) {
      final next = AdvanceCase(
        id: current.id,
        scenario: scenario,
        trackingMode: current.trackingMode,
        aaPeopleCount:
            scenario == AdvanceScenario.aa &&
                current.trackingMode == AdvanceTrackingMode.itemized
            ? aaPeopleCount
            : null,
      );
      next.validate();
      await _cases.save(next);
      return next;
    }
    final next =
        await _cases.findAccountCase(
          receivableAccountId: receivableAccountId,
          scenario: scenario,
        ) ??
        AdvanceCase(
          id: _idGenerator.newId(),
          scenario: scenario,
          trackingMode: current.trackingMode,
          receivableAccountId: receivableAccountId,
          aaPeopleCount: null,
        );
    next.validate();
    await _cases.save(next);
    return next;
  }

  Future<TransactionOwnership?> _ownershipForTransactionOrAccount({
    required String? advanceTransactionId,
    required String receivableAccountId,
    required AdvanceScenario? scenario,
  }) async {
    if (advanceTransactionId != null) {
      final group = await _requireGroup(advanceTransactionId);
      await _requireCaseForGroup(group);
      return group.parentTransaction.ownership;
    }
    if (scenario == null) {
      throw ArgumentError('Account-tracked advances require a scenario.');
    }
    final advanceCase = await _caseForCreate(
      scenario: scenario,
      trackingMode: AdvanceTrackingMode.account,
      receivableAccountId: receivableAccountId,
      aaPeopleCount: 0,
    );
    return _ownership(advanceCase);
  }

  Future<TransactionGroup> _requireGroup(String transactionId) async {
    final group = await _ledger.findGroup(transactionId);
    if (group == null) throw StateError('Transaction group not found.');
    return group;
  }

  Future<AdvanceCase> _requireCaseForGroup(TransactionGroup group) async {
    final advanceCase = await _caseForGroup(group);
    if (advanceCase == null) throw StateError('Advance case not found.');
    return advanceCase;
  }

  Future<AdvanceCase?> _caseForGroup(TransactionGroup group) async {
    final ownership = group.parentTransaction.ownership;
    if (ownership?.ownerType != orchestrationAdvanceOwnerType) return null;
    return _cases.findById(ownership!.ownerId);
  }

  Transaction _requireTransaction(
    TransactionGroup group,
    String transactionId,
  ) {
    final transaction = group.findTransaction(transactionId);
    if (transaction == null) {
      throw StateError('Transaction does not belong to the loaded group.');
    }
    return transaction;
  }

  TransactionOwnership _ownership(AdvanceCase advanceCase) {
    return TransactionOwnership(
      ownerType: orchestrationAdvanceOwnerType,
      ownerId: advanceCase.id,
    );
  }
}
