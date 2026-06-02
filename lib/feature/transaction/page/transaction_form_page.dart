import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/provider.dart';
import '../../../core/error/failure.dart';
import '../../../core/money/money.dart';
import '../../../core/patch/patch.dart';
import '../../../core/result/result.dart';
import '../../../design_system/theme/app_text_styles.dart';
import '../../../design_system/theme/app_theme_extension.dart';
import '../../../design_system/token/colors.dart';
import '../../../design_system/token/radius.dart';
import '../../../design_system/token/spacing.dart';
import '../../../design_system/widget/app_datetime_picker.dart';
import '../../../design_system/widget/app_surface.dart';
import '../../../application/ledger/ledger_command_api.dart';
import '../../../application/ledger/ledger_query_api.dart';
import '../../../widget/business/business_icon.dart';
import '../../../widget/business/category_grid_picker.dart';
import '../../../widget/business/money_text.dart';
import '../../../widget/business/plain_transaction_fields.dart';
import '../../shared/view_model/ui_action_outcome.dart';
import '../view_model/transaction_form_view_model.dart';

enum _TransactionFormMode { expense, income, transfer, borrowing }

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

  _TransactionFormMode _mode = _TransactionFormMode.expense;
  DateTime _occurredAt = DateTime.now();
  bool _submitting = false;
  bool _excludeStats = false;
  bool _excludeBudget = false;
  bool _editInitialized = false;

  String? _expenseCategoryId;
  String? _expenseRootId;
  String? _incomeCategoryId;
  String? _incomeRootId;
  String? _fromAccountId;
  String? _toAccountId;
  String? _reimbursementAccountId;
  String? _liabilityAccountId;

  @override
  void initState() {
    super.initState();
    _mode = _toPrivateMode(widget.initialMode);
    _fromAccountId = widget.initialFromAccountId;
    _toAccountId = widget.initialToAccountId;
    _amountController.addListener(_syncAmountTextToViewModel);
    _noteController.addListener(_syncNoteTextToViewModel);
  }

  @override
  void dispose() {
    _amountController.removeListener(_syncAmountTextToViewModel);
    _noteController.removeListener(_syncNoteTextToViewModel);
    _amountController.dispose();
    _noteController.dispose();
    super.dispose();
  }

  void _applyEditData(
    TransactionDetail detail,
    List<CategoryNode> expenseTree,
    List<CategoryNode> incomeTree,
    Map<String, Account> accountsById,
  ) {
    final transaction = detail.transaction;
    _amountController.text = transaction.primaryAmount.format();
    _noteController.text = transaction.note ?? '';
    _occurredAt = transaction.occurredAt;
    _excludeStats = transaction.isExcludedFromStats;
    _excludeBudget = transaction.isExcludedFromBudget;

    switch (transaction.businessPurpose) {
      case BusinessPurpose.dailyExpense:
        _mode = _TransactionFormMode.expense;
        _expenseCategoryId = _firstAccountId(
          detail,
          accountsById,
          AccountType.expense,
          EntryDirection.debit,
        );
        _expenseRootId = _rootCategoryId(expenseTree, _expenseCategoryId);
        _fromAccountId = _firstSettlementId(
          detail,
          accountsById,
          EntryDirection.credit,
        );
      case BusinessPurpose.reimbursementAdvance:
        _mode = _TransactionFormMode.expense;
        _expenseCategoryId = transaction.reimbursementExpenseAccountId;
        _expenseRootId = _rootCategoryId(expenseTree, _expenseCategoryId);
        _fromAccountId = _firstSettlementId(
          detail,
          accountsById,
          EntryDirection.credit,
        );
        _reimbursementAccountId = _firstSettlementId(
          detail,
          accountsById,
          EntryDirection.debit,
        );
      case BusinessPurpose.dailyIncome:
        _mode = _TransactionFormMode.income;
        _incomeCategoryId = _firstAccountId(
          detail,
          accountsById,
          AccountType.income,
          EntryDirection.credit,
        );
        _incomeRootId = _rootCategoryId(incomeTree, _incomeCategoryId);
        _toAccountId = _firstSettlementId(
          detail,
          accountsById,
          EntryDirection.debit,
        );
      case BusinessPurpose.transfer:
        _mode = _TransactionFormMode.transfer;
        _fromAccountId = _firstSettlementId(
          detail,
          accountsById,
          EntryDirection.credit,
        );
        _toAccountId = _firstSettlementId(
          detail,
          accountsById,
          EntryDirection.debit,
        );
        _excludeStats = false;
        _excludeBudget = false;
      case BusinessPurpose.borrowing:
        _mode = _TransactionFormMode.borrowing;
        _liabilityAccountId = _firstAccountId(
          detail,
          accountsById,
          AccountType.liability,
          EntryDirection.credit,
        );
        _toAccountId = _firstSettlementId(
          detail,
          accountsById,
          EntryDirection.debit,
        );
        _excludeStats = false;
        _excludeBudget = false;
      default:
        break;
    }
    _editInitialized = true;
  }

  @override
  Widget build(BuildContext context) {
    final formState = ref.watch(transactionFormViewModelProvider);
    ref.listen<TransactionFormState>(transactionFormViewModelProvider, (
      _,
      next,
    ) {
      if (widget.editTransactionId != null) return;
      _syncControllerText(_amountController, next.amountText);
      _syncControllerText(_noteController, next.noteText);
    });
    final moneyAccountsAsync = ref.watch(
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
    if (editTransactionId != null &&
        (!moneyAccountsAsync.hasValue ||
            !fundAccountsAsync.hasValue ||
            !liabilityAccountsAsync.hasValue ||
            !reimbursementAccountsAsync.hasValue ||
            !expenseTreeAsync.hasValue ||
            !incomeTreeAsync.hasValue ||
            !(editDetailAsync?.hasValue ?? false))) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    final moneyAccounts = moneyAccountsAsync.value ?? const <Account>[];
    final fundAccounts = fundAccountsAsync.value ?? const <Account>[];
    final liabilityAccounts = liabilityAccountsAsync.value ?? const <Account>[];
    final reimbursementAccounts =
        reimbursementAccountsAsync.value ?? const <Account>[];
    final expenseTree = expenseTreeAsync.value ?? const [];
    final incomeTree = incomeTreeAsync.value ?? const [];
    final editDetail = editDetailAsync?.value;
    if (editTransactionId != null && editDetail == null) {
      return const Scaffold(body: Center(child: Text('交易不存在')));
    }
    if (!_editInitialized && editDetail != null) {
      final accountsById =
          ref.watch(accountsByIdProvider).value ?? const <String, Account>{};
      _applyEditData(editDetail, expenseTree, incomeTree, accountsById);
    }
    final keyboardInset = MediaQuery.viewInsetsOf(context).bottom;
    final keyboardVisible = keyboardInset > 0;
    final dailyExpenseSubmitting =
        _isNewDailyExpense(reimbursementAccounts) && formState.submitting;

    return Scaffold(
      backgroundColor: AppColors.neutral99,
      resizeToAvoidBottomInset: false,
      body: SafeArea(
        child: Form(
          key: _formKey,
          child: Column(
            children: [
              _TopBar(
                mode: _mode,
                editing: widget.editTransactionId != null,
                onBack: () => context.pop(),
                onDelete:
                    widget.editTransactionId != null && !_submitting
                        ? _confirmDelete
                        : null,
                onModeChanged: _switchMode,
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
                    if (_mode == _TransactionFormMode.expense)
                      FormField<String>(
                        key: ValueKey('expense-category-$_expenseCategoryId'),
                        initialValue: _expenseCategoryId,
                        validator:
                            (_) =>
                                _mode == _TransactionFormMode.expense &&
                                        _expenseCategoryId == null
                                    ? '请选择支出分类'
                                    : null,
                        builder:
                            (field) => Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                CategoryGridPicker(
                                  nodes: expenseTree,
                                  selectedRootId: _expenseRootId,
                                  selectedCategoryId: _expenseCategoryId,
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
                    if (_mode == _TransactionFormMode.income)
                      CategoryGridPicker(
                        nodes: incomeTree,
                        selectedRootId: _incomeRootId,
                        selectedCategoryId: _incomeCategoryId,
                        emptyLabel: '尚未创建收入分类',
                        onRootSelected: (account) {
                          setState(() {
                            _incomeRootId = account.id;
                            _incomeCategoryId = account.id;
                          });
                        },
                        onChildSelected: (root, child) {
                          setState(() {
                            _incomeRootId = root.id;
                            _incomeCategoryId = child.id;
                          });
                        },
                        onAddRoot: () => _openCategoryForm(AccountType.income),
                        onAddChild:
                            (rootId) => _openCategoryForm(
                              AccountType.income,
                              parentId: rootId,
                            ),
                      ),
                    if (_mode == _TransactionFormMode.transfer)
                      _MainAccountPickerSection(
                        children: [
                          _MainAccountPickerTile(
                            label: '转出账户',
                            accounts: moneyAccounts,
                            selectedId: _fromAccountId,
                            onChanged:
                                (value) =>
                                    setState(() => _fromAccountId = value),
                          ),
                          const SizedBox(height: AppSpacing.space8),
                          _MainAccountPickerTile(
                            label: '转入账户',
                            accounts: moneyAccounts,
                            selectedId: _toAccountId,
                            onChanged:
                                (value) => setState(() => _toAccountId = value),
                          ),
                        ],
                      ),
                    if (_mode == _TransactionFormMode.borrowing)
                      _MainAccountPickerSection(
                        children: [
                          _MainAccountPickerTile(
                            label: '借出账户',
                            accounts: liabilityAccounts,
                            selectedId: _liabilityAccountId,
                            onChanged:
                                (value) =>
                                    setState(() => _liabilityAccountId = value),
                          ),
                          const SizedBox(height: AppSpacing.space8),
                          _MainAccountPickerTile(
                            label: '借入账户',
                            accounts: fundAccounts,
                            selectedId: _toAccountId,
                            onChanged:
                                (value) => setState(() => _toAccountId = value),
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
                      semantic: _amountSemantic(_mode),
                      amountValidator: _validatePositiveAmount,
                    ),
                    const SizedBox(height: AppSpacing.space4),
                    _TransactionOptionsPanel(
                      mode: _mode,
                      occurredAt: _occurredAt,
                      moneyAccounts: moneyAccounts,
                      reimbursementAccounts: reimbursementAccounts,
                      fromAccountId: _fromAccountId,
                      toAccountId: _toAccountId,
                      reimbursementAccountId: _reimbursementAccountId,
                      excludeStats: _excludeStats,
                      excludeBudget: _excludeBudget,
                      onPickDate: _pickDate,
                      onFromAccountChanged: (value) => _setFromAccountId(value),
                      onToAccountChanged:
                          (value) => setState(() => _toAccountId = value),
                      onReimbursementAccountChanged:
                          (value) => _setReimbursementAccountId(value),
                      onExcludeStatsChanged: (value) => _setExcludeStats(value),
                      onExcludeBudgetChanged:
                          (value) => _setExcludeBudget(value),
                    ),
                    if (_mode == _TransactionFormMode.expense)
                      FormField<String>(
                        key: ValueKey(
                          'expense-account-${_effectiveId(_fromAccountId, moneyAccounts)}',
                        ),
                        initialValue: _effectiveId(
                          _fromAccountId,
                          moneyAccounts,
                        ),
                        validator:
                            (_) =>
                                _mode == _TransactionFormMode.expense &&
                                        _effectiveId(
                                              _fromAccountId,
                                              moneyAccounts,
                                            ) ==
                                            null
                                    ? '请选择支出账户'
                                    : null,
                        builder:
                            (field) =>
                                field.errorText == null
                                    ? const SizedBox.shrink()
                                    : Align(
                                      alignment: Alignment.centerLeft,
                                      child: _FormFieldErrorText(
                                        field.errorText!,
                                      ),
                                    ),
                      ),
                    if (keyboardVisible)
                      SizedBox(height: keyboardInset)
                    else ...[
                      const SizedBox(height: AppSpacing.space6),
                      _NumberPad(
                        submitting: dailyExpenseSubmitting || _submitting,
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

  void _switchMode(_TransactionFormMode mode) {
    if (mode == _mode) {
      return;
    }
    setState(() {
      _mode = mode;
      _setReimbursementAccountId(null, updateState: false);
      if (mode == _TransactionFormMode.transfer ||
          mode == _TransactionFormMode.borrowing) {
        _setExcludeStats(false, updateState: false);
      }
      if (mode != _TransactionFormMode.expense) {
        _setExcludeBudget(false, updateState: false);
      }
    });
  }

  Future<void> _pickDate() async {
    final picked = await showAppDateTimePicker(
      context: context,
      initialDateTime: _occurredAt,
      title: '选择交易时间',
    );
    if (picked == null || !mounted) {
      return;
    }
    setState(() {
      _occurredAt = picked;
    });
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
    final current = _amountController.text;
    if (value == '.') {
      if (current.contains('.')) {
        return;
      }
      _amountController.text = current.isEmpty ? '0.' : '$current.';
      return;
    }

    final next = current == '0' ? value : '$current$value';
    final decimalIndex = next.indexOf('.');
    if (decimalIndex >= 0 && next.length - decimalIndex > 3) {
      return;
    }
    _amountController.text = next;
  }

  void _deleteAmountDigit() {
    final text = _amountController.text;
    if (text.isEmpty) {
      return;
    }
    _amountController.text = text.substring(0, text.length - 1);
  }

  void _clearForNext() {
    setState(() {
      _amountController.clear();
      _noteController.clear();
      _reimbursementAccountId = null;
      _excludeStats = false;
      _excludeBudget = false;
      _occurredAt = DateTime.now();
    });
    ref
        .read(transactionFormViewModelProvider.notifier)
        .clearForNext(occurredAt: _occurredAt);
  }

  Future<void> _submit() async {
    final moneyAccounts =
        ref.read(accountsForUsageProvider(AccountUsage.settlement)).value ??
        const <Account>[];
    final reimbursementAccounts =
        ref.read(accountsForUsageProvider(AccountUsage.reimbursement)).value ??
        const <Account>[];

    if (_isNewDailyExpense(reimbursementAccounts)) {
      final isValid = _formKey.currentState?.validate() ?? false;
      if (!isValid) {
        return;
      }
      _syncDailyExpenseStateToViewModel();
      final outcome = await ref
          .read(transactionFormViewModelProvider.notifier)
          .submitDailyExpense(settlementAccounts: moneyAccounts);
      if (!mounted) {
        return;
      }
      switch (outcome) {
        case SubmitSuccess():
          context.pop();
        case SubmitFailure(:final error):
          _showError(error.message);
      }
      return;
    }

    final amount = _parsePositiveAmount();
    if (amount == null) {
      _showError('请输入有效金额');
      return;
    }

    final fundAccounts =
        ref.read(accountsForUsageProvider(AccountUsage.fund)).value ??
        const <Account>[];
    final liabilityAccounts =
        ref
            .read(accountsForUsageProvider(AccountUsage.borrowingLiability))
            .value ??
        const <Account>[];
    final postingService = ref.read(transactionPostingAppServiceProvider);
    final correctionService = ref.read(transactionCorrectionAppServiceProvider);
    final note = _blankToNull(_noteController.text);

    setState(() => _submitting = true);
    final Result result;
    final editTransactionId = widget.editTransactionId;
    if (editTransactionId != null) {
      result = await _submitCorrection(
        service: correctionService,
        transactionId: editTransactionId,
        amount: amount,
        note: note,
        moneyAccounts: moneyAccounts,
        fundAccounts: fundAccounts,
        liabilityAccounts: liabilityAccounts,
        reimbursementAccounts: reimbursementAccounts,
      );
    } else {
      switch (_mode) {
        case _TransactionFormMode.expense:
          final expenseCategoryId = _expenseCategoryId;
          final paidFromAccountId = _effectiveId(_fromAccountId, moneyAccounts);
          if (expenseCategoryId == null) {
            setState(() => _submitting = false);
            _showError('请选择支出分类');
            return;
          }
          if (paidFromAccountId == null) {
            setState(() => _submitting = false);
            _showError('请选择支出账户');
            return;
          }
          final reimbursementAccountId = _selectedId(
            _reimbursementAccountId,
            reimbursementAccounts,
          );
          if (reimbursementAccountId == null) {
            setState(() => _submitting = false);
            _showError('普通支出保存路径不可用');
            return;
          } else {
            result = await postingService.createReimbursementAdvance(
              CreateReimbursementAdvanceCommand(
                amount: amount,
                receivableAccountId: reimbursementAccountId,
                paidFromAccountId: paidFromAccountId,
                expenseCategoryId: expenseCategoryId,
                occurredAt: _occurredAt,
                note: note,
                isExcludedFromStats: _excludeStats,
                isExcludedFromBudget: _excludeBudget,
              ),
            );
          }
        case _TransactionFormMode.income:
          final incomeCategoryId = _incomeCategoryId;
          final receiveAccountId = _effectiveId(_toAccountId, moneyAccounts);
          if (incomeCategoryId == null) {
            setState(() => _submitting = false);
            _showError('请选择收入分类');
            return;
          }
          if (receiveAccountId == null) {
            setState(() => _submitting = false);
            _showError('请选择收入账户');
            return;
          }
          result = await postingService.createIncome(
            CreateIncomeCommand(
              amount: amount,
              receiveAccountId: receiveAccountId,
              incomeAccountId: incomeCategoryId,
              occurredAt: _occurredAt,
              note: note,
              isExcludedFromStats: _excludeStats,
            ),
          );
        case _TransactionFormMode.transfer:
          final fromAccountId = _effectiveId(_fromAccountId, moneyAccounts);
          final toAccountId = _effectiveId(_toAccountId, moneyAccounts);
          if (fromAccountId == null || toAccountId == null) {
            setState(() => _submitting = false);
            _showError('请选择转出和转入账户');
            return;
          }
          result = await postingService.createTransfer(
            CreateTransferCommand(
              amount: amount,
              fromAccountId: fromAccountId,
              toAccountId: toAccountId,
              occurredAt: _occurredAt,
              note: note,
            ),
          );
        case _TransactionFormMode.borrowing:
          final liabilityAccountId = _effectiveId(
            _liabilityAccountId,
            liabilityAccounts,
          );
          final receiveAccountId = _effectiveId(_toAccountId, fundAccounts);
          if (liabilityAccountId == null) {
            setState(() => _submitting = false);
            _showError('请选择借出账户');
            return;
          }
          if (receiveAccountId == null) {
            setState(() => _submitting = false);
            _showError('请选择借入账户');
            return;
          }
          result = await postingService.createBorrowing(
            CreateBorrowingCommand(
              amount: amount,
              liabilityAccountId: liabilityAccountId,
              receiveAccountId: receiveAccountId,
              occurredAt: _occurredAt,
              note: note,
            ),
          );
      }
    }

    if (!mounted) {
      return;
    }
    setState(() => _submitting = false);

    switch (result) {
      case Success():
        if (widget.editTransactionId != null) {
          context.go('/');
        } else {
          context.pop();
        }
      case FailureResult(:final failure):
        _showError(failure.message);
    }
  }

  Future<Result<PostedTransactionResult>> _submitCorrection({
    required TransactionCorrectionAppService service,
    required String transactionId,
    required Money amount,
    required String? note,
    required List<Account> moneyAccounts,
    required List<Account> fundAccounts,
    required List<Account> liabilityAccounts,
    required List<Account> reimbursementAccounts,
  }) async {
    switch (_mode) {
      case _TransactionFormMode.expense:
        final expenseCategoryId = _expenseCategoryId;
        final paidFromAccountId = _effectiveId(_fromAccountId, moneyAccounts);
        if (expenseCategoryId == null) {
          setState(() => _submitting = false);
          _showError('请选择支出分类');
          return const Result.failure(Failure(message: '请选择支出分类'));
        }
        if (paidFromAccountId == null) {
          setState(() => _submitting = false);
          _showError('请选择支出账户');
          return const Result.failure(Failure(message: '请选择支出账户'));
        }
        final reimbursementAccountId = _selectedId(
          _reimbursementAccountId,
          reimbursementAccounts,
        );
        if (reimbursementAccountId == null) {
          return service.correctExpense(
            CorrectExpenseCommand(
              transactionId: transactionId,
              amount: amount,
              paidFromAccountId: paidFromAccountId,
              expenseAccountId: expenseCategoryId,
              occurredAt: _occurredAt,
              note: _stringPatch(note),
              isExcludedFromStats: _excludeStats,
              isExcludedFromBudget: _excludeBudget,
            ),
          );
        }
        return service.correctReimbursementAdvance(
          CorrectReimbursementAdvanceCommand(
            transactionId: transactionId,
            amount: amount,
            receivableAccountId: reimbursementAccountId,
            paidFromAccountId: paidFromAccountId,
            expenseCategoryId: expenseCategoryId,
            occurredAt: _occurredAt,
            note: _stringPatch(note),
            isExcludedFromStats: _excludeStats,
            isExcludedFromBudget: _excludeBudget,
          ),
        );
      case _TransactionFormMode.income:
        final incomeCategoryId = _incomeCategoryId;
        final receiveAccountId = _effectiveId(_toAccountId, moneyAccounts);
        if (incomeCategoryId == null) {
          setState(() => _submitting = false);
          _showError('请选择收入分类');
          return const Result.failure(Failure(message: '请选择收入分类'));
        }
        if (receiveAccountId == null) {
          setState(() => _submitting = false);
          _showError('请选择收入账户');
          return const Result.failure(Failure(message: '请选择收入账户'));
        }
        return service.correctIncome(
          CorrectIncomeCommand(
            transactionId: transactionId,
            amount: amount,
            receiveAccountId: receiveAccountId,
            incomeAccountId: incomeCategoryId,
            occurredAt: _occurredAt,
            note: _stringPatch(note),
            isExcludedFromStats: _excludeStats,
          ),
        );
      case _TransactionFormMode.transfer:
        final fromAccountId = _effectiveId(_fromAccountId, moneyAccounts);
        final toAccountId = _effectiveId(_toAccountId, moneyAccounts);
        if (fromAccountId == null || toAccountId == null) {
          setState(() => _submitting = false);
          _showError('请选择转出和转入账户');
          return const Result.failure(Failure(message: '请选择转出和转入账户'));
        }
        return service.correctTransfer(
          CorrectTransferCommand(
            transactionId: transactionId,
            amount: amount,
            fromAccountId: fromAccountId,
            toAccountId: toAccountId,
            occurredAt: _occurredAt,
            note: _stringPatch(note),
          ),
        );
      case _TransactionFormMode.borrowing:
        final liabilityAccountId = _effectiveId(
          _liabilityAccountId,
          liabilityAccounts,
        );
        final receiveAccountId = _effectiveId(_toAccountId, fundAccounts);
        if (liabilityAccountId == null || receiveAccountId == null) {
          setState(() => _submitting = false);
          _showError('请选择借出和借入账户');
          return const Result.failure(Failure(message: '请选择借出和借入账户'));
        }
        return service.correctBorrowing(
          CorrectBorrowingCommand(
            transactionId: transactionId,
            amount: amount,
            liabilityAccountId: liabilityAccountId,
            receiveAccountId: receiveAccountId,
            occurredAt: _occurredAt,
            note: _stringPatch(note),
          ),
        );
    }
  }

  Money? _parsePositiveAmount() {
    try {
      final money = Money.parse(_amountController.text);
      return money.minorUnits > 0 ? money : null;
    } on FormatException {
      return null;
    }
  }

  String? _effectiveId(String? selectedId, List<Account> options) {
    if (selectedId != null &&
        options.any((account) => account.id == selectedId)) {
      return selectedId;
    }
    return options.isEmpty ? null : options.first.id;
  }

  String? _selectedId(String? selectedId, List<Account> options) {
    if (selectedId != null &&
        options.any((account) => account.id == selectedId)) {
      return selectedId;
    }
    return null;
  }

  String? _blankToNull(String value) {
    final trimmed = value.trim();
    return trimmed.isEmpty ? null : trimmed;
  }

  String? _validatePositiveAmount(String? value) {
    try {
      final money = Money.parse(value ?? '');
      return money.minorUnits > 0 ? null : '请输入有效金额';
    } on FormatException {
      return '请输入有效金额';
    }
  }

  Patch<String?> _stringPatch(String? value) {
    return value == null ? const Patch<String?>.clear() : Patch.set(value);
  }

  MoneySemantic _amountSemantic(_TransactionFormMode mode) {
    return switch (mode) {
      _TransactionFormMode.expense => MoneySemantic.expense,
      _TransactionFormMode.income => MoneySemantic.income,
      _TransactionFormMode.transfer => MoneySemantic.neutral,
      _TransactionFormMode.borrowing => MoneySemantic.neutral,
    };
  }

  void _showError(String message) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  bool _isNewDailyExpense(List<Account> reimbursementAccounts) {
    return widget.editTransactionId == null &&
        _mode == _TransactionFormMode.expense &&
        _selectedId(_reimbursementAccountId, reimbursementAccounts) == null;
  }

  void _syncAmountTextToViewModel() {
    if (widget.editTransactionId != null) return;
    ref
        .read(transactionFormViewModelProvider.notifier)
        .setAmountText(_amountController.text);
  }

  void _syncNoteTextToViewModel() {
    if (widget.editTransactionId != null) return;
    ref
        .read(transactionFormViewModelProvider.notifier)
        .setNoteText(_noteController.text);
  }

  void _syncControllerText(TextEditingController controller, String text) {
    if (controller.text == text) return;
    controller.value = TextEditingValue(
      text: text,
      selection: TextSelection.collapsed(offset: text.length),
    );
  }

  void _selectExpenseCategory({
    required String? rootId,
    required String? categoryId,
  }) {
    setState(() {
      _expenseRootId = rootId;
      _expenseCategoryId = categoryId;
    });
    ref
        .read(transactionFormViewModelProvider.notifier)
        .setExpenseCategory(rootId: rootId, categoryId: categoryId);
  }

  void _setFromAccountId(String? value, {bool updateState = true}) {
    if (updateState) {
      setState(() => _fromAccountId = value);
    } else {
      _fromAccountId = value;
    }
    ref.read(transactionFormViewModelProvider.notifier).setFromAccountId(value);
  }

  void _setReimbursementAccountId(String? value, {bool updateState = true}) {
    if (updateState) {
      setState(() => _reimbursementAccountId = value);
    } else {
      _reimbursementAccountId = value;
    }
    ref
        .read(transactionFormViewModelProvider.notifier)
        .setReimbursementAccountId(value);
  }

  void _setExcludeStats(bool value, {bool updateState = true}) {
    if (updateState) {
      setState(() => _excludeStats = value);
    } else {
      _excludeStats = value;
    }
    ref.read(transactionFormViewModelProvider.notifier).setExcludeStats(value);
  }

  void _setExcludeBudget(bool value, {bool updateState = true}) {
    if (updateState) {
      setState(() => _excludeBudget = value);
    } else {
      _excludeBudget = value;
    }
    ref.read(transactionFormViewModelProvider.notifier).setExcludeBudget(value);
  }

  void _syncDailyExpenseStateToViewModel() {
    ref
        .read(transactionFormViewModelProvider.notifier)
        .setExpenseCategory(
          rootId: _expenseRootId,
          categoryId: _expenseCategoryId,
        );
    ref
        .read(transactionFormViewModelProvider.notifier)
        .setFromAccountId(_fromAccountId);
    ref
        .read(transactionFormViewModelProvider.notifier)
        .setOccurredAt(_occurredAt);
    ref
        .read(transactionFormViewModelProvider.notifier)
        .setExcludeStats(_excludeStats);
    ref
        .read(transactionFormViewModelProvider.notifier)
        .setExcludeBudget(_excludeBudget);
  }

  Future<void> _confirmDelete() async {
    final transactionId = widget.editTransactionId;
    if (transactionId == null || _submitting) {
      return;
    }
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
    if (confirmed != true || !mounted) {
      return;
    }

    setState(() => _submitting = true);
    final result = await ref
        .read(transactionCorrectionAppServiceProvider)
        .deleteTransaction(
          DeleteTransactionCommand(transactionId: transactionId),
        );
    if (!mounted) {
      return;
    }
    setState(() => _submitting = false);
    result.when(
      success: (_) => context.go('/'),
      failure: (failure) => _showError('删除失败：${failure.message}'),
    );
  }

  String? _firstAccountId(
    TransactionDetail detail,
    Map<String, Account> accountsById,
    AccountType type,
    EntryDirection direction,
  ) {
    for (final entry in detail.entries) {
      if (accountsById[entry.accountId]?.type == type &&
          entry.direction == direction) {
        return entry.accountId;
      }
    }
    return null;
  }

  String? _firstSettlementId(
    TransactionDetail detail,
    Map<String, Account> accountsById,
    EntryDirection direction,
  ) {
    for (final entry in detail.entries) {
      final type = accountsById[entry.accountId]?.type;
      if ((type == AccountType.asset || type == AccountType.liability) &&
          entry.direction == direction) {
        return entry.accountId;
      }
    }
    return null;
  }

  String? _rootCategoryId(List<CategoryNode> tree, String? categoryId) {
    if (categoryId == null) return null;
    for (final node in tree) {
      if (node.account.id == categoryId) return node.account.id;
      for (final child in node.children) {
        if (child.id == categoryId) return node.account.id;
      }
    }
    return categoryId;
  }
}

Account? _effectiveAccount(String? selectedId, List<Account> options) {
  if (selectedId != null) {
    for (final account in options) {
      if (account.id == selectedId) {
        return account;
      }
    }
  }
  return options.firstOrNull;
}

class _TopBar extends StatelessWidget {
  const _TopBar({
    required this.mode,
    required this.editing,
    required this.onBack,
    required this.onDelete,
    required this.onModeChanged,
  });

  final _TransactionFormMode mode;
  final bool editing;
  final VoidCallback onBack;
  final VoidCallback? onDelete;
  final ValueChanged<_TransactionFormMode> onModeChanged;

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

  final _TransactionFormMode mode;
  final ValueChanged<_TransactionFormMode> onChanged;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: [
        for (final value in _TransactionFormMode.values)
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
    final effective = _effectiveAccount(selectedId, accounts);
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
      selectedId: _effectiveAccount(selectedId, accounts)?.id,
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
              inputFormatters: [
                FilteringTextInputFormatter.allow(RegExp(r'[0-9.]')),
              ],
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

  final _TransactionFormMode mode;
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
        mode == _TransactionFormMode.expense ||
        mode == _TransactionFormMode.income;
    final showExcludeStats = showPrimaryAccount;
    final accountLabel = mode == _TransactionFormMode.income ? '收入账户' : '支出账户';
    final primaryAccountId =
        mode == _TransactionFormMode.income ? toAccountId : fromAccountId;
    final primaryChanged =
        mode == _TransactionFormMode.income
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
            if (mode == _TransactionFormMode.expense)
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
            if (mode == _TransactionFormMode.expense)
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
    final effective = selected ?? (accounts.isEmpty ? null : accounts.first);
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
      selectedId: _effectiveAccount(selectedId, accounts)?.id,
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

String _modeLabel(_TransactionFormMode mode) {
  return switch (mode) {
    _TransactionFormMode.expense => '支出',
    _TransactionFormMode.income => '收入',
    _TransactionFormMode.transfer => '转账',
    _TransactionFormMode.borrowing => '借入',
  };
}

_TransactionFormMode _toPrivateMode(TransactionFormInitialMode mode) {
  return switch (mode) {
    TransactionFormInitialMode.expense => _TransactionFormMode.expense,
    TransactionFormInitialMode.income => _TransactionFormMode.income,
    TransactionFormInitialMode.transfer => _TransactionFormMode.transfer,
    TransactionFormInitialMode.borrowing => _TransactionFormMode.borrowing,
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
