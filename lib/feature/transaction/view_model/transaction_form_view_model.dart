import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../../app/provider.dart';
import '../../../application/ledger/ledger_command_api.dart';
import '../../../core/error/app_exception.dart';
import '../../../core/money/money.dart';
import '../../../core/patch/patch.dart';
import '../../../core/text/text_normalizer.dart';
import '../../../domain/ledger/valobj/ledger_error_code.dart';
import '../../shared/view_model/ui_action_outcome.dart';
import '../presentation/transaction_form_presentation.dart';

part 'transaction_form_view_model.g.dart';

@riverpod
class TransactionFormViewModel extends _$TransactionFormViewModel {
  @override
  TransactionFormState build() {
    return TransactionFormState.initial();
  }

  void initializeNew({
    TransactionFormMode initialMode = TransactionFormMode.expense,
    String? initialFromAccountId,
    String? initialToAccountId,
    DateTime? occurredAt,
  }) {
    if (state.initializedNew) return;
    state = state.copyWith(
      mode: initialMode,
      fromAccountId: initialFromAccountId,
      toAccountId: initialToAccountId,
      occurredAt: occurredAt ?? state.occurredAt,
      initializedNew: true,
    );
    _normalizeModeFlags(initialMode);
  }

  void initializeForEdit({
    required String transactionId,
    required TransactionFormEditSnapshot snapshot,
  }) {
    if (state.initializedEditTransactionId == transactionId) return;
    state = state.copyWith(
      mode: snapshot.mode,
      amountText: snapshot.amountText,
      noteText: snapshot.noteText,
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
      initializedEditTransactionId: transactionId,
    );
  }

  void setMode(TransactionFormMode value) {
    if (state.mode == value) return;
    state = state.copyWith(
      mode: value,
      reimbursementAccountId: null,
      excludeStats:
          value == TransactionFormMode.transfer ||
                  value == TransactionFormMode.borrowing
              ? false
              : state.excludeStats,
      excludeBudget:
          value == TransactionFormMode.expense ? state.excludeBudget : false,
    );
  }

  void setAmountText(String value) {
    if (state.amountText == value) return;
    state = state.copyWith(amountText: value);
  }

  void setNoteText(String value) {
    if (state.noteText == value) return;
    state = state.copyWith(noteText: value);
  }

  void setOccurredAt(DateTime value) {
    state = state.copyWith(occurredAt: value);
  }

  void setExpenseCategory({
    required String? rootId,
    required String? categoryId,
  }) {
    state = state.copyWith(
      expenseRootId: rootId,
      expenseCategoryId: categoryId,
    );
  }

  void setIncomeCategory({
    required String? rootId,
    required String? categoryId,
  }) {
    state = state.copyWith(incomeRootId: rootId, incomeCategoryId: categoryId);
  }

  void setFromAccountId(String? value) {
    state = state.copyWith(fromAccountId: value);
  }

  void setToAccountId(String? value) {
    state = state.copyWith(toAccountId: value);
  }

  void setReimbursementAccountId(String? value) {
    state = state.copyWith(reimbursementAccountId: value);
  }

  void setLiabilityAccountId(String? value) {
    state = state.copyWith(liabilityAccountId: value);
  }

  void setExcludeStats(bool value) {
    state = state.copyWith(excludeStats: value);
  }

  void setExcludeBudget(bool value) {
    state = state.copyWith(excludeBudget: value);
  }

  void clearForNext({DateTime? occurredAt}) {
    state = state.copyWith(
      amountText: '',
      noteText: '',
      reimbursementAccountId: null,
      excludeStats: false,
      excludeBudget: false,
      occurredAt: occurredAt ?? DateTime.now(),
    );
  }

  Future<SubmitOutcome> submit(TransactionFormSubmitOptions options) async {
    final amount = _parsePositiveAmount(state.amountText);
    if (amount == null) {
      return _invalidCommand('请输入有效金额');
    }

    state = state.copyWith(submitting: true);
    try {
      final editTransactionId = options.editTransactionId;
      if (editTransactionId == null) {
        await _submitCreate(amount, options);
      } else {
        await _submitEdit(editTransactionId, amount, options);
      }
      return const SubmitOutcome.success();
    } on AppException catch (exception) {
      return SubmitOutcome.failure(UiError.fromException(exception));
    } on Exception {
      return const SubmitOutcome.failure(UiError.unknown());
    } finally {
      state = state.copyWith(submitting: false);
    }
  }

