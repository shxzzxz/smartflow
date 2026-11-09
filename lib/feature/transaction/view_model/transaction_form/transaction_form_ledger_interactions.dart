part of 'transaction_form_view_model.dart';

extension LedgerTransactionFormInteractions on TransactionFormViewModel {
  void setMode(TransactionFormMode value) {
    _update((current) {
      if (current.mode == value) return current;
      return current.copyWith(
        mode: value,
        relationScene: value == TransactionFormMode.borrowing
            ? TransactionRelationScene.borrowing
            : value == TransactionFormMode.lending
            ? TransactionRelationScene.lending
            : current.relationScene,
        entryMode: TransactionEntryMode.normal,
        categoryAllocations: const [],
        settlementAllocations: const [],
        advanceReceivableAccountId: null,
        advanceScenario: AdvanceScenario.reimbursement,
        expenseScene: TransactionExpenseScene.ordinary,
        incomeScene: TransactionIncomeScene.ordinary,
        amortizationDeferralAccountId: null,
        ordinaryReceivableAccountId: null,
        excludeStats:
            value == TransactionFormMode.transfer ||
                value == TransactionFormMode.borrowing ||
                value == TransactionFormMode.lending
            ? false
            : current.excludeStats,
        excludeBudget: value == TransactionFormMode.expense
            ? current.excludeBudget
            : false,
      );
    });
  }

  void setOccurredAt(DateTime value) {
    _update((current) => current.copyWith(occurredAt: value));
  }

  Future<void> setExpenseCategory({
    required String? rootId,
    required String? categoryId,
  }) async {
    final requestRevision = ++_defaultAccountRequestRevision;
    _update(
      (current) => current.copyWith(
        expenseRootId: rootId,
        expenseCategoryId: categoryId,
      ),
    );
    await _applyLastUsedSettlementAccount(
      categoryId: categoryId,
      requestRevision: requestRevision,
      selectedCategoryId: (current) => current.expenseCategoryId,
      selectAccount: (current, accountId) =>
          current.copyWith(fromAccountId: accountId),
    );
  }

  Future<void> setIncomeCategory({
    required String? rootId,
    required String? categoryId,
  }) async {
    final requestRevision = ++_defaultAccountRequestRevision;
    _update(
      (current) =>
          current.copyWith(incomeRootId: rootId, incomeCategoryId: categoryId),
    );
    await _applyLastUsedSettlementAccount(
      categoryId: categoryId,
      requestRevision: requestRevision,
      selectedCategoryId: (current) => current.incomeCategoryId,
      selectAccount: (current, accountId) =>
          current.copyWith(toAccountId: accountId),
    );
  }

  Future<void> _applyLastUsedSettlementAccount({
    required String? categoryId,
    required int requestRevision,
    required String? Function(TransactionFormState) selectedCategoryId,
    required TransactionFormState Function(TransactionFormState, String)
    selectAccount,
  }) async {
    if (_editTransactionId != null || categoryId == null) return;
    try {
      final accountId = await _findLastUsedSettlementAccountId(categoryId);
      final current = _currentState;
      if (accountId == null ||
          current == null ||
          (current.mode == TransactionFormMode.expense &&
              current.expenseScene ==
                  TransactionExpenseScene.consumptionInstallment) ||
          current.isAmortization ||
          requestRevision != _defaultAccountRequestRevision ||
          selectedCategoryId(current) != categoryId ||
          !(current.mode == TransactionFormMode.expense
                  ? current.expenseSettlementAccounts
                  : current.settlementAccounts)
              .any((account) => account.id == accountId)) {
        return;
      }
      _update((current) => selectAccount(current, accountId));
    } on Exception catch (error, stackTrace) {
      _logger.warning(
        'Failed to load the last settlement account for category',
        error,
        stackTrace,
      );
    }
  }

  void setFromAccountId(String? value) {
    _defaultAccountRequestRevision += 1;
    _update((current) => current.copyWith(fromAccountId: value));
  }

  void setToAccountId(String? value) {
    _defaultAccountRequestRevision += 1;
    _update((current) => current.copyWith(toAccountId: value));
  }

