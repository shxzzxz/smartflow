import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/money/money.dart';
import '../../../design_system/token/spacing.dart';
import '../../../design_system/widget/app_datetime_picker.dart';
import '../../../design_system/widget/app_form_field.dart';
import '../../../design_system/widget/app_form_section.dart';
import '../../../design_system/widget/app_page_header.dart';
import '../../../design_system/widget/app_submit_button.dart';
import 'package:smartflow/widget/business/finance/money_input.dart';
import 'package:smartflow/widget/business/form/plain_transaction_fields.dart';
import '../../shared/view_model/ui_action_outcome.dart';
import '../view_model/reimbursement_form_view_model.dart';
import '../widget/transaction_allocation_fields.dart';

class ReimbursementCloseFormPage extends ConsumerStatefulWidget {
  const ReimbursementCloseFormPage({
    required this.advanceTransactionId,
    super.key,
  });

  final String advanceTransactionId;

  @override
  ConsumerState<ReimbursementCloseFormPage> createState() =>
      _ReimbursementCloseFormPageState();
}

class _ReimbursementCloseFormPageState
    extends ConsumerState<ReimbursementCloseFormPage> {
  final _formKey = GlobalKey<FormState>();
  final _amountController = TextEditingController();
  final _noteController = TextEditingController();
  String? _hydratedAdvanceTransactionId;

  @override
  void dispose() {
    _amountController.dispose();
    _noteController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final provider = reimbursementCloseFormViewModelProvider(
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
    ReimbursementCloseFormViewModelProvider provider,
    ReimbursementCloseFormState state,
  ) {
    if (state.status == ReimbursementFormStatus.notFound) {
      return const Center(child: Text('报销垫付不存在'));
    }
    if (state.status == ReimbursementFormStatus.notEditable) {
      return const Center(child: Text('该报销记录不可结束'));
    }
    if (_hydratedAdvanceTransactionId != widget.advanceTransactionId) {
      syncTextControllerText(
        _amountController,
        state.outstanding?.format() ?? '',
      );
      _hydratedAdvanceTransactionId = widget.advanceTransactionId;
    }
    return Form(
      key: _formKey,
      child: Column(
        children: [
          const AppPageHeader(title: '结束报销', subtitle: '记录最后一笔到账并对账差额'),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.space16,
                AppSpacing.space8,
                AppSpacing.space16,
                AppSpacing.space24,
              ),
              children: [
                if (state.outstanding != null)
                  Padding(
                    padding: const EdgeInsets.only(bottom: AppSpacing.space8),
                    child: Text('剩余应收：${state.outstanding!.format()}'),
                  ),
                ValueListenableBuilder<TextEditingValue>(
                  valueListenable: _amountController,
                  builder: (context, value, _) {
                    final actual = Money.tryParse(value.text);
                    final outstanding = state.outstanding;
                    if (actual == null || outstanding == null) {
                      return const SizedBox.shrink();
                    }
                    final gap = actual - outstanding;
                    if (gap.minorUnits == 0) return const SizedBox.shrink();
                    return Padding(
                      padding: const EdgeInsets.only(
                        bottom: AppSpacing.space12,
                      ),
                      child: Text(
                        gap.minorUnits > 0
                            ? '多收 ${gap.format()}（计入报销差额收入）'
                            : '少收 ${gap.abs().format()}（按差额分类分配计入支出）',
                      ),
                    );
                  },
                ),
                AppFormSection(
                  title: '到账信息',
                  children: [
                    MoneyPlainFormRow(
                      label: '实收金额',
                      controller: _amountController,
                      hintText: '请输入实收金额',
                      validator: validateNonNegativeMoneyText,
                    ),
                    DateTimePlainFormRow(
                      label: '结束时间',
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
                _buildSettlementAllocations(provider, state),
                _buildGapAllocations(provider, state),
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

  Widget _buildSettlementAllocations(
    ReimbursementCloseFormViewModelProvider provider,
    ReimbursementCloseFormState state,
  ) {
    return ValueListenableBuilder<TextEditingValue>(
      valueListenable: _amountController,
      builder: (context, value, _) {
        final amount = Money.tryParse(value.text);
        return TransactionInlineAllocationColumn(
          key: const ValueKey('reimbursement-close-settlement-allocations'),
          title: '到账账户',
          allocations: transactionAllocationFieldValues(
            allocations: state.settlementAllocations,
            fallbackAccountId: state.receiveAccountId,
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

  Widget _buildGapAllocations(
    ReimbursementCloseFormViewModelProvider provider,
    ReimbursementCloseFormState state,
  ) {
    return ValueListenableBuilder<TextEditingValue>(
      valueListenable: _amountController,
      builder: (context, value, _) {
        final actual = Money.tryParse(value.text);
        final outstanding = state.outstanding;
        if (actual == null ||
            outstanding == null ||
            actual.minorUnits >= outstanding.minorUnits) {
          return const SizedBox.shrink();
        }
        final shortfall = outstanding - actual;
        final fallbackCategoryId =
            state.availableCategoryAllocations.length == 1
            ? state.availableCategoryAllocations.single.accountId
            : null;
        return Padding(
          padding: const EdgeInsets.only(top: AppSpacing.space14),
          child: TransactionAllocationAmountFields(
            key: const ValueKey('reimbursement-close-gap-allocations'),
            title: '差额分类',
            allocations: transactionAllocationFieldValues(
              allocations: state.gapExpenseAllocations,
              fallbackAccountId: fallbackCategoryId,
              total: shortfall,
            ),
            options: transactionAllocationOptionsForAccounts(
              state.categoryAccounts,
            ),
            expectedTotal: shortfall,
            maximumByAccountId: transactionAllocationMaximums(
              options: transactionAllocationOptionsForAccounts(
                state.categoryAccounts,
              ),
              availableAllocations: state.availableCategoryAllocations,
            ),
            onChanged: ref.read(provider.notifier).setGapExpenseAllocations,
          ),
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
      title: '选择结束时间',
    );
    if (!mounted || picked == null) return;
    onSelected(picked);
  }

  Future<void> _submit(ReimbursementCloseFormViewModelProvider provider) async {
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
