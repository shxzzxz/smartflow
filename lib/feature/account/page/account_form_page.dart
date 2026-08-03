import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:remixicon/remixicon.dart';

import '../../../design_system/theme/app_text_styles.dart';
import '../../../design_system/token/radius.dart';
import '../../../design_system/token/spacing.dart';
import '../../../design_system/widget/app_datetime_picker.dart';
import '../../../design_system/widget/app_form_field.dart';
import '../../../design_system/widget/app_form_section.dart';
import '../../../design_system/widget/app_plain_form_field.dart';
import '../../../design_system/widget/app_plain_form_row.dart';
import '../../../application/ledger/ledger_query_api.dart';
import '../../../shared/account_profile/account_profile_kind.dart';
import 'package:smartflow/widget/business/finance/money_input.dart';
import 'package:smartflow/widget/business/icon/business_icon.dart';
import 'package:smartflow/widget/business/icon/icon_catalog_picker.dart';
import '../../shared/view_model/ui_action_outcome.dart';
import '../../shared/provider/ledger_query_providers.dart';
import '../view_model/account_form_view_model.dart';

class AccountFormPage extends ConsumerWidget {
  const AccountFormPage({this.accountId, super.key});

  final String? accountId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final asyncState = ref.watch(accountFormViewModelProvider(accountId));
    return switch (asyncState) {
      AsyncData(value: final formState) when formState != null =>
        _AccountFormContent(
          key: ValueKey<String?>(accountId),
          accountId: accountId,
          initialState: formState,
        ),
      AsyncData(value: null) => const _AccountFormStatusPage(
        title: '编辑账户',
        message: '账户不存在',
      ),
      AsyncError() => _AccountFormStatusPage(
        title: accountId == null ? '新建账户' : '编辑账户',
        message: '账户加载失败，请稍后重试',
      ),
      _ => const Scaffold(body: Center(child: CircularProgressIndicator())),
    };
  }
}

class _AccountFormStatusPage extends StatelessWidget {
  const _AccountFormStatusPage({required this.title, required this.message});

  final String title;
  final String message;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(title)),
      body: Center(child: Text(message)),
    );
  }
}

class _AccountFormContent extends ConsumerStatefulWidget {
  const _AccountFormContent({
    required this.accountId,
    required this.initialState,
    super.key,
  });

  final String? accountId;
  final AccountFormState initialState;

  @override
  ConsumerState<_AccountFormContent> createState() =>
      _AccountFormContentState();
}

