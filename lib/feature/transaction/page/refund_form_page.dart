import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../application/ledger/ledger_command_api.dart';
import '../../../design_system/theme/app_text_styles.dart';
import '../../../design_system/token/spacing.dart';
import '../../../design_system/widget/app_datetime_picker.dart';
import '../../../design_system/widget/app_form_field.dart';
import '../../../design_system/widget/app_form_section.dart';
import '../../../design_system/widget/app_page_header.dart';
import '../../../design_system/widget/app_plain_form_row.dart';
import '../../../design_system/widget/app_submit_button.dart';
import 'package:smartflow/widget/business/finance/money_input.dart';
import 'package:smartflow/widget/business/finance/money_text.dart';
import 'package:smartflow/widget/business/form/plain_transaction_fields.dart';
import '../../shared/view_model/ui_action_outcome.dart';
import '../view_model/refund_form_view_model.dart';

class RefundFormPage extends ConsumerStatefulWidget {
  const RefundFormPage({required this.parentTransactionId, super.key});

  final String parentTransactionId;

  @override
  ConsumerState<RefundFormPage> createState() => _RefundFormPageState();
}

class _RefundFormPageState extends ConsumerState<RefundFormPage> {
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
    final provider = refundFormViewModelProvider(widget.parentTransactionId);
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
    RefundFormViewModelProvider provider,
    RefundFormState state,
  ) {
    if (state.status == RefundFormStatus.notFound) {
      return const Center(child: Text('原交易不存在'));
    }
    _syncControllers(state);
    final refundToAccount = findAccountById(
      state.refundToAccountId,
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
          const AppPageHeader(title: '退款', showBackButton: true),
          const SizedBox(height: AppSpacing.space14),
          AppFormSection(
            title: '退款信息',
            children: [
              if (state.remaining != null)
                AppPlainValueRow(
                  label: '可退余额',
                  child: MoneyText(
                    money: state.remaining!,
                    style: context.appTextStyles.formPlainValue,
                  ),
                ),
              MoneyPlainFormRow(
                label: '退款金额',
                controller: _amountController,
                hintText: '请输入退款金额',
                validator: validatePositiveMoneyText,
              ),
              AccountPlainFormRow(
                label: '退款账户',
                account: refundToAccount,
                selectedId: state.refundToAccountId,
                placeholder: '请选择退款账户',
                onTap:
                    () => _pickRefundAccount(
                      provider,
                      state.accounts,
                      selectedId: state.refundToAccountId,
                    ),
                validator: (value) => value == null ? '请选择账户' : null,
              ),
              DateTimePlainFormRow(
                label: '退款时间',
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

  Future<void> _pickRefundAccount(
    RefundFormViewModelProvider provider,
    List<Account> accounts, {
    required String? selectedId,
  }) async {
    final selected = await showAccountPickerSheet(
      context: context,
      title: '选择退款账户',
      accounts: accounts,
      selectedId: selectedId,
    );
    if (!mounted || selected == null) return;
    ref.read(provider.notifier).setRefundToAccountId(selected);
  }

  Future<void> _pickOccurredAt(
    RefundFormViewModelProvider provider,
    DateTime occurredAt,
  ) async {
    final picked = await showAppDateTimePicker(
      context: context,
      initialDateTime: occurredAt,
      title: '选择退款时间',
    );
    if (!mounted || picked == null) return;
    ref.read(provider.notifier).setOccurredAt(picked);
  }

  Future<void> _submit(RefundFormViewModelProvider provider) async {
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

  void _syncControllers(RefundFormState state) {
    _syncing = true;
    syncTextControllerText(_amountController, state.amountText);
    syncTextControllerText(_noteController, state.noteText);
    _syncing = false;
  }

  void _setText(
    void Function(RefundFormViewModel, String) setter,
    String value,
  ) {
    if (_syncing) return;
    setter(
      ref.read(
        refundFormViewModelProvider(widget.parentTransactionId).notifier,
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
