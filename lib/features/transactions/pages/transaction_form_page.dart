import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/providers.dart';
import '../../../core/errors/failure.dart';
import '../../../core/money/money.dart';
import '../../../core/result/result.dart';
import '../../../design_system/theme/app_text_styles.dart';
import '../../../design_system/theme/app_theme_extension.dart';
import '../../../design_system/tokens/colors.dart';
import '../../../design_system/tokens/radius.dart';
import '../../../design_system/tokens/spacing.dart';
import '../../../design_system/widgets/app_datetime_picker.dart';
import '../../../design_system/widgets/app_surface.dart';
import '../../../domain/accounting/accounting_api.dart';
import '../../../widgets/business/business_icon.dart';
import '../../../widgets/business/category_grid_picker.dart';
import '../../../widgets/business/money_text.dart';
import '../../../widgets/business/plain_transaction_fields.dart';

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

  final int? editTransactionId;
  final TransactionFormInitialMode initialMode;
  final int? initialFromAccountId;
  final int? initialToAccountId;

  @override
  ConsumerState<TransactionFormPage> createState() =>
      _TransactionFormPageState();
}

class _TransactionFormPageState extends ConsumerState<TransactionFormPage> {
  final _amountController = TextEditingController();
  final _noteController = TextEditingController();

  _TransactionFormMode _mode = _TransactionFormMode.expense;
  DateTime _occurredAt = DateTime.now();
  bool _submitting = false;
  bool _excludeStats = false;
  bool _excludeBudget = false;
  bool _editInitialized = false;

  int? _expenseCategoryId;
  int? _expenseRootId;
  int? _incomeCategoryId;
  int? _incomeRootId;
  int? _fromAccountId;
  int? _toAccountId;
  int? _reimbursementAccountId;
  int? _liabilityAccountId;

  @override
  void initState() {
    super.initState();
    _mode = _toPrivateMode(widget.initialMode);
    _fromAccountId = widget.initialFromAccountId;
    _toAccountId = widget.initialToAccountId;
  }

  @override
  void dispose() {
    _amountController.dispose();
    _noteController.dispose();
    super.dispose();
  }

  void _applyEditData(
    TransactionDetail detail,
    List<CategoryNode> expenseTree,
    List<CategoryNode> incomeTree,
    Map<int, Account> accountsById,
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
          ref.watch(accountsByIdProvider).value ?? const <int, Account>{};
      _applyEditData(editDetail, expenseTree, incomeTree, accountsById);
    }
    final keyboardInset = MediaQuery.viewInsetsOf(context).bottom;
    final keyboardVisible = keyboardInset > 0;

