import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../application/ledger/ledger_command_api.dart';
import '../../../design_system/token/spacing.dart';
import '../../../design_system/widget/app_datetime_picker.dart';
import '../../../design_system/widget/app_form_field.dart';
import '../../../design_system/widget/app_form_section.dart';
import '../../../design_system/widget/app_submit_button.dart';
import 'package:smartflow/widget/business/finance/money_input.dart';
import 'package:smartflow/widget/business/form/plain_transaction_fields.dart';
import '../../shared/view_model/ui_action_outcome.dart';
import '../view_model/repayment_form_view_model.dart';

class RepaymentFormPage extends ConsumerStatefulWidget {
  const RepaymentFormPage({required this.liabilityAccountId, super.key})
    : editTransactionId = null,
      assert(liabilityAccountId != null);

  const RepaymentFormPage.edit({required this.editTransactionId, super.key})
    : liabilityAccountId = null,
      assert(editTransactionId != null);

  final String? liabilityAccountId;
  final String? editTransactionId;

  @override
  ConsumerState<RepaymentFormPage> createState() => _RepaymentFormPageState();
}

class _RepaymentFormPageState extends ConsumerState<RepaymentFormPage> {
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
    final provider = repaymentFormViewModelProvider(_args);
    final asyncState = ref.watch(provider);
    return Scaffold(
      backgroundColor: Theme.of(context).colorScheme.surface,
      appBar: AppBar(title: Text(_pageTitle)),
      body: switch (asyncState) {
        AsyncData(value: final state) => _buildLoaded(provider, state),
        AsyncError() => const Center(child: Text('加载失败，请稍后重试')),
        _ => const Center(child: CircularProgressIndicator()),
      },
    );
  }

  Widget _buildLoaded(
    RepaymentFormViewModelProvider provider,
    RepaymentFormState state,
  ) {
    switch (state.status) {
      case RepaymentFormLoadStatus.notFound:
        return const Center(child: Text('还款记录不存在'));
      case RepaymentFormLoadStatus.notEditable:
        return const Center(child: Text('该还款记录不可编辑'));
      case RepaymentFormLoadStatus.loaded:
        break;
    }
    _hydrateControllers(state);
    final liabilityAccount = _findAccount(
      state.liabilityAccounts,
      state.liabilityAccountId,
    );
    final paidFromAccount = _findAccount(
      state.repaymentAccounts,
      state.paidFromAccountId,
    );
    final isEdit = widget.editTransactionId != null;

    return Form(
      key: _formKey,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(
          AppSpacing.space28,
          AppSpacing.space18,
          AppSpacing.space28,
          AppSpacing.space24,
        ),
        children: [
          AppFormSection(
            title: '还款信息',
            children: [
              AccountPlainFormRow(
                label: '债务账户',
                account: liabilityAccount,
                selectedId: state.liabilityAccountId,
                placeholder: '请选择债务账户',
                onTap:
                    (isEdit || state.liabilityAccounts.isEmpty)
                        ? null
                        : () => _pickAccount(
                          title: '选择债务账户',
                          accounts: state.liabilityAccounts,
                          selectedId: state.liabilityAccountId,
                          onSelected:
                              (value) => ref
                                  .read(provider.notifier)
                                  .setLiabilityAccountId(value),
                        ),
                onChanged: ref.read(provider.notifier).setLiabilityAccountId,
                validator: (value) => value == null ? '请选择债务账户' : null,
              ),
              MoneyPlainFormRow(
                label: '本金',
                controller: _principalController,
                hintText: '请输入还款本金',
                validator: validateNonNegativeMoneyText,
              ),
              MoneyPlainFormRow(
                label: '利息',
                controller: _interestController,
                hintText: '请输入利息（可选）',
                validator: validateOptionalNonNegativeMoneyText,
              ),
              MoneyPlainFormRow(
                label: '手续费',
                controller: _feeController,
                hintText: '请输入手续费（可选）',
                validator: validateOptionalNonNegativeMoneyText,
              ),
              MoneyPlainFormRow(
                label: '优惠',
                controller: _discountController,
                hintText: '请输入优惠（可选）',
                validator: validateOptionalNonNegativeMoneyText,
              ),
              DateTimePlainFormRow(
                label: '还款日期',
                dateTime: state.occurredAt,
                value: _formatDateTime(state.occurredAt),
                onTap: () => _pickDate(provider, state.occurredAt),
                onChanged: (value) {
                  if (value != null) {
                    ref.read(provider.notifier).setOccurredAt(value);
                  }
                },
              ),
              AccountPlainFormRow(
                label: '还款账户',
                account: paidFromAccount,
                selectedId: state.paidFromAccountId,
                placeholder: '请选择还款账户',
                onTap:
                    state.repaymentAccounts.isEmpty
                        ? null
                        : () => _pickAccount(
                          title: '选择还款账户',
                          accounts: state.repaymentAccounts,
                          selectedId: state.paidFromAccountId,
                          onSelected:
                              (value) => ref
                                  .read(provider.notifier)
                                  .setPaidFromAccountId(value),
                        ),
                onChanged: ref.read(provider.notifier).setPaidFromAccountId,
                validator: (value) => value == null ? '请选择还款账户' : null,
              ),
              NotePlainFormRow(controller: _noteController),
            ],
          ),
          const SizedBox(height: AppSpacing.space24),
          AppSubmitButton(
            label: '保存',
            loading: state.submitting,
            onPressed: () => _submit(provider),
          ),
        ],
      ),
    );
  }

  Future<void> _pickDate(
    RepaymentFormViewModelProvider provider,
    DateTime occurredAt,
  ) async {
    final picked = await showAppDateTimePicker(
      context: context,
      initialDateTime: occurredAt,
      title: '选择还款日期',
    );
    if (picked == null || !mounted) return;
    ref.read(provider.notifier).setOccurredAt(picked);
  }

  Future<void> _pickAccount({
    required String title,
    required List<Account> accounts,
    required String? selectedId,
    required ValueChanged<String> onSelected,
  }) async {
    final selected = await showAccountPickerSheet(
      context: context,
      title: title,
      accounts: accounts,
      selectedId: selectedId,
    );
    if (!mounted || selected == null) return;
    onSelected(selected);
  }

  Future<void> _submit(RepaymentFormViewModelProvider provider) async {
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

  void _hydrateControllers(RepaymentFormState state) {
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

  RepaymentFormArgs get _args {
    return RepaymentFormArgs(
      liabilityAccountId: widget.liabilityAccountId,
      editTransactionId: widget.editTransactionId,
    );
  }

  String get _pageTitle => widget.editTransactionId == null ? '还款' : '编辑还款';
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
