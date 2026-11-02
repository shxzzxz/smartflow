part of 'transaction_form_view_model.dart';

extension CommonTransactionFormInteractions on TransactionFormViewModel {
  void setAaPeopleCount(int value) {
    _update(
      (current) => current.copyWith(aaPeopleCount: value.clamp(2, 99).toInt()),
    );
  }

  void setExcludeStats(bool value) {
    _update((current) => current.copyWith(excludeStats: value));
  }

  void setTagIds(Set<String> value) {
    _update((current) => current.copyWith(selectedTagIds: value));
  }

  void setCounterpartyId(String? value) {
    _update((current) => current.copyWith(counterpartyId: value));
  }

  void setCounterparty(CounterpartyView? value) {
    _update((current) {
      final counterparties = [...current.counterparties];
      if (value != null && !counterparties.any((item) => item.id == value.id)) {
        counterparties
          ..add(value)
          ..sort((left, right) => left.name.compareTo(right.name));
      }
      return current.copyWith(
        counterpartyId: value?.id,
        counterparties: counterparties,
      );
    });
  }

  void setExcludeBudget(bool value) {
    _update((current) => current.copyWith(excludeBudget: value));
  }

  void clearForNext({DateTime? occurredAt}) {
    _update(
      (current) => current.copyWith(
        categoryAllocations: current.entryMode == TransactionEntryMode.allocated
            ? const []
            : current.categoryAllocations,
        settlementAllocations:
            current.entryMode == TransactionEntryMode.allocated
            ? const []
            : current.settlementAllocations,
        advanceReceivableAccountId: null,
        advanceScenario: AdvanceScenario.reimbursement,
        expenseScene: TransactionExpenseScene.ordinary,
        incomeScene: TransactionIncomeScene.ordinary,
        amortizationDeferralAccountId: null,
        aaPeopleCount: 2,
        ordinaryReceivableAccountId: null,
        excludeStats: false,
        excludeBudget: false,
        occurredAt: occurredAt ?? DateTime.now(),
      ),
    );
  }
}
