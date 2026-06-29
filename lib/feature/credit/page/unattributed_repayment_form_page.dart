import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../application/ledger/ledger_query_api.dart';
import '../../../core/money/money.dart';
import '../../../design_system/token/spacing.dart';
import '../../../design_system/widget/app_datetime_picker.dart';
import '../../../design_system/widget/app_form_field.dart';
import '../../../design_system/widget/app_plain_form_row.dart';
import '../../../design_system/widget/app_submit_button.dart';
import 'package:smartflow/widget/business/form/plain_transaction_fields.dart';
import '../../shared/view_model/ui_action_outcome.dart';
import '../view_model/unattributed_repayment_form_view_model.dart';

class UnattributedRepaymentFormPage extends ConsumerStatefulWidget {
  const UnattributedRepaymentFormPage({required this.accountId, super.key});

  final String accountId;

  @override
  ConsumerState<UnattributedRepaymentFormPage> createState() =>
      _UnattributedRepaymentFormPageState();
}

class _UnattributedRepaymentFormPageState
    extends ConsumerState<UnattributedRepaymentFormPage> {
  final _formKey = GlobalKey<FormState>();
  final _amountController = TextEditingController();
  final _noteController = TextEditingController();
  bool _syncing = false;

  @override
  void initState() {
    super.initState();
    _amountController.addListener(
      () => _setText(
        (vm, value) => vm.setAmountText(value),
        _amountController.text,
      ),
    );
    _noteController.addListener(
      () =>
          _setText((vm, value) => vm.setNoteText(value), _noteController.text),
    );
  }

  @override
  void dispose() {
    _amountController.dispose();
    _noteController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final provider = unattributedRepaymentFormViewModelProvider(
      widget.accountId,
    );
    final asyncState = ref.watch(provider);
    return Scaffold(
      backgroundColor: Theme.of(context).colorScheme.surface,
      appBar: AppBar(title: const Text('账单外还款')),
      body: switch (asyncState) {
        AsyncData(value: final state) => _buildState(provider, state),
        AsyncError(:final error) => Center(child: Text('加载失败：$error')),
        _ => const Center(child: CircularProgressIndicator()),
      },
    );
  }

  Widget _buildState(
    UnattributedRepaymentFormViewModelProvider provider,
    UnattributedRepaymentFormState state,
  ) {
    switch (state.status) {
      case UnattributedRepaymentFormLoadStatus.notFound:
        return const Center(child: Text('信贷账户不存在'));
      case UnattributedRepaymentFormLoadStatus.noDebt:
        return const Center(child: Text('没有可偿还的账单外欠款'));
      case UnattributedRepaymentFormLoadStatus.loaded:
        return _buildForm(provider, state);
    }
  }

  Widget _buildForm(
    UnattributedRepaymentFormViewModelProvider provider,
    UnattributedRepaymentFormState state,
  ) {
    _syncControllers(state);
    final paidFromAccount = _findAccount(
      state.repaymentAccounts,
      state.paidFromAccountId,
    );

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
          AppPlainFormSection(
            children: [
              AppPlainValueRow(
                label: '账单外欠款',
                value: state.overview!.buckets.unattributedDebt.format(),
              ),
              MoneyPlainFormRow(
                label: '金额',
                controller: _amountController,
                hintText: '请输入还款金额',
                validator: validatePositiveMoneyText,
              ),
              AppPlainSwitchRow(
                label: '生成流水',
                value: state.createTransaction,
                onChanged:
                    (value) =>
                        ref.read(provider.notifier).setCreateTransaction(value),
              ),
              if (state.createTransaction) ...[
                DateTimePlainFormRow(
                  label: '还款日期',
                  value: _formatDateTime(state.occurredAt),
                  onTap: () => _pickDate(provider, state.occurredAt),
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
                            accounts: state.repaymentAccounts,
                            selectedId: state.paidFromAccountId,
                            onSelected:
                                (id) => ref
                                    .read(provider.notifier)
                                    .setPaidFromAccountId(id),
                          ),
                  validator: (value) => value == null ? '请选择还款账户' : null,
                ),
              ],
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
    UnattributedRepaymentFormViewModelProvider provider,
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
    required List<Account> accounts,
    required String? selectedId,
    required ValueChanged<String> onSelected,
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
    UnattributedRepaymentFormViewModelProvider provider,
  ) async {
    if (!_formKey.currentState!.validate()) return;
    final amount = Money.tryParse(_amountController.text);
    final max =
        ref.read(provider).asData?.value.overview?.buckets.unattributedDebt;
    if (amount != null && max != null && amount.minorUnits > max.minorUnits) {
      _showError('还款金额不能超过账单外欠款');
      return;
    }

    final outcome = await ref.read(provider.notifier).submit();
    if (!mounted) return;
    switch (outcome) {
      case SubmitSuccess():
        context.pop(true);
      case SubmitFailure(:final error):
        _showError(error.message);
    }
  }

  void _syncControllers(UnattributedRepaymentFormState state) {
    _syncing = true;
    syncTextControllerText(_amountController, state.amountText);
    syncTextControllerText(_noteController, state.noteText);
    _syncing = false;
  }

  void _setText(
    void Function(UnattributedRepaymentFormViewModel, String) setter,
    String value,
  ) {
    if (_syncing) return;
    setter(
      ref.read(
        unattributedRepaymentFormViewModelProvider(widget.accountId).notifier,
      ),
      value,
    );
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), behavior: SnackBarBehavior.floating),
    );
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
