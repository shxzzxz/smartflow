import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/provider.dart';
import '../../../application/ledger/ledger_query_api.dart';
import '../../../design_system/theme/app_text_styles.dart';
import '../../../design_system/theme/app_theme_extension.dart';
import '../../../design_system/token/colors.dart';
import '../../../design_system/token/radius.dart';
import '../../../design_system/token/spacing.dart';
import '../../../design_system/widget/app_datetime_picker.dart';
import '../../../design_system/widget/app_form_field.dart';
import '../../../design_system/widget/app_surface.dart';
import '../../../widget/business/business_icon.dart';
import '../../../widget/business/category_grid_picker.dart';
import '../../../widget/business/money_text.dart';
import '../../../widget/business/plain_transaction_fields.dart';
import '../../shared/view_model/ui_action_outcome.dart';
import '../presentation/transaction_form_presentation.dart';
import '../view_model/transaction_form_view_model.dart';

enum TransactionFormInitialMode { expense, income, transfer, borrowing }

class TransactionFormPage extends ConsumerStatefulWidget {
  const TransactionFormPage({
    this.editTransactionId,
    this.initialMode = TransactionFormInitialMode.expense,
    this.initialFromAccountId,
    this.initialToAccountId,
    super.key,
  });

  final String? editTransactionId;
  final TransactionFormInitialMode initialMode;
  final String? initialFromAccountId;
  final String? initialToAccountId;

  @override
  ConsumerState<TransactionFormPage> createState() =>
      _TransactionFormPageState();
}

