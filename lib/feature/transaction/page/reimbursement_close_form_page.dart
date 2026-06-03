import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/provider.dart';
import '../../../core/money/money.dart';
import '../../../core/result/result.dart';
import '../../../core/text/text_normalizer.dart';
import '../../../design_system/token/spacing.dart';
import '../../../design_system/widget/app_datetime_picker.dart';
import '../../../design_system/widget/app_page_header.dart';
import '../../../design_system/widget/app_plain_form_row.dart';
import '../../../design_system/widget/app_submit_button.dart';
import '../../../application/ledger/ledger_command_api.dart';
import '../../../widget/business/plain_transaction_fields.dart';
import '../presentation/transaction_form_presentation.dart';

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
  DateTime _occurredAt = DateTime.now();
  String? _receiveAccountId;
  bool _submitting = false;

  @override
  void initState() {
    super.initState();
    _amountController.addListener(() => setState(() {}));
  }

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
        ref.watch(accountsByIdProvider).value ?? const <String, Account>{};
    final receiveAccount = findAccountById(_receiveAccountId, accounts);
    final detail =
        ref.watch(transactionDetailProvider(widget.advanceTransactionId)).value;
    final summary = detail?.reimbursementSummary;
    final receivable = reimbursementReceivableAccountId(detail, accountsById);
    final outstanding = summary?.outstanding;
    final actualMinor = parseMoneyMinorUnitsOrNull(_amountController.text);
    final gap =
        (outstanding != null && actualMinor != null)
            ? Money(minorUnits: actualMinor - outstanding.minorUnits)
            : null;

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
                title: '结束报销',
                subtitle: '记录最后一笔到账并对账差额',
                showBackButton: true,
              ),
              const SizedBox(height: AppSpacing.space14),
              if (outstanding != null)
                Padding(
                  padding: const EdgeInsets.only(bottom: AppSpacing.space8),
                  child: Text('剩余应收：${outstanding.format()}'),
                ),
              if (gap != null && gap.minorUnits != 0)
                Padding(
                  padding: const EdgeInsets.only(bottom: AppSpacing.space12),
                  child: Text(
                    gap.minorUnits > 0
                        ? '多收 ${gap.format()}（计入报销差额收入）'
                        : '少收 ${gap.abs().format()}（计入原报销支出分类）',
                  ),
                ),
              AppPlainFormSection(
                children: [
                  MoneyPlainFormRow(
                    label: '实收金额',
                    controller: _amountController,
                    hintText: '请输入实收金额',
                    validator: validateNonNegativeMoneyText,
                  ),
                  AccountPlainFormRow(
                    label: '到账账户',
                    account: receiveAccount,
                    selectedId: _receiveAccountId,
                    placeholder: '请选择到账账户',
                    onTap: () => _pickReceiveAccount(accounts),
                    validator: (value) {
                      final amount = parseMoneyMinorUnitsOrNull(
                        _amountController.text,
                      );
                      if (amount != null && amount > 0 && value == null) {
                        return '请选择账户';
                      }
                      return null;
                    },
                  ),
                  DateTimePlainFormRow(
                    label: '结束时间',
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
      title: '选择结束时间',
    );
    if (!mounted || picked == null) return;
    setState(() => _occurredAt = picked);
  }

  Future<void> _submit(String receivableAccountId) async {
    if (!_formKey.currentState!.validate()) {
      return;
    }
    final amount = Money.parse(_amountController.text);
    setState(() => _submitting = true);
    final service = ref.read(transactionPostingAppServiceProvider);
    final result = await service.closeReimbursement(
      CloseReimbursementCommand(
        actualReceivedAmount: amount,
        advanceTransactionId: widget.advanceTransactionId,
        receivableAccountId: receivableAccountId,
        receiveAccountId: _receiveAccountId ?? receivableAccountId,
        occurredAt: _occurredAt,
        note: trimToNull(_noteController.text),
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

String _formatDateTime(DateTime date) {
  final time =
      '${date.hour.toString().padLeft(2, '0')}:'
      '${date.minute.toString().padLeft(2, '0')}';
  return '${date.year}-${date.month.toString().padLeft(2, '0')}-'
      '${date.day.toString().padLeft(2, '0')} $time';
}
