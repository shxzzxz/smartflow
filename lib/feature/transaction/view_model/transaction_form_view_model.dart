import 'package:logging/logging.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../../app/provider.dart';
import '../../../application/ledger/ledger_command_api.dart';
import '../../../application/ledger/ledger_query_api.dart';
import '../../../core/error/app_exception.dart';
import '../../../core/money/money.dart';
import '../../../core/patch/patch.dart';
import '../../../core/text/text_normalizer.dart';
import '../../../domain/ledger/valobj/ledger_error_code.dart';
import '../../../shared/account_profile/account_selection_purpose.dart';
import '../../shared/provider/ledger_query_providers.dart';
import '../../shared/view_model/ui_action_outcome.dart';
import '../presentation/transaction_form_presentation.dart';

part 'transaction_form_view_model.g.dart';

final _logger = Logger('feature.transaction.form');

@riverpod
class TransactionFormViewModel extends _$TransactionFormViewModel {
  TransactionFormState? _initializedState;
  String? _editTransactionId;

  @override
  AsyncValue<TransactionFormState?> build({
    String? editTransactionId,
    TransactionFormMode initialMode = TransactionFormMode.expense,
    String? initialFromAccountId,
    String? initialToAccountId,
  }) {
    _editTransactionId = editTransactionId;
    final settlementAccountsAsync = ref.watch(
      accountsForSelectionPurposeProvider(AccountSelectionPurpose.settlement),
    );
    final fundAccountsAsync = ref.watch(
      accountsForSelectionPurposeProvider(AccountSelectionPurpose.fund),
    );
    final liabilityAccountsAsync = ref.watch(
      accountsForSelectionPurposeProvider(
        AccountSelectionPurpose.borrowingLiability,
      ),
    );
    final reimbursementAccountsAsync = ref.watch(
      accountsForSelectionPurposeProvider(
        AccountSelectionPurpose.reimbursementReceivable,
      ),
    );
    final expenseTreeAsync = ref.watch(
      categoryTreeProvider(AccountType.expense),
    );
    final incomeTreeAsync = ref.watch(categoryTreeProvider(AccountType.income));
    final editDetailAsync =
        editTransactionId == null
            ? null
            : ref.watch(transactionDetailProvider(editTransactionId));
    final accountsByIdAsync =
        editTransactionId == null ? null : ref.watch(accountsByIdProvider);

    final initializedState = _initializedState;
    if (initializedState != null) {
      final next = _refreshReferenceData(
        initializedState,
        settlementAccounts: settlementAccountsAsync.value,
        fundAccounts: fundAccountsAsync.value,
        liabilityAccounts: liabilityAccountsAsync.value,
        reimbursementAccounts: reimbursementAccountsAsync.value,
        expenseTree: expenseTreeAsync.value,
        incomeTree: incomeTreeAsync.value,
      );
      _initializedState = next;
      return AsyncValue.data(next);
    }

    if (editTransactionId == null) {
      return AsyncValue.data(
        _initializedState ??= TransactionFormState.initial(
          mode: initialMode,
          fromAccountId: initialFromAccountId,
          toAccountId: initialToAccountId,
          settlementAccounts:
              settlementAccountsAsync.value ?? const <Account>[],
          fundAccounts: fundAccountsAsync.value ?? const <Account>[],
          liabilityAccounts: liabilityAccountsAsync.value ?? const <Account>[],
          reimbursementAccounts:
              reimbursementAccountsAsync.value ?? const <Account>[],
          expenseTree: expenseTreeAsync.value ?? const <CategoryNode>[],
          incomeTree: incomeTreeAsync.value ?? const <CategoryNode>[],
        ),
      );
    }

    final queries = <AsyncValue<dynamic>>[
      settlementAccountsAsync,
      fundAccountsAsync,
      liabilityAccountsAsync,
      reimbursementAccountsAsync,
      expenseTreeAsync,
      incomeTreeAsync,
      if (editDetailAsync != null) editDetailAsync,
      if (accountsByIdAsync != null) accountsByIdAsync,
    ];
    for (final query in queries) {
      if (query case AsyncError(:final error, :final stackTrace)) {
        return AsyncValue.error(error, stackTrace);
      }
    }
    if (queries.any((query) => !query.hasValue)) {
      return const AsyncValue.loading();
    }

    final settlementAccounts = settlementAccountsAsync.requireValue;
    final fundAccounts = fundAccountsAsync.requireValue;
    final liabilityAccounts = liabilityAccountsAsync.requireValue;
    final reimbursementAccounts = reimbursementAccountsAsync.requireValue;
    final expenseTree = expenseTreeAsync.requireValue;
    final incomeTree = incomeTreeAsync.requireValue;

    final detail = editDetailAsync!.requireValue;
    if (detail == null) return const AsyncValue.data(null);
    if (!supportsTransactionFormEdit(detail.transaction.businessPurpose)) {
      return const AsyncValue.data(null);
    }
    final snapshot = transactionFormEditSnapshot(
      detail: detail,
      expenseTree: expenseTree,
      incomeTree: incomeTree,
      accountsById: accountsByIdAsync!.requireValue,
    );
    return AsyncValue.data(
      _initializedState ??= TransactionFormState.fromEditSnapshot(
        snapshot: snapshot,
        settlementAccounts: settlementAccounts,
        fundAccounts: fundAccounts,
        liabilityAccounts: liabilityAccounts,
        reimbursementAccounts: reimbursementAccounts,
        expenseTree: expenseTree,
        incomeTree: incomeTree,
      ),
    );
  }