  Future<UiActionOutcome<void>> deleteTransaction(String transactionId) async {
    state = state.copyWith(submitting: true);
    try {
      await ref
          .read(transactionEditAppServiceProvider)
          .deleteTransaction(
            DeleteTransactionCommand(transactionId: transactionId),
          );
      return const UiActionOutcome.success(null);
    } on AppException catch (exception) {
      return UiActionOutcome.failure(UiError.fromException(exception));
    } on Exception {
      return const UiActionOutcome.failure(UiError.unknown());
    } finally {
      state = state.copyWith(submitting: false);
    }
  }

  Future<void> _submitCreate(
    Money amount,
    TransactionFormSubmitOptions options,
  ) async {
    final postingService = ref.read(transactionPostingAppServiceProvider);
    final note = trimToNull(state.noteText);

    switch (state.mode) {
      case TransactionFormMode.expense:
        final expenseCategoryId = state.expenseCategoryId;
        if (expenseCategoryId == null) {
          throw _invalidCommandException('请选择支出分类');
        }
        final paidFromAccountId = _effectiveId(
          state.fromAccountId,
          options.settlementAccounts,
        );
        if (paidFromAccountId == null) {
          throw _invalidCommandException('请选择支出账户');
        }
        final reimbursementAccountId = _selectedId(
          state.reimbursementAccountId,
          options.reimbursementAccounts,
        );
        if (reimbursementAccountId == null) {
          await postingService.createExpense(
            CreateExpenseCommand(
              amount: amount,
              paidFromAccountId: paidFromAccountId,
              expenseAccountId: expenseCategoryId,
              occurredAt: state.occurredAt,
              note: note,
              isExcludedFromStats: state.excludeStats,
              isExcludedFromBudget: state.excludeBudget,
            ),
          );
        } else {
          await postingService.createReimbursementAdvance(
            CreateReimbursementAdvanceCommand(
              amount: amount,
              receivableAccountId: reimbursementAccountId,
              paidFromAccountId: paidFromAccountId,
              expenseCategoryId: expenseCategoryId,
              occurredAt: state.occurredAt,
              note: note,
              isExcludedFromStats: state.excludeStats,
              isExcludedFromBudget: state.excludeBudget,
            ),
          );
        }
      case TransactionFormMode.income:
        final incomeCategoryId = state.incomeCategoryId;
        if (incomeCategoryId == null) throw _invalidCommandException('请选择收入分类');
        final receiveAccountId = _effectiveId(
          state.toAccountId,
          options.settlementAccounts,
        );
        if (receiveAccountId == null) throw _invalidCommandException('请选择收入账户');
        await postingService.createIncome(
          CreateIncomeCommand(
            amount: amount,
            receiveAccountId: receiveAccountId,
            incomeAccountId: incomeCategoryId,
            occurredAt: state.occurredAt,
            note: note,
            isExcludedFromStats: state.excludeStats,
          ),
        );
      case TransactionFormMode.transfer:
        final fromAccountId = _effectiveId(
          state.fromAccountId,
          options.settlementAccounts,
        );
        final toAccountId = _effectiveId(
          state.toAccountId,
          options.settlementAccounts,
        );
        if (fromAccountId == null || toAccountId == null) {
          throw _invalidCommandException('请选择转出和转入账户');
        }
        await postingService.createTransfer(
          CreateTransferCommand(
            amount: amount,
            fromAccountId: fromAccountId,
            toAccountId: toAccountId,
            occurredAt: state.occurredAt,
            note: note,
          ),
        );
      case TransactionFormMode.borrowing:
        final liabilityAccountId = _effectiveId(
          state.liabilityAccountId,
          options.liabilityAccounts,
        );
        if (liabilityAccountId == null) {
          throw _invalidCommandException('请选择借出账户');
        }
        final receiveAccountId = _effectiveId(
          state.toAccountId,
          options.fundAccounts,
        );
        if (receiveAccountId == null) throw _invalidCommandException('请选择借入账户');
        await postingService.createBorrowing(
          CreateBorrowingCommand(
            amount: amount,
            liabilityAccountId: liabilityAccountId,
            receiveAccountId: receiveAccountId,
            occurredAt: state.occurredAt,
            note: note,
          ),
        );
    }
  }

