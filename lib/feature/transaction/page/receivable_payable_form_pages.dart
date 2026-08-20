import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../design_system/token/spacing.dart';
import '../../../design_system/widget/app_datetime_picker.dart';
import '../../../design_system/widget/app_form_section.dart';
import '../../../design_system/widget/app_page_header.dart';
import '../../../design_system/widget/app_submit_button.dart';
import '../../../widget/business/finance/money_input.dart';
import '../../../widget/business/form/plain_transaction_fields.dart';
import '../../shared/view_model/ui_action_outcome.dart';
import '../view_model/receivable_payable_form_view_model.dart';

class ReceivableCollectionFormPage extends StatelessWidget {
  const ReceivableCollectionFormPage({
    this.receivableAccountId,
    this.transactionId,
    super.key,
  });

  final String? receivableAccountId;
  final String? transactionId;

  @override
  Widget build(BuildContext context) => _ReceivablePayableFormPage(
    args: ReceivablePayableFormArgs(
      kind: ReceivablePayableFormKind.collection,
      accountId: receivableAccountId,
      transactionId: transactionId,
    ),
  );
}

class BadDebtFormPage extends StatelessWidget {
  const BadDebtFormPage({
    this.receivableAccountId,
    this.transactionId,
    super.key,
  });

  final String? receivableAccountId;
  final String? transactionId;

  @override
  Widget build(BuildContext context) => _ReceivablePayableFormPage(
    args: ReceivablePayableFormArgs(
      kind: ReceivablePayableFormKind.badDebt,
      accountId: receivableAccountId,
      transactionId: transactionId,
    ),
  );
}

class DebtReliefFormPage extends StatelessWidget {
  const DebtReliefFormPage({
    this.liabilityAccountId,
    this.transactionId,
    super.key,
  });

  final String? liabilityAccountId;
  final String? transactionId;

  @override
  Widget build(BuildContext context) => _ReceivablePayableFormPage(
    args: ReceivablePayableFormArgs(
      kind: ReceivablePayableFormKind.debtRelief,
      accountId: liabilityAccountId,
      transactionId: transactionId,
    ),
  );
}

class _ReceivablePayableFormPage extends ConsumerWidget {
  const _ReceivablePayableFormPage({required this.args});

  final ReceivablePayableFormArgs args;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final asyncState = ref.watch(receivablePayableFormViewModelProvider(args));
    return Scaffold(
      backgroundColor: Theme.of(context).colorScheme.surface,
      body: SafeArea(
        child: switch (asyncState) {
          AsyncData(value: final state) when state.isLoaded =>
            _ReceivablePayableFormContent(
              key: ValueKey('${args.kind.name}:${args.transactionId ?? 'new'}'),
              args: args,
              initialState: state,
            ),
          AsyncData() => const Center(child: Text('原交易不存在')),
          AsyncError() => const Center(child: Text('加载失败，请稍后重试')),
          _ => const Center(child: CircularProgressIndicator()),
        },
      ),
    );
  }
}

class _ReceivablePayableFormContent extends ConsumerStatefulWidget {
  const _ReceivablePayableFormContent({
    required this.args,
    required this.initialState,
    super.key,
  });

  final ReceivablePayableFormArgs args;
  final ReceivablePayableFormState initialState;

  @override
  ConsumerState<_ReceivablePayableFormContent> createState() =>
      _ReceivablePayableFormContentState();
}

