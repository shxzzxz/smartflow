import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:remixicon/remixicon.dart';

import '../../../application/ledger/ledger_query_api.dart';
import '../../../core/money/money.dart';
import '../../../core/money/money_formatter.dart';
import '../../../design_system/theme/app_text_styles.dart';
import '../../../design_system/token/colors.dart';
import '../../../design_system/token/component.dart';
import '../../../design_system/token/header.dart';
import '../../../design_system/token/radius.dart';
import '../../../design_system/token/spacing.dart';
import '../../../design_system/widget/app_datetime_picker.dart';
import '../../../design_system/widget/app_form_field.dart';
import '../../../design_system/widget/app_page_header.dart';
import '../../../design_system/widget/app_submit_button.dart';
import '../../../design_system/widget/app_surface.dart';
import 'package:smartflow/widget/business/icon/business_icon.dart';
import 'package:smartflow/widget/business/category/category_grid_picker.dart';
import 'package:smartflow/widget/business/finance/money_input.dart';
import 'package:smartflow/widget/business/finance/money_text.dart';
import 'package:smartflow/widget/business/form/plain_transaction_fields.dart';
import 'package:smartflow/widget/business/tag/tag_badge.dart';
import 'package:smartflow/widget/business/transaction/transaction_amount_input.dart';
import 'package:smartflow/widget/business/tag/tag_multi_select_sheet.dart';
import '../../shared/view_model/ui_action_outcome.dart';
import '../presentation/transaction_form_presentation.dart';
import '../view_model/transaction_form_view_model.dart';
import '../widget/transaction_allocation_fields.dart';

enum TransactionFormInitialMode {
  expense,
  income,
  transfer,
  borrowing,
  lending,
}

class TransactionFormPage extends ConsumerWidget {
  const TransactionFormPage({
    this.editTransactionId,
    this.initialMode = TransactionFormInitialMode.expense,
    this.initialFromAccountId,
    this.initialToAccountId,
    this.initialLiabilityAccountId,
    super.key,
  });

  final String? editTransactionId;
  final TransactionFormInitialMode initialMode;
  final String? initialFromAccountId;
  final String? initialToAccountId;
  final String? initialLiabilityAccountId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final asyncState = ref.watch(
      transactionFormViewModelProvider(
        editTransactionId: editTransactionId,
        initialMode: _toFormMode(initialMode),
        initialFromAccountId: initialFromAccountId,
        initialToAccountId: initialToAccountId,
        initialLiabilityAccountId: initialLiabilityAccountId,
      ),
    );
    return switch (asyncState) {
      AsyncData(value: final formState) when formState != null =>
        _TransactionFormContent(
          key: ValueKey<String?>(editTransactionId),
          editTransactionId: editTransactionId,
          initialMode: initialMode,
          initialFromAccountId: initialFromAccountId,
          initialToAccountId: initialToAccountId,
          initialLiabilityAccountId: initialLiabilityAccountId,
          formState: formState,
        ),
      AsyncData(value: null) => const _TransactionFormStatusPage(
        title: '编辑交易',
        message: '交易不存在或当前类型不支持在此编辑',
      ),
      AsyncError() => _TransactionFormStatusPage(
        title: editTransactionId == null ? '新增交易' : '编辑交易',
        message: '交易加载失败，请稍后重试',
      ),
      _ => const Scaffold(body: Center(child: CircularProgressIndicator())),
    };
  }
}

class _TransactionFormStatusPage extends StatelessWidget {
  const _TransactionFormStatusPage({
    required this.title,
    required this.message,
  });

  final String title;
  final String message;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            AppPageHeader(title: title),
            Expanded(child: Center(child: Text(message))),
          ],
        ),
      ),
    );
  }
}

class _TransactionFormContent extends ConsumerStatefulWidget {
  const _TransactionFormContent({
    required this.editTransactionId,
    required this.initialMode,
    required this.initialFromAccountId,
    required this.initialToAccountId,
    required this.initialLiabilityAccountId,
    required this.formState,
    super.key,
  });

