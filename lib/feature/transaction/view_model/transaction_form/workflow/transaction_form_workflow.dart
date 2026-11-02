import '../../../../../application/credit/credit_command_api.dart';
import '../../../../../application/ledger/ledger_command_api.dart';
import '../../../../../application/orchestration/orchestration_command_api.dart';
import '../../../../../core/error/app_exception.dart';
import '../../../../../core/money/money.dart';
import '../../../../../core/patch/patch.dart';
import '../../../../../domain/ledger/valobj/ledger_error_code.dart';
import '../../../../amortization/presentation/amortization_configuration_draft.dart';
import '../../../presentation/transaction_form_presentation.dart';
import '../transaction_form_helpers.dart';
import '../transaction_form_state.dart';

part 'transaction_form_command_support.dart';
part 'transaction_ledger_workflow.dart';
part 'expense_scene_workflow.dart';
part 'consumption_installment_workflow.dart';
part 'amortization_form_workflow.dart';

final class TransactionFormWorkflowDispatcher {
  TransactionFormWorkflowDispatcher({
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
          configuration: amortizationConfiguration,
        ),
      TransactionFormMode.income
          when state.incomeScene == TransactionIncomeScene.amortization =>
        _amortization.create(
          state: state,
          amount: amount,
          note: note,
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
        note: note,
      ),
    };
  }

  Future<void> edit({
    required TransactionFormState state,
    required String transactionId,
    required Money amount,
    required Money? feeAmount,
    required String? note,
  }) {
    return switch (state.mode) {
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
        note: note,
      ),
    };
  }
}