  void setMode(TransactionFormMode value) {
    _update((current) {
      if (current.mode == value) return current;
      return current.copyWith(
        mode: value,
        reimbursementAccountId: null,
        excludeStats:
            value == TransactionFormMode.transfer ||
                    value == TransactionFormMode.borrowing
                ? false
                : current.excludeStats,
        excludeBudget:
            value == TransactionFormMode.expense
                ? current.excludeBudget
                : false,
      );
    });
  }

  void setOccurredAt(DateTime value) {
    _update((current) => current.copyWith(occurredAt: value));
  }

  void setExpenseCategory({
    required String? rootId,
    required String? categoryId,
  }) {
    _update(
      (current) => current.copyWith(
        expenseRootId: rootId,
        expenseCategoryId: categoryId,
      ),
    );
  }

  void setIncomeCategory({
    required String? rootId,
    required String? categoryId,
  }) {
    _update(
      (current) =>
          current.copyWith(incomeRootId: rootId, incomeCategoryId: categoryId),
    );
  }

  void setFromAccountId(String? value) {
    _update((current) => current.copyWith(fromAccountId: value));
  }

  void setToAccountId(String? value) {
    _update((current) => current.copyWith(toAccountId: value));
  }

  void setReimbursementAccountId(String? value) {
    _update((current) => current.copyWith(reimbursementAccountId: value));
  }

  void setLiabilityAccountId(String? value) {
    _update((current) => current.copyWith(liabilityAccountId: value));
  }

  void setExcludeStats(bool value) {
    _update((current) => current.copyWith(excludeStats: value));
  }

  void setExcludeBudget(bool value) {
    _update((current) => current.copyWith(excludeBudget: value));
  }

  void clearForNext({DateTime? occurredAt}) {
    _update(
      (current) => current.copyWith(
        reimbursementAccountId: null,
        excludeStats: false,
        excludeBudget: false,
        occurredAt: occurredAt ?? DateTime.now(),
      ),
    );
  }

  Future<SubmitOutcome> submit({
    required String amountText,
    required String noteText,
  }) async {
    final current = state.asData?.value;
    if (current == null) return _invalidCommand('交易表单尚未加载');
    final amount = _parsePositiveAmount(amountText);
    if (amount == null) {
      return _invalidCommand('请输入有效金额');
    }

    _update((current) => current.copyWith(submitting: true));
    try {
      final editTransactionId = _editTransactionId;
      if (editTransactionId == null) {
        await _submitCreate(current, amount, noteText);
      } else {
        await _submitEdit(current, editTransactionId, amount, noteText);
      }
      return const SubmitOutcome.success();
    } on AppException catch (exception) {
      return SubmitOutcome.failure(UiError.fromException(exception));
    } on Exception catch (exception, stackTrace) {
      _logger.severe(
        'Transaction form submit failed unexpectedly.',
        exception,
        stackTrace,
      );
      return const SubmitOutcome.failure(UiError.unknown());
    } finally {
      _update((current) => current.copyWith(submitting: false));
    }
  }

