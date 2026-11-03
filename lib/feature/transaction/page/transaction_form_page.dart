import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:remixicon/remixicon.dart';

import '../../../application/ledger/ledger_query_api.dart';
import '../../../application/orchestration/orchestration_command_api.dart';
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
import '../../../design_system/widget/app_grouped_choice_grid.dart';
import '../../../design_system/widget/app_page_header.dart';
import '../../../design_system/widget/app_submit_button.dart';
import '../../../design_system/widget/app_surface.dart';
import 'package:smartflow/widget/business/icon/business_icon.dart';
import 'package:smartflow/widget/business/account/account_picker_sheet.dart';
import 'package:smartflow/widget/business/category/category_grid_picker.dart';
import 'package:smartflow/widget/business/finance/money_input.dart';
import 'package:smartflow/widget/business/finance/money_text.dart';
import 'package:smartflow/widget/business/form/plain_transaction_fields.dart';
import 'package:smartflow/widget/business/counterparty/counterparty_badge.dart';
import 'package:smartflow/widget/business/counterparty/counterparty_single_select_sheet.dart';
import 'package:smartflow/widget/business/tag/tag_badge.dart';
import 'package:smartflow/widget/business/transaction/transaction_amount_input.dart';
import 'package:smartflow/widget/business/tag/tag_multi_select_sheet.dart';
import '../../shared/view_model/ui_action_outcome.dart';
import '../../amortization/page/amortization_configuration_page.dart';
import '../../amortization/presentation/amortization_configuration_draft.dart';
import '../../credit/page/loan_configuration_page.dart';
import '../../credit/view_model/installment_terms_draft.dart';
import '../../credit/view_model/loan_configuration_view_model.dart';
import '../presentation/transaction_form_presentation.dart';
import '../view_model/transaction_form/transaction_form_view_model.dart';
import '../../../widget/business/transaction/transaction_allocation_fields.dart';

part 'transaction_form_chrome.dart';
part 'transaction_form_entry_sections.dart';
part 'transaction_form_input_sections.dart';
part 'transaction_form_keypad.dart';
part 'transaction_form_options.dart';
part 'transaction_form_scene_selection.dart';

enum TransactionFormInitialMode {
  expense,
  income,
  transfer,
  borrowing,
  lending,
}

enum _TransactionModeTab { expense, income, transfer, relations }

extension on _TransactionModeTab {
  String get label => switch (this) {
    _TransactionModeTab.expense => '支出',
    _TransactionModeTab.income => '收入',
    _TransactionModeTab.transfer => '转账',
    _TransactionModeTab.relations => '往来',
  };
}

_TransactionModeTab _modeTabFor(TransactionFormMode mode) {
  return switch (mode) {
    TransactionFormMode.expense => _TransactionModeTab.expense,
    TransactionFormMode.income => _TransactionModeTab.income,
    TransactionFormMode.transfer => _TransactionModeTab.transfer,
    TransactionFormMode.borrowing ||
    TransactionFormMode.lending => _TransactionModeTab.relations,
  };
}

DateTime _oneMonthAfter(DateTime value) {
  final month = DateTime(value.year, value.month + 1);
  final lastDay = DateTime(month.year, month.month + 1, 0).day;
  return DateTime(
    month.year,
    month.month,
    value.day > lastDay ? lastDay : value.day,
  );
}

class TransactionFormPage extends ConsumerWidget {
  const TransactionFormPage({
    this.editTransactionId,
    this.initialMode = TransactionFormInitialMode.expense,
    this.initialFromAccountId,
    this.initialToAccountId,
    this.initialLiabilityAccountId,
    this.initialAmortizationKind,
    this.initialAmortizationDeferralAccountId,
    super.key,
  });

