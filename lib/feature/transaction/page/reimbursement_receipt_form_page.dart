import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../application/ledger/ledger_command_api.dart';
import '../../../design_system/token/spacing.dart';
import '../../../design_system/widget/app_datetime_picker.dart';
import '../../../design_system/widget/app_page_header.dart';
import '../../../design_system/widget/app_plain_form_row.dart';
import '../../../design_system/widget/app_submit_button.dart';
import '../../../widget/business/plain_transaction_fields.dart';
import '../../shared/view_model/ui_action_outcome.dart';
import '../view_model/reimbursement_form_view_model.dart';

class ReimbursementReceiptFormPage extends ConsumerStatefulWidget {
  const ReimbursementReceiptFormPage({
    required this.advanceTransactionId,
    super.key,
  });

  final String advanceTransactionId;

  @override
  ConsumerState<ReimbursementReceiptFormPage> createState() =>
      _ReimbursementReceiptFormPageState();
}

class _ReimbursementReceiptFormPageState
    extends ConsumerState<ReimbursementReceiptFormPage> {
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
    final provider = reimbursementReceiptFormViewModelProvider(
      widget.advanceTransactionId,
    );
    final asyncState = ref.watch(provider);
    return Scaffold(
      backgroundColor: Theme.of(context).colorScheme.surface,
      body: SafeArea(
        child: switch (asyncState) {
          AsyncData(value: final state) => _buildLoaded(provider, state),
          AsyncError(:final error) => Center(child: Text('加载失败：$error')),
          _ => const Center(child: CircularProgressIndicator()),
        },
      ),
    );
  }

  Widget _buildLoaded(
    ReimbursementReceiptFormViewModelProvider provider,
    ReimbursementReceiptFormState state,
  ) {
    if (state.status == ReimbursementFormStatus.notFound) {
      return const Center(child: Text('报销垫付不存在'));
    }
    if (state.status == ReimbursementFormStatus.notEditable) {
      return const Center(child: Text('该报销记录不可继续到账'));
    }
    _syncControllers(state);
    final receiveAccount = findAccountById(
      state.receiveAccountId,
      state.accounts,
    );

    return Form(
      key: _formKey,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(
          AppSpacing.space16,
          AppSpacing.space14,
          AppSpacing.space16,
          AppSpacing.space24,
        ),
        children: [
          const AppPageHeader(
            title: '记一笔到账',
            subtitle: '将报销款记入资金账户',
            showBackButton: true,
          ),
          const SizedBox(height: AppSpacing.space14),
          if (state.outstanding != null)
            Padding(
              padding: const EdgeInsets.only(bottom: AppSpacing.space12),
              child: Text('剩余应收：${state.outstanding!.format()}'),
            ),
          AppPlainFormSection(
            children: [
              MoneyPlainFormRow(
                label: '到账金额',
                controller: _amountController,
                hintText: '请输入到账金额',
                validator: validatePositiveMoneyText,
              ),
              AccountPlainFormRow(
                label: '到账账户',
                account: receiveAccount,
                selectedId: state.receiveAccountId,
                placeholder: '请选择到账账户',
                onTap:
                    () => _pickReceiveAccount(
                      provider,
                      state.accounts,
                      selectedId: state.receiveAccountId,
                    ),
                validator: (value) => value == null ? '请选择账户' : null,
              ),
              DateTimePlainFormRow(
                label: '到账时间',
                value: _formatDateTime(state.occurredAt),
                onTap: () => _pickOccurredAt(provider, state.occurredAt),
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

  Future<void> _pickReceiveAccount(
    ReimbursementReceiptFormViewModelProvider provider,
    List<Account> accounts, {
    required String? selectedId,
  }) async {
    final selected = await showAccountPickerSheet(
      context: context,
      title: '选择到账账户',
      accounts: accounts,
      selectedId: selectedId,
    );
    if (!mounted || selected == null) return;
    ref.read(provider.notifier).setReceiveAccountId(selected);
  }

  Future<void> _pickOccurredAt(
    ReimbursementReceiptFormViewModelProvider provider,
    DateTime occurredAt,
  ) async {
    final picked = await showAppDateTimePicker(
      context: context,
      initialDateTime: occurredAt,
      title: '选择到账时间',
    );
    if (!mounted || picked == null) return;
    ref.read(provider.notifier).setOccurredAt(picked);
  }

  Future<void> _submit(
    ReimbursementReceiptFormViewModelProvider provider,
  ) async {
    if (!_formKey.currentState!.validate()) return;
    final outcome = await ref.read(provider.notifier).submit();
    if (!mounted) return;
    switch (outcome) {
      case SubmitSuccess():
        context.pop();
      case SubmitFailure(:final error):
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(error.message)));
    }
  }

  void _syncControllers(ReimbursementReceiptFormState state) {
    _syncing = true;
    _setControllerText(_amountController, state.amountText);
    _setControllerText(_noteController, state.noteText);
    _syncing = false;
  }

  void _setControllerText(TextEditingController controller, String value) {
    if (controller.text == value) return;
    controller.text = value;
  }

  void _setText(
    void Function(ReimbursementReceiptFormViewModel, String) setter,
    String value,
  ) {
    if (_syncing) return;
    setter(
      ref.read(
        reimbursementReceiptFormViewModelProvider(
          widget.advanceTransactionId,
        ).notifier,
      ),
      value,
    );
  }
}

String _formatDateTime(DateTime date) {
  final time =
      '${date.hour.toString().padLeft(2, '0')}:'
      '${date.minute.toString().padLeft(2, '0')}';
  return '${date.year}-${date.month.toString().padLeft(2, '0')}-'
      '${date.day.toString().padLeft(2, '0')} $time';
}
