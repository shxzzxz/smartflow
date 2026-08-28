import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/money/money_formatter.dart';
import '../../../core/money/money.dart';
import '../../../design_system/theme/app_text_styles.dart';
import '../../../design_system/token/spacing.dart';
import '../../../design_system/widget/app_datetime_picker.dart';
import '../../../design_system/widget/app_form_section.dart';
import '../../../design_system/widget/app_page_header.dart';
import '../../../design_system/widget/app_plain_form_row.dart';
import '../../../design_system/widget/app_submit_button.dart';
import 'package:smartflow/widget/business/finance/money_input.dart';
import 'package:smartflow/widget/business/form/plain_transaction_fields.dart';
import '../../shared/view_model/ui_action_outcome.dart';
import '../presentation/reimbursement_edit_form_presentation.dart';
import '../view_model/reimbursement_form_view_model.dart';
import '../widget/transaction_allocation_fields.dart';

class ReimbursementFormPage extends ConsumerWidget {
  const ReimbursementFormPage({required this.advanceTransactionId, super.key});

  final String advanceTransactionId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final provider = reimbursementFormViewModelProvider(advanceTransactionId);
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
    ReimbursementFormViewModelProvider provider,
    ReimbursementFormState state,
  ) {
    if (state.status == ReimbursementFormStatus.notFound) {
      return const Center(child: Text('报销垫付不存在'));
    }
    if (state.status == ReimbursementFormStatus.notEditable) {
      return const Center(child: Text('该报销记录不可继续到账'));
    }
    return _ReimbursementFormContent(
      key: ValueKey(advanceTransactionId),
      provider: provider,
      state: state,
    );
  }
}

class _ReimbursementFormContent extends ConsumerStatefulWidget {
  const _ReimbursementFormContent({
    required this.provider,
    required this.state,
    super.key,
  });

  final ReimbursementFormViewModelProvider provider;
  final ReimbursementFormState state;

  @override
  ConsumerState<_ReimbursementFormContent> createState() =>
      _ReimbursementFormContentState();
}

class _ReimbursementFormContentState
    extends ConsumerState<_ReimbursementFormContent> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _amountController;
  late final TextEditingController _noteController;

  @override
  void initState() {
    super.initState();
    _amountController = TextEditingController(
      text: widget.state.outstanding?.format() ?? '',
    );
    _noteController = TextEditingController();
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
    final isClose = state.isClose;
    return Form(
      key: _formKey,
      child: Column(
        children: [
          const AppPageHeader(title: '报销'),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.space16,
                AppSpacing.space8,
                AppSpacing.space16,
                AppSpacing.space24,
              ),
              children: [
                if (state.outstanding != null) ...[
                  AppFormSection(
                    children: [
                      Text(
                        '应收：${formatMoney(state.outstanding!, style: MoneyFormatStyle.plain)}',
                        style: context.appTextStyles.formValue,
                      ),
                    ],
                  ),
                  const SizedBox(height: AppSpacing.space14),
                ],
                AppFormSection(
                  title: '到账信息',
                  children: [
                    MoneyPlainFormRow(
                      label: isClose ? '实收金额' : '到账金额',
                      controller: _amountController,
                      hintText: isClose ? '请输入实收金额' : '请输入到账金额',
                      validator: isClose
                          ? validateNonNegativeMoneyText
                          : (value) => validateReimbursementReceiptAmount(
                              amountText: value ?? '',
                              outstanding: state.outstanding,
                            ),
                    ),
                    DateTimePlainFormRow(
                      label: isClose ? '结束时间' : '到账时间',
                      dateTime: state.occurredAt,
                      value: _formatDateTime(state.occurredAt),
                      onTap: (onSelected) => _pickOccurredAt(
                        state.occurredAt,
                        onSelected,
                        isClose,
                      ),
                      onChanged: (value) {
                        if (value != null) {
                          ref.read(provider.notifier).setOccurredAt(value);
                        }
                      },
                    ),
                    NotePlainFormRow(controller: _noteController),
                    AppPlainSwitchRow(
                      label: '结束报销',
                      value: isClose,
                      onChanged: ref
                          .read(provider.notifier)
                          .setCloseReimbursement,
                    ),
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
    ReimbursementFormViewModelProvider provider,
    ReimbursementFormState state,
  ) {
    return ValueListenableBuilder<TextEditingValue>(
      valueListenable: _amountController,
      builder: (context, value, _) {
        final amount = Money.tryParse(value.text);
        return TransactionInlineAllocationColumn(
          key: const ValueKey('reimbursement-settlement-allocations'),
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
    ReimbursementFormViewModelProvider provider,
    ReimbursementFormState state,
  ) {
    return ValueListenableBuilder<TextEditingValue>(
      valueListenable: _amountController,
      builder: (context, value, _) {
        final actual = Money.tryParse(value.text);
        final outstanding = state.outstanding;
        if (!state.isClose ||
            actual == null ||
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
            key: const ValueKey('reimbursement-gap-allocations'),
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
    bool isClose,
  ) async {
    final picked = await showAppDateTimePicker(
      context: context,
      initialDateTime: occurredAt,
      title: isClose ? '选择结束时间' : '选择到账时间',
    );
    if (!mounted || picked == null) return;
    onSelected(picked);
  }

  Future<void> _submit(ReimbursementFormViewModelProvider provider) async {
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