  final String? editTransactionId;
  final TransactionFormInitialMode initialMode;
  final String? initialFromAccountId;
  final String? initialToAccountId;
  final String? initialLiabilityAccountId;
  final TransactionFormState formState;

  @override
  ConsumerState<_TransactionFormContent> createState() =>
      _TransactionFormContentState();
}

class _TransactionFormContentState
    extends ConsumerState<_TransactionFormContent> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _amountController;
  late final TextEditingController _feeController;
  late final TextEditingController _noteController;

  @override
  void initState() {
    super.initState();
    final initialValues = widget.formState.initialValues;
    _amountController = TextEditingController(text: initialValues.amount);
    _feeController = TextEditingController(text: initialValues.fee);
    _noteController = TextEditingController(text: initialValues.note);
  }

  @override
  void dispose() {
    _amountController.dispose();
    _feeController.dispose();
    _noteController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final formState = widget.formState;
    final settlementAccounts = formState.settlementAccounts;
    final fundAccounts = formState.fundAccounts;
    final liabilityAccounts = formState.liabilityAccounts;
    final reimbursementAccounts = formState.reimbursementAccounts;
    final ordinaryReceivableAccounts = formState.ordinaryReceivableAccounts;
    final incomeTree = formState.incomeTree;
    final editTransactionId = widget.editTransactionId;

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
                onDelete: editTransactionId != null && !formState.submitting
                    ? _confirmDelete
                    : null,
                onModeChanged: (mode) =>
                    ref.read(_formProvider.notifier).setMode(mode),
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
                      _ExpenseEntryArea(
                        state: formState,
                        onSelectCategory: (rootId, categoryId) =>
                            _selectExpenseCategory(
                              rootId: rootId,
                              categoryId: categoryId,
                            ),
                        onAddRootCategory: () =>
                            _openCategoryForm(AccountType.expense),
                        onAddChildCategory: (rootId) => _openCategoryForm(
                          AccountType.expense,
                          parentId: rootId,
                        ),
                        onCategoryAllocationsChanged: _setCategoryAllocations,
                        onSettlementAllocationsChanged:
                            _setSettlementAllocations,
                      ),
                    if (formState.mode == TransactionFormMode.income)
                      AppControlledFormField<String>(
                        value: formState.incomeCategoryId,
                        validator: (value) =>
                            formState.mode == TransactionFormMode.income &&
                                value == null
                            ? '请选择收入分类'
                            : null,
                        builder: (context, _, errorText, onChanged) => Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            CategoryGridPicker(
                              nodes: incomeTree,
                              selectedRootId: formState.incomeRootId,
                              selectedCategoryId: formState.incomeCategoryId,
                              emptyLabel: '尚未创建收入分类',
                              onRootSelected: (account) {
                                _selectIncomeCategory(
                                  rootId: account.id,
                                  categoryId: account.id,
                                );
                                onChanged(account.id);
                              },
                              onChildSelected: (root, child) {
                                _selectIncomeCategory(
                                  rootId: root.id,
                                  categoryId: child.id,
                                );
                                onChanged(child.id);
                              },
                              onAddRoot: () =>
                                  _openCategoryForm(AccountType.income),
                              onAddChild: (rootId) => _openCategoryForm(
                                AccountType.income,
                                parentId: rootId,
                              ),
                            ),
                            if (errorText != null)
                              _FormFieldErrorText(errorText),
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
                            validator: (value) =>
                                value == null ? '请选择转出账户' : null,
                            onChanged: (value) => ref
                                .read(_formProvider.notifier)
                                .setFromAccountId(value),
                          ),
                          const SizedBox(height: AppSpacing.space8),
                          _MainAccountPickerTile(
                            key: const ValueKey('transfer-to-account-tile'),
                            label: '转入账户',
                            accounts: settlementAccounts,
                            selectedId: formState.toAccountId,
                            validator: (value) =>
                                value == null ? '请选择转入账户' : null,
                            onChanged: (value) => ref
                                .read(_formProvider.notifier)
                                .setToAccountId(value),
                          ),
                          const SizedBox(height: AppSpacing.space8),
                          _MainFeeInputTile(
                            key: const ValueKey('transfer-fee-input'),
                            controller: _feeController,
                          ),
                        ],
                      ),
                    if (formState.mode == TransactionFormMode.borrowing)
                      _MainAccountPickerSection(
                        children: [
                          _MainAccountPickerTile(
                            label: '负债账户',
                            accounts: liabilityAccounts,
                            selectedId: formState.liabilityAccountId,
                            validator: (value) =>
                                value == null ? '请选择负债账户' : null,
                            onChanged: (value) => ref
                                .read(_formProvider.notifier)
                                .setLiabilityAccountId(value),
                          ),
                          const SizedBox(height: AppSpacing.space8),
                          _MainAccountPickerTile(
                            label: '收款账户',
                            accounts: fundAccounts,
                            selectedId: formState.toAccountId,
                            validator: (value) =>
                                value == null ? '请选择收款账户' : null,
                            onChanged: (value) => ref
                                .read(_formProvider.notifier)
                                .setToAccountId(value),
                          ),
                        ],
                      ),
                    if (formState.mode == TransactionFormMode.lending)
                      _MainAccountPickerSection(
                        children: [
                          _MainAccountPickerTile(
                            label: '付款账户',
                            accounts: fundAccounts,
                            selectedId: formState.fromAccountId,
                            validator: (value) =>
                                value == null ? '请选择付款账户' : null,
                            onChanged: (value) => ref
                                .read(_formProvider.notifier)
                                .setFromAccountId(value),
                          ),
                          const SizedBox(height: AppSpacing.space8),
                          _MainAccountPickerTile(
                            label: '应收账户',
                            accounts: ordinaryReceivableAccounts,
                            selectedId: formState.ordinaryReceivableAccountId,
                            validator: (value) =>
                                value == null ? '请选择应收账户' : null,
                            onChanged: (value) => ref
                                .read(_formProvider.notifier)
                                .setOrdinaryReceivableAccountId(value),
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
                    _TransactionTagActionRow(
                      allocated:
                          formState.expenseEntryMode ==
                          ExpenseEntryMode.allocated,
                      showExpenseEntryMode:
                          formState.mode == TransactionFormMode.expense,
                      tagNames: _selectedTagNames(formState),
                      onSelectTags: _selectTags,
                      onToggleMode: () => _toggleExpenseEntryMode(formState),
                    ),
                    const SizedBox(height: AppSpacing.space4),
                    TransactionAmountInput(
                      amountController: _amountController,
                      noteController: _noteController,
                      semantic: _amountSemantic(formState.mode),
                      amountValidator: (value) => validatePositiveMoneyText(
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
                      allocatedExpense:
                          formState.mode == TransactionFormMode.expense &&
                          formState.expenseEntryMode ==
                              ExpenseEntryMode.allocated,
                      excludeStats: formState.excludeStats,
                      excludeBudget: formState.excludeBudget,
                      onPickDate: _pickDate,
                      onFromAccountChanged: (value) => ref
                          .read(_formProvider.notifier)
                          .setFromAccountId(value),
                      onToAccountChanged: (value) => ref
                          .read(_formProvider.notifier)
                          .setToAccountId(value),
                      onReimbursementAccountChanged: (value) => ref
                          .read(_formProvider.notifier)
                          .setReimbursementAccountId(value),
                      onExcludeStatsChanged: (value) => ref
                          .read(_formProvider.notifier)
                          .setExcludeStats(value),
                      onExcludeBudgetChanged: (value) => ref
                          .read(_formProvider.notifier)
                          .setExcludeBudget(value),
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

  TransactionFormViewModelProvider get _formProvider =>
      transactionFormViewModelProvider(
        editTransactionId: widget.editTransactionId,
        initialMode: _toFormMode(widget.initialMode),
        initialFromAccountId: widget.initialFromAccountId,
        initialToAccountId: widget.initialToAccountId,
        initialLiabilityAccountId: widget.initialLiabilityAccountId,
      );

  Future<void> _pickDate() async {
    final picked = await showAppDateTimePicker(
      context: context,
      initialDateTime: ref.read(_formProvider).requireValue!.occurredAt,
      title: '选择交易时间',
    );
    if (picked == null || !mounted) return;
    ref.read(_formProvider.notifier).setOccurredAt(picked);
  }

  List<String> _selectedTagNames(TransactionFormState formState) {
    final nameById = {for (final tag in formState.tags) tag.id: tag.name};
    return [
      for (final id in formState.selectedTagIds)
        if (nameById.containsKey(id)) nameById[id]!,
    ];
  }

  Future<void> _selectTags() async {
    final formState = ref.read(_formProvider).requireValue!;
    final result = await showTagMultiSelectSheet(
      context: context,
      tags: formState.tags,
      selectedIds: formState.selectedTagIds,
      allowCreate: true,
    );
    if (!mounted || result == null) return;
    ref.read(_formProvider.notifier).setTagIds(result.selectedTagIds);
  }

  void _openCategoryForm(AccountType type, {String? parentId}) {
    final query = Uri(
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
    _amountController.clear();
    _feeController.clear();
    _noteController.clear();
    ref.read(_formProvider.notifier).clearForNext();
  }

  void _setCategoryAllocations(List<AccountAmountAllocation> allocations) {
    ref.read(_formProvider.notifier).setCategoryAllocations(allocations);
    final total = sumAllocations(allocations);
    syncTextControllerText(
      _amountController,
      total.minorUnits == 0
          ? ''
          : formatMoney(total, style: MoneyFormatStyle.plain),
    );
  }

  void _setSettlementAllocations(List<AccountAmountAllocation> allocations) {
    ref.read(_formProvider.notifier).setSettlementAllocations(allocations);
  }

  void _toggleExpenseEntryMode(TransactionFormState formState) {
    final notifier = ref.read(_formProvider.notifier);
    if (formState.expenseEntryMode == ExpenseEntryMode.normal) {
      notifier.useAllocatedExpenseEntry(
        Money.tryParse(_amountController.text) ?? Money.zero(),
      );
      return;
    }
    final total = sumAllocations(formState.categoryAllocations);
    syncTextControllerText(
      _amountController,
      total.minorUnits == 0
          ? ''
          : formatMoney(total, style: MoneyFormatStyle.plain),
    );
    notifier.useNormalExpenseEntry();
  }

  Future<void> _submit() async {
    final isValid = _formKey.currentState?.validate() ?? false;
    if (!isValid) return;

    final outcome = await ref
        .read(_formProvider.notifier)
        .submit(
          amountText: _amountController.text,
          feeText: _feeController.text,
          noteText: _noteController.text,
        );
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

  MoneySemantic _amountSemantic(TransactionFormMode mode) {
    return switch (mode) {
      TransactionFormMode.expense => MoneySemantic.expense,
      TransactionFormMode.income => MoneySemantic.income,
      TransactionFormMode.transfer => MoneySemantic.neutral,
      TransactionFormMode.borrowing => MoneySemantic.neutral,
      TransactionFormMode.lending => MoneySemantic.neutral,
    };
  }

  void _showError(String message) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  void _selectExpenseCategory({
    required String? rootId,
    required String? categoryId,
  }) {
    ref
        .read(_formProvider.notifier)
        .setExpenseCategory(rootId: rootId, categoryId: categoryId);
  }

  void _selectIncomeCategory({
    required String? rootId,
    required String? categoryId,
  }) {
    ref
        .read(_formProvider.notifier)
        .setIncomeCategory(rootId: rootId, categoryId: categoryId);
  }

  Future<void> _confirmDelete() async {
    final transactionId = widget.editTransactionId;
    final formState = ref.read(_formProvider).requireValue;
    if (transactionId == null || formState == null || formState.submitting) {
      return;
    }

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('删除交易'),
        content: const Text('删除后交易及其账务记录将无法恢复。'),
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
        .read(_formProvider.notifier)
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
            icon: const Icon(RemixIcons.arrow_left_s_line),
            tooltip: '返回',
            style: appHeaderIconButtonStyle,
          ),
          Expanded(
            child: editing
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
              icon: const Icon(RemixIcons.delete_bin_line),
              tooltip: '删除',
              style: appHeaderIconButtonStyle,
            )
          else
            const SizedBox(width: AppHeaderTokens.iconButtonSize),
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
    return LayoutBuilder(
      builder: (context, constraints) => SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: ConstrainedBox(
          constraints: BoxConstraints(minWidth: constraints.maxWidth),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              for (final value in TransactionFormMode.values)
                _ModeTabItem(
                  label: _modeLabel(value),
                  selected: value == mode,
                  onTap: () => onChanged(value),
                ),
            ],
          ),
        ),
      ),
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
      child: ConstrainedBox(
        constraints: const BoxConstraints(
          minHeight: AppComponentTokens.controlMinHeight,
        ),
        child: Center(
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
                        color: selected
                            ? colors.primary
                            : colors.onSurfaceVariant,
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
        ),
      ),
    );
  }
}

class _ExpenseEntryArea extends StatelessWidget {
  const _ExpenseEntryArea({
    required this.state,
    required this.onSelectCategory,
    required this.onAddRootCategory,
    required this.onAddChildCategory,
    required this.onCategoryAllocationsChanged,
    required this.onSettlementAllocationsChanged,
  });

  final TransactionFormState state;
  final void Function(String? rootId, String? categoryId) onSelectCategory;
  final VoidCallback onAddRootCategory;
  final ValueChanged<String> onAddChildCategory;
  final ValueChanged<List<AccountAmountAllocation>>
  onCategoryAllocationsChanged;
  final ValueChanged<List<AccountAmountAllocation>>
  onSettlementAllocationsChanged;

  @override
  Widget build(BuildContext context) {
    if (state.expenseEntryMode == ExpenseEntryMode.allocated) {
      final total = sumAllocations(state.categoryAllocations);
      return Column(
        key: const ValueKey('expense-entry-allocated'),
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          TransactionInlineAllocationColumn(
            key: const ValueKey('expense-category-allocations'),
            title: '多分类',
            allocations: state.categoryAllocations,
            options: _categoryOptions(state.expenseTree),
            addLabel: '添加分类',
            statusInHeader: true,
            onSelectOption: (context, selectedId, options) =>
                _showCategoryAllocationPickerSheet(
                  context: context,
                  nodes: state.expenseTree,
                  options: options,
                  selectedId: selectedId,
                  onAddRootCategory: onAddRootCategory,
                  onAddChildCategory: onAddChildCategory,
                ),
            onChanged: onCategoryAllocationsChanged,
          ),
          const SizedBox(height: AppSpacing.space8),
          TransactionInlineAllocationColumn(
            key: const ValueKey('expense-settlement-allocations'),
            title: '组合支付',
            allocations: state.settlementAllocations,
            options: _accountOptions(state.settlementAccounts),
            addLabel: '添加账户',
            expectedTotal: total,
            statusInHeader: true,
            onSelectOption: (context, selectedId, options) async {
              final optionIds = {
                for (final option in options) option.accountId,
              };
              final selected = await showAccountPickerSheet(
                context: context,
                title: '选择账户',
                accounts: [
                  for (final account in state.settlementAccounts)
                    if (optionIds.contains(account.id)) account,
                ],
                selectedId: selectedId,
              );
              if (selected == null) return null;
              return options
                  .where((option) => option.accountId == selected)
                  .firstOrNull;
            },
            onChanged: onSettlementAllocationsChanged,
          ),
        ],
      );
    }

    return AppControlledFormField<String>(
      key: const ValueKey('expense-entry-normal'),
      value: state.expenseCategoryId,
      validator: (value) => value == null ? '请选择支出分类' : null,
      builder: (context, _, errorText, onChanged) => Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          CategoryGridPicker(
            nodes: state.expenseTree,
            selectedRootId: state.expenseRootId,
            selectedCategoryId: state.expenseCategoryId,
            emptyLabel: '尚未创建支出分类',
            onRootSelected: (account) {
              onSelectCategory(account.id, account.id);
              onChanged(account.id);
            },
            onChildSelected: (root, child) {
              onSelectCategory(root.id, child.id);
              onChanged(child.id);
            },
            onAddRoot: onAddRootCategory,
            onAddChild: onAddChildCategory,
          ),
          if (errorText != null) _FormFieldErrorText(errorText),
        ],
      ),
    );
  }
}

