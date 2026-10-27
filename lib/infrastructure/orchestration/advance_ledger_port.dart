import '../../application/ledger/transaction/command/transaction_command.dart';
import '../../application/ledger/transaction/command/transaction_edit_app_service.dart';
import '../../application/ledger/transaction/command/transaction_posting_app_service.dart';
import '../../core/patch/patch.dart';
import '../../domain/ledger/entity/transaction_group.dart';
import '../../domain/ledger/port/transaction_group_repository.dart';
import '../../domain/ledger/valobj/ledger_enum.dart';
import '../../domain/orchestration/port/advance_ledger_port.dart';

class LedgerAdvancePort implements AdvanceLedgerPort {
  const LedgerAdvancePort({
    required TransactionPostingAppService posting,
    required TransactionEditAppService editing,
    required TransactionGroupRepository groups,
  }) : _posting = posting,
       _editing = editing,
       _groups = groups;

  final TransactionPostingAppService _posting;
  final TransactionEditAppService _editing;
  final TransactionGroupRepository _groups;

  @override
  Future<String> postAdvance({
    required amount,
    required advanceAmount,
    required receivableAccountId,
    required categoryAllocations,
    required selfBorneAllocations,
    required settlementAllocations,
    required ownership,
    required occurredAt,
    postedAt,
    counterpartyId,
    note,
    isExcludedFromStats = false,
    isExcludedFromBudget = false,
    sourceKind = SourceKind.manual,
    tagIds = const {},
  }) async {
    final result = await _posting.createAdvance(
      CreateAdvanceCommand(
        amount: amount,
        advanceAmount: advanceAmount,
        receivableAccountId: receivableAccountId,
        categoryAllocations: categoryAllocations,
        selfBorneAllocations: selfBorneAllocations,
        settlementAllocations: settlementAllocations,
        ownership: ownership,
        occurredAt: occurredAt,
        postedAt: postedAt,
        counterpartyId: counterpartyId,
        note: note,
        isExcludedFromStats: isExcludedFromStats,
        isExcludedFromBudget: isExcludedFromBudget,
        sourceKind: sourceKind,
        tagIds: tagIds,
      ),
    );
    return result.transactionId;
  }

  @override
  Future<String> postAdvanceCollection({
    required amount,
    required advanceTransactionId,
    required receivableAccountId,
    required settlementAllocations,
    required ownership,
    required occurredAt,
    postedAt,
    counterpartyId,
    note,
  }) async {
    final command = advanceTransactionId == null
        ? CreateAdvanceCollectionCommand.account(
            amount: amount,
            receivableAccountId: receivableAccountId,
            settlementAllocations: settlementAllocations,
            ownership: ownership!,
            occurredAt: occurredAt,
            postedAt: postedAt,
            counterpartyId: counterpartyId,
            note: note,
          )
        : CreateAdvanceCollectionCommand(
            amount: amount,
            advanceTransactionId: advanceTransactionId,
            receivableAccountId: receivableAccountId,
            settlementAllocations: settlementAllocations,
            occurredAt: occurredAt,
            postedAt: postedAt,
            counterpartyId: counterpartyId,
            note: note,
          );
    final result = await _posting.createAdvanceCollection(command);
    return result.transactionId;
  }

  @override
  Future<String> postAdvanceSettlement({
    required actualReceivedAmount,
    required advanceTransactionId,
    required receivableAccountId,
    required settlementAllocations,
    required gapExpenseAllocations,
    required shortfallKind,
    required ownership,
    required occurredAt,
    postedAt,
    counterpartyId,
    note,
  }) async {
    final command = advanceTransactionId == null
        ? CreateAdvanceSettlementCommand.account(
            actualReceivedAmount: actualReceivedAmount,
            receivableAccountId: receivableAccountId,
            settlementAllocations: settlementAllocations,
            gapExpenseAllocations: gapExpenseAllocations,
            ownership: ownership!,
            shortfallKind: shortfallKind,
            occurredAt: occurredAt,
            postedAt: postedAt,
            counterpartyId: counterpartyId,
            note: note,
          )
        : CreateAdvanceSettlementCommand(
            actualReceivedAmount: actualReceivedAmount,
            advanceTransactionId: advanceTransactionId,
            receivableAccountId: receivableAccountId,
            settlementAllocations: settlementAllocations,
            gapExpenseAllocations: gapExpenseAllocations,
            shortfallKind: shortfallKind,
            occurredAt: occurredAt,
            postedAt: postedAt,
            counterpartyId: counterpartyId,
            note: note,
          );
    final result = await _posting.settleAdvance(command);
    return result.transactionId;
  }

