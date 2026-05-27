import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/provider.dart';
import '../../../core/money/money.dart';
import '../../../core/result/result.dart';
import '../../../design_system/token/spacing.dart';
import '../../../design_system/widget/app_datetime_picker.dart';
import '../../../design_system/widget/app_plain_form_row.dart';
import '../../../design_system/widget/app_submit_button.dart';
import '../../../application/ledger/ledger_api.dart'
    hide CreateRepaymentCommand, CorrectRepaymentCommand;
import '../../../application/credit/use_case/credit_service.dart';
import '../../../widget/business/plain_transaction_fields.dart';

class RepaymentFormPage extends ConsumerStatefulWidget {
  const RepaymentFormPage({required this.liabilityAccountId, super.key})
    : editTransactionId = null,
      assert(liabilityAccountId != null);

  const RepaymentFormPage.edit({required this.editTransactionId, super.key})
    : liabilityAccountId = null,
      assert(editTransactionId != null);

  final String? liabilityAccountId;
  final String? editTransactionId;

  @override
  ConsumerState<RepaymentFormPage> createState() => _RepaymentFormPageState();
}

class _RepaymentFormPageState extends ConsumerState<RepaymentFormPage> {
  final _formKey = GlobalKey<FormState>();
  final _principalController = TextEditingController();
  final _interestController = TextEditingController();
  final _feeController = TextEditingController();
  final _discountController = TextEditingController();
  final _noteController = TextEditingController();

  DateTime _occurredAt = DateTime.now();
  String? _liabilityAccountId;
  String? _paidFromAccountId;
  bool _submitting = false;
  bool _editInitialized = false;

  @override
  void initState() {
    super.initState();
    _liabilityAccountId = widget.liabilityAccountId;
  }

