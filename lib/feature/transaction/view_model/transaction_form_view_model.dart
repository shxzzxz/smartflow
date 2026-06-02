import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../../app/provider.dart';
import '../../../application/ledger/ledger_command_api.dart';
import '../../../core/error/app_exception.dart';
import '../../../core/money/money.dart';
import '../../../core/text/text_normalizer.dart';
import '../../../domain/ledger/valobj/ledger_error_code.dart';
import '../../shared/view_model/ui_action_outcome.dart';

part 'transaction_form_view_model.g.dart';

@riverpod
class TransactionFormViewModel extends _$TransactionFormViewModel {
  @override
  TransactionFormState build() {
    return TransactionFormState.initial();
  }

  void initialize({String? initialFromAccountId, DateTime? occurredAt}) {
    state = state.copyWith(
      fromAccountId: initialFromAccountId,
      occurredAt: occurredAt ?? state.occurredAt,
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

  void setFromAccountId(String? value) {
    state = state.copyWith(fromAccountId: value);
  }

  void setReimbursementAccountId(String? value) {
    state = state.copyWith(reimbursementAccountId: value);
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

  Future<SubmitOutcome> submitDailyExpense({
    required List<Account> settlementAccounts,
  }) async {
    final amount = _parsePositiveAmount(state.amountText);
    if (amount == null) {
      return _invalidCommand('请输入有效金额');
    }
    final expenseCategoryId = state.expenseCategoryId;
    if (expenseCategoryId == null) {
      return _invalidCommand('请选择支出分类');
    }
    final paidFromAccountId = _effectiveId(
      state.fromAccountId,
      settlementAccounts,
    );
    if (paidFromAccountId == null) {
      return _invalidCommand('请选择支出账户');
    }

    state = state.copyWith(submitting: true);
    try {
      await ref
          .read(transactionPostingAppServiceProvider)
          .createExpense(
            CreateExpenseCommand(
              amount: amount,
              paidFromAccountId: paidFromAccountId,
              expenseAccountId: expenseCategoryId,
              occurredAt: state.occurredAt,
              note: trimToNull(state.noteText),
              isExcludedFromStats: state.excludeStats,
              isExcludedFromBudget: state.excludeBudget,
            ),
          );
      return const SubmitOutcome.success();
    } on BusinessException catch (exception) {
      return SubmitOutcome.failure(UiError.fromException(exception));
    } on CallException catch (exception) {
      return SubmitOutcome.failure(UiError.fromException(exception));
    } finally {
      state = state.copyWith(submitting: false);
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

  Money? _parsePositiveAmount(String value) {
    try {
      final money = Money.parse(value);
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
}

class TransactionFormState {
  const TransactionFormState({
    required this.amountText,
    required this.noteText,
    required this.occurredAt,
    required this.excludeStats,
    required this.excludeBudget,
    required this.submitting,
    this.expenseCategoryId,
    this.expenseRootId,
    this.fromAccountId,
    this.reimbursementAccountId,
  });

  factory TransactionFormState.initial() {
    return TransactionFormState(
      amountText: '',
      noteText: '',
      occurredAt: DateTime.now(),
      excludeStats: false,
      excludeBudget: false,
      submitting: false,
    );
  }

  final String amountText;
  final String noteText;
  final DateTime occurredAt;
  final String? expenseCategoryId;
  final String? expenseRootId;
  final String? fromAccountId;
  final String? reimbursementAccountId;
  final bool excludeStats;
  final bool excludeBudget;
  final bool submitting;

  TransactionFormState copyWith({
    String? amountText,
    String? noteText,
    DateTime? occurredAt,
    Object? expenseCategoryId = _sentinel,
    Object? expenseRootId = _sentinel,
    Object? fromAccountId = _sentinel,
    Object? reimbursementAccountId = _sentinel,
    bool? excludeStats,
    bool? excludeBudget,
    bool? submitting,
  }) {
    return TransactionFormState(
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
      fromAccountId:
          fromAccountId == _sentinel
              ? this.fromAccountId
              : fromAccountId as String?,
      reimbursementAccountId:
          reimbursementAccountId == _sentinel
              ? this.reimbursementAccountId
              : reimbursementAccountId as String?,
      excludeStats: excludeStats ?? this.excludeStats,
      excludeBudget: excludeBudget ?? this.excludeBudget,
      submitting: submitting ?? this.submitting,
    );
  }
}

const Object _sentinel = Object();