Future<TransactionAllocationOption?> _showCategoryAllocationPickerSheet({
  required BuildContext context,
  required List<CategoryNode> nodes,
  required List<TransactionAllocationOption> options,
  required String? selectedId,
  required VoidCallback onAddRootCategory,
  required ValueChanged<String> onAddChildCategory,
}) {
  return showModalBottomSheet<TransactionAllocationOption>(
    context: context,
    showDragHandle: true,
    isScrollControlled: true,
    builder: (context) => _CategoryAllocationPickerSheet(
      nodes: nodes,
      options: options,
      selectedId: selectedId,
      onAddRootCategory: onAddRootCategory,
      onAddChildCategory: onAddChildCategory,
    ),
  );
}

class _CategoryAllocationPickerSheet extends StatefulWidget {
  const _CategoryAllocationPickerSheet({
    required this.nodes,
    required this.options,
    required this.selectedId,
    required this.onAddRootCategory,
    required this.onAddChildCategory,
  });

  final List<CategoryNode> nodes;
  final List<TransactionAllocationOption> options;
  final String? selectedId;
  final VoidCallback onAddRootCategory;
  final ValueChanged<String> onAddChildCategory;

  @override
  State<_CategoryAllocationPickerSheet> createState() =>
      _CategoryAllocationPickerSheetState();
}

