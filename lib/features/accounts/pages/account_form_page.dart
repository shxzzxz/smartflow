import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:remixicon/remixicon.dart';

import '../../../app/providers.dart';
import '../../../core/errors/failure.dart';
import '../../../core/money/money.dart';
import '../../../core/patch/patch.dart';
import '../../../core/result/result.dart';
import '../../../design_system/theme/app_text_styles.dart';
import '../../../design_system/tokens/radius.dart';
import '../../../design_system/tokens/spacing.dart';
import '../../../design_system/widgets/app_datetime_picker.dart';
import '../../../design_system/widgets/app_form_field.dart';
import '../../../design_system/widgets/app_plain_form_row.dart';
import '../../../domain/accounting/accounting_api.dart';
import '../../../widgets/business/business_icon.dart';
import '../../../widgets/business/icon_choice_grid.dart';

enum _AccountKind { fund, credit, loan, reimbursement }

class AccountFormPage extends ConsumerStatefulWidget {
  const AccountFormPage({this.accountId, super.key});

  final int? accountId;

  @override
  ConsumerState<AccountFormPage> createState() => _AccountFormPageState();
}

class _AccountFormPageState extends ConsumerState<AccountFormPage> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _openingBalanceController = TextEditingController(text: '0');
  final _creditLimitController = TextEditingController();
  final _noteController = TextEditingController();
  _AccountKind _kind = _AccountKind.fund;
  String _currencyCode = Money.defaultCurrency;
  String _iconKey = _defaultAccountIconKey(_AccountKind.fund);
  int? _billingDay;
  int? _repaymentDay;
  bool _submitting = false;
  int? _loadedAccountId;
  Account? _loadedAccount;

  bool get _isEditMode => widget.accountId != null;

  @override
  void dispose() {
    _nameController.dispose();
    _openingBalanceController.dispose();
    _creditLimitController.dispose();
    _noteController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final accountId = widget.accountId;
    if (accountId != null) {
      final accountsAsync = ref.watch(accountListProvider);
      return switch (accountsAsync) {
        AsyncData(value: final accounts) => _buildForEdit(context, accounts),
        AsyncError(:final error) => Scaffold(
          appBar: AppBar(title: const Text('编辑账户')),
          body: Center(child: Text('账户加载失败：$error')),
        ),
        _ => const Scaffold(body: Center(child: CircularProgressIndicator())),
      };
    }

    return _buildFormScaffold(context);
  }

  Widget _buildForEdit(BuildContext context, List<Account> accounts) {
    final account = _findAccount(accounts, widget.accountId!);
    if (account == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('编辑账户')),
        body: const Center(child: Text('账户不存在')),
      );
    }
    _populateForEdit(account);
    return _buildFormScaffold(context);
  }

  Widget _buildFormScaffold(BuildContext context) {
    final colors = Theme.of(context).colorScheme;

    return Scaffold(
      backgroundColor: colors.surface,
      body: SafeArea(
        child: Form(
          key: _formKey,
          child: Column(
            children: [
              _AccountFormHeader(
                title: _isEditMode ? '编辑账户' : '新建账户',
                submitting: _submitting,
                onSave: _submit,
              ),
              if (!_isEditMode) ...[
                _AccountKindTabs(kind: _kind, onChanged: _switchKind),
                const Divider(height: 1),
              ],
              Expanded(
                child: ListView(
                  padding: const EdgeInsets.fromLTRB(
                    AppSpacing.space28,
                    AppSpacing.space24,
                    AppSpacing.space28,
                    AppSpacing.space24,
                  ),
                  children: [
                    IconChoiceGrid(
                      choices: _accountIconGridItems,
                      selectedKey: _iconKey,
                      onChanged: (value) => setState(() => _iconKey = value),
                    ),
                    const SizedBox(height: AppSpacing.space20),
                    const Divider(height: 1),
                    AppPlainFormRow(
                      label: '账户名称',
                      child: AppPlainTextFormField(
                        controller: _nameController,
                        hintText: '请输入账户名称',
                        textInputAction: TextInputAction.next,
                        validator:
                            (value) =>
                                value == null || value.trim().isEmpty
                                    ? '请输入账户名称'
                                    : null,
                      ),
                    ),
                    const Divider(height: 1),
                    if (_showsManualBalanceField(_kind)) ...[
                      AppPlainFormRow(
                        label: _manualBalanceLabel(
                          kind: _kind,
                          isEdit: _isEditMode,
                        ),
                        child: Row(
                          children: [
                            Expanded(
                              child: AppPlainTextFormField(
                                controller: _openingBalanceController,
                                hintText: _manualBalanceHint(
                                  kind: _kind,
                                  isEdit: _isEditMode,
                                ),
                                keyboardType:
                                    const TextInputType.numberWithOptions(
                                      decimal: true,
                                    ),
                                validator: _validateMoney,
                              ),
                            ),
                            InkWell(
                              onTap: _isEditMode ? null : _showCurrencySheet,
                              child: Padding(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: AppSpacing.space8,
                                  vertical: AppSpacing.space12,
                                ),
                                child: Text(
                                  _currencyLabel(_currencyCode),
                                  style: context.appTextStyles.formPlainValue,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const Divider(height: 1),
                    ],
                    if (_isLiabilityKind(_kind)) ...[
                      AppPlainFormRow(
                        label: '信用额度',
                        child: AppPlainTextFormField(
                          controller: _creditLimitController,
                          hintText: '请输入信用额度（可选）',
                          keyboardType: const TextInputType.numberWithOptions(
                            decimal: true,
                          ),
                          validator: _validateOptionalMoney,
                        ),
                      ),
                      const Divider(height: 1),
                      if (_kind == _AccountKind.credit)
                        AppPlainFormRow(
                          label: '出账还款日',
                          child: _BillingRepaymentFields(
                            billingDay: _billingDay,
                            repaymentDay: _repaymentDay,
                            onSelectBillingDay:
                                () => _pickMonthlyDay(
                                  title: '选择出账日',
                                  selectedDay: _billingDay,
                                  onChanged:
                                      (day) =>
                                          setState(() => _billingDay = day),
                                ),
                            onSelectRepaymentDay:
                                () => _pickMonthlyDay(
                                  title: '选择还款日',
                                  selectedDay: _repaymentDay,
                                  onChanged:
                                      (day) =>
                                          setState(() => _repaymentDay = day),
                                ),
                          ),
                        )
                      else
                        AppPlainFormRow(
                          label: '还款日',
                          child: _MonthlyDayField(
                            day: _repaymentDay,
                            placeholder: '还款日',
                            onTap:
                                () => _pickMonthlyDay(
                                  title: '选择还款日',
                                  selectedDay: _repaymentDay,
                                  onChanged:
                                      (day) =>
                                          setState(() => _repaymentDay = day),
                                ),
                          ),
                        ),
                      const Divider(height: 1),
                    ],
                    AppPlainFormRow(
                      label: '备注',
                      child: AppPlainTextFormField(
                        controller: _noteController,
                        hintText: '请输入备注（可选）',
                      ),
                    ),
                    const Divider(height: 1),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _populateForEdit(Account account) {
    if (_loadedAccountId == account.id) return;

    final kind = _accountKindForAccount(account);
    _loadedAccountId = account.id;
    _loadedAccount = account;
    _kind = kind;
    _nameController.text = account.name;
    _openingBalanceController.text = account.balance.format();
    _creditLimitController.text = account.creditLimit?.format() ?? '';
    _noteController.text = account.note ?? '';
    _currencyCode = account.currencyCode;
    _iconKey = account.iconKey ?? _defaultAccountIconKey(kind);
    _billingDay = account.billingDay;
    _repaymentDay = account.repaymentDay;
  }

  void _switchKind(_AccountKind kind) {
    if (kind == _kind) return;
    setState(() {
      _kind = kind;
      _iconKey = _defaultAccountIconKey(kind);
    });
  }

  String? _validateMoney(String? value) {
    try {
      final money = Money.parse(value ?? '0');
      if (money.minorUnits < 0) {
        return '请输入非负金额';
      }
      return null;
    } on FormatException {
      return '请输入有效金额';
    }
  }

  String? _validateOptionalMoney(String? value) {
    final text = value?.trim() ?? '';
    if (text.isEmpty) return null;
    return _validateMoney(text);
  }

  Money _openingBalanceForKind() {
    if (!_showsManualBalanceField(_kind)) {
      return const Money(minorUnits: 0);
    }
    return Money.parse(_openingBalanceController.text, currency: _currencyCode);
  }

  Money? _creditLimitForKind() {
    if (!_isLiabilityKind(_kind)) {
      return null;
    }
    final text = _creditLimitController.text.trim();
    return text.isEmpty ? null : Money.parse(text, currency: _currencyCode);
  }

  Future<void> _showCurrencySheet() async {
    final selected = await showModalBottomSheet<String>(
      context: context,
      showDragHandle: true,
      builder: (context) {
        return SafeArea(
          child: ListView(
            shrinkWrap: true,
            children: [
              for (final option in _currencyOptions)
                ListTile(
                  leading: Icon(
                    _currencyCode == option.code
                        ? RemixIcons.checkbox_circle_fill
                        : RemixIcons.checkbox_blank_circle_line,
                  ),
                  title: Text(option.label),
                  onTap: () => Navigator.of(context).pop(option.code),
                ),
            ],
          ),
        );
      },
    );
    if (!mounted || selected == null) return;
    setState(() => _currencyCode = selected);
  }

  Future<void> _pickMonthlyDay({
    required String title,
    required int? selectedDay,
    required ValueChanged<int?> onChanged,
  }) async {
    final selected = await showAppDayOfMonthPicker(
      context: context,
      title: title,
      selectedDay: selectedDay,
    );
    if (!mounted) return;
    onChanged(selected);
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    setState(() => _submitting = true);
    if (_isEditMode) {
      final account = _loadedAccount;
      if (account == null) {
        _completeSubmit<void>(
          const Result.failure(
            Failure(
              code: 'account_not_loaded',
              message: 'Account has not been loaded.',
            ),
          ),
        );
        return;
      }
      final noteText = _noteController.text.trim();
      final creditLimit = _creditLimitForKind();
      final billingDayValue =
          _kind == _AccountKind.credit ? _billingDay : null;
      final repaymentDayValue =
          _isLiabilityKind(_kind) ? _repaymentDay : null;

      final result = await ref
          .read(accountServiceProvider)
          .editAccount(
            EditAccountCommand(
              id: account.id,
              name: _nameController.text,
              iconKey: Patch.set(_iconKey),
              note:
                  noteText.isEmpty
                      ? const Patch<String>.clear()
                      : Patch.set(noteText),
              creditLimit:
                  creditLimit == null
                      ? const Patch<Money>.clear()
                      : Patch.set(creditLimit),
              billingDay:
                  billingDayValue == null
                      ? const Patch<int>.clear()
                      : Patch.set(billingDayValue),
              repaymentDay:
                  repaymentDayValue == null
                      ? const Patch<int>.clear()
                      : Patch.set(repaymentDayValue),
              targetBalance:
                  _showsManualBalanceField(_kind)
                      ? _openingBalanceForKind()
                      : null,
            ),
          );
      _completeSubmit(result);
      return;
    }

    final type = _accountTypeForKind(_kind);
    final result = await ref
        .read(accountServiceProvider)
        .createAccount(
          CreateAccountCommand(
            name: _nameController.text,
            type: type,
            currencyCode: _currencyCode,
            subtype: _accountSubtypeForKind(_kind),
            iconKey: _iconKey,
            openingBalance: _openingBalanceForKind(),
            note: _noteController.text,
            creditLimit: _creditLimitForKind(),
            billingDay: _kind == _AccountKind.credit ? _billingDay : null,
            repaymentDay: _isLiabilityKind(_kind) ? _repaymentDay : null,
          ),
        );
    _completeSubmit(result);
  }

  void _completeSubmit<T>(Result<T> result) {
    if (!mounted) {
      return;
    }
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

class _AccountFormHeader extends StatelessWidget {
  const _AccountFormHeader({
    required this.title,
    required this.submitting,
    required this.onSave,
  });

  final String title;
  final bool submitting;
  final VoidCallback onSave;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.space4,
        AppSpacing.space12,
        AppSpacing.space12,
        AppSpacing.space4,
      ),
      child: Stack(
        alignment: Alignment.center,
        children: [
          Align(
            alignment: Alignment.centerLeft,
            child: IconButton(
              onPressed: () => context.pop(),
              icon: const Icon(RemixIcons.arrow_left_s_line),
              iconSize: 32,
              tooltip: '返回',
            ),
          ),
          Align(
            alignment: Alignment.centerRight,
            child: TextButton(
              onPressed: submitting ? null : onSave,
              child:
                  submitting
                      ? const SizedBox.square(
                        dimension: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                      : const Text('保存'),
            ),
          ),
          Text(title, style: context.appTextStyles.dateNavigationTitle),
        ],
      ),
    );
  }
}

class _AccountKindTabs extends StatelessWidget {
  const _AccountKindTabs({required this.kind, required this.onChanged});

  final _AccountKind kind;
  final ValueChanged<_AccountKind> onChanged;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        _AccountKindTab(
          label: '资金',
          selected: kind == _AccountKind.fund,
          onTap: () => onChanged(_AccountKind.fund),
        ),
        _AccountKindTab(
          label: '信用',
          selected: kind == _AccountKind.credit,
          onTap: () => onChanged(_AccountKind.credit),
        ),
        _AccountKindTab(
          label: '贷款',
          selected: kind == _AccountKind.loan,
          onTap: () => onChanged(_AccountKind.loan),
        ),
        _AccountKindTab(
          label: '报销',
          selected: kind == _AccountKind.reimbursement,
          onTap: () => onChanged(_AccountKind.reimbursement),
        ),
      ],
    );
  }
}

class _AccountKindTab extends StatelessWidget {
  const _AccountKindTab({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final textStyles = context.appTextStyles;
    return Expanded(
      child: InkWell(
        onTap: onTap,
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(vertical: AppSpacing.space4),
              child: Text(
                label,
                style: textStyles
                    .segmentedControlLabel(selected: selected)
                    .copyWith(
                      color:
                          selected ? colors.primary : colors.onSurfaceVariant,
                    ),
              ),
            ),
            AnimatedContainer(
              duration: const Duration(milliseconds: 160),
              width: selected ? 82 : 0,
              height: 3,
              decoration: BoxDecoration(
                color: selected ? colors.primary : Colors.transparent,
                borderRadius: BorderRadius.circular(AppRadius.radiusSm),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _BillingRepaymentFields extends StatelessWidget {
  const _BillingRepaymentFields({
    required this.billingDay,
    required this.repaymentDay,
    required this.onSelectBillingDay,
    required this.onSelectRepaymentDay,
  });

  final int? billingDay;
  final int? repaymentDay;
  final VoidCallback onSelectBillingDay;
  final VoidCallback onSelectRepaymentDay;

  @override
  Widget build(BuildContext context) {
    final textStyle = context.appTextStyles.formPlainValue;
    return Row(
      children: [
        Expanded(
          child: _MonthlyDayField(
            day: billingDay,
            placeholder: '出账日',
            onTap: onSelectBillingDay,
          ),
        ),
        Text('/', style: textStyle),
        Expanded(
          child: _MonthlyDayField(
            day: repaymentDay,
            placeholder: '还款日',
            onTap: onSelectRepaymentDay,
          ),
        ),
      ],
    );
  }
}

class _MonthlyDayField extends StatelessWidget {
  const _MonthlyDayField({
    required this.day,
    required this.placeholder,
    required this.onTap,
  });

  final int? day;
  final String placeholder;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: AppPlainValueText(text: day == null ? placeholder : '$day 日'),
    );
  }
}

AccountType _accountTypeForKind(_AccountKind kind) {
  return switch (kind) {
    _AccountKind.fund || _AccountKind.reimbursement => AccountType.asset,
    _AccountKind.credit || _AccountKind.loan => AccountType.liability,
  };
}

AccountSubtype? _accountSubtypeForKind(_AccountKind kind) {
  return switch (kind) {
    _AccountKind.reimbursement => AccountSubtype.reimbursement,
    _AccountKind.credit => AccountSubtype.consumerCredit,
    _AccountKind.loan => AccountSubtype.loan,
    _ => null,
  };
}

String _defaultAccountIconKey(_AccountKind kind) {
  return switch (kind) {
    _AccountKind.fund => 'alipay',
    _AccountKind.reimbursement => 'reimburse',
    _AccountKind.credit => 'cmb_credit_card',
    _AccountKind.loan => 'loan',
  };
}

bool _isLiabilityKind(_AccountKind kind) {
  return kind == _AccountKind.credit || kind == _AccountKind.loan;
}

bool _showsManualBalanceField(_AccountKind kind) {
  return kind == _AccountKind.fund || _isLiabilityKind(kind);
}

String _manualBalanceLabel({required _AccountKind kind, required bool isEdit}) {
  if (_isLiabilityKind(kind)) {
    return isEdit ? '当前欠款' : '初始欠款';
  }
  return isEdit ? '当前余额' : '初始余额';
}

String _manualBalanceHint({required _AccountKind kind, required bool isEdit}) {
  if (_isLiabilityKind(kind)) {
    return isEdit ? '请输入当前欠款' : '请输入初始欠款';
  }
  return isEdit ? '请输入当前余额' : '请输入初始余额';
}

_AccountKind _accountKindForAccount(Account account) {
  if (account.type == AccountType.liability) {
    return account.subtype == AccountSubtype.loan
        ? _AccountKind.loan
        : _AccountKind.credit;
  }
  return account.subtype == AccountSubtype.reimbursement
      ? _AccountKind.reimbursement
      : _AccountKind.fund;
}

Account? _findAccount(List<Account> accounts, int id) {
  for (final account in accounts) {
    if (account.id == id) {
      return account;
    }
  }
  return null;
}

final List<IconChoiceGridItem> _accountIconGridItems = [
  for (final spec in businessIconSpecsForUsage(BusinessIconUsage.account))
    IconChoiceGridItem(
      iconKey: spec.iconKey,
      label: spec.label,
      iconBuilder:
          (context, size) => BusinessIcon(iconKey: spec.iconKey, size: size),
    ),
];

const List<_CurrencyOption> _currencyOptions = [
  _CurrencyOption(code: Money.defaultCurrency, label: 'CNY-人民币'),
];

String _currencyLabel(String code) {
  return _currencyOptions
      .firstWhere(
        (option) => option.code == code,
        orElse: () => _CurrencyOption(code: code, label: code),
      )
      .label;
}

class _CurrencyOption {
  const _CurrencyOption({required this.code, required this.label});

  final String code;
  final String label;
}
