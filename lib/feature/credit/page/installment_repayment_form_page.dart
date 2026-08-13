import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../application/ledger/ledger_command_api.dart';
import '../../../design_system/token/spacing.dart';
import '../../../design_system/widget/app_datetime_picker.dart';
import '../../../design_system/widget/app_form_field.dart';
import '../../../design_system/widget/app_page_header.dart';
import '../../../design_system/widget/app_submit_button.dart';
import 'package:smartflow/widget/business/form/plain_transaction_fields.dart';
import '../../shared/view_model/ui_action_outcome.dart';
import '../view_model/installment_repayment_form_view_model.dart';
import '../widget/repayment_form_fields.dart';

class InstallmentRepaymentFormPage extends ConsumerStatefulWidget {
  const InstallmentRepaymentFormPage({required this.contractId, super.key});

  final String contractId;

  @override
  ConsumerState<InstallmentRepaymentFormPage> createState() =>
      _InstallmentRepaymentFormPageState();
}

class _InstallmentRepaymentFormPageState
    extends ConsumerState<InstallmentRepaymentFormPage> {
  final _formKey = GlobalKey<FormState>();
  final _principalController = TextEditingController();
  final _interestController = TextEditingController();
  final _feeController = TextEditingController();
  final _discountController = TextEditingController();
  final _noteController = TextEditingController();
  bool _controllersHydrated = false;

  @override
  void dispose() {
    _principalController.dispose();
    _interestController.dispose();
    _feeController.dispose();
    _discountController.dispose();
    _noteController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final provider = installmentRepaymentFormViewModelProvider(_args);
    final asyncState = ref.watch(provider);
    return Scaffold(
      backgroundColor: Theme.of(context).colorScheme.surface,
      body: SafeArea(
        child: Column(
          children: [
            const AppPageHeader(title: '提前还款'),
            Expanded(
              child: switch (asyncState) {
                AsyncData(value: final state) => _buildLoaded(provider, state),
                AsyncError() => const Center(child: Text('加载失败，请稍后重试')),
                _ => const Center(child: CircularProgressIndicator()),
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLoaded(
    InstallmentRepaymentFormViewModelProvider provider,
    InstallmentRepaymentFormState state,
  ) {
    switch (state.status) {
      case InstallmentRepaymentFormStatus.notFound:
        return const Center(child: Text('合同不存在'));
      case InstallmentRepaymentFormStatus.loaded:
        break;
    }
    _hydrateControllers(state);

    return Form(
      key: _formKey,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(
          AppSpacing.space16,
          AppSpacing.space18,
          AppSpacing.space16,
          AppSpacing.space24,
        ),
        children: [
          CreditRepaymentFormSection(
            title: '还款信息',
            children: [
              CreditRepaymentAmountFields(
                principalController: _principalController,
                interestController: _interestController,
                feeController: _feeController,
                discountController: _discountController,
              ),
              CreditRepaymentTransactionFields(
                createTransaction: state.createTransaction,
                onCreateTransactionChanged:
                    (value) =>
                        ref.read(provider.notifier).setCreateTransaction(value),
                occurredAt: state.occurredAt,
                occurredAtText: _formatDateTime(state.occurredAt),
                onPickDate:
                    (onSelected) => _pickDate(state.occurredAt, onSelected),
                onOccurredAtChanged: (value) {
                  if (value != null) {
                    ref.read(provider.notifier).setOccurredAt(value);
                  }
                },
                repaymentAccount: _findAccount(
                  state.accounts,
                  state.paidFromAccountId,
                ),
                selectedRepaymentAccountId: state.paidFromAccountId,
                repaymentAccounts: state.accounts,
                onRepaymentAccountChanged:
                    ref.read(provider.notifier).setPaidFromAccountId,
                onPickAccount:
                    (onSelected) => _pickAccount(
                      accounts: state.accounts,
                      selectedId: state.paidFromAccountId,
                      onSelected: onSelected,
                    ),
              ),
              NotePlainFormRow(controller: _noteController),
            ],
          ),
          const SizedBox(height: AppSpacing.space24),
          const CreditRepaymentSubmitHint(text: '提交后，全部待还期次金额将按剩余本金重新计算。'),
          AppSubmitButton(
            label: '提交并重算',
            loading: state.submitting,
            onPressed: () => _submit(provider),
          ),
        ],
      ),
    );
  }

  Future<void> _pickDate(
    DateTime occurredAt,
    ValueChanged<DateTime?> onSelected,
  ) async {
    final picked = await showAppDateTimePicker(
      context: context,
      initialDateTime: occurredAt,
      title: '选择还款日期',
    );
    if (picked == null || !mounted) return;
    onSelected(picked);
  }

  Future<void> _pickAccount({
    required List<Account> accounts,
    required String? selectedId,
    required ValueChanged<String?> onSelected,
  }) async {
    final selected = await showAccountPickerSheet(
      context: context,
      title: '选择还款账户',
      accounts: accounts,
      selectedId: selectedId,
    );
    if (!mounted || selected == null) return;
    onSelected(selected);
  }

  Future<void> _submit(
    InstallmentRepaymentFormViewModelProvider provider,
  ) async {
    if (!_formKey.currentState!.validate()) return;
    final outcome = await ref
        .read(provider.notifier)
        .submit(
          principalText: _principalController.text,
          interestText: _interestController.text,
          feeText: _feeController.text,
          discountText: _discountController.text,
          noteText: _noteController.text,
        );
    if (!mounted) return;
    switch (outcome) {
      case SubmitSuccess():
        context.pop();
      case SubmitFailure(:final error):
        _showError(error.message);
    }
  }

  void _hydrateControllers(InstallmentRepaymentFormState state) {
    if (_controllersHydrated) return;
    syncTextControllerText(_principalController, state.principalText);
    syncTextControllerText(_interestController, state.interestText);
    syncTextControllerText(_feeController, state.feeText);
    syncTextControllerText(_discountController, state.discountText);
    syncTextControllerText(_noteController, state.noteText);
    _controllersHydrated = true;
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), behavior: SnackBarBehavior.floating),
    );
  }

  InstallmentRepaymentFormArgs get _args {
    return InstallmentRepaymentFormArgs(contractId: widget.contractId);
  }
}

Account? _findAccount(List<Account> accounts, String? id) {
  if (id == null) return null;
  for (final account in accounts) {
    if (account.id == id) return account;
  }
  return null;
}

String _formatDateTime(DateTime date) {
  final time =
      '${date.hour.toString().padLeft(2, '0')}:'
      '${date.minute.toString().padLeft(2, '0')}';
  return '${date.year}-${date.month.toString().padLeft(2, '0')}-'
      '${date.day.toString().padLeft(2, '0')} $time';
}