  Future<void> _submitEdit(
    String transactionId,
    Money amount,
    TransactionFormSubmitOptions options,
  ) async {
    final editService = ref.read(transactionEditAppServiceProvider);
    final note = _stringPatch(trimToNull(state.noteText));

    switch (state.mode) {
      case TransactionFormMode.expense:
        final expenseCategoryId = state.expenseCategoryId;
        if (expenseCategoryId == null) {
          throw _invalidCommandException('请选择支出分类');
        }
        final paidFromAccountId = _effectiveId(
          state.fromAccountId,
          options.settlementAccounts,
        );
        if (paidFromAccountId == null) {
          throw _invalidCommandException('请选择支出账户');
        }
        final reimbursementAccountId = _selectedId(
          state.reimbursementAccountId,
          options.reimbursementAccounts,
        );
        if (reimbursementAccountId == null) {
          await editService.editExpense(
            EditExpenseCommand(
              transactionId: transactionId,
              amount: amount,
              paidFromAccountId: paidFromAccountId,
              expenseAccountId: expenseCategoryId,
              occurredAt: state.occurredAt,
              note: note,
              isExcludedFromStats: state.excludeStats,
              isExcludedFromBudget: state.excludeBudget,
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
              occurredAt: state.occurredAt,
              note: note,
              isExcludedFromStats: state.excludeStats,
              isExcludedFromBudget: state.excludeBudget,
            ),
          );
        }
      case TransactionFormMode.income:
        final incomeCategoryId = state.incomeCategoryId;
        if (incomeCategoryId == null) throw _invalidCommandException('请选择收入分类');
        final receiveAccountId = _effectiveId(
          state.toAccountId,
          options.settlementAccounts,
        );
        if (receiveAccountId == null) throw _invalidCommandException('请选择收入账户');
        await editService.editIncome(
          EditIncomeCommand(
            transactionId: transactionId,
            amount: amount,
            receiveAccountId: receiveAccountId,
            incomeAccountId: incomeCategoryId,
            occurredAt: state.occurredAt,
            note: note,
            isExcludedFromStats: state.excludeStats,
          ),
        );
      case TransactionFormMode.transfer:
        final fromAccountId = _effectiveId(
          state.fromAccountId,
          options.settlementAccounts,
        );
        final toAccountId = _effectiveId(
          state.toAccountId,
          options.settlementAccounts,
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
            occurredAt: state.occurredAt,
            note: note,
          ),
        );
      case TransactionFormMode.borrowing:
        final liabilityAccountId = _effectiveId(
          state.liabilityAccountId,
          options.liabilityAccounts,
        );
        final receiveAccountId = _effectiveId(
          state.toAccountId,
          options.fundAccounts,
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
            occurredAt: state.occurredAt,
            note: note,
          ),
        );
    }
  }

  void _normalizeModeFlags(TransactionFormMode mode) {
    if (mode == TransactionFormMode.transfer ||
        mode == TransactionFormMode.borrowing) {
      state = state.copyWith(excludeStats: false, excludeBudget: false);
      return;
    }
    if (mode != TransactionFormMode.expense) {
      state = state.copyWith(excludeBudget: false);
    }
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

class TransactionFormSubmitOptions {
  const TransactionFormSubmitOptions({
    required this.settlementAccounts,
    required this.fundAccounts,
    required this.liabilityAccounts,
    required this.reimbursementAccounts,
    this.editTransactionId,
  });

  final String? editTransactionId;
  final List<Account> settlementAccounts;
  final List<Account> fundAccounts;
  final List<Account> liabilityAccounts;
  final List<Account> reimbursementAccounts;
}

class TransactionFormState {
  const TransactionFormState({
    required this.mode,
    required this.amountText,
    required this.noteText,
    required this.occurredAt,
    required this.excludeStats,
    required this.excludeBudget,
    required this.submitting,
    required this.initializedNew,
    this.initializedEditTransactionId,
    this.expenseCategoryId,
    this.expenseRootId,
    this.incomeCategoryId,
    this.incomeRootId,
    this.fromAccountId,
    this.toAccountId,
    this.reimbursementAccountId,
    this.liabilityAccountId,
  });

  factory TransactionFormState.initial() {
    return TransactionFormState(
      mode: TransactionFormMode.expense,
      amountText: '',
      noteText: '',
      occurredAt: DateTime.now(),
      excludeStats: false,
      excludeBudget: false,
      submitting: false,
      initializedNew: false,
    );
  }

  final TransactionFormMode mode;
  final String amountText;
  final String noteText;
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
  final bool initializedNew;
  final String? initializedEditTransactionId;

  TransactionFormState copyWith({
    TransactionFormMode? mode,
    String? amountText,
    String? noteText,
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
    bool? initializedNew,
    Object? initializedEditTransactionId = _sentinel,
  }) {
    return TransactionFormState(
      mode: mode ?? this.mode,
      amountText: amountText ?? this.amountText,
      noteText: noteText ?? this.noteText,
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
      initializedNew: initializedNew ?? this.initializedNew,
      initializedEditTransactionId:
          initializedEditTransactionId == _sentinel
              ? this.initializedEditTransactionId
              : initializedEditTransactionId as String?,
    );
  }
}

const Object _sentinel = Object();
