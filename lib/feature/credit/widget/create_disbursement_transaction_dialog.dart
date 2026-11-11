import 'package:flutter/material.dart';
import 'package:smartflow/application/credit/credit_query_api.dart';
import 'package:smartflow/application/ledger/ledger_query_api.dart';
import 'package:smartflow/design_system/widget/app_datetime_picker.dart';
import 'package:smartflow/design_system/widget/app_plain_form_row.dart';
import 'package:smartflow/widget/business/account/account_picker_sheet.dart';
import 'package:smartflow/widget/business/form/plain_transaction_fields.dart';

import '../../../core/time/date_label.dart';
import '../../../design_system/theme/app_text_styles.dart';
import '../../../design_system/token/spacing.dart';
import '../../shared/view_model/ui_action_outcome.dart';

class CreateDisbursementTransactionDialog extends StatefulWidget {
  const CreateDisbursementTransactionDialog({
    required this.installment,
    required this.fundAccounts,
    required this.submit,
    super.key,
  });

  final InstallmentDTO installment;
  final List<Account> fundAccounts;
  final Future<UiActionOutcome<String>> Function({
    required String receiveAccountId,
    required DateTime occurredAt,
  })
  submit;

  @override
  State<CreateDisbursementTransactionDialog> createState() =>
      _CreateDisbursementTransactionDialogState();
}

class _CreateDisbursementTransactionDialogState
    extends State<CreateDisbursementTransactionDialog> {
  final _formKey = GlobalKey<FormState>();
  Account? _receiveAccount;
  late DateTime _occurredAt;
  bool _submitting = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _occurredAt = DateTime.now();
  }

  @override
  Widget build(BuildContext context) {
    final hasAccounts = widget.fundAccounts.isNotEmpty;
    return AlertDialog(
      title: const Text('补建放款交易'),
      scrollable: true,
      content: SizedBox(
        width: double.maxFinite,
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                '将按合同本金创建一笔借入交易，并关联到当前分期。交易时间默认当前时间，可按实际补录调整。',
                style: context.appTextStyles.formSupporting,
              ),
              const SizedBox(height: AppSpacing.space8),
              Text(
                '创建后会按本金增加到账账户和负债账户余额。若导入数据已通过期初余额或其它交易体现这笔借款，请勿重复补建。',
                style: context.appTextStyles.formSupporting.copyWith(
                  color: Theme.of(context).colorScheme.error,
                ),
              ),
              const SizedBox(height: AppSpacing.space12),
              AppPlainValueRow(
                label: '本金',
                value: widget.installment.principal.format(),
                valueAlignment: AppPlainRowValueAlignment.start,
              ),
              AppPlainValueRow(
                label: '借款日期',
                value: formatDateLabel(widget.installment.borrowingDate),
                valueAlignment: AppPlainRowValueAlignment.start,
              ),
              AccountPlainFormRow(
                label: '到账账户',
                account: _receiveAccount,
                selectedId: _receiveAccount?.id,
                placeholder: hasAccounts ? '请选择到账账户' : '暂无可用资金账户',
                validator: (_) => _receiveAccount == null ? '请选择到账账户' : null,
                onChanged: (accountId) {
                  final selected = _findAccount(accountId);
                  if (selected == null) return;
                  setState(() => _receiveAccount = selected);
                },
                onTap: hasAccounts
                    ? (onSelected) async {
                        final accountId = await showAccountPickerSheet(
                          context: context,
                          accounts: widget.fundAccounts,
                          selectedId: _receiveAccount?.id,
                        );
                        if (accountId != null && mounted) onSelected(accountId);
                      }
                    : null,
              ),
              AppPlainValueRow(
                label: '交易时间',
                value: formatDateTimeLabel(_occurredAt),
                valueAlignment: AppPlainRowValueAlignment.start,
                onTap: _submitting ? null : () => _selectDateTime(context),
              ),
              if (_error != null) ...[
                const SizedBox(height: AppSpacing.space12),
                Text(
                  _error!,
                  style: context.appTextStyles.formSupporting.copyWith(
                    color: Theme.of(context).colorScheme.error,
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: _submitting ? null : () => Navigator.of(context).pop(),
          child: const Text('取消'),
        ),
        FilledButton(
          onPressed: _submitting || !hasAccounts ? null : _submit,
          child: Text(_submitting ? '创建中…' : '创建交易'),
        ),
      ],
    );
  }

  Account? _findAccount(String? accountId) {
    if (accountId == null) return null;
    for (final account in widget.fundAccounts) {
      if (account.id == accountId) return account;
    }
    return null;
  }

  Future<void> _selectDateTime(BuildContext context) async {
    final dateTime = await showAppDateTimePicker(
      context: context,
      initialDateTime: _occurredAt,
      title: '选择交易时间',
    );
    if (dateTime == null || !mounted) return;
    setState(() => _occurredAt = dateTime);
  }

  Future<void> _submit() async {
    if (_submitting || !(_formKey.currentState?.validate() ?? false)) return;
    final account = _receiveAccount;
    if (account == null) return;
    setState(() {
      _submitting = true;
      _error = null;
    });
    final outcome = await widget.submit(
      receiveAccountId: account.id,
      occurredAt: _occurredAt,
    );
    if (!mounted) return;
    switch (outcome) {
      case UiActionSuccess<String>():
        Navigator.of(context).pop(true);
      case UiActionFailure<String>(:final error):
        setState(() {
          _submitting = false;
          _error = error.message;
        });
    }
  }
}
