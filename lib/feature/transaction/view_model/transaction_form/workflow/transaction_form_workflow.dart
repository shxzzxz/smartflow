part of '../transaction_form_view_model.dart';

final class _TransactionFormWorkflowDispatcher {
  _TransactionFormWorkflowDispatcher({
    required TransactionPostingAppService postingService,
    required TransactionEditAppService editService,
    required AdvanceOrchestrationAppService advanceService,
    required ConsumptionInstallmentAppService consumptionInstallmentService,
    required AmortizationPlanAppService amortizationService,
  }) : _ledger = _LedgerTransactionFormWorkflow(
         postingService: postingService,
         editService: editService,
       ),
       _expense = _ExpenseSceneFormWorkflow(advanceService),
       _installment = _ConsumptionInstallmentFormWorkflow(
         consumptionInstallmentService,
       ),
       _amortization = _AmortizationFormWorkflow(amortizationService);

  final _LedgerTransactionFormWorkflow _ledger;
  final _ExpenseSceneFormWorkflow _expense;
  final _ConsumptionInstallmentFormWorkflow _installment;
  final _AmortizationFormWorkflow _amortization;

  Future<void> create({
    required TransactionFormState state,
    required Money amount,
    required Money? feeAmount,
    Money? discountAmount,
    required String? note,
    required ConsumptionInstallmentConfiguration? consumptionInstallment,
    required AmortizationConfigurationDraft? amortizationConfiguration,
  }) {
    return switch (state.mode) {
      TransactionFormMode.expense
          when state.expenseScene == TransactionExpenseScene.amortization =>
        _amortization.create(
          state: state,
          amount: amount,
          note: note,
          feeAmount: feeAmount,
          configuration: amortizationConfiguration,
        ),
      TransactionFormMode.income
          when state.incomeScene == TransactionIncomeScene.amortization =>
        _amortization.create(
          state: state,
          amount: amount,
          note: note,
          feeAmount: feeAmount,
          configuration: amortizationConfiguration,
        ),
      TransactionFormMode.expense
          when state.expenseScene ==
              TransactionExpenseScene.consumptionInstallment =>
        _installment.create(
          state: state,
          amount: amount,
          note: note,
          configuration: consumptionInstallment,
        ),
      TransactionFormMode.expense => _expense.create(
        state: state,
        amount: amount,
        note: note,
      ),
      TransactionFormMode.income ||
      TransactionFormMode.transfer ||
      TransactionFormMode.borrowing ||
      TransactionFormMode.lending => _ledger.create(
        state: state,
        amount: amount,
        feeAmount: feeAmount,
        discountAmount: discountAmount,
        note: note,
      ),
    };
  }

  Future<void> edit({
    required TransactionFormState state,
    required String transactionId,
    required String? amortizationPlanId,
    required Money amount,
    required Money? feeAmount,
    Money? discountAmount,
    required String? note,
    required AmortizationConfigurationDraft? amortizationConfiguration,
  }) {
    return switch (state.mode) {
      TransactionFormMode.expense when state.isAmortization =>
        _amortization.update(
          planId:
              amortizationPlanId ?? (throw invalidCommandException('无法定位摊销计划')),
          state: state,
          amount: amount,
          feeAmount: feeAmount,
          note: note,
          configuration: amortizationConfiguration,
        ),
      TransactionFormMode.income when state.isAmortization =>
        _amortization.update(
          planId:
              amortizationPlanId ?? (throw invalidCommandException('无法定位摊销计划')),
          state: state,
          amount: amount,
          feeAmount: feeAmount,
          note: note,
          configuration: amortizationConfiguration,
        ),
      TransactionFormMode.expense => _expense.edit(
        state: state,
        transactionId: transactionId,
        amount: amount,
        note: note,
      ),
      TransactionFormMode.income ||
      TransactionFormMode.transfer ||
      TransactionFormMode.borrowing ||
      TransactionFormMode.lending => _ledger.edit(
        state: state,
        transactionId: transactionId,
        amount: amount,
        feeAmount: feeAmount,
        discountAmount: discountAmount,
        note: note,
      ),
    };
  }
}
