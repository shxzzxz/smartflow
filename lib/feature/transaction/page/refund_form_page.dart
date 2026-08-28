import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/money/money.dart';
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
import '../widget/transaction_allocation_fields.dart';

class RefundFormPage extends ConsumerWidget {
  const RefundFormPage({required String parentTransactionId, Key? key})
    : this._(parentTransactionId: parentTransactionId, key: key);

  const RefundFormPage.edit({required String editTransactionId, Key? key})
    : this._(editTransactionId: editTransactionId, key: key);

  const RefundFormPage._({
    this.parentTransactionId,
    this.editTransactionId,
    super.key,
  });

  final String? parentTransactionId;
  final String? editTransactionId;

  bool get editing => editTransactionId != null;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final transactionId = editTransactionId ?? parentTransactionId!;
    final provider = refundFormViewModelProvider(
      transactionId,
      editing: editing,
    );
    final asyncState = ref.watch(provider);
    return Scaffold(
      backgroundColor: Theme.of(context).colorScheme.surface,
      body: SafeArea(
        child: switch (asyncState) {
          AsyncData(value: final state) => _buildLoaded(provider, state),
          AsyncError() => const Center(child: Text('加载失败，请稍后重试')),
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
    if (state.status == RefundFormStatus.notEditable) {
      return const Center(child: Text('报销已结束，请先删除结束报销'));
    }
    return _RefundFormContent(
      key: ValueKey('${state.transactionId}:${state.editing}'),
      provider: provider,
      state: state,
    );
  }
}

class _RefundFormContent extends ConsumerStatefulWidget {
  const _RefundFormContent({
    required this.provider,
    required this.state,
    super.key,
  });

  final RefundFormViewModelProvider provider;
  final RefundFormState state;

  @override
  ConsumerState<_RefundFormContent> createState() => _RefundFormContentState();
}

class _RefundFormContentState extends ConsumerState<_RefundFormContent> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _amountController;
  late final TextEditingController _noteController;

  @override
  void initState() {
    super.initState();
    _amountController = TextEditingController(text: widget.state.amountText);
    _noteController = TextEditingController(text: widget.state.noteText);
  }

  @override
  void dispose() {
    _amountController.dispose();
    _noteController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final provider = widget.provider;
    final state = widget.state;
    return Form(
      key: _formKey,
      child: Column(
        children: [
          AppPageHeader(title: state.editing ? '编辑退款' : '退款'),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.space16,
                AppSpacing.space8,
                AppSpacing.space16,
                AppSpacing.space24,
              ),
              children: [
                AppFormSection(
                  title: '退款信息',
                  children: [
                    if (state.remaining != null)
                      AppPlainValueRow(
                        label: '可退余额',
                        child: MoneyText(
                          money: state.remaining!,
                          style: context.appTextStyles.formValue,
                        ),
                      ),
                    MoneyPlainFormRow(
                      label: '退款金额',
                      controller: _amountController,
                      hintText: '请输入退款金额',
                      validator: validatePositiveMoneyText,
                    ),
                    DateTimePlainFormRow(
                      label: '退款时间',
                      dateTime: state.occurredAt,
                      value: _formatDateTime(state.occurredAt),
                      onTap: (onSelected) =>
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
                const SizedBox(height: AppSpacing.space14),
                _buildCategoryAllocations(provider, state),
                const SizedBox(height: AppSpacing.space14),
                _buildSettlementAllocations(provider, state),
                const SizedBox(height: AppSpacing.space24),
                AppSubmitButton(
                  label: '保存',
                  loading: state.submitting,
                  onPressed: () => _submit(provider),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCategoryAllocations(
    RefundFormViewModelProvider provider,
    RefundFormState state,
  ) {
    return ValueListenableBuilder<TextEditingValue>(
      valueListenable: _amountController,
      builder: (context, value, _) {
        final amount = Money.tryParse(value.text);
        final fallbackCategoryId =
            state.availableCategoryAllocations.length == 1
            ? state.availableCategoryAllocations.single.accountId
            : null;
        return TransactionAllocationAmountFields(
          key: const ValueKey('refund-category-allocations'),
          title: '退款分类',
          allocations: transactionAllocationFieldValues(
            allocations: state.categoryAllocations,
            fallbackAccountId: fallbackCategoryId,
            total: amount,
          ),
          options: transactionAllocationOptionsForAccounts(
            state.categoryAccounts,
          ),
          expectedTotal: amount,
          maximumByAccountId: transactionAllocationMaximums(
            options: transactionAllocationOptionsForAccounts(
              state.categoryAccounts,
            ),
            availableAllocations: state.availableCategoryAllocations,
          ),
          onChanged: ref.read(provider.notifier).setCategoryAllocations,
        );
      },
    );
  }

  Widget _buildSettlementAllocations(
    RefundFormViewModelProvider provider,
    RefundFormState state,
  ) {
    return ValueListenableBuilder<TextEditingValue>(
      valueListenable: _amountController,
      builder: (context, value, _) {
        final amount = Money.tryParse(value.text);
        return TransactionInlineAllocationColumn(
          key: const ValueKey('refund-settlement-allocations'),
          title: '到账账户',
          allocations: transactionAllocationFieldValues(
            allocations: state.settlementAllocations,
            fallbackAccountId: state.refundToAccountId,
            total: amount,
          ),
          options: transactionAllocationOptionsForAccounts(state.accounts),
          addLabel: '添加账户',
          expectedTotal: amount,
          onSelectOption: (context, selectedId, options) =>
              selectTransactionAllocationAccount(
                context,
                accounts: state.accounts,
                selectedAccountId: selectedId,
                options: options,
              ),
          onChanged: ref.read(provider.notifier).setSettlementAllocations,
        );
      },
    );
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