class _TransactionFormPageState extends ConsumerState<TransactionFormPage> {
  final _formKey = GlobalKey<FormState>();
  final _amountController = TextEditingController();
  final _noteController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _amountController.addListener(_syncAmountTextToViewModel);
    _noteController.addListener(_syncNoteTextToViewModel);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      ref
          .read(transactionFormViewModelProvider.notifier)
          .initializeNew(
            initialMode: _toFormMode(widget.initialMode),
            initialFromAccountId: widget.initialFromAccountId,
            initialToAccountId: widget.initialToAccountId,
          );
    });
  }

  @override
  void dispose() {
    _amountController.removeListener(_syncAmountTextToViewModel);
    _noteController.removeListener(_syncNoteTextToViewModel);
    _amountController.dispose();
    _noteController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final formState = ref.watch(transactionFormViewModelProvider);
    ref.listen<TransactionFormState>(transactionFormViewModelProvider, (
      _,
      next,
    ) {
      syncTextControllerText(_amountController, next.amountText);
      syncTextControllerText(_noteController, next.noteText);
    });

    final settlementAccountsAsync = ref.watch(
      accountsForUsageProvider(AccountUsage.settlement),
    );
    final fundAccountsAsync = ref.watch(
      accountsForUsageProvider(AccountUsage.fund),
    );
    final liabilityAccountsAsync = ref.watch(
      accountsForUsageProvider(AccountUsage.borrowingLiability),
    );
    final reimbursementAccountsAsync = ref.watch(
      accountsForUsageProvider(AccountUsage.reimbursement),
    );
    final expenseTreeAsync = ref.watch(
      categoryTreeProvider(AccountType.expense),
    );
    final incomeTreeAsync = ref.watch(categoryTreeProvider(AccountType.income));
    final editTransactionId = widget.editTransactionId;
    final editDetailAsync =
        editTransactionId == null
            ? null
            : ref.watch(transactionDetailProvider(editTransactionId));
    final accountsByIdAsync =
        editTransactionId == null ? null : ref.watch(accountsByIdProvider);

    if (editTransactionId != null &&
        (!settlementAccountsAsync.hasValue ||
            !fundAccountsAsync.hasValue ||
            !liabilityAccountsAsync.hasValue ||
            !reimbursementAccountsAsync.hasValue ||
            !expenseTreeAsync.hasValue ||
            !incomeTreeAsync.hasValue ||
            !(editDetailAsync?.hasValue ?? false) ||
            !(accountsByIdAsync?.hasValue ?? false))) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    final settlementAccounts =
        settlementAccountsAsync.value ?? const <Account>[];
    final fundAccounts = fundAccountsAsync.value ?? const <Account>[];
    final liabilityAccounts = liabilityAccountsAsync.value ?? const <Account>[];
    final reimbursementAccounts =
        reimbursementAccountsAsync.value ?? const <Account>[];
    final expenseTree = expenseTreeAsync.value ?? const <CategoryNode>[];
    final incomeTree = incomeTreeAsync.value ?? const <CategoryNode>[];
    final editDetail = editDetailAsync?.value;

    if (editTransactionId != null && editDetail == null) {
      return const Scaffold(body: Center(child: Text('交易不存在')));
    }

    if (editTransactionId != null &&
        editDetail != null &&
        formState.initializedEditTransactionId != editTransactionId) {
      final snapshot = transactionFormEditSnapshot(
        detail: editDetail,
        expenseTree: expenseTree,
        incomeTree: incomeTree,
        accountsById: accountsByIdAsync?.value ?? const <String, Account>{},
      );
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        ref
            .read(transactionFormViewModelProvider.notifier)
            .initializeForEdit(
              transactionId: editTransactionId,
              snapshot: snapshot,
            );
      });
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    final keyboardInset = MediaQuery.viewInsetsOf(context).bottom;
    final keyboardVisible = keyboardInset > 0;

    return Scaffold(
      backgroundColor: AppColors.neutral99,
      resizeToAvoidBottomInset: false,
      body: SafeArea(
        child: Form(
          key: _formKey,
          child: Column(
            children: [
              _TopBar(
                mode: formState.mode,
                editing: editTransactionId != null,
                onBack: () => context.pop(),
                onDelete:
                    editTransactionId != null && !formState.submitting
                        ? _confirmDelete
                        : null,
                onModeChanged:
                    (mode) => ref
                        .read(transactionFormViewModelProvider.notifier)
                        .setMode(mode),
              ),
              Expanded(
                child: ListView(
                  padding: const EdgeInsets.fromLTRB(
                    AppSpacing.space16,
                    AppSpacing.space8,
                    AppSpacing.space16,
                    AppSpacing.space12,
                  ),
                  children: [
                    if (formState.mode == TransactionFormMode.expense)
                      FormField<String>(
                        key: ValueKey(
                          'expense-category-${formState.expenseCategoryId}',
                        ),
                        initialValue: formState.expenseCategoryId,
                        validator:
                            (_) =>
                                formState.mode == TransactionFormMode.expense &&
                                        formState.expenseCategoryId == null
                                    ? '请选择支出分类'
                                    : null,
                        builder:
                            (field) => Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                CategoryGridPicker(
                                  nodes: expenseTree,
                                  selectedRootId: formState.expenseRootId,
                                  selectedCategoryId:
                                      formState.expenseCategoryId,
                                  emptyLabel: '尚未创建支出分类',
                                  onRootSelected: (account) {
                                    _selectExpenseCategory(
                                      rootId: account.id,
                                      categoryId: account.id,
                                    );
                                    field.didChange(account.id);
                                  },
                                  onChildSelected: (root, child) {
                                    _selectExpenseCategory(
                                      rootId: root.id,
                                      categoryId: child.id,
                                    );
                                    field.didChange(child.id);
                                  },
                                  onAddRoot:
                                      () => _openCategoryForm(
                                        AccountType.expense,
                                      ),
                                  onAddChild:
                                      (rootId) => _openCategoryForm(
                                        AccountType.expense,
                                        parentId: rootId,
                                      ),
                                ),
                                if (field.errorText != null)
                                  _FormFieldErrorText(field.errorText!),
                              ],
                            ),
                      ),
                    if (formState.mode == TransactionFormMode.income)
                      FormField<String>(
                        key: ValueKey(
                          'income-category-${formState.incomeCategoryId}',
                        ),
                        initialValue: formState.incomeCategoryId,
                        validator:
                            (_) =>
                                formState.mode == TransactionFormMode.income &&
                                        formState.incomeCategoryId == null
                                    ? '请选择收入分类'
                                    : null,
                        builder:
                            (field) => Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                CategoryGridPicker(
                                  nodes: incomeTree,
                                  selectedRootId: formState.incomeRootId,
                                  selectedCategoryId:
                                      formState.incomeCategoryId,
                                  emptyLabel: '尚未创建收入分类',
                                  onRootSelected: (account) {
                                    _selectIncomeCategory(
                                      rootId: account.id,
                                      categoryId: account.id,
                                    );
                                    field.didChange(account.id);
                                  },
                                  onChildSelected: (root, child) {
                                    _selectIncomeCategory(
                                      rootId: root.id,
                                      categoryId: child.id,
                                    );
                                    field.didChange(child.id);
                                  },
                                  onAddRoot:
                                      () =>
                                          _openCategoryForm(AccountType.income),
                                  onAddChild:
                                      (rootId) => _openCategoryForm(
                                        AccountType.income,
                                        parentId: rootId,
                                      ),
                                ),
                                if (field.errorText != null)
                                  _FormFieldErrorText(field.errorText!),
                              ],
                            ),
                      ),
                    if (formState.mode == TransactionFormMode.transfer)
                      _MainAccountPickerSection(
                        children: [
                          _MainAccountPickerTile(
                            label: '转出账户',
                            accounts: settlementAccounts,
                            selectedId: formState.fromAccountId,
                            onChanged:
                                (value) => ref
                                    .read(
                                      transactionFormViewModelProvider.notifier,
                                    )
                                    .setFromAccountId(value),
                          ),
                          const SizedBox(height: AppSpacing.space8),
                          _MainAccountPickerTile(
                            label: '转入账户',
                            accounts: settlementAccounts,
                            selectedId: formState.toAccountId,
                            onChanged:
                                (value) => ref
                                    .read(
                                      transactionFormViewModelProvider.notifier,
                                    )
                                    .setToAccountId(value),
                          ),
                        ],
                      ),
                    if (formState.mode == TransactionFormMode.borrowing)
                      _MainAccountPickerSection(
                        children: [
                          _MainAccountPickerTile(
                            label: '借出账户',
                            accounts: liabilityAccounts,
                            selectedId: formState.liabilityAccountId,
                            onChanged:
                                (value) => ref
                                    .read(
                                      transactionFormViewModelProvider.notifier,
                                    )
                                    .setLiabilityAccountId(value),
                          ),
                          const SizedBox(height: AppSpacing.space8),
                          _MainAccountPickerTile(
                            label: '借入账户',
                            accounts: fundAccounts,
                            selectedId: formState.toAccountId,
                            onChanged:
                                (value) => ref
                                    .read(
                                      transactionFormViewModelProvider.notifier,
                                    )
                                    .setToAccountId(value),
                          ),
                        ],
                      ),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(
                  AppSpacing.space16,
                  AppSpacing.space4,
                  AppSpacing.space16,
                  AppSpacing.space8,
                ),
                child: Column(
                  children: [
                    _AmountNotePanel(
                      amountController: _amountController,
                      noteController: _noteController,
                      semantic: _amountSemantic(formState.mode),
                      amountValidator:
                          (value) => validatePositiveMoneyText(
                            value,
                            nonPositiveMessage: '请输入有效金额',
                          ),
                    ),
                    const SizedBox(height: AppSpacing.space4),
                    _TransactionOptionsPanel(
                      mode: formState.mode,
                      occurredAt: formState.occurredAt,
                      moneyAccounts: settlementAccounts,
                      reimbursementAccounts: reimbursementAccounts,
                      fromAccountId: formState.fromAccountId,
                      toAccountId: formState.toAccountId,
                      reimbursementAccountId: formState.reimbursementAccountId,
                      excludeStats: formState.excludeStats,
                      excludeBudget: formState.excludeBudget,
                      onPickDate: _pickDate,
                      onFromAccountChanged:
                          (value) => ref
                              .read(transactionFormViewModelProvider.notifier)
                              .setFromAccountId(value),
                      onToAccountChanged:
                          (value) => ref
                              .read(transactionFormViewModelProvider.notifier)
                              .setToAccountId(value),
                      onReimbursementAccountChanged:
                          (value) => ref
                              .read(transactionFormViewModelProvider.notifier)
                              .setReimbursementAccountId(value),
                      onExcludeStatsChanged:
                          (value) => ref
                              .read(transactionFormViewModelProvider.notifier)
                              .setExcludeStats(value),
                      onExcludeBudgetChanged:
                          (value) => ref
                              .read(transactionFormViewModelProvider.notifier)
                              .setExcludeBudget(value),
                    ),
                    _AccountValidationFields(
                      state: formState,
                      settlementAccounts: settlementAccounts,
                      fundAccounts: fundAccounts,
                      liabilityAccounts: liabilityAccounts,
                    ),
                    if (keyboardVisible)
                      SizedBox(height: keyboardInset)
                    else ...[
                      const SizedBox(height: AppSpacing.space6),
                      _NumberPad(
                        submitting: formState.submitting,
                        onInput: _handleNumberInput,
                        onBackspace: _deleteAmountDigit,
                        onClear: _clearForNext,
                        onCancel: () => context.pop(),
                        onSubmit: _submit,
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _pickDate() async {
    final picked = await showAppDateTimePicker(
      context: context,
      initialDateTime: ref.read(transactionFormViewModelProvider).occurredAt,
      title: '选择交易时间',
    );
    if (picked == null || !mounted) return;
    ref.read(transactionFormViewModelProvider.notifier).setOccurredAt(picked);
  }

  void _openCategoryForm(AccountType type, {String? parentId}) {
    final query =
        Uri(
          path: '/category/new',
          queryParameters: {
            'type': type.name,
            if (parentId != null) 'parentId': parentId.toString(),
          },
        ).toString();
    context.push(query);
  }

  void _handleNumberInput(String value) {
    syncTextControllerText(
      _amountController,
      appendMoneyInputText(_amountController.text, value),
    );
  }

  void _deleteAmountDigit() {
    syncTextControllerText(
      _amountController,
      deleteLastMoneyInputText(_amountController.text),
    );
  }

  void _clearForNext() {
    ref.read(transactionFormViewModelProvider.notifier).clearForNext();
  }

  Future<void> _submit() async {
    final isValid = _formKey.currentState?.validate() ?? false;
    if (!isValid) return;

    final outcome = await ref
        .read(transactionFormViewModelProvider.notifier)
        .submit(_submitOptions());
    if (!mounted) return;

    switch (outcome) {
      case SubmitSuccess():
        if (widget.editTransactionId != null) {
          context.go('/');
        } else {
          context.pop();
        }
      case SubmitFailure(:final error):
        _showError(error.message);
    }
  }

  TransactionFormSubmitOptions _submitOptions() {
    return TransactionFormSubmitOptions(
      editTransactionId: widget.editTransactionId,
      settlementAccounts:
          ref.read(accountsForUsageProvider(AccountUsage.settlement)).value ??
          const <Account>[],
      fundAccounts:
          ref.read(accountsForUsageProvider(AccountUsage.fund)).value ??
          const <Account>[],
      liabilityAccounts:
          ref
              .read(accountsForUsageProvider(AccountUsage.borrowingLiability))
              .value ??
          const <Account>[],
      reimbursementAccounts:
          ref
              .read(accountsForUsageProvider(AccountUsage.reimbursement))
              .value ??
          const <Account>[],
    );
  }

  MoneySemantic _amountSemantic(TransactionFormMode mode) {
    return switch (mode) {
      TransactionFormMode.expense => MoneySemantic.expense,
      TransactionFormMode.income => MoneySemantic.income,
      TransactionFormMode.transfer => MoneySemantic.neutral,
      TransactionFormMode.borrowing => MoneySemantic.neutral,
    };
  }

  void _showError(String message) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  void _syncAmountTextToViewModel() {
    ref
        .read(transactionFormViewModelProvider.notifier)
        .setAmountText(_amountController.text);
  }

  void _syncNoteTextToViewModel() {
    ref
        .read(transactionFormViewModelProvider.notifier)
        .setNoteText(_noteController.text);
  }

  void _selectExpenseCategory({
    required String? rootId,
    required String? categoryId,
  }) {
    ref
        .read(transactionFormViewModelProvider.notifier)
        .setExpenseCategory(rootId: rootId, categoryId: categoryId);
  }

  void _selectIncomeCategory({
    required String? rootId,
    required String? categoryId,
  }) {
    ref
        .read(transactionFormViewModelProvider.notifier)
        .setIncomeCategory(rootId: rootId, categoryId: categoryId);
  }

  Future<void> _confirmDelete() async {
    final transactionId = widget.editTransactionId;
    final formState = ref.read(transactionFormViewModelProvider);
    if (transactionId == null || formState.submitting) return;

    final confirmed = await showDialog<bool>(
      context: context,
      builder:
          (ctx) => AlertDialog(
            title: const Text('删除交易'),
            content: const Text('删除后会写入冲销记录，历史链路仍可追溯。'),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(ctx).pop(false),
                child: const Text('取消'),
              ),
              FilledButton(
                onPressed: () => Navigator.of(ctx).pop(true),
                child: const Text('删除'),
              ),
            ],
          ),
    );
    if (confirmed != true || !mounted) return;

    final outcome = await ref
        .read(transactionFormViewModelProvider.notifier)
        .deleteTransaction(transactionId);
    if (!mounted) return;

    switch (outcome) {
      case UiActionSuccess<void>():
        context.go('/');
      case UiActionFailure<void>(:final error):
        _showError('删除失败：${error.message}');
    }
  }
}

class _AccountValidationFields extends StatelessWidget {
  const _AccountValidationFields({
    required this.state,
    required this.settlementAccounts,
    required this.fundAccounts,
    required this.liabilityAccounts,
  });

  final TransactionFormState state;
  final List<Account> settlementAccounts;
  final List<Account> fundAccounts;
  final List<Account> liabilityAccounts;

  @override
  Widget build(BuildContext context) {
    final fields = <Widget>[
      if (state.mode == TransactionFormMode.expense)
        _HiddenValidationField(
          keyValue:
              'expense-account-${effectiveAccountId(state.fromAccountId, settlementAccounts)}',
          validator:
              () =>
                  effectiveAccountId(state.fromAccountId, settlementAccounts) ==
                          null
                      ? '请选择支出账户'
                      : null,
        ),
      if (state.mode == TransactionFormMode.income)
        _HiddenValidationField(
          keyValue:
              'income-account-${effectiveAccountId(state.toAccountId, settlementAccounts)}',
          validator:
              () =>
                  effectiveAccountId(state.toAccountId, settlementAccounts) ==
                          null
                      ? '请选择收入账户'
                      : null,
        ),
      if (state.mode == TransactionFormMode.transfer)
        _HiddenValidationField(
          keyValue:
              'transfer-accounts-${effectiveAccountId(state.fromAccountId, settlementAccounts)}-${effectiveAccountId(state.toAccountId, settlementAccounts)}',
          validator:
              () =>
                  effectiveAccountId(state.fromAccountId, settlementAccounts) ==
                              null ||
                          effectiveAccountId(
                                state.toAccountId,
                                settlementAccounts,
                              ) ==
                              null
                      ? '请选择转出和转入账户'
                      : null,
        ),
      if (state.mode == TransactionFormMode.borrowing)
        _HiddenValidationField(
          keyValue:
              'borrowing-accounts-${effectiveAccountId(state.liabilityAccountId, liabilityAccounts)}-${effectiveAccountId(state.toAccountId, fundAccounts)}',
          validator:
              () =>
                  effectiveAccountId(
                                state.liabilityAccountId,
                                liabilityAccounts,
                              ) ==
                              null ||
                          effectiveAccountId(state.toAccountId, fundAccounts) ==
                              null
                      ? '请选择借出和借入账户'
                      : null,
        ),
    ];

    return Column(children: fields);
  }
}

class _HiddenValidationField extends StatelessWidget {
  const _HiddenValidationField({
    required this.keyValue,
    required this.validator,
  });

  final String keyValue;
  final String? Function() validator;

  @override
  Widget build(BuildContext context) {
    return FormField<String>(
      key: ValueKey(keyValue),
      validator: (_) => validator(),
      builder:
          (field) =>
              field.errorText == null
                  ? const SizedBox.shrink()
                  : Align(
                    alignment: Alignment.centerLeft,
                    child: _FormFieldErrorText(field.errorText!),
                  ),
    );
  }
}

class _TopBar extends StatelessWidget {
  const _TopBar({
    required this.mode,
    required this.editing,
    required this.onBack,
    required this.onDelete,
    required this.onModeChanged,
  });

  final TransactionFormMode mode;
  final bool editing;
  final VoidCallback onBack;
  final VoidCallback? onDelete;
  final ValueChanged<TransactionFormMode> onModeChanged;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.space8,
        AppSpacing.space6,
        AppSpacing.space8,
        AppSpacing.space2,
      ),
      child: Row(
        children: [
          IconButton(
            onPressed: onBack,
            icon: const Icon(Icons.arrow_back_ios_new),
            tooltip: '返回',
          ),
          Expanded(
            child:
                editing
                    ? Center(
                      child: Text(
                        '编辑${_modeLabel(mode)}',
                        style: context.appTextStyles.subsectionTitleStrong,
                      ),
                    )
                    : _ModeTabs(mode: mode, onChanged: onModeChanged),
          ),
          if (editing)
            IconButton(
              onPressed: onDelete,
              icon: const Icon(Icons.delete_outline),
              tooltip: '删除',
            )
          else
            const SizedBox(width: AppSpacing.space48),
        ],
      ),
    );
  }
}

class _ModeTabs extends StatelessWidget {
  const _ModeTabs({required this.mode, required this.onChanged});

  final TransactionFormMode mode;
  final ValueChanged<TransactionFormMode> onChanged;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: [
        for (final value in TransactionFormMode.values)
          _ModeTabItem(
            label: _modeLabel(value),
            selected: value == mode,
            onTap: () => onChanged(value),
          ),
      ],
    );
  }
}

