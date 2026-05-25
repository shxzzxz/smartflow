import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/providers.dart';
import '../../../core/money/money.dart';
import '../../../core/result/result.dart';
import '../../../design_system/theme/app_text_styles.dart';
import '../../../design_system/tokens/spacing.dart';
import '../../../design_system/widgets/app_datetime_picker.dart';
import '../../../design_system/widgets/app_page_header.dart';
import '../../../design_system/widgets/app_plain_form_row.dart';
import '../../../design_system/widgets/app_submit_button.dart';
import '../../../application/accounting/accounting_api.dart';
import '../../../widgets/business/money_text.dart';
import '../../../widgets/business/plain_transaction_fields.dart';

class RefundFormPage extends ConsumerStatefulWidget {
  const RefundFormPage({required this.parentTransactionId, super.key});

  final int parentTransactionId;

  @override
  ConsumerState<RefundFormPage> createState() => _RefundFormPageState();
}

class _RefundFormPageState extends ConsumerState<RefundFormPage> {
  final _formKey = GlobalKey<FormState>();
  final _amountController = TextEditingController();
  final _noteController = TextEditingController();
  DateTime _occurredAt = DateTime.now();
  int? _refundToAccountId;
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
    final detailAsync = ref.watch(
      transactionDetailProvider(widget.parentTransactionId),
    );
    final refundToAccountId = _effectiveRefundToAccountId(
      selectedId: _refundToAccountId,
      parentSettlementAccountId: _resolveParentSettlementAccountId(
        detailAsync.value,
        accountsById,
      ),
      accounts: accounts,
    );

    final remaining = detailAsync.value?.let((detail) {
      final amount = detail.transaction.primaryAmount;
      final refunded = detail.refundedTotal ?? const Money(minorUnits: 0);
      return amount - refunded;
    });
    final refundToAccount = _findAccount(refundToAccountId, accounts);

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
              const AppPageHeader(title: '退款', showBackButton: true),
              const SizedBox(height: AppSpacing.space14),
              AppPlainFormSection(
                children: [
                  if (remaining != null)
                    AppPlainValueRow(
                      label: '可退余额',
                      child: MoneyText(
                        money: remaining,
                        style: context.appTextStyles.formPlainValue,
                      ),
                    ),
                  MoneyPlainFormRow(
                    label: '退款金额',
                    controller: _amountController,
                    hintText: '请输入退款金额',
                    validator: _validatePositive,
                  ),
                  AccountPlainFormRow(
                    label: '退款账户',
                    account: refundToAccount,
                    selectedId: refundToAccountId,
                    placeholder: '请选择退款账户',
                    onTap:
                        () => _pickRefundAccount(
                          accounts,
                          selectedId: refundToAccountId,
                        ),
                    validator: (value) => value == null ? '请选择账户' : null,
                  ),
                  DateTimePlainFormRow(
                    label: '退款时间',
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
                onPressed: _submit,
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

  Future<void> _pickRefundAccount(
    List<Account> accounts, {
    required int? selectedId,
  }) async {
    final selected = await showAccountPickerSheet(
      context: context,
      title: '选择退款账户',
      accounts: accounts,
      selectedId: selectedId,
    );
    if (!mounted || selected == null) return;
    setState(() => _refundToAccountId = selected);
  }

  Future<void> _pickOccurredAt() async {
    final picked = await showAppDateTimePicker(
      context: context,
      initialDateTime: _occurredAt,
      title: '选择退款时间',
    );
    if (!mounted || picked == null) return;
    setState(() => _occurredAt = picked);
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }
    final accounts =
        ref.read(accountsForUsageProvider(AccountUsage.settlement)).value ??
        const <Account>[];
    final accountsById =
        ref.read(accountsByIdProvider).value ?? const <int, Account>{};
    final detail =
        ref.read(transactionDetailProvider(widget.parentTransactionId)).value;
    final refundToAccountId = _effectiveRefundToAccountId(
      selectedId: _refundToAccountId,
      parentSettlementAccountId: _resolveParentSettlementAccountId(
        detail,
        accountsById,
      ),
      accounts: accounts,
    );
    if (refundToAccountId == null) {
      return;
    }
    setState(() => _submitting = true);
    final service = ref.read(transactionServiceProvider);
    final result = await service.createRefund(
      CreateRefundCommand(
        amount: Money.parse(_amountController.text),
        parentTransactionId: widget.parentTransactionId,
        refundToAccountId: refundToAccountId,
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

int? _effectiveRefundToAccountId({
  required int? selectedId,
  required int? parentSettlementAccountId,
  required List<Account> accounts,
}) {
  if (_containsAccount(accounts, selectedId)) {
    return selectedId;
  }
  if (_containsAccount(accounts, parentSettlementAccountId)) {
    return parentSettlementAccountId;
  }
  return null;
}

bool _containsAccount(List<Account> accounts, int? accountId) {
  if (accountId == null) {
    return false;
  }
  return accounts.any((account) => account.id == accountId);
}

int? _resolveParentSettlementAccountId(
  TransactionDetail? detail,
  Map<int, Account> accountsById,
) {
  if (detail == null) {
    return null;
  }
  for (final entry in detail.entries) {
    final type = accountsById[entry.accountId]?.type;
    if ((type == AccountType.asset || type == AccountType.liability) &&
        entry.direction == EntryDirection.credit) {
      return entry.accountId;
    }
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

extension<T> on T {
  R let<R>(R Function(T) f) => f(this);
}