class _AccountFormContentState extends ConsumerState<_AccountFormContent> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _nameController;
  late final TextEditingController _openingBalanceController;
  late final TextEditingController _creditLimitController;
  late final TextEditingController _noteController;
  late final FocusNode _nameFocusNode;

  bool get _isEditMode => widget.accountId != null;

  @override
  void initState() {
    super.initState();
    final initialValues = widget.initialState.initialValues;
    _nameController = TextEditingController(text: initialValues.name);
    _openingBalanceController = TextEditingController(
      text: initialValues.openingBalance,
    );
    _creditLimitController = TextEditingController(
      text: initialValues.creditLimit,
    );
    _noteController = TextEditingController(text: initialValues.note);
    _nameFocusNode = FocusNode();
  }

  @override
  void dispose() {
    _nameFocusNode.dispose();
    _nameController.dispose();
    _openingBalanceController.dispose();
    _creditLimitController.dispose();
    _noteController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return _buildFormScaffold(context, widget.initialState);
  }

  Widget _buildFormScaffold(BuildContext context, AccountFormState formState) {
    final colors = Theme.of(context).colorScheme;
    final notifier = ref.read(
      accountFormViewModelProvider(widget.accountId).notifier,
    );
    final groups =
        ref.watch(accountGroupsProvider).value ?? const <AccountGroup>[];
    final selectedGroup =
        groups.where((group) => group.id == formState.groupId).firstOrNull;

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
              ],
              Expanded(
                child: ListView(
                  padding: const EdgeInsets.fromLTRB(
                    AppSpacing.space20,
                    AppSpacing.space16,
                    AppSpacing.space20,
                    AppSpacing.space24,
                  ),
                  children: [
                    AppFormSection(
                      title: '账户图标',
                      description: '选择一个容易识别的图标',
                      children: [
                        IconCatalogPicker(
                          usage: BusinessIconUsage.account,
                          selectedKey: formState.iconKey,
                          onChanged: notifier.setIconKey,
                        ),
                      ],
                    ),
                    const SizedBox(height: AppSpacing.space24),
                    AppFormSection(
                      title: '基本信息',
                      children: [
                        AppPlainTextFormRow(
                          label: '账户名称',
                          requiredIndicator: true,
                          controller: _nameController,
                          focusNode: _nameFocusNode,
                          hintText: '请输入账户名称',
                          textInputAction: TextInputAction.next,
                          validator:
                              (value) =>
                                  value == null || value.trim().isEmpty
                                      ? '请输入账户名称'
                                      : null,
                        ),
                        if (showsManualBalanceField(formState.kind))
                          MoneyPlainFormRow(
                            label: manualBalanceLabel(
                              kind: formState.kind,
                              isEdit: _isEditMode,
                            ),
                            controller: _openingBalanceController,
                            hintText: manualBalanceHint(
                              kind: formState.kind,
                              isEdit: _isEditMode,
                            ),
                            validator: validateNonNegativeMoneyText,
                          ),
                        AppPlainSelectFormRow<String>(
                          label: '账户分组',
                          value: formState.groupId,
                          valueText: selectedGroup?.name,
                          placeholder: '未分组',
                          onTap:
                              (onSelected) =>
                                  _showGroupSheet(groups, onSelected),
                          onChanged: notifier.setGroupId,
                        ),
                      ],
                    ),
                    if (isLiabilityAccountKind(formState.kind)) ...[
                      const SizedBox(height: AppSpacing.space24),
                      AppFormSection(
                        title:
                            formState.kind == AccountProfileKind.credit
                                ? '信用设置'
                                : '负债设置',
                        children: [
                          MoneyPlainFormRow(
                            label: '信用额度',
                            controller: _creditLimitController,
                            hintText: '请输入信用额度（可选）',
                            validator: validateOptionalNonNegativeMoneyText,
                          ),
                          if (formState.kind == AccountProfileKind.credit) ...[
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
                            ),
                            AppPlainSwitchRow(
                              label: '出账日计入下期',
                              value: formState.billingDayToNext,
                              onChanged: notifier.setBillingDayToNext,
                            ),
                          ],
                        ],
                      ),
                    ],
                    const SizedBox(height: AppSpacing.space24),
                    AppFormSection(
                      title: '其他',
                      children: [
                        AppPlainTextFormRow(
                          label: '备注',
                          controller: _noteController,
                          hintText: '请输入备注（可选）',
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _showGroupSheet(
    List<AccountGroup> groups,
    ValueChanged<String?> onSelected,
  ) async {
    final selected = await showModalBottomSheet<String>(
      context: context,
      showDragHandle: true,
      builder:
          (sheetContext) => SafeArea(
            child: ListView(
              shrinkWrap: true,
              children: [
                ListTile(
                  title: const Text('未分组'),
                  onTap: () => Navigator.of(sheetContext).pop(''),
                ),
                for (final group in groups)
                  ListTile(
                    title: Text(group.name),
                    onTap: () => Navigator.of(sheetContext).pop(group.id),
                  ),
              ],
            ),
          ),
    );
    if (!mounted || selected == null) return;
    onSelected(selected.isEmpty ? null : selected);
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
      maxDay: 28,
    );
    if (!mounted) return;
    onChanged(selected);
  }

  void _setKind(AccountProfileKind kind) {
    ref
        .read(accountFormViewModelProvider(widget.accountId).notifier)
        .setKind(kind);
    if (!isLiabilityAccountKind(kind)) {
      syncTextControllerText(_creditLimitController, '');
    }
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    final outcome = await ref
        .read(accountFormViewModelProvider(widget.accountId).notifier)
        .submit(
          nameText: _nameController.text,
          openingBalanceText: _openingBalanceController.text,
          creditLimitText: _creditLimitController.text,
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

  final AccountProfileKind kind;
  final ValueChanged<AccountProfileKind> onChanged;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        _AccountKindTab(
          label: '资金',
          selected: kind == AccountProfileKind.fund,
          onTap: () => onChanged(AccountProfileKind.fund),
        ),
        _AccountKindTab(
          label: '信用',
          selected: kind == AccountProfileKind.credit,
          onTap: () => onChanged(AccountProfileKind.credit),
        ),
        _AccountKindTab(
          label: '贷款',
          selected: kind == AccountProfileKind.loan,
          onTap: () => onChanged(AccountProfileKind.loan),
        ),
        _AccountKindTab(
          label: '报销',
          selected: kind == AccountProfileKind.reimbursement,
          onTap: () => onChanged(AccountProfileKind.reimbursement),
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
