import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../application/ledger/ledger_command_api.dart';
import '../../../design_system/theme/app_text_styles.dart';
import '../../../design_system/token/spacing.dart';
import '../../../design_system/widget/app_datetime_picker.dart';
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
                    (onSelected) => _pickRefundAccount(
                      state.accounts,
                      selectedId: state.refundToAccountId,
                      onSelected: onSelected,
                    ),
                onChanged: ref.read(provider.notifier).setRefundToAccountId,
                validator: (value) => value == null ? '请选择账户' : null,
              ),
              DateTimePlainFormRow(
                label: '退款时间',
                dateTime: state.occurredAt,
                value: _formatDateTime(state.occurredAt),
                onTap:
                    (onSelected) =>
                        _pickOccurredAt(state.occurredAt, onSelected),
                onChanged: (value) {
                  if (value != null) {
                    ref.read(provider.notifier).setOccurredAt(value);
                  }
                },
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
    List<Account> accounts, {
    required String? selectedId,
    required ValueChanged<String?> onSelected,
  }) async {
    final selected = await showAccountPickerSheet(
      context: context,
      title: '选择退款账户',
      accounts: accounts,
      selectedId: selectedId,
    );
    if (!mounted || selected == null) return;
    onSelected(selected);
  }

  Future<void> _pickOccurredAt(
    DateTime occurredAt,
    ValueChanged<DateTime?> onSelected,
  ) async {
    final picked = await showAppDateTimePicker(
      context: context,
      initialDateTime: occurredAt,
      title: '选择退款时间',
    );
    if (!mounted || picked == null) return;
    onSelected(picked);
  }

  Future<void> _submit(RefundFormViewModelProvider provider) async {
    if (!_formKey.currentState!.validate()) return;
    final outcome = await ref
        .read(provider.notifier)
        .submit(
          amountText: _amountController.text,
          noteText: _noteController.text,
        );
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
}

String _formatDateTime(DateTime date) {
  final time =
      '${date.hour.toString().padLeft(2, '0')}:'
      '${date.minute.toString().padLeft(2, '0')}';
  return '${date.year}-${date.month.toString().padLeft(2, '0')}-'
      '${date.day.toString().padLeft(2, '0')} $time';
}
