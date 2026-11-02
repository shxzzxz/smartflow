part of '../transaction_form_view_model.dart';

final class _LedgerTransactionFormWorkflow {
  const _LedgerTransactionFormWorkflow({
    required TransactionPostingAppService postingService,
    required TransactionEditAppService editService,
  }) : _postingService = postingService,
       _editService = editService;

  final TransactionPostingAppService _postingService;
  final TransactionEditAppService _editService;

  Future<void> create({
    required TransactionFormState state,
    required Money amount,
    required Money? feeAmount,
    required String? note,
  }) async {
    switch (state.mode) {
      case TransactionFormMode.income:
        final allocations = incomeAllocations(state, amount);
        await _postingService.createIncome(
          CreateIncomeCommand(
            amount: amount,
            categoryAllocations: allocations.categories,
            settlementAllocations: allocations.settlements,
            occurredAt: state.occurredAt,
            counterpartyId: state.counterpartyId,
            note: note,
            isExcludedFromStats: state.excludeStats,
            tagIds: state.selectedTagIds,
          ),
        );
      case TransactionFormMode.transfer:
        final fromAccountId = effectiveAccountId(
          state.fromAccountId,
          state.settlementAccounts,
        );
        final toAccountId = effectiveAccountId(
          state.toAccountId,
          state.settlementAccounts,
        );
        if (fromAccountId == null || toAccountId == null) {
          throw invalidCommandException('请选择转出和转入账户');
        }
        await _postingService.createTransfer(
          CreateTransferCommand.simple(
            amount: amount,
            fromAccountId: fromAccountId,
            toAccountId: toAccountId,
            feeAmount: feeAmount,
            occurredAt: state.occurredAt,
            counterpartyId: state.counterpartyId,
            note: note,
            isExcludedFromStats: state.excludeStats,
            isExcludedFromBudget: state.excludeBudget,
            tagIds: state.selectedTagIds,
          ),
        );
      case TransactionFormMode.borrowing:
        final liabilityAccountId = effectiveAccountId(
          state.liabilityAccountId,
          state.liabilityAccounts,
        );
        if (liabilityAccountId == null) {
          throw invalidCommandException('请选择负债账户');
        }
        final receiveAccountId = effectiveAccountId(
          state.toAccountId,
          state.fundAccounts,
        );
        if (receiveAccountId == null) {
          throw invalidCommandException('请选择收款账户');
        }
        await _postingService.createBorrowing(
          CreateBorrowingCommand(
            amount: amount,
            liabilityAccountId: liabilityAccountId,
            receiveAccountId: receiveAccountId,
            occurredAt: state.occurredAt,
            counterpartyId: state.counterpartyId,
            note: note,
            tagIds: state.selectedTagIds,
          ),
        );
      case TransactionFormMode.lending:
        final paidFromAccountId = effectiveAccountId(
          state.fromAccountId,
          state.fundAccounts,
        );
        final receivableAccountId = effectiveAccountId(
          state.ordinaryReceivableAccountId,
          state.ordinaryReceivableAccounts,
        );
        if (paidFromAccountId == null || receivableAccountId == null) {
          throw invalidCommandException(
            '请选择${state.relationScene.cashAccountLabel}和'
            '${state.relationScene.receivableAccountLabel}',
          );
        }
        await (_postingService as ReceivableTransactionPostingAppService)
            .createLending(
              CreateLendingCommand(
                amount: amount,
                receivableAccountId: receivableAccountId,
                paidFromAccountId: paidFromAccountId,
                occurredAt: state.occurredAt,
                counterpartyId: state.counterpartyId,
                note: note,
                tagIds: state.selectedTagIds,
              ),
            );
      case TransactionFormMode.expense:
        throw StateError(
          'Expense transactions are handled by _ExpenseSceneFormWorkflow.',
        );
    }
  }

  Future<void> edit({
    required TransactionFormState state,
    required String transactionId,
    required Money amount,
    required Money? feeAmount,
    required String? note,
  }) async {
    final notePatch = stringPatch(note);
    final counterpartyId = counterpartyPatch(state.counterpartyId);

    switch (state.mode) {
      case TransactionFormMode.income:
        final allocations = incomeAllocations(state, amount);
        await _editService.editIncome(
          EditIncomeCommand(
            transactionId: transactionId,
            amount: amount,
            categoryAllocations: allocations.categories,
            settlementAllocations: allocations.settlements,
            occurredAt: state.occurredAt,
            counterpartyId: counterpartyId,
            note: notePatch,
            isExcludedFromStats: state.excludeStats,
            tagIds: state.selectedTagIds,
          ),
        );
      case TransactionFormMode.transfer:
        final fromAccountId = effectiveAccountId(
          state.fromAccountId,
          state.settlementAccounts,
        );
        final toAccountId = effectiveAccountId(
          state.toAccountId,
          state.settlementAccounts,
        );
        if (fromAccountId == null || toAccountId == null) {
          throw invalidCommandException('请选择转出和转入账户');
        }
        await _editService.editTransfer(
          EditTransferCommand(
            transactionId: transactionId,
            amount: amount,
            outgoingAllocations: singleAllocation(
              accountId: fromAccountId,
              amount: amount,
            ),
            incomingAllocations: singleAllocation(
              accountId: toAccountId,
              amount: amount,
            ),
            feeAmount: feeAmount,
            occurredAt: state.occurredAt,
            counterpartyId: counterpartyId,
            note: notePatch,
            isExcludedFromStats: state.excludeStats,
            isExcludedFromBudget: state.excludeBudget,
            tagIds: state.selectedTagIds,
          ),
        );
      case TransactionFormMode.borrowing:
        final liabilityAccountId = effectiveAccountId(
          state.liabilityAccountId,
          state.liabilityAccounts,
        );
        final receiveAccountId = effectiveAccountId(
          state.toAccountId,
          state.fundAccounts,
        );
        if (liabilityAccountId == null || receiveAccountId == null) {
          throw invalidCommandException('请选择负债账户和收款账户');
        }
        await _editService.editBorrowing(
          EditBorrowingCommand(
            transactionId: transactionId,
            amount: amount,
            liabilityAccountId: liabilityAccountId,
            receiveAccountId: receiveAccountId,
            occurredAt: state.occurredAt,
            counterpartyId: counterpartyId,
            note: notePatch,
            tagIds: state.selectedTagIds,
          ),
        );
      case TransactionFormMode.lending:
        final paidFromAccountId = effectiveAccountId(
          state.fromAccountId,
          state.fundAccounts,
        );
        final receivableAccountId = effectiveAccountId(
          state.ordinaryReceivableAccountId,
          state.ordinaryReceivableAccounts,
        );
        if (paidFromAccountId == null || receivableAccountId == null) {
          throw invalidCommandException(
            '请选择${state.relationScene.cashAccountLabel}和'
            '${state.relationScene.receivableAccountLabel}',
          );
        }
        await (_editService as ReceivableTransactionEditAppService).editLending(
          EditLendingCommand(
            transactionId: transactionId,
            amount: amount,
            receivableAccountId: receivableAccountId,
            paidFromAccountId: paidFromAccountId,
            occurredAt: state.occurredAt,
            counterpartyId: counterpartyId,
            note: notePatch,
            tagIds: state.selectedTagIds,
          ),
        );
      case TransactionFormMode.expense:
        throw StateError(
          'Expense transactions are handled by _ExpenseSceneFormWorkflow.',
        );
    }
  }
}
