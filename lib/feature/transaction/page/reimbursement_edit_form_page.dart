import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../application/ledger/ledger_command_api.dart';
import '../../../design_system/token/spacing.dart';
import '../../../design_system/widget/app_datetime_picker.dart';
import '../../../design_system/widget/app_form_section.dart';
import '../../../design_system/widget/app_page_header.dart';
import '../../../design_system/widget/app_submit_button.dart';
import 'package:smartflow/widget/business/finance/money_input.dart';
import 'package:smartflow/widget/business/form/plain_transaction_fields.dart';
import '../../shared/view_model/ui_action_outcome.dart';
import '../presentation/reimbursement_edit_form_presentation.dart';
import '../view_model/reimbursement_edit_form_view_model.dart';

class ReimbursementEditFormPage extends ConsumerWidget {
  const ReimbursementEditFormPage({required this.transactionId, super.key});

  final String transactionId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final provider = reimbursementEditFormViewModelProvider(transactionId);
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
    ReimbursementEditFormViewModelProvider provider,
    ReimbursementEditFormState state,
  ) {
    if (state.status == ReimbursementEditFormStatus.notFound) {
      return const Center(child: Text('原报销交易不存在'));
    }
    if (state.status == ReimbursementEditFormStatus.notEditable) {
      return Center(child: Text(state.unavailableReason ?? '当前报销交易不可编辑'));
    }
    final kind = state.kind;
    if (kind == null) {
      return const Center(child: Text('原报销交易类型不受支持'));
    }
    return _ReimbursementEditFormContent(
      key: ValueKey('${state.transactionId}:${kind.name}'),
      provider: provider,
      state: state,
      kind: kind,
    );
  }
}

class _ReimbursementEditFormContent extends ConsumerStatefulWidget {
  const _ReimbursementEditFormContent({
    required this.provider,
    required this.state,
    required this.kind,
    super.key,
  });

  final ReimbursementEditFormViewModelProvider provider;
  final ReimbursementEditFormState state;
  final ReimbursementEditKind kind;

  @override
  ConsumerState<_ReimbursementEditFormContent> createState() =>
      _ReimbursementEditFormContentState();
}

class _ReimbursementEditFormContentState
    extends ConsumerState<_ReimbursementEditFormContent> {
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
    final isClose = kind == ReimbursementEditKind.close;
    final receiveAccount = findAccountById(
      state.receiveAccountId,
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
          AppPageHeader(
            title: isClose ? '编辑结束报销' : '编辑报销到账',
            subtitle: isClose ? '修改最后一笔到账并对账差额' : '修改报销到账记录',
            showBackButton: true,
          ),
          const SizedBox(height: AppSpacing.space14),
          if (state.outstandingBeforeTransaction != null)
            Padding(
              padding: const EdgeInsets.only(bottom: AppSpacing.space12),
              child: Text(
                isClose
                    ? '结束前应收：${state.outstandingBeforeTransaction!.format()}'
                    : '本笔到账前应收：${state.outstandingBeforeTransaction!.format()}',
              ),
            ),
          if (isClose)
            ValueListenableBuilder<TextEditingValue>(
              valueListenable: _amountController,
              builder: (context, value, _) {
                final message = reimbursementCloseGapMessage(
                  amountText: value.text,
                  outstandingBeforeTransaction:
                      state.outstandingBeforeTransaction,
                );
                if (message == null) return const SizedBox.shrink();
                return Padding(
                  padding: const EdgeInsets.only(bottom: AppSpacing.space12),
                  child: Text(message),
                );
              },
            ),
          AppFormSection(
            title: '到账信息',
            children: [
              MoneyPlainFormRow(
                label: isClose ? '实收金额' : '到账金额',
                controller: _amountController,
                hintText: isClose ? '请输入实收金额' : '请输入到账金额',
                validator:
                    isClose
                        ? validateNonNegativeMoneyText
                        : validatePositiveMoneyText,
              ),
              AccountPlainFormRow(
                label: '到账账户',
                account: receiveAccount,
                selectedId: state.receiveAccountId,
                placeholder: '请选择到账账户',
                onTap:
                    (onSelected) => _pickReceiveAccount(
                      state.accounts,
                      selectedId: state.receiveAccountId,
                      onSelected: onSelected,
                    ),
                onChanged: ref.read(provider.notifier).setReceiveAccountId,
                validator:
                    (value) => validateReimbursementReceiveAccount(
                      isClose: isClose,
                      amountText: _amountController.text,
                      accountId: value,
                    ),
              ),
              DateTimePlainFormRow(
                label: isClose ? '结束时间' : '到账时间',
                dateTime: state.occurredAt,
                value: _formatDateTime(state.occurredAt),
                onTap:
                    (onSelected) =>
                        _pickOccurredAt(state.occurredAt, onSelected, isClose),
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

  Future<void> _pickReceiveAccount(
    List<Account> accounts, {
    required String? selectedId,
    required ValueChanged<String?> onSelected,
  }) async {
    final selected = await showAccountPickerSheet(
      context: context,
      title: '选择到账账户',
      accounts: accounts,
      selectedId: selectedId,
    );
    if (!mounted || selected == null) return;
    onSelected(selected);
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

  Future<void> _submit(ReimbursementEditFormViewModelProvider provider) async {
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
