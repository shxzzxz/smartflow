import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/money/money.dart';
import '../../../design_system/token/spacing.dart';
import '../../../design_system/widget/app_datetime_picker.dart';
import '../../../design_system/widget/app_form_section.dart';
import '../../../design_system/widget/app_page_header.dart';
import '../../../design_system/widget/app_plain_form_row.dart';
import '../../../design_system/widget/app_submit_button.dart';
import '../../../widget/business/finance/money_input.dart';
import '../../../widget/business/form/plain_transaction_fields.dart';
import '../../shared/view_model/ui_action_outcome.dart';
import '../view_model/advance_form_view_model.dart';
import '../widget/transaction_allocation_fields.dart';

class AccountAdvanceFormPage extends ConsumerWidget {
  const AccountAdvanceFormPage({required this.target, super.key});

  final AccountAdvanceFormTarget target;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final provider = accountAdvanceFormViewModelProvider(target);
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
    AccountAdvanceFormViewModelProvider provider,
    AccountAdvanceFormState state,
  ) {
    if (!state.isLoaded) {
      return const Center(child: Text('当前账户不能记录垫付收回'));
    }
    return _AccountAdvanceFormContent(
      key: ValueKey('${state.target.accountId}:${state.target.scenario.name}'),
      provider: provider,
      state: state,
    );
  }
}

class _AccountAdvanceFormContent extends ConsumerStatefulWidget {
  const _AccountAdvanceFormContent({
    required this.provider,
    required this.state,
    super.key,
  });

  final AccountAdvanceFormViewModelProvider provider;
  final AccountAdvanceFormState state;

  @override
  ConsumerState<_AccountAdvanceFormContent> createState() =>
      _AccountAdvanceFormContentState();
}

class _AccountAdvanceFormContentState
    extends ConsumerState<_AccountAdvanceFormContent> {
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
    final provider = widget.provider;
    final state = widget.state;
    final isSettlement = state.isSettlement;
    return Form(
      key: _formKey,
      child: Column(
        children: [
          AppPageHeader(
            title: state.actionLabel,
            subtitle: isSettlement ? '确认账户垫付结清' : '记录账户垫付到账',
          ),
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
                  title: '到账信息',
                  children: [
                    MoneyPlainFormRow(
                      key: const ValueKey('account-advance-amount'),
                      label: isSettlement ? '实收金额' : '到账金额',
                      controller: _amountController,
                      hintText: isSettlement ? '请输入实收金额' : '请输入到账金额',
                      validator: validatePositiveMoneyText,
                    ),
                    DateTimePlainFormRow(
                      label: isSettlement ? '结清时间' : '到账时间',
                      dateTime: state.occurredAt,
                      value: _formatDateTime(state.occurredAt),
                      onTap: (onSelected) => _pickOccurredAt(
                        state.occurredAt,
                        onSelected,
                        isSettlement,
                      ),
                      onChanged: (value) {
                        if (value != null) {
                          ref.read(provider.notifier).setOccurredAt(value);
                        }
                      },
                    ),
                    NotePlainFormRow(controller: _noteController),
                    AppPlainSwitchRow(
                      key: const ValueKey('account-advance-settlement-switch'),
                      label: '垫付结清',
                      value: isSettlement,
                      onChanged: ref.read(provider.notifier).setSettlement,
                    ),
                  ],
                ),
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

  Widget _buildSettlementAllocations(
    AccountAdvanceFormViewModelProvider provider,
    AccountAdvanceFormState state,
  ) {
    return ValueListenableBuilder<TextEditingValue>(
      valueListenable: _amountController,
      builder: (context, value, _) {
        final amount = Money.tryParse(value.text);
        return TransactionInlineAllocationColumn(
          key: const ValueKey('account-advance-settlement-allocations'),
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

  Future<void> _pickOccurredAt(
    DateTime occurredAt,
    ValueChanged<DateTime?> onSelected,
    bool isSettlement,
  ) async {
    final picked = await showAppDateTimePicker(
      context: context,
      initialDateTime: occurredAt,
      title: isSettlement ? '选择结清时间' : '选择到账时间',
    );
    if (!mounted || picked == null) return;
    onSelected(picked);
  }

  Future<void> _submit(AccountAdvanceFormViewModelProvider provider) async {
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