class _CategoryAllocationPickerSheetState
    extends State<_CategoryAllocationPickerSheet> {
  String? _selectedRootId;
  String? _selectedCategoryId;

  Set<String> get _selectableIds => {
    for (final option in widget.options) option.accountId,
  };

  TransactionAllocationOption? get _selectedOption {
    final selectedId = _selectedCategoryId;
    if (selectedId == null) return null;
    return widget.options
        .where((option) => option.accountId == selectedId)
        .firstOrNull;
  }

  @override
  void initState() {
    super.initState();
    final selectedId = widget.selectedId;
    if (selectedId == null || !_selectableIds.contains(selectedId)) return;
    _selectedCategoryId = selectedId;
    for (final node in widget.nodes) {
      if (node.account.id == selectedId ||
          node.children.any((child) => child.id == selectedId)) {
        _selectedRootId = node.account.id;
        break;
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final maxHeight =
        MediaQuery.sizeOf(context).height *
        AppComponentTokens.selectionSheetMaxHeightFactor;
    return ConstrainedBox(
      constraints: BoxConstraints(maxHeight: maxHeight),
      child: SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.space16,
                0,
                AppSpacing.space16,
                AppSpacing.space8,
              ),
              child: Text('选择分类', style: context.appTextStyles.subsectionTitle),
            ),
            Flexible(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.space16,
                ),
                child: CategoryGridPicker(
                  nodes: widget.nodes,
                  selectedRootId: _selectedRootId,
                  selectedCategoryId: _selectedCategoryId,
                  emptyLabel: '尚未创建支出分类',
                  onRootSelected: (account) => setState(() {
                    _selectedRootId = account.id;
                    _selectedCategoryId = _selectableIds.contains(account.id)
                        ? account.id
                        : null;
                  }),
                  onChildSelected: (root, child) => setState(() {
                    _selectedRootId = root.id;
                    _selectedCategoryId = child.id;
                  }),
                  onAddRoot: () {
                    Navigator.of(context).pop();
                    widget.onAddRootCategory();
                  },
                  onAddChild: (rootId) {
                    Navigator.of(context).pop();
                    widget.onAddChildCategory(rootId);
                  },
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.space16,
                AppSpacing.space8,
                AppSpacing.space16,
                AppSpacing.space8,
              ),
              child: AppSubmitButton(
                label: '确定',
                onPressed: _selectedOption == null
                    ? null
                    : () => Navigator.of(context).pop(_selectedOption),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _TransactionTagActionRow extends StatelessWidget {
  const _TransactionTagActionRow({
    required this.allocated,
    required this.showExpenseEntryMode,
    required this.tagNames,
    required this.onSelectTags,
    required this.onToggleMode,
  });

  final bool allocated;
  final bool showExpenseEntryMode;
  final List<String> tagNames;
  final VoidCallback onSelectTags;
  final VoidCallback onToggleMode;

  @override
  Widget build(BuildContext context) {
    final tags = tagNames.isEmpty
        ? _QuickActionChip(label: '标签', selected: false, onTap: onSelectTags)
        : InkWell(
            onTap: onSelectTags,
            borderRadius: BorderRadius.circular(AppRadius.radiusMd),
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: AppSpacing.space2),
              child: Wrap(
                spacing: AppSpacing.space4,
                runSpacing: AppSpacing.space4,
                children: [for (final name in tagNames) TagBadge(name: name)],
              ),
            ),
          );
    return Row(
      key: const ValueKey('expense-entry-mode-row'),
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Expanded(
          child: Align(alignment: Alignment.centerLeft, child: tags),
        ),
        const SizedBox(width: AppSpacing.space8),
        if (showExpenseEntryMode)
          _QuickActionChip(
            key: const ValueKey('toggle-expense-entry-mode'),
            icon: RemixIcons.list_check_3,
            label: '分项',
            selected: allocated,
            onTap: onToggleMode,
          ),
      ],
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
    required this.validator,
    super.key,
  });

  final String label;
  final List<Account> accounts;
  final String? selectedId;
  final ValueChanged<String?> onChanged;
  final FormFieldValidator<String> validator;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final textStyles = context.appTextStyles;
    final effective = effectiveAccount(selectedId, accounts);
    final title = effective?.name ?? '$label为空';

    return AppControlledFormField<String>(
      value: effective?.id,
      onChanged: onChanged,
      validator: validator,
      builder: (context, _, errorText, changeValue) {
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Material(
              color: colors.surfaceContainerLowest,
              borderRadius: BorderRadius.circular(AppRadius.radiusMd),
              child: InkWell(
                onTap: () => _showAccountSheet(context, changeValue),
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
                          child: BusinessIcon(
                            iconKey: effective?.iconKey,
                            size: 28,
                            usage: BusinessIconUsage.account,
                          ),
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
            ),
            if (errorText != null) _FormFieldErrorText(errorText),
          ],
        );
      },
    );
  }

  Future<void> _showAccountSheet(
    BuildContext context,
    ValueChanged<String?> changeValue,
  ) async {
    final selected = await showAccountPickerSheet(
      context: context,
      title: '选择$label',
      accounts: accounts,
      selectedId: effectiveAccount(selectedId, accounts)?.id,
    );
    if (selected == null) return;
    changeValue(selected);
  }
}