    return Scaffold(
      backgroundColor: AppColors.neutral99,
      resizeToAvoidBottomInset: false,
      body: SafeArea(
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
                    CategoryGridPicker(
                      nodes: expenseTree,
                      selectedRootId: _expenseRootId,
                      selectedCategoryId: _expenseCategoryId,
                      emptyLabel: '尚未创建支出分类',
                      onRootSelected: (account) {
                        setState(() {
                          _expenseRootId = account.id;
                          _expenseCategoryId = account.id;
                        });
                      },
                      onChildSelected: (root, child) {
                        setState(() {
                          _expenseRootId = root.id;
                          _expenseCategoryId = child.id;
                        });
                      },
                      onAddRoot: () => _openCategoryForm(AccountType.expense),
                      onAddChild:
                          (rootId) => _openCategoryForm(
                            AccountType.expense,
                            parentId: rootId,
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
                              (value) => setState(() => _fromAccountId = value),
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
                    onFromAccountChanged:
                        (value) => setState(() => _fromAccountId = value),
                    onToAccountChanged:
                        (value) => setState(() => _toAccountId = value),
                    onReimbursementAccountChanged:
                        (value) =>
                            setState(() => _reimbursementAccountId = value),
                    onExcludeStatsChanged:
                        (value) => setState(() => _excludeStats = value),
                    onExcludeBudgetChanged:
                        (value) => setState(() => _excludeBudget = value),
                  ),
                  if (keyboardVisible)
                    SizedBox(height: keyboardInset)
                  else ...[
                    const SizedBox(height: AppSpacing.space6),
                    _NumberPad(
                      submitting: _submitting,
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
    );
  }

  void _switchMode(_TransactionFormMode mode) {
    if (mode == _mode) {
      return;
    }
    setState(() {
      _mode = mode;
      _reimbursementAccountId = null;
      if (mode == _TransactionFormMode.transfer ||
          mode == _TransactionFormMode.borrowing) {
        _excludeStats = false;
      }
      if (mode != _TransactionFormMode.expense) {
        _excludeBudget = false;
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
  }

  void _openCategoryForm(AccountType type, {int? parentId}) {
    final query =
        Uri(
          path: '/categories/new',
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
  }

  Future<void> _submit() async {
    final amount = _parsePositiveAmount();
    if (amount == null) {
      _showError('请输入有效金额');
      return;
    }

    final moneyAccounts =
        ref.read(accountsForUsageProvider(AccountUsage.settlement)).value ??
        const <Account>[];
    final fundAccounts =
        ref.read(accountsForUsageProvider(AccountUsage.fund)).value ??
        const <Account>[];
    final liabilityAccounts =
        ref
            .read(accountsForUsageProvider(AccountUsage.borrowingLiability))
            .value ??
        const <Account>[];
    final reimbursementAccounts =
        ref.read(accountsForUsageProvider(AccountUsage.reimbursement)).value ??
        const <Account>[];

    final service = ref.read(transactionServiceProvider);
    final note = _blankToNull(_noteController.text);

    setState(() => _submitting = true);
    final Result result;
    final editTransactionId = widget.editTransactionId;
    if (editTransactionId != null) {
      result = await _submitCorrection(
        service: service,
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
            result = await service.createExpense(
              CreateExpenseCommand(
                amount: amount,
                paidFromAccountId: paidFromAccountId,
                expenseAccountId: expenseCategoryId,
                occurredAt: _occurredAt,
                note: note,
                isExcludedFromStats: _excludeStats,
                isExcludedFromBudget: _excludeBudget,
              ),
            );
          } else {
            result = await service.createReimbursementAdvance(
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
          result = await service.createIncome(
            CreateIncomeCommand(
              amount: amount,
              receiveAccountId: receiveAccountId,
              incomeAccountId: incomeCategoryId,
              occurredAt: _occurredAt,
              note: note,
              isExcludedFromStats: _excludeStats,
              isExcludedFromBudget: false,
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
          result = await service.createTransfer(
            CreateTransferCommand(
              amount: amount,
              fromAccountId: fromAccountId,
              toAccountId: toAccountId,
              occurredAt: _occurredAt,
              note: note,
              isExcludedFromStats: false,
              isExcludedFromBudget: false,
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
          result = await service.createBorrowing(
            CreateBorrowingCommand(
              amount: amount,
              liabilityAccountId: liabilityAccountId,
              receiveAccountId: receiveAccountId,
              occurredAt: _occurredAt,
              note: note,
              isExcludedFromStats: false,
              isExcludedFromBudget: false,
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

  Future<Result<CreatedTransactionResult>> _submitCorrection({
    required TransactionService service,
    required int transactionId,
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
              note: note,
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
            note: note,
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
            note: note,
            isExcludedFromStats: _excludeStats,
            isExcludedFromBudget: false,
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
            note: note,
            isExcludedFromStats: false,
            isExcludedFromBudget: false,
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
            note: note,
            isExcludedFromStats: false,
            isExcludedFromBudget: false,
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

  int? _effectiveId(int? selectedId, List<Account> options) {
    if (selectedId != null &&
        options.any((account) => account.id == selectedId)) {
      return selectedId;
    }
    return options.isEmpty ? null : options.first.id;
  }

  int? _selectedId(int? selectedId, List<Account> options) {
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
        .read(transactionServiceProvider)
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

  int? _firstAccountId(
    TransactionDetail detail,
    Map<int, Account> accountsById,
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

  int? _firstSettlementId(
    TransactionDetail detail,
    Map<int, Account> accountsById,
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

  int? _rootCategoryId(List<CategoryNode> tree, int? categoryId) {
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

Account? _effectiveAccount(int? selectedId, List<Account> options) {
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
  final int? selectedId;
  final ValueChanged<int?> onChanged;

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
  });

  final TextEditingController amountController;
  final TextEditingController noteController;
  final MoneySemantic semantic;

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
            child: TextField(
              controller: amountController,
              readOnly: true,
              showCursor: false,
              textAlign: TextAlign.end,
              inputFormatters: [
                FilteringTextInputFormatter.allow(RegExp(r'[0-9.]')),
              ],
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
  final int? fromAccountId;
  final int? toAccountId;
  final int? reimbursementAccountId;
  final bool excludeStats;
  final bool excludeBudget;
  final VoidCallback onPickDate;
  final ValueChanged<int?> onFromAccountChanged;
  final ValueChanged<int?> onToAccountChanged;
  final ValueChanged<int?> onReimbursementAccountChanged;
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
  final int? selectedId;
  final ValueChanged<int?> onChanged;
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
