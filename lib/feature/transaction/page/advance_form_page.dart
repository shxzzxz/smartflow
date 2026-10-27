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
import '../presentation/advance_edit_form_presentation.dart';
import '../view_model/advance_form_view_model.dart';
import '../widget/transaction_allocation_fields.dart';

class AdvanceFormPage extends ConsumerWidget {
  const AdvanceFormPage({required this.advanceTransactionId, super.key});

  final String advanceTransactionId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final provider = advanceFormViewModelProvider(advanceTransactionId);
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
    AdvanceFormViewModelProvider provider,
    AdvanceFormState state,
  ) {
    if (state.status == AdvanceFormStatus.notFound) {
      return const Center(child: Text('垫付不存在'));
    }
    if (state.status == AdvanceFormStatus.notEditable) {
      return const Center(child: Text('该垫付记录不可继续到账'));
    }
    return _AdvanceFormContent(
      key: ValueKey(advanceTransactionId),
      provider: provider,
      state: state,
    );
  }
}

class _AdvanceFormContent extends ConsumerStatefulWidget {
  const _AdvanceFormContent({
    required this.provider,
    required this.state,
    super.key,
  });

  final AdvanceFormViewModelProvider provider;
  final AdvanceFormState state;

  @override
  ConsumerState<_AdvanceFormContent> createState() =>
      _AdvanceFormContentState();
}

class _AdvanceFormContentState extends ConsumerState<_AdvanceFormContent> {
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
          const AppPageHeader(title: '垫付'),
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
                      key: const ValueKey('advance-form-amount'),
                      label: isClose ? '实收金额' : '到账金额',
                      controller: _amountController,
                      hintText: isClose ? '请输入实收金额' : '请输入到账金额',
                      validator: isClose
                          ? validateNonNegativeMoneyText
                          : (value) => validateAdvanceCollectionAmount(
                              amountText: value ?? '',
                              outstanding: state.outstanding,
                            ),
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
                    AppPlainSwitchRow(
                      label: '垫付结清',
                      value: isClose,
                      onChanged: ref.read(provider.notifier).setCloseAdvance,
                    ),
                  ],
                ),
                const SizedBox(height: AppSpacing.space14),
                _buildSettlementAllocations(provider, state),
                _buildShortfallSection(provider, state),
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
    AdvanceFormViewModelProvider provider,
    AdvanceFormState state,
  ) {
    return ValueListenableBuilder<TextEditingValue>(
      valueListenable: _amountController,
      builder: (context, value, _) {
        final amount = Money.tryParse(value.text);
        return TransactionInlineAllocationColumn(
          key: const ValueKey('advance-settlement-allocations'),
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
    AdvanceFormViewModelProvider provider,
    AdvanceFormState state,
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
          child: Column(
            children: [
              AppPlainSwitchRow(
                key: const ValueKey('advance-self-borne-switch'),
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
                  key: const ValueKey('advance-gap-allocations'),
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
                  key: const ValueKey('advance-gap-builtin'),
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

  Future<void> _submit(AdvanceFormViewModelProvider provider) async {
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