  Future<UiActionOutcome<void>> deleteTransaction(String transactionId) async {
    _update((current) => current.copyWith(submitting: true));
    try {
      await ref
          .read(transactionEditAppServiceProvider)
          .deleteTransaction(
            DeleteTransactionCommand(transactionId: transactionId),
          );
      return const UiActionOutcome.success(null);
    } on AppException catch (exception) {
      return UiActionOutcome.failure(UiError.fromException(exception));
    } on Exception catch (exception, stackTrace) {
      _logger.severe(
        'Transaction delete failed unexpectedly.',
        exception,
        stackTrace,
      );
      return const UiActionOutcome.failure(UiError.unknown());
    } finally {
      _update((current) => current.copyWith(submitting: false));
    }
  }

  Future<void> _submitCreate(
    TransactionFormState formState,
    Money amount,
    String noteText,
  ) async {
    final postingService = ref.read(transactionPostingAppServiceProvider);
    final note = trimToNull(noteText);

    switch (formState.mode) {
      case TransactionFormMode.expense:
        final expenseCategoryId = formState.expenseCategoryId;
        if (expenseCategoryId == null) {
          throw _invalidCommandException('请选择支出分类');
        }
        final paidFromAccountId = _effectiveId(
          formState.fromAccountId,
          formState.settlementAccounts,
        );
        if (paidFromAccountId == null) {
          throw _invalidCommandException('请选择支出账户');
        }
        final reimbursementAccountId = _selectedId(
          formState.reimbursementAccountId,
          formState.reimbursementAccounts,
        );
        if (reimbursementAccountId == null) {
          await postingService.createExpense(
            CreateExpenseCommand(
              amount: amount,
              paidFromAccountId: paidFromAccountId,
              expenseAccountId: expenseCategoryId,
              occurredAt: formState.occurredAt,
              note: note,
              isExcludedFromStats: formState.excludeStats,
              isExcludedFromBudget: formState.excludeBudget,
            ),
          );
        } else {
          await postingService.createReimbursementAdvance(
            CreateReimbursementAdvanceCommand(
              amount: amount,
              receivableAccountId: reimbursementAccountId,
              paidFromAccountId: paidFromAccountId,
              expenseCategoryId: expenseCategoryId,
              occurredAt: formState.occurredAt,
              note: note,
              isExcludedFromStats: formState.excludeStats,
              isExcludedFromBudget: formState.excludeBudget,
            ),
          );
        }
      case TransactionFormMode.income:
        final incomeCategoryId = formState.incomeCategoryId;
        if (incomeCategoryId == null) throw _invalidCommandException('请选择收入分类');
        final receiveAccountId = _effectiveId(
          formState.toAccountId,
          formState.settlementAccounts,
        );
        if (receiveAccountId == null) throw _invalidCommandException('请选择收入账户');
        await postingService.createIncome(
          CreateIncomeCommand(
            amount: amount,
            receiveAccountId: receiveAccountId,
            incomeAccountId: incomeCategoryId,
            occurredAt: formState.occurredAt,
            note: note,
            isExcludedFromStats: formState.excludeStats,
          ),
        );
      case TransactionFormMode.transfer:
        final fromAccountId = _effectiveId(
          formState.fromAccountId,
          formState.settlementAccounts,
        );
        final toAccountId = _effectiveId(
          formState.toAccountId,
          formState.settlementAccounts,
        );
        if (fromAccountId == null || toAccountId == null) {
          throw _invalidCommandException('请选择转出和转入账户');
        }
        await postingService.createTransfer(
          CreateTransferCommand(
            amount: amount,
            fromAccountId: fromAccountId,
            toAccountId: toAccountId,
            occurredAt: formState.occurredAt,
            note: note,
          ),
        );
      case TransactionFormMode.borrowing:
        final liabilityAccountId = _effectiveId(
          formState.liabilityAccountId,
          formState.liabilityAccounts,
        );
        if (liabilityAccountId == null) {
          throw _invalidCommandException('请选择借出账户');
        }
        final receiveAccountId = _effectiveId(
          formState.toAccountId,
          formState.fundAccounts,
        );
        if (receiveAccountId == null) throw _invalidCommandException('请选择借入账户');
        await postingService.createBorrowing(
          CreateBorrowingCommand(
            amount: amount,
            liabilityAccountId: liabilityAccountId,
            receiveAccountId: receiveAccountId,
            occurredAt: formState.occurredAt,
            note: note,
          ),
        );
    }
  }