class _MainFeeInputTile extends StatelessWidget {
  const _MainFeeInputTile({required this.controller, super.key});

  final TextEditingController controller;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final textStyles = context.appTextStyles;

    return Material(
      color: colors.surfaceContainerLowest,
      borderRadius: BorderRadius.circular(AppRadius.radiusMd),
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.space12,
          vertical: AppSpacing.space12,
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            const SizedBox(
              width: AppSpacing.space32,
              child: Center(
                child: BusinessIcon(
                  iconKey: 'swap-box-line',
                  size: 28,
                  usage: BusinessIconUsage.system,
                ),
              ),
            ),
            const SizedBox(width: AppSpacing.space12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('手续费', style: textStyles.formLabel),
                  const SizedBox(height: AppSpacing.space2),
                  AppPlainTextFormField(
                    controller: controller,
                    hintText: '0.00',
                    keyboardType: const TextInputType.numberWithOptions(
                      decimal: true,
                    ),
                    inputFormatters: [moneyInputFormatter],
                    validator: validateOptionalNonNegativeMoneyText,
                    textAlign: TextAlign.left,
                    style: textStyles.formValue,
                  ),
                ],
              ),
            ),
          ],
        ),
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
    required this.allocatedExpense,
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
  final bool allocatedExpense;
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
        (mode == TransactionFormMode.expense && !allocatedExpense) ||
        mode == TransactionFormMode.income;
    final showExcludeStats =
        mode == TransactionFormMode.expense ||
        mode == TransactionFormMode.income;
    final accountLabel = mode == TransactionFormMode.income ? '收入账户' : '支出账户';
    final primaryAccountId = mode == TransactionFormMode.income
        ? toAccountId
        : fromAccountId;
    final primaryChanged = mode == TransactionFormMode.income
        ? onToAccountChanged
        : onFromAccountChanged;

    Widget buildPanel(ValueChanged<String?> accountChanged, String? errorText) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Align(
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
                      key: mode == TransactionFormMode.expense
                          ? const ValueKey('expense-primary-account-option')
                          : null,
                      label: accountLabel,
                      accounts: moneyAccounts,
                      selectedId: primaryAccountId,
                      onChanged: accountChanged,
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
          ),
          if (errorText != null) _FormFieldErrorText(errorText),
        ],
      );
    }

    if (!showPrimaryAccount) return buildPanel(primaryChanged, null);

    return AppControlledFormField<String>(
      value: effectiveAccountId(primaryAccountId, moneyAccounts),
      onChanged: primaryChanged,
      validator: (value) => value == null ? '请选择$accountLabel' : null,
      builder: (context, _, errorText, changeValue) =>
          buildPanel(changeValue, errorText),
    );
  }
}