  void setRelationScene(TransactionRelationScene value) {
    _update((current) {
      final changingMode = current.mode != value.mode;
      return current.copyWith(
        mode: value.mode,
        relationScene: value,
        entryMode: changingMode
            ? TransactionEntryMode.normal
            : current.entryMode,
        categoryAllocations: changingMode
            ? const []
            : current.categoryAllocations,
        settlementAllocations: changingMode
            ? const []
            : current.settlementAllocations,
        advanceReceivableAccountId: null,
        advanceScenario: AdvanceScenario.reimbursement,
        expenseScene: TransactionExpenseScene.ordinary,
        incomeScene: TransactionIncomeScene.ordinary,
        amortizationDeferralAccountId: null,
        ordinaryReceivableAccountId: value.mode == TransactionFormMode.lending
            ? current.ordinaryReceivableAccountId
            : null,
        liabilityAccountId: value.mode == TransactionFormMode.borrowing
            ? current.liabilityAccountId
            : null,
        excludeStats: false,
        excludeBudget: false,
      );
    });
  }

  void setCategoryAllocations(List<AccountAmountAllocation> allocations) {
    _update((current) => current.copyWith(categoryAllocations: allocations));
  }

  void setSettlementAllocations(List<AccountAmountAllocation> allocations) {
    _update((current) {
      final consumptionInstallment =
          current.mode == TransactionFormMode.expense &&
          current.expenseScene ==
              TransactionExpenseScene.consumptionInstallment &&
          current.entryMode == TransactionEntryMode.allocated;
      if (!consumptionInstallment) {
        return current.copyWith(settlementAllocations: allocations);
      }
      final creditAccountIds = {
        for (final account in current.creditAccounts) account.id,
      };
      final allocatedCreditIds = [
        for (final allocation in allocations)
          if (allocation.amount.minorUnits > 0 &&
              creditAccountIds.contains(allocation.accountId))
            allocation.accountId,
      ];
      final selectedInstallmentAccountId =
          allocatedCreditIds.contains(current.fromAccountId)
          ? current.fromAccountId
          : allocatedCreditIds.firstOrNull;
      return current.copyWith(
        settlementAllocations: allocations,
        fromAccountId: selectedInstallmentAccountId,
      );
    });
  }

  void useAllocatedEntry(Money amount) {
    _defaultAccountRequestRevision += 1;
    _update((current) {
      final consumptionInstallment =
          current.mode == TransactionFormMode.expense &&
          current.expenseScene ==
              TransactionExpenseScene.consumptionInstallment;
      final categoryId = switch (current.mode) {
        TransactionFormMode.expense => current.expenseCategoryId,
        TransactionFormMode.income => current.incomeCategoryId,
        _ => null,
      };
      final settlementId = effectiveAccountId(
        switch (current.mode) {
          TransactionFormMode.expense => current.fromAccountId,
          TransactionFormMode.income => current.toAccountId,
          _ => null,
        },
        current.isAmortization
            ? current.settlementAccounts
            : current.mode == TransactionFormMode.expense
            ? current.expenseSettlementAccounts
            : current.settlementAccounts,
      );
      return current.copyWith(
        entryMode: TransactionEntryMode.allocated,
        categoryAllocations: categoryId == null
            ? const []
            : singleAllocation(accountId: categoryId, amount: amount),
        settlementAllocations: settlementId == null
            ? const []
            : singleAllocation(accountId: settlementId, amount: amount),
        expenseCategoryId: null,
        expenseRootId: null,
        fromAccountId: consumptionInstallment ? current.fromAccountId : null,
        incomeCategoryId: null,
        incomeRootId: null,
        toAccountId: null,
      );
    });
  }

  void useNormalEntry() {
    _defaultAccountRequestRevision += 1;
    _update((current) {
      final consumptionInstallment =
          current.mode == TransactionFormMode.expense &&
          current.expenseScene ==
              TransactionExpenseScene.consumptionInstallment;
      return current.copyWith(
        entryMode: TransactionEntryMode.normal,
        categoryAllocations: const [],
        settlementAllocations: const [],
        expenseCategoryId: null,
        expenseRootId: null,
        fromAccountId: consumptionInstallment ? current.fromAccountId : null,
        incomeCategoryId: null,
        incomeRootId: null,
        toAccountId: null,
      );
    });
  }

  void setOrdinaryReceivableAccountId(String? value) {
    _update((current) => current.copyWith(ordinaryReceivableAccountId: value));
  }

  void setLiabilityAccountId(String? value) {
    _update((current) => current.copyWith(liabilityAccountId: value));
  }
}