class _ModeTabItem extends StatelessWidget {
  const _ModeTabItem({
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

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(AppRadius.radiusSm),
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.space6,
          vertical: AppSpacing.space6,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              label,
              style: textStyles
                  .segmentedControlLabel(selected: selected)
                  .copyWith(
                    color: selected ? colors.primary : colors.onSurfaceVariant,
                  ),
            ),
            const SizedBox(height: AppSpacing.space6),
            AnimatedContainer(
              duration: const Duration(milliseconds: 160),
              width: selected ? 40 : AppSpacing.space0,
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

class _MainAccountPickerSection extends StatelessWidget {
  const _MainAccountPickerSection({required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return AppSurface(
      border: true,
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.space16),
        child: Column(children: children),
      ),
    );
  }
}

class _MainAccountPickerTile extends StatelessWidget {
  const _MainAccountPickerTile({
    required this.label,
    required this.accounts,
    required this.selectedId,
    required this.onChanged,
  });

  final String label;
  final List<Account> accounts;
  final String? selectedId;
  final ValueChanged<String?> onChanged;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final textStyles = context.appTextStyles;
    final effective = effectiveAccount(selectedId, accounts);
    final title = effective?.name ?? '$label为空';

    return Material(
      color: colors.surfaceContainerLowest,
      borderRadius: BorderRadius.circular(AppRadius.radiusMd),
      child: InkWell(
        onTap: () => _showAccountSheet(context),
        borderRadius: BorderRadius.circular(AppRadius.radiusMd),
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.space12,
            vertical: AppSpacing.space12,
          ),
          child: Row(
            children: [
              SizedBox(
                width: AppSpacing.space32,
                child: Center(
                  child: BusinessIcon(iconKey: effective?.iconKey, size: 28),
                ),
              ),
              const SizedBox(width: AppSpacing.space12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(label, style: textStyles.formLabel),
                    const SizedBox(height: AppSpacing.space2),
                    Text(
                      title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: textStyles.formValue,
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

  Future<void> _showAccountSheet(BuildContext context) async {
    final selected = await showAccountPickerSheet(
      context: context,
      title: '选择$label',
      accounts: accounts,
      selectedId: effectiveAccount(selectedId, accounts)?.id,
    );
    if (selected == null) return;
    onChanged(selected);
  }
}

class _AmountNotePanel extends StatelessWidget {
  const _AmountNotePanel({
    required this.amountController,
    required this.noteController,
    required this.semantic,
    required this.amountValidator,
  });

  final TextEditingController amountController;
  final TextEditingController noteController;
  final MoneySemantic semantic;
  final FormFieldValidator<String> amountValidator;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final financeColors = Theme.of(context).extension<AppThemeExtension>();
    final textStyles = context.appTextStyles;
    final amountColor = switch (semantic) {
      MoneySemantic.expense => financeColors?.expense ?? colors.error,
      MoneySemantic.income => financeColors?.income ?? colors.primary,
      _ => colors.onSurface,
    };

    return Container(
      height: 42,
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.space8),
      color: AppColors.neutral99,
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: noteController,
              minLines: 1,
              maxLines: 1,
              style: textStyles.inputText,
              decoration: const InputDecoration(
                hintText: '点击填写备注',
                border: InputBorder.none,
                enabledBorder: InputBorder.none,
                focusedBorder: InputBorder.none,
                isDense: true,
                contentPadding: EdgeInsets.zero,
              ),
            ),
          ),
          const SizedBox(width: AppSpacing.space10),
          SizedBox(
            width: 104,
            child: TextFormField(
              controller: amountController,
              readOnly: true,
              showCursor: false,
              textAlign: TextAlign.end,
              inputFormatters: [moneyInputFormatter],
              validator: amountValidator,
              style: textStyles.amountHero.copyWith(color: amountColor),
              decoration: InputDecoration(
                hintText: '0.00',
                hintStyle: textStyles.amountHero.copyWith(
                  color: amountColor.withValues(alpha: 0.58),
                ),
                border: InputBorder.none,
                enabledBorder: InputBorder.none,
                focusedBorder: InputBorder.none,
                isDense: true,
                contentPadding: EdgeInsets.zero,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _FormFieldErrorText extends StatelessWidget {
  const _FormFieldErrorText(this.message);

  final String message;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(
        left: AppSpacing.space8,
        top: AppSpacing.space4,
        bottom: AppSpacing.space4,
      ),
      child: Text(
        message,
        style: context.appTextStyles.formLabel.copyWith(
          color: Theme.of(context).colorScheme.error,
        ),
      ),
    );
  }
}

class _TransactionOptionsPanel extends StatelessWidget {
  const _TransactionOptionsPanel({
    required this.mode,
    required this.occurredAt,
    required this.moneyAccounts,
    required this.reimbursementAccounts,
    required this.fromAccountId,
    required this.toAccountId,
    required this.reimbursementAccountId,
    required this.excludeStats,
    required this.excludeBudget,
    required this.onPickDate,
    required this.onFromAccountChanged,
    required this.onToAccountChanged,
    required this.onReimbursementAccountChanged,
    required this.onExcludeStatsChanged,
    required this.onExcludeBudgetChanged,
  });

  final TransactionFormMode mode;
  final DateTime occurredAt;
  final List<Account> moneyAccounts;
  final List<Account> reimbursementAccounts;
  final String? fromAccountId;
  final String? toAccountId;
  final String? reimbursementAccountId;
  final bool excludeStats;
  final bool excludeBudget;
  final VoidCallback onPickDate;
  final ValueChanged<String?> onFromAccountChanged;
  final ValueChanged<String?> onToAccountChanged;
  final ValueChanged<String?> onReimbursementAccountChanged;
  final ValueChanged<bool> onExcludeStatsChanged;
  final ValueChanged<bool> onExcludeBudgetChanged;

  @override
  Widget build(BuildContext context) {
    final showPrimaryAccount =
        mode == TransactionFormMode.expense ||
        mode == TransactionFormMode.income;
    final showExcludeStats = showPrimaryAccount;
    final accountLabel = mode == TransactionFormMode.income ? '收入账户' : '支出账户';
    final primaryAccountId =
        mode == TransactionFormMode.income ? toAccountId : fromAccountId;
    final primaryChanged =
        mode == TransactionFormMode.income
            ? onToAccountChanged
            : onFromAccountChanged;

    return Align(
      alignment: Alignment.centerLeft,
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          mainAxisAlignment: MainAxisAlignment.start,
          children: [
            _QuickActionChip(
              label: _formatDateTime(occurredAt),
              selected: false,
              onTap: onPickDate,
            ),
            if (showPrimaryAccount)
              _AccountSelectorChip(
                label: accountLabel,
                accounts: moneyAccounts,
                selectedId: primaryAccountId,
                onChanged: primaryChanged,
              ),
            if (mode == TransactionFormMode.expense)
              _AccountSelectorChip(
                label: '报销账户',
                accounts: reimbursementAccounts,
                selectedId: reimbursementAccountId,
                allowNone: true,
                noneLabel: '不报销',
                onChanged: onReimbursementAccountChanged,
              ),
            if (showExcludeStats)
              _ToggleChip(
                icon: Icons.remove_circle_outline,
                label: '不计收支',
                selected: excludeStats,
                onChanged: onExcludeStatsChanged,
              ),
            if (mode == TransactionFormMode.expense)
              _ToggleChip(
                icon: Icons.pie_chart_outline,
                label: '不计预算',
                selected: excludeBudget,
                onChanged: onExcludeBudgetChanged,
              ),
          ],
        ),
      ),
    );
  }
}

class _AccountSelectorChip extends StatelessWidget {
  const _AccountSelectorChip({
    required this.label,
    required this.accounts,
    required this.selectedId,
    required this.onChanged,
    this.allowNone = false,
    this.noneLabel = '无',
  });

  final String label;
  final List<Account> accounts;
  final String? selectedId;
  final ValueChanged<String?> onChanged;
  final bool allowNone;
  final String noneLabel;

  @override
  Widget build(BuildContext context) {
    final selected =
        selectedId == null
            ? null
            : accounts.where((account) => account.id == selectedId).firstOrNull;
    final effective = selected ?? effectiveAccount(null, accounts);
    final text =
        allowNone && selectedId == null
            ? noneLabel
            : effective == null
            ? '$label为空'
            : effective.name;
    final leading =
        effective == null || (allowNone && selectedId == null)
            ? null
            : BusinessIcon(iconKey: effective.iconKey, size: 14);

    return _QuickActionChip(
      label: text,
      leading: leading,
      selected: false,
      onTap: () => _showAccountSheet(context),
    );
  }

  Future<void> _showAccountSheet(BuildContext context) async {
    if (allowNone) {
      final selected = await showOptionalAccountPickerSheet(
        context: context,
        title: '选择$label',
        accounts: accounts,
        selectedId: selectedId,
        noneLabel: noneLabel,
      );
      if (selected == null) return;
      onChanged(selected.accountId);
      return;
    }

    final selected = await showAccountPickerSheet(
      context: context,
      title: '选择$label',
      accounts: accounts,
      selectedId: effectiveAccount(selectedId, accounts)?.id,
    );
    if (selected == null) return;
    onChanged(selected);
  }
}

class _ToggleChip extends StatelessWidget {
  const _ToggleChip({
    required this.icon,
    required this.label,
    required this.selected,
    required this.onChanged,
  });

  final IconData icon;
  final String label;
  final bool selected;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    return _QuickActionChip(
      icon: icon,
      label: label,
      selected: selected,
      onTap: () => onChanged(!selected),
    );
  }
}

class _QuickActionChip extends StatelessWidget {
  const _QuickActionChip({
    required this.label,
    required this.selected,
    required this.onTap,
    this.icon,
    this.leading,
  });

  final IconData? icon;
  final String label;
  final bool selected;
  final VoidCallback onTap;
  final Widget? leading;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final foreground = selected ? colors.primary : colors.onSurface;

    return Padding(
      padding: const EdgeInsets.only(right: AppSpacing.space2),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppRadius.radiusMd),
        child: Container(
          constraints: const BoxConstraints(minHeight: 30),
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.space6,
            vertical: AppSpacing.space4,
          ),
          decoration: BoxDecoration(
            color:
                selected
                    ? colors.primary.withValues(alpha: 0.08)
                    : AppColors.neutral99,
            borderRadius: BorderRadius.circular(AppRadius.radiusMd),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (leading != null) ...[
                leading!,
                const SizedBox(width: AppSpacing.space2),
              ] else if (icon != null) ...[
                Icon(icon, size: 14, color: foreground),
                const SizedBox(width: AppSpacing.space2),
              ],
              ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 96),
                child: Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: context.appTextStyles
                      .quickActionLabel(selected: selected)
                      .copyWith(color: foreground),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _NumberPad extends StatelessWidget {
  const _NumberPad({
    required this.submitting,
    required this.onInput,
    required this.onBackspace,
    required this.onClear,
    required this.onCancel,
    required this.onSubmit,
  });

  final bool submitting;
  final ValueChanged<String> onInput;
  final VoidCallback onBackspace;
  final VoidCallback onClear;
  final VoidCallback onCancel;
  final VoidCallback onSubmit;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 236,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Expanded(
            flex: 3,
            child: Column(
              children: [
                for (final row in const [
                  ['1', '2', '3'],
                  ['4', '5', '6'],
                  ['7', '8', '9'],
                  ['再记', '0', '.'],
                ])
                  Row(
                    children: [
                      for (final value in row)
                        Expanded(
                          child: _PadKey(
                            label: value,
                            onTap:
                                value == '再记' ? onClear : () => onInput(value),
                          ),
                        ),
                    ],
                  ),
              ],
            ),
          ),
          const SizedBox(width: AppSpacing.space4),
          Expanded(
            child: Column(
              children: [
                _PadKey(icon: Icons.backspace_outlined, onTap: onBackspace),
                const SizedBox(height: AppSpacing.space4),
                Expanded(
                  child: Column(
                    children: [
                      Expanded(
                        child: _ActionKey(
                          label: '取消',
                          onTap: onCancel,
                          filled: false,
                        ),
                      ),
                      const SizedBox(height: AppSpacing.space4),
                      Expanded(
                        child: _ActionKey(
                          label: '完成',
                          onTap: onSubmit,
                          filled: true,
                          submitting: submitting,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _PadKey extends StatelessWidget {
  const _PadKey({this.label, this.icon, required this.onTap});

  final String? label;
  final IconData? icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final textStyles = context.appTextStyles;

    return Padding(
      padding: const EdgeInsets.all(AppSpacing.space2),
      child: Material(
        color: colors.surfaceContainerLowest,
        borderRadius: BorderRadius.circular(AppRadius.radiusMd),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(AppRadius.radiusMd),
          child: SizedBox(
            height: 52,
            child: Center(
              child:
                  icon == null
                      ? Text(
                        label!,
                        style:
                            label == '再记'
                                ? textStyles.keypadSecondary
                                : textStyles.keypadPrimary,
                      )
                      : Icon(icon, size: 22),
            ),
          ),
        ),
      ),
    );
  }
}

class _ActionKey extends StatelessWidget {
  const _ActionKey({
    required this.label,
    required this.onTap,
    required this.filled,
    this.submitting = false,
  });

  final String label;
  final bool submitting;
  final VoidCallback onTap;
  final bool filled;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;

    return Padding(
      padding: const EdgeInsets.all(AppSpacing.space2),
      child:
          filled
              ? FilledButton(
                onPressed: submitting ? null : onTap,
                style: FilledButton.styleFrom(
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(AppRadius.radiusMd),
                  ),
                  backgroundColor: colors.primary,
                ),
                child:
                    submitting
                        ? const SizedBox.square(
                          dimension: 20,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                        : Text(label),
              )
              : TextButton(
                onPressed: onTap,
                style: TextButton.styleFrom(
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(AppRadius.radiusMd),
                  ),
                ),
                child: Text(label),
              ),
    );
  }
}

String _modeLabel(TransactionFormMode mode) {
  return switch (mode) {
    TransactionFormMode.expense => '支出',
    TransactionFormMode.income => '收入',
    TransactionFormMode.transfer => '转账',
    TransactionFormMode.borrowing => '借入',
  };
}

TransactionFormMode _toFormMode(TransactionFormInitialMode mode) {
  return switch (mode) {
    TransactionFormInitialMode.expense => TransactionFormMode.expense,
    TransactionFormInitialMode.income => TransactionFormMode.income,
    TransactionFormInitialMode.transfer => TransactionFormMode.transfer,
    TransactionFormInitialMode.borrowing => TransactionFormMode.borrowing,
  };
}

String _formatDateTime(DateTime date) {
  final now = DateTime.now();
  final time =
      '${date.hour.toString().padLeft(2, '0')}:'
      '${date.minute.toString().padLeft(2, '0')}';
  if (date.year == now.year && date.month == now.month && date.day == now.day) {
    return '今天 $time';
  }
  return '${date.month}/${date.day} $time';
}
