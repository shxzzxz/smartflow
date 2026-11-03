import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/money/money.dart';
import '../../../core/money/money_formatter.dart';
import '../../../design_system/theme/app_text_styles.dart';
import '../../../design_system/token/spacing.dart';
import '../../../design_system/widget/app_datetime_picker.dart';
import '../../../design_system/widget/app_form_section.dart';
import '../../../design_system/widget/app_page_header.dart';
import '../../../design_system/widget/app_plain_form_row.dart';
import '../../../design_system/widget/app_submit_button.dart';
import '../../../design_system/widget/app_surface.dart';
import 'package:smartflow/widget/business/finance/money_input.dart';
import 'package:smartflow/widget/business/finance/money_text.dart';
import 'package:smartflow/widget/business/form/plain_transaction_fields.dart';
import '../../shared/view_model/ui_action_outcome.dart';
import '../view_model/transaction_form/refund/refund_form_view_model.dart';
import '../../../widget/business/transaction/transaction_allocation_fields.dart';

class RefundFormPage extends ConsumerWidget {
  const RefundFormPage({required String parentTransactionId, Key? key})
    : this._(parentTransactionId: parentTransactionId, key: key);

  const RefundFormPage.edit({required String editTransactionId, Key? key})
    : this._(editTransactionId: editTransactionId, key: key);

  const RefundFormPage.amortizationTermination({
    required String transactionId,
    Key? key,
  }) : this._(
         transactionId: transactionId,
         amortizationTermination: true,
         key: key,
       );

  const RefundFormPage.amortizationTerminationEdit({
    required String transactionId,
    Key? key,
  }) : this._(
         editTransactionId: transactionId,
         amortizationTermination: true,
         key: key,
       );

  const RefundFormPage._({
    this.parentTransactionId,
    this.editTransactionId,
    this.transactionId,
    this.amortizationTermination = false,
    super.key,
  });

  final String? parentTransactionId;
  final String? editTransactionId;
  final String? transactionId;
  final bool amortizationTermination;

  bool get editing => editTransactionId != null;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final resolvedTransactionId =
        editTransactionId ?? transactionId ?? parentTransactionId!;
    final provider = refundFormViewModelProvider(
      resolvedTransactionId,
      editing: editing,
      amortizationTermination: amortizationTermination,
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
      return Center(child: Text(state.message ?? '原交易不存在'));
    }
    if (state.status == RefundFormStatus.notEditable) {
      return Center(child: Text(state.message ?? '交易当前不可编辑'));
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
    final termination = state.amortizationTermination;
    return Form(
      key: _formKey,
      child: Column(
        children: [
          AppPageHeader(title: _pageTitle(state)),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.space16,
                AppSpacing.space8,
                AppSpacing.space16,
                AppSpacing.space24,
              ),
              children: [
                if (state.remaining != null) ...[
                  _AmountSummaryCard(
                    key: const ValueKey('refund-remaining-summary'),
                    label: termination ? '剩余待摊' : '可退余额',
                    amount: state.remaining!,
                  ),
                  const SizedBox(height: AppSpacing.space14),
                ],
                AppFormSection(
                  title: termination ? '终止信息' : '退款信息',
                  children: [
                    MoneyPlainFormRow(
                      label: termination ? '退还金额' : '退款金额',
                      controller: _amountController,
                      hintText: termination ? '可为 0，剩余部分将立即确认' : '请输入退款金额',
                      validator: termination
                          ? validateOptionalNonNegativeMoneyText
                          : validatePositiveMoneyText,
                    ),
                    DateTimePlainFormRow(
                      label: termination ? '终止时间' : '退款时间',
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
                    if (!termination)
                      NotePlainFormRow(controller: _noteController),
                  ],
                ),
                const SizedBox(height: AppSpacing.space14),
                if (state.installmentContractId != null) ...[
                  AppSurface(
                    child: Padding(
                      padding: const EdgeInsets.all(AppSpacing.space12),
                      child: Text(
                        '退回到分期负债的部分会作为退款还本重算后续计划；'
                        '分期账户金额不能超过退款日之后的待还本金，'
                        '超出部分请直接分配到资产账户。',
                        style: context.appTextStyles.listSupporting,
                      ),
                    ),
                  ),
                  const SizedBox(height: AppSpacing.space8),
                  AppPlainValueRow(
                    label: '可退款还本',
                    child: state.refundLimitLoading
                        ? Text(
                            '计算中',
                            style: context.appTextStyles.listSupporting,
                          )
                        : MoneyText(
                            money: state.refundablePrincipal ?? Money.zero(),
                            style: context.appTextStyles.formValue,
                          ),
                  ),
                  const SizedBox(height: AppSpacing.space14),
                ],
                _buildCategoryAllocations(provider, state),
                const SizedBox(height: AppSpacing.space14),
                _buildSettlementAllocations(provider, state),
                if (termination && state.remaining != null) ...[
                  const SizedBox(height: AppSpacing.space14),
                  ValueListenableBuilder<TextEditingValue>(
                    valueListenable: _amountController,
                    builder: (context, value, _) {
                      final amount = Money.tryParse(value.text) ?? Money.zero();
                      return _AmountSummaryCard(
                        key: const ValueKey('refund-termination-confirmation'),
                        label: '终止确认',
                        amount: state.remaining! - amount,
                      );
                    },
                  ),
                ],
                const SizedBox(height: AppSpacing.space24),
                AppSubmitButton(
                  label: termination
                      ? state.editing
                            ? '保存修改'
                            : '确认终止'
                      : '保存',
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
          title: state.amortizationTermination ? '退还分类' : '退款分类',
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
          maximumByAccountId: {
            ?state.installmentLiabilityAccountId:
                state.refundablePrincipal ?? Money.zero(),
          },
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
      title: widget.state.amortizationTermination ? '选择终止时间' : '选择退款时间',
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

  String _pageTitle(RefundFormState state) {
    if (state.amortizationTermination) {
      return state.editing ? '编辑摊销终止' : '摊销终止';
    }
    if (state.amortizationPlanId != null) {
      return state.editing ? '编辑摊销退款' : '摊销退款';
    }
    return state.editing ? '编辑退款' : '退款';
  }
}

class _AmountSummaryCard extends StatelessWidget {
  const _AmountSummaryCard({
    required this.label,
    required this.amount,
    super.key,
  });

  final String label;
  final Money amount;

  @override
  Widget build(BuildContext context) {
    return AppFormSection(
      children: [
        Text(
          '$label：${formatMoney(amount, style: MoneyFormatStyle.plain)}',
          style: context.appTextStyles.formValue,
        ),
      ],
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
