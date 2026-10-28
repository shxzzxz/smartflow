import 'package:smartflow/application/shared/transaction_runner.dart';
import 'package:smartflow/core/error/app_exception.dart';
import 'package:smartflow/core/id/id_generator.dart';
import 'package:smartflow/core/money/money.dart';
import 'package:smartflow/core/patch/patch.dart';
import 'package:smartflow/domain/ledger/entity/transaction.dart';
import 'package:smartflow/domain/ledger/entity/transaction_group.dart';
import 'package:smartflow/domain/ledger/valobj/account_amount_allocation.dart';
import 'package:smartflow/domain/ledger/valobj/ledger_enum.dart';
import 'package:smartflow/domain/ledger/valobj/transaction_ownership.dart';
import 'package:smartflow/domain/orchestration/entity/advance_case.dart';
import 'package:smartflow/domain/orchestration/port/advance_case_repository.dart';
import 'package:smartflow/domain/orchestration/port/advance_ledger_port.dart';
import 'package:smartflow/domain/orchestration/service/advance_share_calculator.dart';
import 'package:smartflow/domain/orchestration/valobj/advance_error_code.dart';
import 'package:smartflow/domain/orchestration/valobj/advance_enums.dart';

import 'advance_command.dart';

abstract interface class AdvanceOrchestrationAppService {
  Future<String> createAdvance(CreateAdvanceWorkflowCommand command);

  Future<String> createExpenseScene(CreateExpenseSceneWorkflowCommand command);

  Future<String> editAdvance(EditAdvanceWorkflowCommand command);

