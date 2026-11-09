part of 'transaction_form_view_model.dart';

extension ExpenseSceneTransactionFormInteractions on TransactionFormViewModel {
  void setAdvanceAccountId(String? value) {
    _update((current) => current.copyWith(advanceReceivableAccountId: value));
  }

  void setAdvanceScenario(AdvanceScenario value) {
    setExpenseScene(transactionExpenseSceneForAdvanceScenario(value));
  }

  void setExpenseScene(TransactionExpenseScene value) {
    _defaultAccountRequestRevision += 1;
    _update((current) {
      final changingMode = current.mode != TransactionFormMode.expense;
      final enteringConsumptionInstallment =
          value == TransactionExpenseScene.consumptionInstallment &&
          current.expenseScene != value;
      final enteringAmortization =
          value == TransactionExpenseScene.amortization &&
          current.expenseScene != value;
      final resetEntry =
          changingMode ||
          enteringConsumptionInstallment ||
          enteringAmortization;
      final selectedAccountId = current.advanceReceivableAccountId;
      final availableAccountIds = {
        for (final account in advanceAccountsForExpenseScene(
          value,
          current.advanceReceivableAccounts,
        ))
          account.id,
      };
      final selectedAccount = current.advanceReceivableAccounts
          .where((account) => account.id == selectedAccountId)
          .firstOrNull;
      final canKeepSelectedAccount =
          selectedAccountId != null &&
          selectedAccount != null &&
          (selectedAccount.profileKey == null ||
              availableAccountIds.contains(selectedAccountId));
      final currentCreditAccount = current.creditAccounts
          .where((account) => account.id == current.fromAccountId)
          .firstOrNull;
      final consumptionAccountId =
          currentCreditAccount?.id ?? current.creditAccounts.firstOrNull?.id;
      final currentSettlementAccount = current.settlementAccounts
          .where((account) => account.id == current.fromAccountId)
          .firstOrNull;
      final amortizationSettlementAccountId =
          currentSettlementAccount?.id ??
          current.fundAccounts.firstOrNull?.id ??
          current.settlementAccounts.firstOrNull?.id;
      final currentDeferralAccount = current.prepaidExpenseAccounts
          .where(
            (account) => account.id == current.amortizationDeferralAccountId,
          )
          .firstOrNull;
      return current.copyWith(
        mode: TransactionFormMode.expense,
        entryMode: resetEntry ? TransactionEntryMode.normal : current.entryMode,
        categoryAllocations: resetEntry
            ? const []
            : current.categoryAllocations,
        settlementAllocations: resetEntry
            ? const []
            : current.settlementAllocations,
        fromAccountId: switch (value) {
          TransactionExpenseScene.consumptionInstallment =>
            consumptionAccountId,
          TransactionExpenseScene.amortization =>
            amortizationSettlementAccountId,
          _ => current.fromAccountId,
        },
        expenseScene: value,
        incomeScene: TransactionIncomeScene.ordinary,
        amortizationDeferralAccountId:
            value == TransactionExpenseScene.amortization
            ? currentDeferralAccount?.id ??
                  current.prepaidExpenseAccounts.firstOrNull?.id
            : null,
        advanceScenario: value.advanceScenario ?? AdvanceScenario.reimbursement,
        advanceReceivableAccountId: canKeepSelectedAccount
            ? selectedAccountId
            : null,
        ordinaryReceivableAccountId: null,
        excludeBudget: current.excludeBudget,
      );
    });
  }

  void setIncomeScene(TransactionIncomeScene value) {
    _defaultAccountRequestRevision += 1;
    _update((current) {
      final enteringAmortization =
          value == TransactionIncomeScene.amortization &&
          current.incomeScene != value;
      final currentSettlementAccount = current.settlementAccounts
          .where((account) => account.id == current.toAccountId)
          .firstOrNull;
      final currentDeferralAccount = current.deferredIncomeAccounts
          .where(
            (account) => account.id == current.amortizationDeferralAccountId,
          )
          .firstOrNull;
      return current.copyWith(
        mode: TransactionFormMode.income,
        entryMode: enteringAmortization
            ? TransactionEntryMode.normal
            : current.entryMode,
        categoryAllocations: enteringAmortization
            ? const []
            : current.categoryAllocations,
        settlementAllocations: enteringAmortization
            ? const []
            : current.settlementAllocations,
        toAccountId: value == TransactionIncomeScene.amortization
            ? currentSettlementAccount?.id ??
                  current.fundAccounts.firstOrNull?.id ??
                  current.settlementAccounts.firstOrNull?.id
            : current.toAccountId,
        expenseScene: TransactionExpenseScene.ordinary,
        incomeScene: value,
        amortizationDeferralAccountId:
            value == TransactionIncomeScene.amortization
            ? currentDeferralAccount?.id ??
                  current.deferredIncomeAccounts.firstOrNull?.id
            : null,
        ordinaryReceivableAccountId: null,
      );
    });
  }

  void setAmortizationDeferralAccountId(String? value) {
    _update(
      (current) => current.copyWith(amortizationDeferralAccountId: value),
    );
  }
}