  @override
  void dispose() {
    _principalController.dispose();
    _interestController.dispose();
    _feeController.dispose();
    _discountController.dispose();
    _noteController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isEdit = widget.editTransactionId != null;
    final liabilityAccountsAsync = ref.watch(
      accountsForUsageProvider(AccountUsage.repaymentTarget),
    );
    final repaymentAccountsAsync = ref.watch(
      accountsForUsageProvider(AccountUsage.repaymentSource),
    );
    final detailAsync =
        isEdit
            ? ref.watch(transactionDetailProvider(widget.editTransactionId!))
            : null;

    final loadError =
        liabilityAccountsAsync.error ??
        repaymentAccountsAsync.error ??
        detailAsync?.error;
    if (loadError != null) {
      return _scaffold(Center(child: Text('加载失败：$loadError')));
    }
    if (!liabilityAccountsAsync.hasValue ||
        !repaymentAccountsAsync.hasValue ||
        (isEdit && !(detailAsync?.hasValue ?? false))) {
      return _scaffold(const Center(child: CircularProgressIndicator()));
    }

    if (isEdit && !_editInitialized) {
      final detail = detailAsync!.value;
      final accountsById =
          ref.read(accountsByIdProvider).value ?? const <String, Account>{};
      final view =
          detail == null
              ? null
              : ref
                  .read(creditServiceProvider)
                  .parseRepaymentEditView(detail, accountsById: accountsById);
      if (view == null) {
        return _scaffold(const Center(child: Text('该还款记录不可编辑')));
      }
      _applyView(view);
      _editInitialized = true;
    }

    final liabilityAccounts = liabilityAccountsAsync.value ?? const <Account>[];
    final allRepaymentAccounts =
        repaymentAccountsAsync.value ?? const <Account>[];
    final liabilityAccountId = _selectedId(
      _liabilityAccountId,
      liabilityAccounts,
    );
    final repaymentAccounts =
        allRepaymentAccounts
            .where((account) => account.id != liabilityAccountId)
            .toList();
    final paidFromAccountId = _selectedId(
      _paidFromAccountId,
      repaymentAccounts,
    );
    final liabilityAccount = _findAccount(
      liabilityAccounts,
      liabilityAccountId,
    );
    final paidFromAccount = _findAccount(repaymentAccounts, paidFromAccountId);

    return _scaffold(
      Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.space28,
            AppSpacing.space18,
            AppSpacing.space28,
            AppSpacing.space24,
          ),
          children: [
            AppPlainFormSection(
              children: [
                AccountPlainFormRow(
                  label: '债务账户',
                  account: liabilityAccount,
                  selectedId: liabilityAccountId,
                  placeholder: '请选择债务账户',
                  // 编辑态禁止改债务账户：金额校验依赖原账户余额，改了语义就乱了。
                  onTap:
                      (isEdit || liabilityAccounts.isEmpty)
                          ? null
                          : () => _pickAccount(
                            title: '选择债务账户',
                            accounts: liabilityAccounts,
                            selectedId: liabilityAccountId,
                            onSelected:
                                (value) => setState(() {
                                  _liabilityAccountId = value;
                                  if (_paidFromAccountId == value) {
                                    _paidFromAccountId = null;
                                  }
                                }),
                          ),
                ),
                MoneyPlainFormRow(
                  label: '金额',
                  controller: _principalController,
                  hintText: '请输入还款金额',
                  validator: _validatePositiveMoney,
                ),
                MoneyPlainFormRow(
                  label: '利息',
                  controller: _interestController,
                  hintText: '请输入利息（可选）',
                  validator: _validateOptionalMoney,
                ),
                MoneyPlainFormRow(
                  label: '手续费',
                  controller: _feeController,
                  hintText: '请输入手续费（可选）',
                  validator: _validateOptionalMoney,
                ),
                MoneyPlainFormRow(
                  label: '优惠',
                  controller: _discountController,
                  hintText: '请输入优惠（可选）',
                  validator: _validateOptionalMoney,
                ),
                DateTimePlainFormRow(
                  label: '还款日期',
                  value: _formatDateTime(_occurredAt),
                  onTap: _pickDate,
                ),
                AccountPlainFormRow(
                  label: '还款账户',
                  account: paidFromAccount,
                  selectedId: paidFromAccountId,
                  placeholder: '请选择还款账户',
                  onTap:
                      repaymentAccounts.isEmpty
                          ? null
                          : () => _pickAccount(
                            title: '选择还款账户',
                            accounts: repaymentAccounts,
                            selectedId: paidFromAccountId,
                            onSelected:
                                (value) =>
                                    setState(() => _paidFromAccountId = value),
                          ),
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
    );
  }

  Scaffold _scaffold(Widget body) {
    return Scaffold(
      backgroundColor: Theme.of(context).colorScheme.surface,
      appBar: AppBar(title: Text(_pageTitle)),
      body: body,
    );
  }

  void _applyView(RepaymentEditView view) {
    _principalController.text = view.principal.format();
    _interestController.text = view.interest?.format() ?? '';
    _feeController.text = view.fee?.format() ?? '';
    _discountController.text = view.discount?.format() ?? '';
    _noteController.text = view.note ?? '';
    _liabilityAccountId = view.liabilityAccountId;
    _paidFromAccountId = view.paidFromAccountId;
    _occurredAt = view.occurredAt;
  }

  Future<void> _pickDate() async {
    final picked = await showAppDateTimePicker(
      context: context,
      initialDateTime: _occurredAt,
      title: '选择还款日期',
    );
    if (picked == null || !mounted) return;
    setState(() => _occurredAt = picked);
  }

  Future<void> _pickAccount({
    required String title,
    required List<Account> accounts,
    required String? selectedId,
    required ValueChanged<String> onSelected,
  }) async {
    final selected = await showAccountPickerSheet(
      context: context,
      title: title,
      accounts: accounts,
      selectedId: selectedId,
    );
    if (!mounted || selected == null) return;
    onSelected(selected);
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    final liabilityAccounts =
        ref
            .read(accountsForUsageProvider(AccountUsage.repaymentTarget))
            .value ??
        const <Account>[];
    final liabilityAccountId = _selectedId(
      _liabilityAccountId,
      liabilityAccounts,
    );
    final allRepaymentAccounts =
        ref
            .read(accountsForUsageProvider(AccountUsage.repaymentSource))
            .value ??
        const <Account>[];
    final repaymentAccounts =
        allRepaymentAccounts
            .where((account) => account.id != liabilityAccountId)
            .toList();
    final paidFromAccountId = _selectedId(
      _paidFromAccountId,
      repaymentAccounts,
    );
    if (liabilityAccountId == null) {
      _showError('请选择债务账户');
      return;
    }
    if (paidFromAccountId == null) {
      _showError('请选择还款账户');
      return;
    }

    final principal = Money.parse(_principalController.text);
    final interest = _parseOptionalMoney(_interestController.text);
    final fee = _parseOptionalMoney(_feeController.text);
    final discount = _parseOptionalMoney(_discountController.text);
    final note = _blankToNull(_noteController.text);

    setState(() => _submitting = true);
    final service = ref.read(creditServiceProvider);
    final editTransactionId = widget.editTransactionId;
    final Result<CreatedTransactionResult> result;
    if (editTransactionId == null) {
      result = await service.createRepayment(
        CreateRepaymentCommand(
          liabilityAccountId: liabilityAccountId,
          paidFromAccountId: paidFromAccountId,
          principal: principal,
          interest: interest,
          fee: fee,
          discount: discount,
          occurredAt: _occurredAt,
          note: note,
        ),
      );
    } else {
      result = await service.correctRepayment(
        CorrectRepaymentCommand(
          transactionId: editTransactionId,
          liabilityAccountId: liabilityAccountId,
          paidFromAccountId: paidFromAccountId,
          principal: principal,
          interest: interest,
          fee: fee,
          discount: discount,
          occurredAt: _occurredAt,
          note: note,
        ),
      );
    }
    if (!mounted) return;
    setState(() => _submitting = false);

    switch (result) {
      case Success(:final value):
        if (editTransactionId == null) {
          context.pop();
        } else if (context.canPop()) {
          context.pop(value.transactionId);
        } else {
          context.go('/transaction/${value.transactionId}');
        }
      case FailureResult(:final failure):
        _showError(failure.message);
    }
  }

  String get _pageTitle => widget.editTransactionId == null ? '还款' : '编辑还款';

  String? _validatePositiveMoney(String? value) {
    try {
      final money = Money.parse(value ?? '');
      return money.minorUnits > 0 ? null : '金额必须大于 0';
    } on FormatException {
      return '请输入有效金额';
    }
  }

  String? _validateOptionalMoney(String? value) {
    final trimmed = value?.trim() ?? '';
    if (trimmed.isEmpty) return null;
    try {
      final money = Money.parse(trimmed);
      return money.minorUnits >= 0 ? null : '金额不能小于 0';
    } on FormatException {
      return '请输入有效金额';
    }
  }

  Money? _parseOptionalMoney(String value) {
    final trimmed = value.trim();
    if (trimmed.isEmpty) return null;
    final money = Money.parse(trimmed);
    return money.minorUnits > 0 ? money : null;
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), behavior: SnackBarBehavior.floating),
    );
  }
}

Account? _findAccount(List<Account> accounts, String? id) {
  if (id == null) return null;
  for (final account in accounts) {
    if (account.id == id) return account;
  }
  return null;
}

String? _selectedId(String? id, List<Account> accounts) {
  if (id == null) return null;
  for (final account in accounts) {
    if (account.id == id) return id;
  }
  return null;
}

String? _blankToNull(String value) {
  final trimmed = value.trim();
  return trimmed.isEmpty ? null : trimmed;
}

String _formatDateTime(DateTime date) {
  final time =
      '${date.hour.toString().padLeft(2, '0')}:'
      '${date.minute.toString().padLeft(2, '0')}';
  return '${date.year}-${date.month.toString().padLeft(2, '0')}-'
      '${date.day.toString().padLeft(2, '0')} $time';
}