  Future<String> editExpenseScene(EditExpenseSceneWorkflowCommand command);

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
    return _transactionRunner.run(() => _createAdvance(command));
  }

  @override
  Future<String> createExpenseScene(CreateExpenseSceneWorkflowCommand command) {
    return _transactionRunner.run(() async {
      switch (command.target) {
        case OrdinaryExpenseSceneTarget():
          return _ledger.postExpense(
            amount: command.amount,
            categoryAllocations: command.categoryAllocations,
            settlementAllocations: command.settlementAllocations,
            occurredAt: command.occurredAt,
            postedAt: command.postedAt,
            counterpartyId: command.counterpartyId,
            note: command.note,
            isExcludedFromStats: command.isExcludedFromStats,
            isExcludedFromBudget: command.isExcludedFromBudget,
            sourceKind: command.sourceKind,
            tagIds: command.tagIds,
          );
        case ItemizedAdvanceSceneTarget(
          :final scenario,
          :final aaPeopleCount,
          :final receivableAccountId,
        ):
          return _createAdvance(
            CreateAdvanceWorkflowCommand(
              amount: command.amount,
              scenario: scenario,
              trackingMode: AdvanceTrackingMode.itemized,
              aaPeopleCount: aaPeopleCount,
              receivableAccountId: receivableAccountId,
              categoryAllocations: command.categoryAllocations,
              settlementAllocations: command.settlementAllocations,
              occurredAt: command.occurredAt,
              postedAt: command.postedAt,
              counterpartyId: command.counterpartyId,
              note: command.note,
              isExcludedFromStats: command.isExcludedFromStats,
              isExcludedFromBudget: command.isExcludedFromBudget,
              sourceKind: command.sourceKind,
              tagIds: command.tagIds,
            ),
          );
        case AccountAdvanceSceneTarget(
          :final scenario,
          :final aaPeopleCount,
          :final receivableAccountId,
        ):
          return _createAdvance(
            CreateAdvanceWorkflowCommand(
              amount: command.amount,
              scenario: scenario,
              trackingMode: AdvanceTrackingMode.account,
              aaPeopleCount: aaPeopleCount,
              receivableAccountId: receivableAccountId,
              categoryAllocations: command.categoryAllocations,
              settlementAllocations: command.settlementAllocations,
              occurredAt: command.occurredAt,
              postedAt: command.postedAt,
              counterpartyId: command.counterpartyId,
              note: command.note,
              isExcludedFromStats: command.isExcludedFromStats,
              isExcludedFromBudget: command.isExcludedFromBudget,
              sourceKind: command.sourceKind,
              tagIds: command.tagIds,
            ),
          );
      }
    });
  }

  Future<String> _createAdvance(CreateAdvanceWorkflowCommand command) async {
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
  }

  @override
  Future<String> editAdvance(EditAdvanceWorkflowCommand command) {
    return _transactionRunner.run(() async {
      final group = await _requireGroup(command.transactionId);
      final parent = group.parentTransaction;
      if (parent.id != command.transactionId ||
          parent.businessPurpose != BusinessPurpose.advance) {
        throw BusinessException(AdvanceErrorCode.invalidCommand);
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
        throw BusinessException(
          AdvanceErrorCode.invalidCommand,
          message: '垫付应收账户不能为空。',
        );
      }
      final aaPeopleCount = _resolvedAaPeopleCount(
        scenario: command.scenario,
        requested: command.aaPeopleCount ?? currentCase.aaPeopleCount,
        amount: amount,
        parent: parent,
      );
      final target = switch (currentCase.trackingMode) {
        AdvanceTrackingMode.itemized => ItemizedAdvanceSceneTarget(
          scenario: command.scenario,
          aaPeopleCount: aaPeopleCount,
          receivableAccountId: receivableAccountId,
        ),
        AdvanceTrackingMode.account => AccountAdvanceSceneTarget(
          scenario: command.scenario,
          aaPeopleCount: aaPeopleCount,
          receivableAccountId: receivableAccountId,
        ),
      };
      return _editLoadedExpenseScene(
        group: group,
        command: EditExpenseSceneWorkflowCommand(
          transactionId: command.transactionId,
          target: target,
          amount: amount,
          categoryAllocations: categoryAllocations,
          settlementAllocations: settlementAllocations,
          occurredAt: command.occurredAt,
          counterpartyId: command.counterpartyId,
          note: command.note,
          isExcludedFromStats: command.isExcludedFromStats,
          isExcludedFromBudget: command.isExcludedFromBudget,
          tagIds: command.tagIds,
        ),
      );
    });
  }

  @override
  Future<String> editExpenseScene(EditExpenseSceneWorkflowCommand command) {
    return _transactionRunner.run(() async {
      final group = await _requireGroup(command.transactionId);
      return _editLoadedExpenseScene(group: group, command: command);
    });
  }

  Future<String> _editLoadedExpenseScene({
    required TransactionGroup group,
    required EditExpenseSceneWorkflowCommand command,
  }) async {
    final parent = group.parentTransaction;
    if (parent.id != command.transactionId ||
        (parent.businessPurpose != BusinessPurpose.dailyExpense &&
            parent.businessPurpose != BusinessPurpose.advance)) {
      throw BusinessException(AdvanceErrorCode.invalidCommand);
    }
    final currentCase = parent.businessPurpose == BusinessPurpose.advance
        ? await _requireCaseForGroup(group)
        : null;
    final amount = command.amount ?? parent.primaryAmount;
    final categoryAllocations =
        command.categoryAllocations ?? _categoryAllocations(parent);
    final settlementAllocations =
        command.settlementAllocations ??
        parent.accountAllocationsOf(TransactionRole.settlementOut);
    final occurredAt = command.occurredAt ?? parent.occurredAt;

    switch (command.target) {
      case OrdinaryExpenseSceneTarget():
        if (currentCase?.trackingMode == AdvanceTrackingMode.account) {
          throw BusinessException(AdvanceErrorCode.conversionNotAllowed);
        }
        final transactionId = await _ledger.rewriteExpense(
          transactionId: command.transactionId,
          amount: amount,
          categoryAllocations: categoryAllocations,
          settlementAllocations: settlementAllocations,
          refundSelfBorneAllocations: {
            for (final child in group.childTransactions)
              if (child.businessPurpose == BusinessPurpose.refund)
                child.id: const [],
          },
          occurredAt: occurredAt,
          counterpartyId: command.counterpartyId,
          note: command.note,
          isExcludedFromStats: command.isExcludedFromStats,
          isExcludedFromBudget: command.isExcludedFromBudget,
          tagIds: command.tagIds,
        );
        if (currentCase != null) {
          await _cases.deleteById(currentCase.id);
        }
        return transactionId;
      case ItemizedAdvanceSceneTarget(
        :final scenario,
        :final aaPeopleCount,
        :final receivableAccountId,
      ):
        if (currentCase?.trackingMode == AdvanceTrackingMode.account) {
          throw BusinessException(AdvanceErrorCode.conversionNotAllowed);
        }
        return _rewriteAdvanceScene(
          group: group,
          parent: parent,
          currentCase: currentCase,
          scenario: scenario,
          trackingMode: AdvanceTrackingMode.itemized,
          receivableAccountId: receivableAccountId,
          aaPeopleCount: aaPeopleCount,
          amount: amount,
          categoryAllocations: categoryAllocations,
          settlementAllocations: settlementAllocations,
          occurredAt: occurredAt,
          counterpartyId: command.counterpartyId,
          note: command.note,
          isExcludedFromStats: command.isExcludedFromStats,
          isExcludedFromBudget: command.isExcludedFromBudget,
          tagIds: command.tagIds,
        );
      case AccountAdvanceSceneTarget(
        :final scenario,
        :final aaPeopleCount,
        :final receivableAccountId,
      ):
        if (currentCase?.trackingMode != AdvanceTrackingMode.account) {
          throw BusinessException(AdvanceErrorCode.conversionNotAllowed);
        }
        return _rewriteAdvanceScene(
          group: group,
          parent: parent,
          currentCase: currentCase,
          scenario: scenario,
          trackingMode: AdvanceTrackingMode.account,
          receivableAccountId: receivableAccountId,
          aaPeopleCount: aaPeopleCount,
          amount: amount,
          categoryAllocations: categoryAllocations,
          settlementAllocations: settlementAllocations,
          occurredAt: occurredAt,
          counterpartyId: command.counterpartyId,
          note: command.note,
          isExcludedFromStats: command.isExcludedFromStats,
          isExcludedFromBudget: command.isExcludedFromBudget,
          tagIds: command.tagIds,
        );
    }
  }

  Future<String> _rewriteAdvanceScene({
    required TransactionGroup group,
    required Transaction parent,
    required AdvanceCase? currentCase,
    required AdvanceScenario scenario,
    required AdvanceTrackingMode trackingMode,
    required String receivableAccountId,
    required int aaPeopleCount,
    required Money amount,
    required List<AccountAmountAllocation> categoryAllocations,
    required List<AccountAmountAllocation> settlementAllocations,
    required DateTime occurredAt,
    required Patch<String?>? counterpartyId,
    required Patch<String?>? note,
    required bool? isExcludedFromStats,
    required bool? isExcludedFromBudget,
    required Set<String>? tagIds,
  }) async {
    final split = _sharePolicy.splitForEntry(
      scenario: scenario,
      total: amount,
      aaPeopleCount: aaPeopleCount,
      categoryAllocations: categoryAllocations,
    );
    final nextCase = currentCase == null
        ? await _caseForCreate(
            scenario: scenario,
            trackingMode: trackingMode,
            receivableAccountId: trackingMode == AdvanceTrackingMode.account
                ? receivableAccountId
                : null,
            aaPeopleCount: aaPeopleCount,
          )
        : await _caseForEdit(
            current: currentCase,
            scenario: scenario,
            receivableAccountId: trackingMode == AdvanceTrackingMode.account
                ? receivableAccountId
                : null,
            aaPeopleCount: aaPeopleCount,
          );
    final refundSelfBorne = <String, List<AccountAmountAllocation>>{
      for (final child in group.childTransactions)
        if (child.businessPurpose == BusinessPurpose.refund)
          child.id: _sharePolicy
              .splitForRefund(
                scenario: scenario,
                group: group,
                refundAmount:
                    child.amountOf(TransactionRole.settlementIn) ??
                    child.primaryAmount,
                refundCategoryAllocations: group.refundCategoryAllocations(
                  child,
                ),
                parentTotal: amount,
                advanceAmount: split.advanceAmount,
                aaPeopleCount: split.aaPeopleCount,
                excludingRefundTransactionId: child.id,
              )
              .selfBorneAllocations,
    };
    return _ledger.rewriteAdvance(
      transactionId: parent.id,
      amount: amount,
      advanceAmount: split.advanceAmount,
      receivableAccountId: receivableAccountId,
      categoryAllocations: categoryAllocations,
      selfBorneAllocations: split.selfBorneAllocations,
      settlementAllocations: settlementAllocations,
      ownership: _ownership(nextCase),
      refundSelfBorneAllocations: refundSelfBorne,
      occurredAt: occurredAt,
      counterpartyId: counterpartyId,
      note: note,
      isExcludedFromStats: isExcludedFromStats,
      isExcludedFromBudget: isExcludedFromBudget,
      tagIds: tagIds,
    );
  }

  @override
  Future<String> createCollection(
    CreateAdvanceCollectionWorkflowCommand command,
  ) {
    return _transactionRunner.run(() async {
      final ownership = await _ownershipForTransaction(
        command.advanceTransactionId,
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
      final ownership = await _ownershipForTransaction(
        command.advanceTransactionId,
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
      final receivableAccountId =
          command.receivableAccountId ??
          transaction.accountOf(TransactionRole.receivable);
      if (receivableAccountId == null) {
        throw BusinessException(AdvanceErrorCode.invalidCommand);
      }
      final ownership = _ownership(await _requireCaseForGroup(group));
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
        throw BusinessException(AdvanceErrorCode.transactionNotFound);
      }
      final transaction = _requireTransaction(group, command.transactionId);
      final receivableAccountId =
          command.receivableAccountId ??
          transaction.accountOf(TransactionRole.receivable);
      if (receivableAccountId == null) {
        throw BusinessException(AdvanceErrorCode.invalidCommand);
      }
      final ownership = _ownership(await _requireCaseForGroup(group));
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
        throw BusinessException(AdvanceErrorCode.invalidCommand);
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
    required String? receivableAccountId,
    required int aaPeopleCount,
  }) async {
    final advanceCase = AdvanceCase(
      id: _idGenerator.newId(),
      scenario: scenario,
      trackingMode: trackingMode,
      receivableAccountId: trackingMode == AdvanceTrackingMode.account
          ? receivableAccountId
          : null,
      aaPeopleCount: scenario == AdvanceScenario.aa ? aaPeopleCount : null,
    );
    _validateCase(advanceCase);
    await _cases.save(advanceCase);
    return advanceCase;
  }

  Future<AdvanceCase> _caseForEdit({
    required AdvanceCase current,
    required AdvanceScenario scenario,
    required String? receivableAccountId,
    required int aaPeopleCount,
  }) async {
    final next = AdvanceCase(
      id: current.id,
      scenario: scenario,
      trackingMode: current.trackingMode,
      receivableAccountId: current.trackingMode == AdvanceTrackingMode.account
          ? receivableAccountId
          : null,
      aaPeopleCount: scenario == AdvanceScenario.aa ? aaPeopleCount : null,
    );
    _validateCase(next);
    await _cases.save(next);
    return next;
  }

  Future<TransactionOwnership> _ownershipForTransaction(
    String advanceTransactionId,
  ) async {
    final group = await _requireGroup(advanceTransactionId);
    await _requireCaseForGroup(group);
    final ownership = group.parentTransaction.ownership;
    if (ownership == null) {
      throw BusinessException(AdvanceErrorCode.caseNotFound);
    }
    return ownership;
  }

  Future<TransactionGroup> _requireGroup(String transactionId) async {
    final group = await _ledger.findGroup(transactionId);
    if (group == null) {
      throw BusinessException(AdvanceErrorCode.transactionNotFound);
    }
    return group;
  }

  Future<AdvanceCase> _requireCaseForGroup(TransactionGroup group) async {
    final advanceCase = await _caseForGroup(group);
    if (advanceCase == null) {
      throw BusinessException(AdvanceErrorCode.caseNotFound);
    }
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
      throw BusinessException(AdvanceErrorCode.transactionNotFound);
    }
    return transaction;
  }

  int _resolvedAaPeopleCount({
    required AdvanceScenario scenario,
    required int? requested,
    required Money amount,
    required Transaction parent,
  }) {
    if (scenario != AdvanceScenario.aa) return 2;
    return requested ??
        _sharePolicy.inferAaPeopleCount(
          total: amount,
          advanceAmount:
              parent.amountOf(TransactionRole.receivable) ??
              parent.primaryAmount,
        );
  }

  List<AccountAmountAllocation> _categoryAllocations(Transaction transaction) {
    return TransactionGroup(
      parentTransaction: transaction,
      childTransactions: const [],
    ).categoryAllocations;
  }

  TransactionOwnership _ownership(AdvanceCase advanceCase) {
    return TransactionOwnership(
      ownerType: orchestrationAdvanceOwnerType,
      ownerId: advanceCase.id,
    );
  }

  void _validateCase(AdvanceCase advanceCase) {
    try {
      advanceCase.validate();
    } on ArgumentError catch (error, stackTrace) {
      throw BusinessException(
        AdvanceErrorCode.invalidCommand,
        message: error.message?.toString(),
        cause: error,
        stackTrace: stackTrace,
      );
    }
  }
}