  final String? editTransactionId;
  final TransactionFormInitialMode initialMode;
  final String? initialFromAccountId;
  final String? initialToAccountId;
  final String? initialLiabilityAccountId;
  final AmortizationKind? initialAmortizationKind;
  final String? initialAmortizationDeferralAccountId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final asyncState = ref.watch(
      transactionFormViewModelProvider(
        editTransactionId: editTransactionId,
        initialMode: _toFormMode(initialMode),
        initialFromAccountId: initialFromAccountId,
        initialToAccountId: initialToAccountId,
        initialLiabilityAccountId: initialLiabilityAccountId,
        initialAmortizationKind: initialAmortizationKind,
        initialAmortizationDeferralAccountId:
            initialAmortizationDeferralAccountId,
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
          initialAmortizationKind: initialAmortizationKind,
          initialAmortizationDeferralAccountId:
              initialAmortizationDeferralAccountId,
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

class _TransactionFormContent extends ConsumerStatefulWidget {
  const _TransactionFormContent({
    required this.editTransactionId,
    required this.initialMode,
    required this.initialFromAccountId,
    required this.initialToAccountId,
    required this.initialLiabilityAccountId,
    required this.initialAmortizationKind,
    required this.initialAmortizationDeferralAccountId,
    required this.formState,
    super.key,
  });

  final String? editTransactionId;
  final TransactionFormInitialMode initialMode;
  final String? initialFromAccountId;
  final String? initialToAccountId;
  final String? initialLiabilityAccountId;
  final AmortizationKind? initialAmortizationKind;
  final String? initialAmortizationDeferralAccountId;
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
  InstallmentConfigurationDraft? _installmentConfiguration;
  AmortizationConfigurationDraft? _amortizationConfiguration;

  @override
  void initState() {
    super.initState();
    final initialValues = widget.formState.initialValues;
    _amountController = TextEditingController(text: initialValues.amount);
    _feeController = TextEditingController(text: initialValues.fee);
    _noteController = TextEditingController(text: initialValues.note);
    _amortizationConfiguration = initialValues.amortizationConfiguration;
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
    final expenseSettlementAccounts = formState.expenseSettlementAccounts;
    final fundAccounts = formState.fundAccounts;
    final liabilityAccounts = formState.liabilityAccounts;
    final advanceReceivableAccounts = formState.advanceReceivableAccounts;
    final ordinaryReceivableAccounts = formState.ordinaryReceivableAccounts;
    final consumptionInstallment =
        formState.mode == TransactionFormMode.expense &&
        formState.expenseScene ==
            TransactionExpenseScene.consumptionInstallment;
    final amortization = formState.isAmortization;
    final installmentAccounts =
        consumptionInstallment &&
            formState.entryMode == TransactionEntryMode.allocated
        ? [
            for (final account in formState.creditAccounts)
              if (formState.settlementAllocations.any(
                (allocation) =>
                    allocation.accountId == account.id &&
                    allocation.amount.minorUnits > 0,
              ))
                account,
          ]
        : formState.creditAccounts;
    final selectableAdvanceAccounts = advanceAccountsForExpenseScene(
      formState.expenseScene,
      advanceReceivableAccounts,
    );
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
                onModeChanged: _changeModeTab,
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
                    if (formState.mode == TransactionFormMode.expense ||
                        formState.mode == TransactionFormMode.income)
                      _CategoryEntryArea(
                        state: formState,
                        categoryType:
                            formState.mode == TransactionFormMode.expense
                            ? AccountType.expense
                            : AccountType.income,
                        categoryTree:
                            formState.mode == TransactionFormMode.expense
                            ? formState.expenseTree
                            : formState.incomeTree,
                        categoryLabel:
                            formState.mode == TransactionFormMode.expense
                            ? '支出分类'
                            : '收入分类',
                        emptyLabel:
                            formState.mode == TransactionFormMode.expense
                            ? '尚未创建支出分类'
                            : '尚未创建收入分类',
                        settlementTitle:
                            formState.mode == TransactionFormMode.expense
                            ? '组合支付'
                            : '组合收款',
                        settlementAddLabel:
                            formState.mode == TransactionFormMode.expense
                            ? '添加账户'
                            : '添加收款账户',
                        onSelectCategory: (rootId, categoryId) =>
                            _selectCategory(
                              rootId: rootId,
                              categoryId: categoryId,
                            ),
                        onAddRootCategory: () => _openCategoryForm(
                          formState.mode == TransactionFormMode.expense
                              ? AccountType.expense
                              : AccountType.income,
                        ),
                        onAddChildCategory: (rootId) => _openCategoryForm(
                          formState.mode == TransactionFormMode.expense
                              ? AccountType.expense
                              : AccountType.income,
                          parentId: rootId,
                        ),
                        onCategoryAllocationsChanged: _setCategoryAllocations,
                        onSettlementAllocationsChanged:
                            _setSettlementAllocations,
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
                            label: formState.relationScene.cashAccountLabel,
                            accounts: fundAccounts,
                            selectedId: formState.toAccountId,
                            validator: (value) => value == null
                                ? '请选择${formState.relationScene.cashAccountLabel}'
                                : null,
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
                            label: formState.relationScene.cashAccountLabel,
                            accounts: fundAccounts,
                            selectedId: formState.fromAccountId,
                            validator: (value) => value == null
                                ? '请选择${formState.relationScene.cashAccountLabel}'
                                : null,
                            onChanged: (value) => ref
                                .read(_formProvider.notifier)
                                .setFromAccountId(value),
                          ),
                          const SizedBox(height: AppSpacing.space8),
                          _MainAccountPickerTile(
                            label:
                                formState.relationScene.receivableAccountLabel,
                            accounts: ordinaryReceivableAccounts,
                            selectedId: formState.ordinaryReceivableAccountId,
                            validator: (value) => value == null
                                ? '请选择${formState.relationScene.receivableAccountLabel}'
                                : null,
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
                    _TransactionMetadataActionRow(
                      allocated:
                          formState.entryMode == TransactionEntryMode.allocated,
                      showEntryMode:
                          (formState.mode == TransactionFormMode.expense ||
                          formState.mode == TransactionFormMode.income),
                      counterpartyName: _selectedCounterpartyName(formState),
                      tagNames: _selectedTagNames(formState),
                      onSelectCounterparty: _selectCounterparty,
                      onSelectTags: _selectTags,
                      onToggleMode: () => _toggleEntryMode(formState),
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
                      moneyAccounts: amortization
                          ? formState.fundAccounts
                          : formState.mode == TransactionFormMode.expense
                          ? expenseSettlementAccounts
                          : settlementAccounts,
                      installmentAccounts: installmentAccounts,
                      amortization: amortization,
                      amortizationConfiguration:
                          amortization && widget.editTransactionId == null,
                      amortizationDeferralAccounts:
                          formState.amortizationDeferralAccounts,
                      advanceAccounts: selectableAdvanceAccounts,
                      fromAccountId: formState.fromAccountId,
                      toAccountId: formState.toAccountId,
                      advanceReceivableAccountId:
                          formState.advanceReceivableAccountId,
                      amortizationDeferralAccountId:
                          formState.amortizationDeferralAccountId,
                      expenseScene: formState.expenseScene,
                      consumptionInstallment: consumptionInstallment,
                      aaPeopleCount: formState.aaPeopleCount,
                      allocatedEntry:
                          formState.entryMode == TransactionEntryMode.allocated,
                      excludeStats: formState.excludeStats,
                      excludeBudget: formState.excludeBudget,
                      onPickDate: _pickDate,
                      onFromAccountChanged: (value) => ref
                          .read(_formProvider.notifier)
                          .setFromAccountId(value),
                      onInstallmentConfiguration: () =>
                          _openInstallmentConfiguration(formState),
                      onAmortizationConfiguration: () =>
                          _openAmortizationConfiguration(formState),
                      onAmortizationDeferralAccountChanged: (value) => ref
                          .read(_formProvider.notifier)
                          .setAmortizationDeferralAccountId(value),
                      onToAccountChanged: (value) => ref
                          .read(_formProvider.notifier)
                          .setToAccountId(value),
                      onAdvanceAccountChanged: (value) => ref
                          .read(_formProvider.notifier)
                          .setAdvanceAccountId(value),
                      onAaPeopleTap: _selectAaPeopleCount,
                      onExcludeStatsChanged: (value) => ref
                          .read(_formProvider.notifier)
                          .setExcludeStats(value),
                      onExcludeBudgetChanged: (value) => ref
                          .read(_formProvider.notifier)
                          .setExcludeBudget(value),
                    ),
                    if (formState.mode == TransactionFormMode.expense &&
                        formState.expenseScene.isAdvance &&
                        formState.advanceReceivableAccountId != null)
                      _AdvanceSplitSummary(
                        scene: formState.expenseScene,
                        aaPeopleCount: formState.aaPeopleCount,
                        amountController: _amountController,
                      ),
                    if (keyboardVisible)
                      SizedBox(height: keyboardInset)
                    else ...[
                      const SizedBox(height: AppSpacing.space6),
                      _NumberPad(
                        submitting: formState.submitting,
                        onInput: _handleNumberInput,
                        onBackspace: _deleteAmountDigit,
                        onSelectScene: _selectScene,
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
        initialAmortizationKind: widget.initialAmortizationKind,
        initialAmortizationDeferralAccountId:
            widget.initialAmortizationDeferralAccountId,
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

  String? _selectedCounterpartyName(TransactionFormState formState) {
    final selectedId = formState.counterpartyId;
    if (selectedId == null) return null;
    for (final counterparty in formState.counterparties) {
      if (counterparty.id == selectedId) return counterparty.name;
    }
    return null;
  }

  Future<void> _selectCounterparty() async {
    final formState = ref.read(_formProvider).requireValue!;
    final result = await showCounterpartySingleSelectSheet(
      context: context,
      counterparties: formState.counterparties,
      selectedId: formState.counterpartyId,
    );
    if (!mounted || result == null) return;
    ref.read(_formProvider.notifier).setCounterparty(result.counterparty);
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

  void _changeModeTab(_TransactionModeTab tab) {
    final notifier = ref.read(_formProvider.notifier);
    switch (tab) {
      case _TransactionModeTab.expense:
        notifier.setMode(TransactionFormMode.expense);
        return;
      case _TransactionModeTab.income:
        notifier.setMode(TransactionFormMode.income);
        return;
      case _TransactionModeTab.transfer:
        notifier.setMode(TransactionFormMode.transfer);
        return;
      case _TransactionModeTab.relations:
        final current = ref.read(_formProvider).requireValue!;
        notifier.setRelationScene(current.relationScene);
        return;
    }
  }

  Future<void> _selectScene() async {
    final formState = ref.read(_formProvider).requireValue!;
    if (widget.editTransactionId != null && formState.isAmortization) {
      return;
    }
    final selected = await _showTransactionSceneSheet(
      context: context,
      mode: formState.mode,
      expenseScene: formState.expenseScene,
      incomeScene: formState.incomeScene,
      relationScene: formState.relationScene,
      groups: _sceneGroups(formState),
    );
    if (!mounted || selected == null) return;
    final form = ref.read(_formProvider.notifier);
    if (selected.mode == TransactionFormMode.expense) {
      form.setExpenseScene(
        selected.expenseScene ?? TransactionExpenseScene.ordinary,
      );
    } else if (selected.incomeScene != null) {
      form.setIncomeScene(selected.incomeScene!);
    } else if (selected.relationScene != null) {
      form.setRelationScene(selected.relationScene!);
    } else {
      form.setMode(selected.mode);
    }
  }

  List<AppChoiceGridGroup<_TransactionSceneChoice>> _sceneGroups(
    TransactionFormState formState,
  ) {
    if (widget.editTransactionId == null) {
      return _allTransactionSceneGroups;
    }
    if (formState.mode == TransactionFormMode.expense) {
      final editableScenes = _editableExpenseScenes(formState).toSet();
      return [
        AppChoiceGridGroup(
          id: 'expense',
          label: '支出',
          items: [
            for (final item in _expenseSceneItems)
              if (editableScenes.contains(item.value.expenseScene)) item,
          ],
        ),
      ];
    }
    return [
      for (final group in _allTransactionSceneGroups)
        if (group.items.any((item) => item.value.mode == formState.mode))
          AppChoiceGridGroup(
            id: group.id,
            label: group.label,
            items: [
              for (final item in group.items)
                if (item.value.mode == formState.mode &&
                    (formState.mode != TransactionFormMode.income ||
                        item.value.incomeScene == formState.incomeScene))
                  item,
            ],
          ),
    ];
  }

  List<TransactionExpenseScene> _editableExpenseScenes(
    TransactionFormState formState,
  ) {
    if (widget.editTransactionId == null) {
      return TransactionExpenseScene.values;
    }
    final trackingMode = formState.expenseScene.advanceTrackingMode;
    final candidates = [
      for (final scene in TransactionExpenseScene.values)
        if (scene != TransactionExpenseScene.consumptionInstallment &&
            scene != TransactionExpenseScene.amortization)
          scene,
    ];
    return switch (trackingMode) {
      null => [
        for (final scene in candidates)
          if (scene.advanceTrackingMode != AdvanceTrackingMode.account) scene,
      ],
      AdvanceTrackingMode.itemized => [
        for (final scene in candidates)
          if (scene == TransactionExpenseScene.ordinary ||
              scene.advanceTrackingMode == AdvanceTrackingMode.itemized)
            scene,
      ],
      AdvanceTrackingMode.account => [
        for (final scene in candidates)
          if (scene.advanceTrackingMode == AdvanceTrackingMode.account) scene,
      ],
    };
  }

  Future<void> _selectAaPeopleCount() async {
    final formState = ref.read(_formProvider).requireValue!;
    if (!formState.expenseScene.isAa) return;
    final selected = await showAaPeopleCountSheet(
      context: context,
      initialCount: formState.aaPeopleCount,
    );
    if (!mounted || selected == null) return;
    ref.read(_formProvider.notifier).setAaPeopleCount(selected);
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

  void _toggleEntryMode(TransactionFormState formState) {
    final notifier = ref.read(_formProvider.notifier);
    if (formState.entryMode == TransactionEntryMode.normal) {
      notifier.useAllocatedEntry(
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
    notifier.useNormalEntry();
  }

  Future<void> _openInstallmentConfiguration(
    TransactionFormState formState,
  ) async {
    final amount = Money.tryParse(_amountController.text);
    if (amount == null || amount.minorUnits <= 0) {
      _showError('请先输入有效成交价');
      return;
    }
    final loanAmount = _loanAmount(formState, amount);
    if (loanAmount.minorUnits <= 0) {
      _showError('请先选择包含在支付分配中的信用账户并填写金额');
      return;
    }
    final existing = _installmentConfiguration;
    final borrowingDate =
        existing?.borrowingDate ?? _dateOnly(formState.occurredAt);
    final configuration = await Navigator.of(context)
        .push<InstallmentConfigurationDraft>(
          MaterialPageRoute(
            builder: (_) => LoanConfigurationPage(
              installment: InstallmentConfigurationDraft(
                principal: loanAmount,
                borrowingDate: borrowingDate,
                terms:
                    existing?.terms ??
                    InstallmentTermsDraft.loan(borrowingDate),
                productId: existing?.productId,
                productName: existing?.productName,
              ),
            ),
          ),
        );
    if (!mounted || configuration == null) return;
    final principal = configuration.principal;
    if (principal == null || principal.minorUnits <= 0) {
      _showError('请输入有效贷款金额');
      return;
    }
    try {
      final nextAmount = ref
          .read(_formProvider.notifier)
          .applyConsumptionInstallmentAmount(principal);
      syncTextControllerText(
        _amountController,
        formatMoney(nextAmount, style: MoneyFormatStyle.plain),
      );
      setState(() => _installmentConfiguration = configuration);
    } on Exception catch (error) {
      _showError(error.toString());
    }
  }

  ConsumptionInstallmentConfiguration _consumptionConfiguration(
    TransactionFormState formState,
  ) {
    final configured = _installmentConfiguration;
    final borrowingDate =
        configured?.borrowingDate ?? _dateOnly(formState.occurredAt);
    final terms =
        configured?.terms ?? InstallmentTermsDraft.loan(borrowingDate);
    return ConsumptionInstallmentConfiguration(
      borrowingDate: borrowingDate,
      stageTerms: terms.contractTerms(),
    );
  }

  Future<void> _openAmortizationConfiguration(
    TransactionFormState formState,
  ) async {
    final initial =
        _amortizationConfiguration ??
        AmortizationConfigurationDraft(
          firstRecognitionAt: _oneMonthAfter(formState.occurredAt),
          cadenceUnit: AmortizationCadenceUnit.monthly,
          cadenceInterval: 1,
          recognitionCount: 1,
        );
    final configuration = await Navigator.of(context)
        .push<AmortizationConfigurationDraft>(
          MaterialPageRoute(
            builder: (_) =>
                AmortizationConfigurationPage(initialConfiguration: initial),
          ),
        );
    if (!mounted || configuration == null) return;
    setState(() => _amortizationConfiguration = configuration);
  }

  Money _loanAmount(TransactionFormState formState, Money amount) {
    if (formState.entryMode == TransactionEntryMode.normal) return amount;
    final selectedId = formState.creditAccounts
        .where((account) => account.id == formState.fromAccountId)
        .firstOrNull
        ?.id;
    if (selectedId == null) return Money.zero();
    for (final allocation in formState.settlementAllocations) {
      if (allocation.accountId == selectedId) return allocation.amount;
    }
    return Money.zero();
  }

  Future<void> _submit() async {
    final isValid = _formKey.currentState?.validate() ?? false;
    if (!isValid) return;

    final formState = ref.read(_formProvider).requireValue!;
    ConsumptionInstallmentConfiguration? consumptionConfiguration;
    if (formState.mode == TransactionFormMode.expense &&
        formState.expenseScene ==
            TransactionExpenseScene.consumptionInstallment) {
      try {
        consumptionConfiguration = _consumptionConfiguration(formState);
      } on Exception catch (error) {
        _showError(error.toString());
        return;
      }
    }
    final amortizationConfiguration = formState.isAmortization
        ? _amortizationConfiguration
        : null;
    if (formState.isAmortization && amortizationConfiguration == null) {
      _showError('请先完成摊销配置');
      return;
    }

    final outcome = await ref
        .read(_formProvider.notifier)
        .submit(
          amountText: _amountController.text,
          feeText: _feeController.text,
          noteText: _noteController.text,
          consumptionInstallment: consumptionConfiguration,
          amortizationConfiguration: amortizationConfiguration,
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

  void _selectCategory({required String? rootId, required String? categoryId}) {
    final notifier = ref.read(_formProvider.notifier);
    final mode = ref.read(_formProvider).requireValue!.mode;
    switch (mode) {
      case TransactionFormMode.expense:
        notifier.setExpenseCategory(rootId: rootId, categoryId: categoryId);
        return;
      case TransactionFormMode.income:
        notifier.setIncomeCategory(rootId: rootId, categoryId: categoryId);
        return;
      case TransactionFormMode.transfer ||
          TransactionFormMode.borrowing ||
          TransactionFormMode.lending:
        return;
    }
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
        title: Text(formState.isAmortization ? '删除摊销' : '删除交易'),
        content: Text(
          formState.isAmortization
              ? '将删除整个摊销计划及其全部关联账务交易，且无法恢复。'
              : '删除后交易及其账务记录将无法恢复。',
        ),
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

TransactionFormMode _toFormMode(TransactionFormInitialMode mode) {
  return switch (mode) {
    TransactionFormInitialMode.expense => TransactionFormMode.expense,
    TransactionFormInitialMode.income => TransactionFormMode.income,
    TransactionFormInitialMode.transfer => TransactionFormMode.transfer,
    TransactionFormInitialMode.borrowing => TransactionFormMode.borrowing,
    TransactionFormInitialMode.lending => TransactionFormMode.lending,
  };
}

DateTime _dateOnly(DateTime value) =>
    DateTime(value.year, value.month, value.day);

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

List<TransactionAllocationOption> _categoryOptions(
  List<CategoryNode> tree, {
  required BusinessIconUsage iconUsage,
}) {
  return [
    for (final node in tree) ...[
      TransactionAllocationOption(
        accountId: node.account.id,
        label: node.account.name,
        iconKey: node.account.iconKey,
        iconUsage: iconUsage,
      ),
      for (final child in node.children)
        TransactionAllocationOption(
          accountId: child.id,
          label: child.name,
          iconKey: child.iconKey,
          iconUsage: iconUsage,
        ),
    ],
  ];
}
