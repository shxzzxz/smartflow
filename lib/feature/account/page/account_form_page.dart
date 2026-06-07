import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:remixicon/remixicon.dart';

import '../../../application/ledger/ledger_command_api.dart';
import '../../../core/money/money.dart';
import '../../../design_system/theme/app_text_styles.dart';
import '../../../design_system/token/radius.dart';
import '../../../design_system/token/spacing.dart';
import '../../../design_system/widget/app_datetime_picker.dart';
import '../../../design_system/widget/app_form_field.dart';
import '../../../design_system/widget/app_plain_form_row.dart';
import 'package:smartflow/widget/business/icon/business_icon.dart';
import 'package:smartflow/widget/business/icon/icon_choice_grid.dart';
import '../../shared/provider/ledger_query_providers.dart';
import '../../shared/view_model/ui_action_outcome.dart';
import '../view_model/account_form_view_model.dart';

class AccountFormPage extends ConsumerStatefulWidget {
  const AccountFormPage({this.accountId, super.key});

  final String? accountId;

  @override
  ConsumerState<AccountFormPage> createState() => _AccountFormPageState();
}

class _AccountFormPageState extends ConsumerState<AccountFormPage> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _openingBalanceController = TextEditingController(text: '0');
  final _creditLimitController = TextEditingController();
  final _noteController = TextEditingController();
  String? _scheduledEditAccountId;

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
    final formState = ref.watch(accountFormViewModelProvider);

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

    return _buildFormScaffold(context, formState);
  }

  Widget _buildForEdit(BuildContext context, List<Account> accounts) {
    final account = _findAccount(accounts, widget.accountId!);
    if (account == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('编辑账户')),
        body: const Center(child: Text('账户不存在')),
      );
    }
    _scheduleEditInitialization(account);
    return _buildFormScaffold(context, ref.watch(accountFormViewModelProvider));
  }

  void _scheduleEditInitialization(Account account) {
    final initializedId =
        ref.read(accountFormViewModelProvider).initializedAccountId;
    if (initializedId == account.id || _scheduledEditAccountId == account.id) {
      return;
    }
    _scheduledEditAccountId = account.id;
    Future.microtask(() {
      if (!mounted) return;
      syncTextControllerText(_nameController, account.name);
      syncTextControllerText(
        _openingBalanceController,
        account.balance.format(),
      );
      syncTextControllerText(
        _creditLimitController,
        account.creditLimit?.format() ?? '',
      );
      syncTextControllerText(_noteController, account.note ?? '');
      ref
          .read(accountFormViewModelProvider.notifier)
          .initializeForEdit(account);
    });
  }

  Widget _buildFormScaffold(BuildContext context, AccountFormState formState) {
    final colors = Theme.of(context).colorScheme;
    final notifier = ref.read(accountFormViewModelProvider.notifier);

    return Scaffold(
      backgroundColor: colors.surface,
      body: SafeArea(
        child: Form(
          key: _formKey,
          child: Column(
            children: [
              _AccountFormHeader(
                title: _isEditMode ? '编辑账户' : '新建账户',
                submitting: formState.submitting,
                onSave: _submit,
              ),
              if (!_isEditMode) ...[
                _AccountKindTabs(kind: formState.kind, onChanged: _setKind),
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
                      selectedKey: formState.iconKey,
                      onChanged: notifier.setIconKey,
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
                    if (showsManualBalanceField(formState.kind)) ...[
                      AppPlainFormRow(
                        label: manualBalanceLabel(
                          kind: formState.kind,
                          isEdit: _isEditMode,
                        ),
                        child: AppPlainTextFormField(
                          controller: _openingBalanceController,
                          hintText: manualBalanceHint(
                            kind: formState.kind,
                            isEdit: _isEditMode,
                          ),
                          keyboardType: const TextInputType.numberWithOptions(
                            decimal: true,
                          ),
                          validator: _validateMoney,
                        ),
                      ),
                      const Divider(height: 1),
                    ],
                    if (isLiabilityAccountKind(formState.kind)) ...[
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
                      if (formState.kind == AccountFormKind.credit)
                        AppPlainFormRow(
                          label: '出账还款日',
                          child: _BillingRepaymentFields(
                            billingDay: formState.billingDay,
                            repaymentDay: formState.repaymentDay,
                            onSelectBillingDay:
                                () => _pickMonthlyDay(
                                  title: '选择出账日',
                                  selectedDay: formState.billingDay,
                                  onChanged: notifier.setBillingDay,
                                ),
                            onSelectRepaymentDay:
                                () => _pickMonthlyDay(
                                  title: '选择还款日',
                                  selectedDay: formState.repaymentDay,
                                  onChanged: notifier.setRepaymentDay,
                                ),
                          ),
                        )
                      else
                        AppPlainFormRow(
                          label: '还款日',
                          child: _MonthlyDayField(
                            day: formState.repaymentDay,
                            placeholder: '还款日',
                            onTap:
                                () => _pickMonthlyDay(
                                  title: '选择还款日',
                                  selectedDay: formState.repaymentDay,
                                  onChanged: notifier.setRepaymentDay,
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

  String? _validateMoney(String? value) {
    final money = Money.tryParse(value ?? '0');
    if (money == null) return '请输入有效金额';
    if (money.minorUnits < 0) return '请输入非负金额';
    return null;
  }

  String? _validateOptionalMoney(String? value) {
    final text = value?.trim() ?? '';
    if (text.isEmpty) return null;
    return _validateMoney(text);
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

  void _setKind(AccountFormKind kind) {
    ref.read(accountFormViewModelProvider.notifier).setKind(kind);
    if (!isLiabilityAccountKind(kind)) {
      syncTextControllerText(_creditLimitController, '');
    }
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    final outcome = await ref
        .read(accountFormViewModelProvider.notifier)
        .submit(
          nameText: _nameController.text,
          openingBalanceText: _openingBalanceController.text,
          creditLimitText: _creditLimitController.text,
          noteText: _noteController.text,
          editAccountId: widget.accountId,
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

  final AccountFormKind kind;
  final ValueChanged<AccountFormKind> onChanged;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        _AccountKindTab(
          label: '资金',
          selected: kind == AccountFormKind.fund,
          onTap: () => onChanged(AccountFormKind.fund),
        ),
        _AccountKindTab(
          label: '信用',
          selected: kind == AccountFormKind.credit,
          onTap: () => onChanged(AccountFormKind.credit),
        ),
        _AccountKindTab(
          label: '贷款',
          selected: kind == AccountFormKind.loan,
          onTap: () => onChanged(AccountFormKind.loan),
        ),
        _AccountKindTab(
          label: '报销',
          selected: kind == AccountFormKind.reimbursement,
          onTap: () => onChanged(AccountFormKind.reimbursement),
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

Account? _findAccount(List<Account> accounts, String id) {
  for (final account in accounts) {
    if (account.id == id) return account;
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