  Future<void> _submitEdit(
    TransactionFormState formState,
    String transactionId,
    Money amount,
    String noteText,
  ) async {
    final editService = ref.read(transactionEditAppServiceProvider);
    final note = _stringPatch(trimToNull(noteText));

    switch (formState.mode) {
      case TransactionFormMode.expense:
        final expenseCategoryId = formState.expenseCategoryId;
        if (expenseCategoryId == null) {
          throw _invalidCommandException('请选择支出分类');
        }
        final paidFromAccountId = _effectiveId(
          formState.fromAccountId,
          formState.settlementAccounts,
        );
        if (paidFromAccountId == null) {
          throw _invalidCommandException('请选择支出账户');
        }
        final reimbursementAccountId = _selectedId(
          formState.reimbursementAccountId,
          formState.reimbursementAccounts,
        );
        if (reimbursementAccountId == null) {
          await editService.editExpense(
            EditExpenseCommand(
              transactionId: transactionId,
              amount: amount,
              paidFromAccountId: paidFromAccountId,
              expenseAccountId: expenseCategoryId,
              occurredAt: formState.occurredAt,
              note: note,
              isExcludedFromStats: formState.excludeStats,
              isExcludedFromBudget: formState.excludeBudget,
            ),
          );
        } else {
          await editService.editReimbursementAdvance(
            EditReimbursementAdvanceCommand(
              transactionId: transactionId,
              amount: amount,
              receivableAccountId: reimbursementAccountId,
              paidFromAccountId: paidFromAccountId,
              expenseCategoryId: expenseCategoryId,
              occurredAt: formState.occurredAt,
              note: note,
              isExcludedFromStats: formState.excludeStats,
              isExcludedFromBudget: formState.excludeBudget,
            ),
          );
        }
      case TransactionFormMode.income:
        final incomeCategoryId = formState.incomeCategoryId;
        if (incomeCategoryId == null) throw _invalidCommandException('请选择收入分类');
        final receiveAccountId = _effectiveId(
          formState.toAccountId,
          formState.settlementAccounts,
        );
        if (receiveAccountId == null) throw _invalidCommandException('请选择收入账户');
        await editService.editIncome(
          EditIncomeCommand(
            transactionId: transactionId,
            amount: amount,
            receiveAccountId: receiveAccountId,
            incomeAccountId: incomeCategoryId,
            occurredAt: formState.occurredAt,
            note: note,
            isExcludedFromStats: formState.excludeStats,
          ),
        );
      case TransactionFormMode.transfer:
        final fromAccountId = _effectiveId(
          formState.fromAccountId,
          formState.settlementAccounts,
        );
        final toAccountId = _effectiveId(
          formState.toAccountId,
          formState.settlementAccounts,
        );
        if (fromAccountId == null || toAccountId == null) {
          throw _invalidCommandException('请选择转出和转入账户');
        }
        await editService.editTransfer(
          EditTransferCommand(
            transactionId: transactionId,
            amount: amount,
            fromAccountId: fromAccountId,
            toAccountId: toAccountId,
            occurredAt: formState.occurredAt,
            note: note,
          ),
        );
      case TransactionFormMode.borrowing:
        final liabilityAccountId = _effectiveId(
          formState.liabilityAccountId,
          formState.liabilityAccounts,
        );
        final receiveAccountId = _effectiveId(
          formState.toAccountId,
          formState.fundAccounts,
        );
        if (liabilityAccountId == null || receiveAccountId == null) {
          throw _invalidCommandException('请选择借出和借入账户');
        }
        await editService.editBorrowing(
          EditBorrowingCommand(
            transactionId: transactionId,
            amount: amount,
            liabilityAccountId: liabilityAccountId,
            receiveAccountId: receiveAccountId,
            occurredAt: formState.occurredAt,
            note: note,
          ),
        );
    }
  }

  void _update(TransactionFormState Function(TransactionFormState) update) {
    final current = state.asData?.value;
    if (current == null) return;
    final next = update(current);
    _initializedState = next;
    state = AsyncValue.data(next);
  }