  @override
  Future<String> rewriteAdvance({
    required transactionId,
    required amount,
    required advanceAmount,
    required receivableAccountId,
    required categoryAllocations,
    required selfBorneAllocations,
    required settlementAllocations,
    required ownership,
    required refundSelfBorneAllocations,
    required occurredAt,
    Patch<String?>? counterpartyId,
    Patch<String?>? note,
    isExcludedFromStats,
    isExcludedFromBudget,
    tagIds,
  }) async {
    final result = await _editing.editAdvance(
      EditAdvanceCommand(
        transactionId: transactionId,
        amount: amount,
        advanceAmount: advanceAmount,
        receivableAccountId: receivableAccountId,
        ownership: ownership,
        categoryAllocations: categoryAllocations,
        selfBorneAllocations: selfBorneAllocations,
        settlementAllocations: settlementAllocations,
        refundSelfBorneAllocations: refundSelfBorneAllocations,
        occurredAt: occurredAt,
        counterpartyId: counterpartyId,
        note: note,
        isExcludedFromStats: isExcludedFromStats,
        isExcludedFromBudget: isExcludedFromBudget,
        tagIds: tagIds,
      ),
    );
    return result.transactionId;
  }

  @override
  Future<String> postRefund({
    required parentTransactionId,
    required amount,
    required categoryAllocations,
    required selfBorneAllocations,
    required settlementAllocations,
    required occurredAt,
    postedAt,
    counterpartyId,
    note,
  }) async {
    final result = await _posting.createRefund(
      CreateRefundCommand(
        amount: amount,
        parentTransactionId: parentTransactionId,
        categoryAllocations: categoryAllocations,
        selfBorneAllocations: selfBorneAllocations,
        settlementAllocations: settlementAllocations,
        occurredAt: occurredAt,
        postedAt: postedAt,
        counterpartyId: counterpartyId,
        note: note,
      ),
    );
    return result.transactionId;
  }

  @override
  Future<String> rewriteRefund({
    required transactionId,
    required amount,
    required categoryAllocations,
    required selfBorneAllocations,
    required settlementAllocations,
    required occurredAt,
    Patch<String?>? counterpartyId,
    Patch<String?>? note,
  }) async {
    final result = await _editing.editRefund(
      EditRefundCommand(
        transactionId: transactionId,
        amount: amount,
        categoryAllocations: categoryAllocations,
        selfBorneAllocations: selfBorneAllocations,
        settlementAllocations: settlementAllocations,
        occurredAt: occurredAt,
        counterpartyId: counterpartyId,
        note: note,
      ),
    );
    return result.transactionId;
  }

  @override
  Future<String> rewriteAdvanceCollection({
    required transactionId,
    required amount,
    required receivableAccountId,
    required settlementAllocations,
    required ownership,
    required occurredAt,
    Patch<String?>? counterpartyId,
    Patch<String?>? note,
  }) async {
    final result = await _editing.editAdvanceCollection(
      EditAdvanceCollectionCommand(
        transactionId: transactionId,
        amount: amount,
        receivableAccountId: receivableAccountId,
        settlementAllocations: settlementAllocations,
        ownership: ownership,
        occurredAt: occurredAt,
        counterpartyId: counterpartyId,
        note: note,
      ),
    );
    return result.transactionId;
  }

  @override
  Future<String> rewriteAdvanceSettlement({
    required transactionId,
    required actualReceivedAmount,
    required receivableAccountId,
    required settlementAllocations,
    required gapExpenseAllocations,
    required shortfallKind,
    required ownership,
    required occurredAt,
    Patch<String?>? counterpartyId,
    Patch<String?>? note,
  }) async {
    final result = await _editing.editAdvanceSettlement(
      EditAdvanceSettlementCommand(
        transactionId: transactionId,
        actualReceivedAmount: actualReceivedAmount,
        receivableAccountId: receivableAccountId,
        settlementAllocations: settlementAllocations,
        gapExpenseAllocations: gapExpenseAllocations,
        shortfallKind: shortfallKind,
        ownership: ownership,
        occurredAt: occurredAt,
        counterpartyId: counterpartyId,
        note: note,
      ),
    );
    return result.transactionId;
  }

  @override
  Future<TransactionGroup?> findGroup(String transactionId) {
    return _groups.findByTransactionId(transactionId);
  }
}