class _AccountSelectorChip extends StatelessWidget {
  const _AccountSelectorChip({
    required this.label,
    required this.accounts,
    required this.selectedId,
    required this.onChanged,
    super.key,
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
    final selected = selectedId == null
        ? null
        : accounts.where((account) => account.id == selectedId).firstOrNull;
    final effective = selected ?? effectiveAccount(null, accounts);
    final text = allowNone && selectedId == null
        ? noneLabel
        : effective == null
        ? '$label为空'
        : effective.name;
    final leading = effective == null || (allowNone && selectedId == null)
        ? null
        : BusinessIcon(
            iconKey: effective.iconKey,
            size: 14,
            usage: BusinessIconUsage.account,
          );

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
    super.key,
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
            color: selected
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
                            onTap: value == '再记'
                                ? onClear
                                : () => onInput(value),
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
              child: icon == null
                  ? Text(
                      label!,
                      style: label == '再记'
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
      child: filled
          ? FilledButton(
              onPressed: submitting ? null : onTap,
              style: FilledButton.styleFrom(
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(AppRadius.radiusMd),
                ),
                backgroundColor: colors.primary,
              ),
              child: submitting
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
    TransactionFormMode.lending => '借出',
  };
}

TransactionFormMode _toFormMode(TransactionFormInitialMode mode) {
  return switch (mode) {
    TransactionFormInitialMode.expense => TransactionFormMode.expense,
    TransactionFormInitialMode.income => TransactionFormMode.income,
    TransactionFormInitialMode.transfer => TransactionFormMode.transfer,
    TransactionFormInitialMode.borrowing => TransactionFormMode.borrowing,
    TransactionFormInitialMode.lending => TransactionFormMode.lending,
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

List<TransactionAllocationOption> _categoryOptions(List<CategoryNode> tree) {
  return [
    for (final node in tree) ...[
      TransactionAllocationOption(
        accountId: node.account.id,
        label: node.account.name,
        iconKey: node.account.iconKey,
      ),
      for (final child in node.children)
        TransactionAllocationOption(
          accountId: child.id,
          label: child.name,
          iconKey: child.iconKey,
        ),
    ],
  ];
}

List<TransactionAllocationOption> _accountOptions(List<Account> accounts) {
  return [
    for (final account in accounts)
      TransactionAllocationOption(
        accountId: account.id,
        label: account.name,
        iconKey: account.iconKey,
      ),
  ];
}
