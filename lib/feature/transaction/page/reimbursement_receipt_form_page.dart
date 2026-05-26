import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/provider.dart';
import '../../../core/money/money.dart';
import '../../../core/result/result.dart';
import '../../../design_system/token/spacing.dart';
import '../../../design_system/widget/app_datetime_picker.dart';
import '../../../design_system/widget/app_page_header.dart';
import '../../../design_system/widget/app_plain_form_row.dart';
import '../../../design_system/widget/app_submit_button.dart';
import '../../../application/ledger/ledger_api.dart';
import '../../../widget/business/plain_transaction_fields.dart';

class ReimbursementReceiptFormPage extends ConsumerStatefulWidget {
  const ReimbursementReceiptFormPage({
    required this.advanceTransactionId,
    super.key,
  });

  final int advanceTransactionId;

  @override
  ConsumerState<ReimbursementReceiptFormPage> createState() =>
      _ReimbursementReceiptFormPageState();
}

class _ReimbursementReceiptFormPageState
    extends ConsumerState<ReimbursementReceiptFormPage> {
  final _formKey = GlobalKey<FormState>();
  final _amountController = TextEditingController();
  final _noteController = TextEditingController();
  DateTime _occurredAt = DateTime.now();
  int? _receiveAccountId;
  bool _submitting = false;

  @override
  void dispose() {
    _amountController.dispose();
    _noteController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final accounts =
        ref.watch(accountsForUsageProvider(AccountUsage.settlement)).value ??
        const <Account>[];
    final accountsById =
        ref.watch(accountsByIdProvider).value ?? const <int, Account>{};
    final receiveAccount = _findAccount(_receiveAccountId, accounts);
    final detail =
        ref.watch(transactionDetailProvider(widget.advanceTransactionId)).value;
    final summary = detail?.reimbursementSummary;
    final receivable = _resolveReceivable(detail, accountsById);

    return Scaffold(
      backgroundColor: Theme.of(context).colorScheme.surface,
      body: SafeArea(
        child: Form(
          key: _formKey,
          child: ListView(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.space16,
              AppSpacing.space14,
              AppSpacing.space16,
              AppSpacing.space24,
            ),
            children: [
              const AppPageHeader(
                title: '记一笔到账',
                subtitle: '将报销款记入资金账户',
                showBackButton: true,
              ),
              const SizedBox(height: AppSpacing.space14),
              if (summary != null)
                Padding(
                  padding: const EdgeInsets.only(bottom: AppSpacing.space12),
                  child: Text('剩余应收：${summary.outstanding.format()}'),
                ),
              AppPlainFormSection(
                children: [
                  MoneyPlainFormRow(
                    label: '到账金额',
                    controller: _amountController,
                    hintText: '请输入到账金额',
                    validator: _validatePositive,
                  ),
                  AccountPlainFormRow(
                    label: '到账账户',
                    account: receiveAccount,
                    selectedId: _receiveAccountId,
                    placeholder: '请选择到账账户',
                    onTap: () => _pickReceiveAccount(accounts),
                    validator: (value) => value == null ? '请选择账户' : null,
                  ),
                  DateTimePlainFormRow(
                    label: '到账时间',
                    value: _formatDateTime(_occurredAt),
                    onTap: _pickOccurredAt,
                  ),
                  NotePlainFormRow(controller: _noteController),
                ],
              ),
              const SizedBox(height: AppSpacing.space24),
              AppSubmitButton(
                label: '保存',
                loading: _submitting,
                onPressed:
                    receivable == null ? null : () => _submit(receivable),
              ),
            ],
          ),
        ),
      ),
    );
  }

  String? _validatePositive(String? value) {
    try {
      final money = Money.parse(value ?? '');
      return money.minorUnits > 0 ? null : '金额必须大于 0';
    } on FormatException {
      return '请输入有效金额';
    }
  }

  int? _resolveReceivable(
    TransactionDetail? detail,
    Map<int, Account> accountsById,
  ) {
    if (detail == null) return null;
    for (final entry in detail.entries) {
      if (accountsById[entry.accountId]?.type == AccountType.asset &&
          entry.direction == EntryDirection.debit) {
        return entry.accountId;
      }
    }
    return null;
  }

  Future<void> _pickReceiveAccount(List<Account> accounts) async {
    final selected = await showAccountPickerSheet(
      context: context,
      title: '选择到账账户',
      accounts: accounts,
      selectedId: _receiveAccountId,
    );
    if (!mounted || selected == null) return;
    setState(() => _receiveAccountId = selected);
  }

  Future<void> _pickOccurredAt() async {
    final picked = await showAppDateTimePicker(
      context: context,
      initialDateTime: _occurredAt,
      title: '选择到账时间',
    );
    if (!mounted || picked == null) return;
    setState(() => _occurredAt = picked);
  }

  Future<void> _submit(int receivableAccountId) async {
    if (!_formKey.currentState!.validate()) {
      return;
    }
    setState(() => _submitting = true);
    final service = ref.read(postingAppServiceProvider);
    final result = await service.createReimbursementReceipt(
      CreateReimbursementReceiptCommand(
        amount: Money.parse(_amountController.text),
        advanceTransactionId: widget.advanceTransactionId,
        receivableAccountId: receivableAccountId,
        receiveAccountId: _receiveAccountId!,
        occurredAt: _occurredAt,
        note:
            _noteController.text.trim().isEmpty
                ? null
                : _noteController.text.trim(),
      ),
    );
    if (!mounted) return;
    setState(() => _submitting = false);
    switch (result) {
      case Success():
        context.pop();
      case FailureResult(:final failure):
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(failure.message)));
    }
  }
}

Account? _findAccount(int? accountId, List<Account> accounts) {
  if (accountId == null) return null;
  for (final account in accounts) {
    if (account.id == accountId) return account;
  }
  return null;
}

String _formatDateTime(DateTime date) {
  final time =
      '${date.hour.toString().padLeft(2, '0')}:'
      '${date.minute.toString().padLeft(2, '0')}';
  return '${date.year}-${date.month.toString().padLeft(2, '0')}-'
      '${date.day.toString().padLeft(2, '0')} $time';
}