class _ReceivablePayableFormContentState
    extends ConsumerState<_ReceivablePayableFormContent> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _amountController;
  late final TextEditingController _interestController;
  late final TextEditingController _noteController;

  @override
  void initState() {
    super.initState();
    _amountController = TextEditingController(
      text: widget.initialState.amountText,
    );
    _interestController = TextEditingController(
      text: widget.initialState.interestText,
    );
    _noteController = TextEditingController(text: widget.initialState.noteText);
  }

  @override
  void dispose() {
    _amountController.dispose();
    _interestController.dispose();
    _noteController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final provider = receivablePayableFormViewModelProvider(widget.args);
    final state = ref.watch(provider).requireValue;
    final receiveAccount = findAccountById(
      state.receiveAccountId,
      state.receiveAccounts,
    );
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
                AppFormSection(
                  title: _sectionTitle(state.kind),
                  children: [
                    MoneyPlainFormRow(
                      label: state.amountLabel,
                      controller: _amountController,
                      hintText: '请输入${state.amountLabel}',
                      validator:
                          (value) => validatePositiveMoneyText(
                            value,
                            nonPositiveMessage: '${state.amountLabel}必须大于 0',
                          ),
                    ),
                    if (state.kind == ReceivablePayableFormKind.collection) ...[
                      MoneyPlainFormRow(
                        label: '利息',
                        controller: _interestController,
                        hintText: '请输入利息',
                        validator: validateOptionalNonNegativeMoneyText,
                      ),
                      AccountPlainFormRow(
                        label: '到账账户',
                        account: receiveAccount,
                        selectedId: state.receiveAccountId,
                        placeholder: '请选择到账账户',
                        onTap:
                            (onSelected) =>
                                _pickReceiveAccount(state, onSelected),
                        onChanged:
                            ref.read(provider.notifier).setReceiveAccountId,
                        validator: (value) => value == null ? '请选择到账账户' : null,
                      ),
                    ],
                    DateTimePlainFormRow(
                      label: '交易日期',
                      dateTime: state.occurredAt,
                      value: _formatDateTime(state.occurredAt),
                      onTap:
                          (onSelected) =>
                              _pickDate(state.occurredAt, onSelected),
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
          ),
        ],
      ),
    );
  }

  Future<void> _pickReceiveAccount(
    ReceivablePayableFormState state,
    ValueChanged<String?> onSelected,
  ) async {
    final selected = await showAccountPickerSheet(
      context: context,
      title: '选择到账账户',
      accounts: state.receiveAccounts,
      selectedId: state.receiveAccountId,
    );
    if (!mounted || selected == null) return;
    onSelected(selected);
  }

  Future<void> _pickDate(
    DateTime occurredAt,
    ValueChanged<DateTime?> onSelected,
  ) async {
    final picked = await showAppDateTimePicker(
      context: context,
      initialDateTime: occurredAt,
      title: '选择交易日期',
    );
    if (!mounted || picked == null) return;
    onSelected(picked);
  }

  Future<void> _submit(ReceivablePayableFormViewModelProvider provider) async {
    if (!_formKey.currentState!.validate()) return;
    final viewModel = ref.read(provider.notifier);
    final confirmation = viewModel.balanceCrossingConfirmation(
      _amountController.text,
    );
    if (confirmation != null && !await _confirm(confirmation)) return;
    final outcome = await viewModel.submit(
      amountText: _amountController.text,
      interestText: _interestController.text,
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

  Future<bool> _confirm(BalanceCrossingConfirmation confirmation) async =>
      await showDialog<bool>(
        context: context,
        builder:
            (context) => AlertDialog(
              title: Text(confirmation.title),
              content: Text(confirmation.message),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context, false),
                  child: const Text('取消'),
                ),
                FilledButton(
                  onPressed: () => Navigator.pop(context, true),
                  child: const Text('继续提交'),
                ),
              ],
            ),
      ) ??
      false;
}

String _pageTitle(ReceivablePayableFormState state) {
  final editing = state.transactionId != null;
  return switch (state.kind) {
    ReceivablePayableFormKind.collection => editing ? '编辑收回' : '收回应收',
    ReceivablePayableFormKind.badDebt => editing ? '编辑坏账' : '确认坏账',
    ReceivablePayableFormKind.debtRelief => editing ? '编辑债务豁免' : '债务豁免',
  };
}

String _sectionTitle(ReceivablePayableFormKind kind) => switch (kind) {
  ReceivablePayableFormKind.collection => '收回信息',
  ReceivablePayableFormKind.badDebt => '坏账信息',
  ReceivablePayableFormKind.debtRelief => '豁免信息',
};

String _formatDateTime(DateTime date) {
  final time =
      '${date.hour.toString().padLeft(2, '0')}:'
      '${date.minute.toString().padLeft(2, '0')}';
  return '${date.year}-${date.month.toString().padLeft(2, '0')}-'
      '${date.day.toString().padLeft(2, '0')} $time';
}