  TransactionFormState _refreshReferenceData(
    TransactionFormState current, {
    required List<Account>? settlementAccounts,
    required List<Account>? fundAccounts,
    required List<Account>? liabilityAccounts,
    required List<Account>? reimbursementAccounts,
    required List<CategoryNode>? expenseTree,
    required List<CategoryNode>? incomeTree,
  }) {
    return current.copyWith(
      settlementAccounts: settlementAccounts,
      fundAccounts: fundAccounts,
      liabilityAccounts: liabilityAccounts,
      reimbursementAccounts: reimbursementAccounts,
      expenseTree: expenseTree,
      incomeTree: incomeTree,
    );
  }

  SubmitOutcome _invalidCommand(String message) {
    return SubmitOutcome.failure(
      UiError(
        code: LedgerErrorCode.transactionInvalidCommand.code,
        message: message,
      ),
    );
  }

  BusinessException _invalidCommandException(String message) {
    return BusinessException(
      LedgerErrorCode.transactionInvalidCommand,
      message: message,
    );
  }

  Money? _parsePositiveAmount(String value) {
    final money = Money.tryParse(value);
    return money != null && money.minorUnits > 0 ? money : null;
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

  Patch<String?> _stringPatch(String? value) {
    return value == null ? const Patch<String?>.clear() : Patch.set(value);
  }
}

class TransactionFormState {
  TransactionFormState({
    required this.initialValues,
    required this.mode,
    required this.occurredAt,
    required this.excludeStats,
    required this.excludeBudget,
    required this.submitting,
    required List<Account> settlementAccounts,
    required List<Account> fundAccounts,
    required List<Account> liabilityAccounts,
    required List<Account> reimbursementAccounts,
    required List<CategoryNode> expenseTree,
    required List<CategoryNode> incomeTree,
    this.expenseCategoryId,
    this.expenseRootId,
    this.incomeCategoryId,
    this.incomeRootId,
    this.fromAccountId,
    this.toAccountId,
    this.reimbursementAccountId,
    this.liabilityAccountId,
  }) : settlementAccounts = List.unmodifiable(settlementAccounts),
       fundAccounts = List.unmodifiable(fundAccounts),
       liabilityAccounts = List.unmodifiable(liabilityAccounts),
       reimbursementAccounts = List.unmodifiable(reimbursementAccounts),
       expenseTree = List.unmodifiable(expenseTree),
       incomeTree = List.unmodifiable(incomeTree);

  factory TransactionFormState.initial({
    required TransactionFormMode mode,
    String? fromAccountId,
    String? toAccountId,
    required List<Account> settlementAccounts,
    required List<Account> fundAccounts,
    required List<Account> liabilityAccounts,
    required List<Account> reimbursementAccounts,
    required List<CategoryNode> expenseTree,
    required List<CategoryNode> incomeTree,
  }) {
    return TransactionFormState(
      initialValues: const TransactionFormInitialValues(),
      mode: mode,
      occurredAt: DateTime.now(),
      excludeStats: false,
      excludeBudget: false,
      submitting: false,
      fromAccountId: fromAccountId,
      toAccountId: toAccountId,
      settlementAccounts: settlementAccounts,
      fundAccounts: fundAccounts,
      liabilityAccounts: liabilityAccounts,
      reimbursementAccounts: reimbursementAccounts,
      expenseTree: expenseTree,
      incomeTree: incomeTree,
    );
  }

  factory TransactionFormState.fromEditSnapshot({
    required TransactionFormEditSnapshot snapshot,
    required List<Account> settlementAccounts,
    required List<Account> fundAccounts,
    required List<Account> liabilityAccounts,
    required List<Account> reimbursementAccounts,
    required List<CategoryNode> expenseTree,
    required List<CategoryNode> incomeTree,
  }) {
    return TransactionFormState(
      initialValues: TransactionFormInitialValues.fromSnapshot(snapshot),
      mode: snapshot.mode,
      occurredAt: snapshot.occurredAt,
      expenseCategoryId: snapshot.expenseCategoryId,
      expenseRootId: snapshot.expenseRootId,
      incomeCategoryId: snapshot.incomeCategoryId,
      incomeRootId: snapshot.incomeRootId,
      fromAccountId: snapshot.fromAccountId,
      toAccountId: snapshot.toAccountId,
      reimbursementAccountId: snapshot.reimbursementAccountId,
      liabilityAccountId: snapshot.liabilityAccountId,
      excludeStats: snapshot.excludeStats,
      excludeBudget: snapshot.excludeBudget,
      submitting: false,
      settlementAccounts: settlementAccounts,
      fundAccounts: fundAccounts,
      liabilityAccounts: liabilityAccounts,
      reimbursementAccounts: reimbursementAccounts,
      expenseTree: expenseTree,
      incomeTree: incomeTree,
    );
  }

