import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../application/ledger/ledger_command_api.dart';
import '../../../design_system/token/spacing.dart';
import '../../../design_system/widget/app_datetime_picker.dart';
import '../../../design_system/widget/app_form_field.dart';
import '../../../design_system/widget/app_plain_form_row.dart';
import '../../../design_system/widget/app_submit_button.dart';
import 'package:smartflow/widget/business/form/plain_transaction_fields.dart';
import '../../shared/view_model/ui_action_outcome.dart';
import '../view_model/installment_repayment_form_view_model.dart';
import '../view_model/installment_repayment_mode.dart';

export '../view_model/installment_repayment_mode.dart';

class InstallmentRepaymentFormPage extends ConsumerStatefulWidget {
  const InstallmentRepaymentFormPage({
    required this.contractId,
    required this.mode,
    this.scheduleId,
    super.key,
  });

  final String contractId;
  final InstallmentRepaymentMode mode;
  final String? scheduleId;

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
  bool _syncing = false;

  @override
  void initState() {
    super.initState();
    _principalController.addListener(
      () => _setText(
        (vm, value) => vm.setPrincipalText(value),
        _principalController.text,
      ),
    );
    _interestController.addListener(
      () => _setText(
        (vm, value) => vm.setInterestText(value),
        _interestController.text,
      ),
    );
    _feeController.addListener(
      () => _setText((vm, value) => vm.setFeeText(value), _feeController.text),
    );
    _discountController.addListener(
      () => _setText(
        (vm, value) => vm.setDiscountText(value),
        _discountController.text,
      ),
    );
    _noteController.addListener(
      () =>
          _setText((vm, value) => vm.setNoteText(value), _noteController.text),
    );
  }

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
      appBar: AppBar(title: Text(_titleForMode(widget.mode))),
      body: switch (asyncState) {
        AsyncData(value: final state) => _buildLoaded(provider, state),
        AsyncError(:final error) => Center(child: Text('加载失败：$error')),
        _ => const Center(child: CircularProgressIndicator()),
      },
    );
  }

  Widget _buildLoaded(
    InstallmentRepaymentFormViewModelProvider provider,
    InstallmentRepaymentFormState state,
  ) {
    switch (state.status) {
      case InstallmentRepaymentFormStatus.notFound:
        return const Center(child: Text('合同不存在'));
      case InstallmentRepaymentFormStatus.scheduleNotFound:
        return const Center(child: Text('计划行不存在'));
      case InstallmentRepaymentFormStatus.loaded:
        break;
    }
    _syncControllers(state);

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
              MoneyPlainFormRow(
                label: '本金',
                controller: _principalController,
                hintText: '请输入还款本金',
                validator: validatePositiveMoneyText,
              ),
              if (widget.mode != InstallmentRepaymentMode.extraPrincipal)
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
              if (widget.mode == InstallmentRepaymentMode.scheduled)
                MoneyPlainFormRow(
                  label: '优惠',
                  controller: _discountController,
                  hintText: '请输入优惠（可选）',
                  validator: validateOptionalNonNegativeMoneyText,
                ),
              DateTimePlainFormRow(
                label: '还款日期',
                value: _formatDateTime(state.occurredAt),
                onTap: () => _pickDate(provider, state.occurredAt),
              ),
              AccountPlainFormRow(
                label: '还款账户',
                account: _findAccount(state.accounts, state.paidFromAccountId),
                selectedId: state.paidFromAccountId,
                placeholder: '请选择还款账户',
                onTap:
                    state.accounts.isEmpty
                        ? null
                        : () => _pickAccount(
                          accounts: state.accounts,
                          selectedId: state.paidFromAccountId,
                          onSelected:
                              (id) => ref
                                  .read(provider.notifier)
                                  .setPaidFromAccountId(id),
                        ),
                validator: (value) => value == null ? '请选择还款账户' : null,
              ),
              NotePlainFormRow(controller: _noteController),
            ],
          ),
          const SizedBox(height: AppSpacing.space24),
          if (widget.mode == InstallmentRepaymentMode.extraPrincipal)
            const Padding(
              padding: EdgeInsets.only(bottom: AppSpacing.space12),
              child: Text(
                '提交后，所有待还期次的金额将按剩余本金重新计算。',
                style: TextStyle(fontSize: 12),
              ),
            ),
          AppSubmitButton(
            label: _submitLabel(widget.mode),
            loading: state.submitting,
            onPressed: () => _submit(provider),
          ),
        ],
      ),
    );
  }

  Future<void> _pickDate(
    InstallmentRepaymentFormViewModelProvider provider,
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
    InstallmentRepaymentFormViewModelProvider provider,
  ) async {
    if (!_formKey.currentState!.validate()) return;
    final outcome = await ref.read(provider.notifier).submit();
    if (!mounted) return;
    switch (outcome) {
      case SubmitSuccess():
        context.pop();
      case SubmitFailure(:final error):
        _showError(error.message);
    }
  }

  void _syncControllers(InstallmentRepaymentFormState state) {
    _syncing = true;
    syncTextControllerText(_principalController, state.principalText);
    syncTextControllerText(_interestController, state.interestText);
    syncTextControllerText(_feeController, state.feeText);
    syncTextControllerText(_discountController, state.discountText);
    syncTextControllerText(_noteController, state.noteText);
    _syncing = false;
  }

  void _setText(
    void Function(InstallmentRepaymentFormViewModel, String) setter,
    String value,
  ) {
    if (_syncing) return;
    setter(
      ref.read(installmentRepaymentFormViewModelProvider(_args).notifier),
      value,
    );
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), behavior: SnackBarBehavior.floating),
    );
  }

  InstallmentRepaymentFormArgs get _args {
    return InstallmentRepaymentFormArgs(
      contractId: widget.contractId,
      mode: widget.mode,
      scheduleId: widget.scheduleId,
    );
  }
}

String _titleForMode(InstallmentRepaymentMode mode) {
  return switch (mode) {
    InstallmentRepaymentMode.scheduled => '期次还款',
    InstallmentRepaymentMode.extraPrincipal => '提前还本',
    InstallmentRepaymentMode.earlySettlement => '提前结清',
  };
}

String _submitLabel(InstallmentRepaymentMode mode) {
  return switch (mode) {
    InstallmentRepaymentMode.scheduled => '保存',
    InstallmentRepaymentMode.extraPrincipal => '提交并重算',
    InstallmentRepaymentMode.earlySettlement => '结清',
  };
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
