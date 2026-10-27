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
import '../../../domain/ledger/valobj/ledger_enum.dart';
import 'package:smartflow/widget/business/finance/money_input.dart';
import 'package:smartflow/widget/business/form/plain_transaction_fields.dart';
import '../../shared/view_model/ui_action_outcome.dart';
import '../view_model/advance_edit_form_view_model.dart';
import '../widget/transaction_allocation_fields.dart';

class AdvanceEditFormPage extends ConsumerWidget {
  const AdvanceEditFormPage({required this.transactionId, super.key});

  final String transactionId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final provider = advanceEditFormViewModelProvider(transactionId);
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
    AdvanceEditFormViewModelProvider provider,
    AdvanceEditFormState state,
  ) {
    if (state.status == AdvanceEditFormStatus.notFound) {
      return const Center(child: Text('原垫付交易不存在'));
    }
    if (state.status == AdvanceEditFormStatus.notEditable) {
      return Center(child: Text(state.unavailableReason ?? '当前垫付交易不可编辑'));
    }
    final kind = state.kind;
    if (kind == null) {
      return const Center(child: Text('原垫付交易类型不受支持'));
    }
    return _AdvanceEditFormContent(
      key: ValueKey('${state.transactionId}:${kind.name}'),
      provider: provider,
      state: state,
      kind: kind,
    );
  }
}

class _AdvanceEditFormContent extends ConsumerStatefulWidget {
  const _AdvanceEditFormContent({
    required this.provider,
    required this.state,
    required this.kind,
    super.key,
  });

  final AdvanceEditFormViewModelProvider provider;
  final AdvanceEditFormState state;
  final AdvanceEditKind kind;

  @override
  ConsumerState<_AdvanceEditFormContent> createState() =>
      _AdvanceEditFormContentState();
}

class _AdvanceEditFormContentState
    extends ConsumerState<_AdvanceEditFormContent> {
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
    final kind = widget.kind;
    final isClose = kind == AdvanceEditKind.close;
    return Form(
      key: _formKey,
      child: Column(
        children: [
          AppPageHeader(title: isClose ? '编辑垫付结清' : '编辑垫付到账'),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.space16,
                AppSpacing.space8,
                AppSpacing.space16,
                AppSpacing.space24,
              ),
              children: [
                if (state.outstandingBeforeTransaction != null) ...[
                  AppFormSection(
                    children: [
                      Text(
                        '应收：${formatMoney(state.outstandingBeforeTransaction!, style: MoneyFormatStyle.plain)}',
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
                          : validatePositiveMoneyText,
                    ),
                    DateTimePlainFormRow(
                      label: isClose ? '结清时间' : '到账时间',
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
                  ],
                ),
                const SizedBox(height: AppSpacing.space14),
                _buildSettlementAllocations(provider, state),
                if (isClose) _buildShortfallSection(provider, state),
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
    AdvanceEditFormViewModelProvider provider,
    AdvanceEditFormState state,
  ) {
    return ValueListenableBuilder<TextEditingValue>(
      valueListenable: _amountController,
      builder: (context, value, _) {
        final amount = Money.tryParse(value.text);
        return TransactionInlineAllocationColumn(
          key: const ValueKey('advance-edit-settlement-allocations'),
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

  Widget _buildShortfallSection(
    AdvanceEditFormViewModelProvider provider,
    AdvanceEditFormState state,
  ) {
    return ValueListenableBuilder<TextEditingValue>(
      valueListenable: _amountController,
      builder: (context, value, _) {
        final actual = Money.tryParse(value.text);
        final outstanding = state.outstandingBeforeTransaction;
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
          child: Column(
            children: [
              AppPlainSwitchRow(
                key: const ValueKey('advance-edit-self-borne-switch'),
                label: '自承担',
                description:
                    state.shortfallKind == AdvanceShortfallKind.selfBorne
                    ? '差额计入所选支出分类'
                    : '差额计入内置坏账损失分类',
                value: state.shortfallKind == AdvanceShortfallKind.selfBorne,
                onChanged: ref.read(provider.notifier).setSelfBorne,
              ),
              if (state.shortfallKind == AdvanceShortfallKind.selfBorne) ...[
                const SizedBox(height: AppSpacing.space8),
                TransactionAllocationAmountFields(
                  key: const ValueKey('advance-edit-gap-allocations'),
                  title: '自承担分类',
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
                  onChanged: ref
                      .read(provider.notifier)
                      .setGapExpenseAllocations,
                ),
              ] else
                Padding(
                  key: const ValueKey('advance-edit-gap-builtin'),
                  padding: const EdgeInsets.only(top: AppSpacing.space8),
                  child: Text('计入内置分类“坏账损失” ${shortfall.format()}'),
                ),
            ],
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
      title: isClose ? '选择结清时间' : '选择到账时间',
    );
    if (!mounted || picked == null) return;
    onSelected(picked);
  }

  Future<void> _submit(AdvanceEditFormViewModelProvider provider) async {
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