  final TransactionFormInitialValues initialValues;
  final TransactionFormMode mode;
  final DateTime occurredAt;
  final String? expenseCategoryId;
  final String? expenseRootId;
  final String? incomeCategoryId;
  final String? incomeRootId;
  final String? fromAccountId;
  final String? toAccountId;
  final String? reimbursementAccountId;
  final String? liabilityAccountId;
  final bool excludeStats;
  final bool excludeBudget;
  final bool submitting;
  final List<Account> settlementAccounts;
  final List<Account> fundAccounts;
  final List<Account> liabilityAccounts;
  final List<Account> reimbursementAccounts;
  final List<CategoryNode> expenseTree;
  final List<CategoryNode> incomeTree;

  TransactionFormState copyWith({
    TransactionFormInitialValues? initialValues,
    TransactionFormMode? mode,
    DateTime? occurredAt,
    Object? expenseCategoryId = _sentinel,
    Object? expenseRootId = _sentinel,
    Object? incomeCategoryId = _sentinel,
    Object? incomeRootId = _sentinel,
    Object? fromAccountId = _sentinel,
    Object? toAccountId = _sentinel,
    Object? reimbursementAccountId = _sentinel,
    Object? liabilityAccountId = _sentinel,
    bool? excludeStats,
    bool? excludeBudget,
    bool? submitting,
    List<Account>? settlementAccounts,
    List<Account>? fundAccounts,
    List<Account>? liabilityAccounts,
    List<Account>? reimbursementAccounts,
    List<CategoryNode>? expenseTree,
    List<CategoryNode>? incomeTree,
  }) {
    return TransactionFormState(
      initialValues: initialValues ?? this.initialValues,
      mode: mode ?? this.mode,
      occurredAt: occurredAt ?? this.occurredAt,
      expenseCategoryId:
          expenseCategoryId == _sentinel
              ? this.expenseCategoryId
              : expenseCategoryId as String?,
      expenseRootId:
          expenseRootId == _sentinel
              ? this.expenseRootId
              : expenseRootId as String?,
      incomeCategoryId:
          incomeCategoryId == _sentinel
              ? this.incomeCategoryId
              : incomeCategoryId as String?,
      incomeRootId:
          incomeRootId == _sentinel
              ? this.incomeRootId
              : incomeRootId as String?,
      fromAccountId:
          fromAccountId == _sentinel
              ? this.fromAccountId
              : fromAccountId as String?,
      toAccountId:
          toAccountId == _sentinel ? this.toAccountId : toAccountId as String?,
      reimbursementAccountId:
          reimbursementAccountId == _sentinel
              ? this.reimbursementAccountId
              : reimbursementAccountId as String?,
      liabilityAccountId:
          liabilityAccountId == _sentinel
              ? this.liabilityAccountId
              : liabilityAccountId as String?,
      excludeStats: excludeStats ?? this.excludeStats,
      excludeBudget: excludeBudget ?? this.excludeBudget,
      submitting: submitting ?? this.submitting,
      settlementAccounts: settlementAccounts ?? this.settlementAccounts,
      fundAccounts: fundAccounts ?? this.fundAccounts,
      liabilityAccounts: liabilityAccounts ?? this.liabilityAccounts,
      reimbursementAccounts:
          reimbursementAccounts ?? this.reimbursementAccounts,
      expenseTree: expenseTree ?? this.expenseTree,
      incomeTree: incomeTree ?? this.incomeTree,
    );
  }
}

/// Text captured once from the transaction snapshot for controller creation.
/// This is not the live text state of the form.
class TransactionFormInitialValues {
  const TransactionFormInitialValues({this.amount = '', this.note = ''});

  factory TransactionFormInitialValues.fromSnapshot(
    TransactionFormEditSnapshot snapshot,
  ) {
    return TransactionFormInitialValues(
      amount: snapshot.amountText,
      note: snapshot.noteText,
    );
  }

  final String amount;
  final String note;
}

const Object _sentinel = Object();
