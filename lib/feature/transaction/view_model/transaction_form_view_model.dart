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
import '../../shared/provider/tag_providers.dart';
import '../../shared/view_model/action_guard.dart';
import '../../shared/view_model/ui_action_outcome.dart';
import '../presentation/transaction_form_presentation.dart';

part 'transaction_form_view_model.g.dart';

final _logger = Logger('feature.transaction.form');

@riverpod
class TransactionFormViewModel extends _$TransactionFormViewModel {
  TransactionFormState? _initializedState;
  String? _editTransactionId;
  int _defaultAccountRequestRevision = 0;

  @override
  AsyncValue<TransactionFormState?> build({
    String? editTransactionId,
    TransactionFormMode initialMode = TransactionFormMode.expense,
    String? initialFromAccountId,
    String? initialToAccountId,
    String? initialLiabilityAccountId,
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
    final ordinaryReceivableAccountsAsync = ref.watch(
      accountsForSelectionPurposeProvider(
        AccountSelectionPurpose.ordinaryReceivable,
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
    final tagsAsync = ref.watch(tagListProvider);
    final editTagIdsAsync =
        editTransactionId == null
            ? null
            : ref.watch(transactionTagIdsProvider(editTransactionId));

    final initializedState = _initializedState;
    if (initializedState != null) {
      final next = _refreshReferenceData(
        initializedState,
        settlementAccounts: settlementAccountsAsync.value,
        fundAccounts: fundAccountsAsync.value,
        liabilityAccounts: liabilityAccountsAsync.value,
        reimbursementAccounts: reimbursementAccountsAsync.value,
        ordinaryReceivableAccounts: ordinaryReceivableAccountsAsync.value,
        expenseTree: expenseTreeAsync.value,
        incomeTree: incomeTreeAsync.value,
        tags: tagsAsync.value,
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
          liabilityAccountId: initialLiabilityAccountId,
          settlementAccounts:
              settlementAccountsAsync.value ?? const <Account>[],
          fundAccounts: fundAccountsAsync.value ?? const <Account>[],
          liabilityAccounts: liabilityAccountsAsync.value ?? const <Account>[],
          reimbursementAccounts:
              reimbursementAccountsAsync.value ?? const <Account>[],
          ordinaryReceivableAccounts:
              ordinaryReceivableAccountsAsync.value ?? const <Account>[],
          expenseTree: expenseTreeAsync.value ?? const <CategoryNode>[],
          incomeTree: incomeTreeAsync.value ?? const <CategoryNode>[],
          tags: tagsAsync.value ?? const <TagView>[],
        ),
      );
    }

    final queries = <AsyncValue<dynamic>>[
      settlementAccountsAsync,
      fundAccountsAsync,
      liabilityAccountsAsync,
      reimbursementAccountsAsync,
      ordinaryReceivableAccountsAsync,
      expenseTreeAsync,
      incomeTreeAsync,
      tagsAsync,
      if (editDetailAsync != null) editDetailAsync,
      if (accountsByIdAsync != null) accountsByIdAsync,
      if (editTagIdsAsync != null) editTagIdsAsync,
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
    final ordinaryReceivableAccounts =
        ordinaryReceivableAccountsAsync.requireValue;
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
        ordinaryReceivableAccounts: ordinaryReceivableAccounts,
        expenseTree: expenseTree,
        incomeTree: incomeTree,
        tags: tagsAsync.value ?? const <TagView>[],
        initialTagIds: editTagIdsAsync!.requireValue,
      ),
    );
  }

  void setMode(TransactionFormMode value) {
    _update((current) {
      if (current.mode == value) return current;
      return current.copyWith(
        mode: value,
        reimbursementAccountId: null,
        ordinaryReceivableAccountId: null,
        excludeStats:
            value == TransactionFormMode.transfer ||
                    value == TransactionFormMode.borrowing ||
                    value == TransactionFormMode.lending
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

  Future<void> setExpenseCategory({
    required String? rootId,
    required String? categoryId,
  }) async {
    final requestRevision = ++_defaultAccountRequestRevision;
    _update(
      (current) => current.copyWith(
        expenseRootId: rootId,
        expenseCategoryId: categoryId,
      ),
    );
    await _applyLastUsedSettlementAccount(
      categoryId: categoryId,
      requestRevision: requestRevision,
      selectedCategoryId: (current) => current.expenseCategoryId,
      selectAccount:
          (current, accountId) => current.copyWith(fromAccountId: accountId),
    );
  }

  Future<void> setIncomeCategory({
    required String? rootId,
    required String? categoryId,
  }) async {
    final requestRevision = ++_defaultAccountRequestRevision;
    _update(
      (current) =>
          current.copyWith(incomeRootId: rootId, incomeCategoryId: categoryId),
    );
    await _applyLastUsedSettlementAccount(
      categoryId: categoryId,
      requestRevision: requestRevision,
      selectedCategoryId: (current) => current.incomeCategoryId,
      selectAccount:
          (current, accountId) => current.copyWith(toAccountId: accountId),
    );
  }

  Future<void> _applyLastUsedSettlementAccount({
    required String? categoryId,
    required int requestRevision,
    required String? Function(TransactionFormState) selectedCategoryId,
    required TransactionFormState Function(TransactionFormState, String)
    selectAccount,
  }) async {
    if (_editTransactionId != null || categoryId == null) return;
    try {
      final accountId = await ref
          .read(transactionQueryServiceProvider)
          .findLastUsedSettlementAccountId(categoryId);
      final current = state.asData?.value;
      if (accountId == null ||
          current == null ||
          requestRevision != _defaultAccountRequestRevision ||
          selectedCategoryId(current) != categoryId ||
          !current.settlementAccounts.any(
            (account) => account.id == accountId,
          )) {
        return;
      }
      _update((current) => selectAccount(current, accountId));
    } on Exception catch (error, stackTrace) {
      _logger.warning(
        'Failed to load the last settlement account for category',
        error,
        stackTrace,
      );
    }
  }

  void setFromAccountId(String? value) {
    _defaultAccountRequestRevision += 1;
    _update((current) => current.copyWith(fromAccountId: value));
  }

  void setToAccountId(String? value) {
    _defaultAccountRequestRevision += 1;
    _update((current) => current.copyWith(toAccountId: value));
  }

  void setReimbursementAccountId(String? value) {
    _update((current) => current.copyWith(reimbursementAccountId: value));
  }

  void setOrdinaryReceivableAccountId(String? value) {
    _update((current) => current.copyWith(ordinaryReceivableAccountId: value));
  }

  void setLiabilityAccountId(String? value) {
    _update((current) => current.copyWith(liabilityAccountId: value));
  }

  void setExcludeStats(bool value) {
    _update((current) => current.copyWith(excludeStats: value));
  }

  void setTagIds(Set<String> value) {
    _update((current) => current.copyWith(selectedTagIds: value));
  }

  void setExcludeBudget(bool value) {
    _update((current) => current.copyWith(excludeBudget: value));
  }

  void clearForNext({DateTime? occurredAt}) {
    _update(
      (current) => current.copyWith(
        reimbursementAccountId: null,
        ordinaryReceivableAccountId: null,
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
      return await guardSubmit(_logger, 'Transaction form submit', () async {
        final editTransactionId = _editTransactionId;
        if (editTransactionId == null) {
          await _submitCreate(current, amount, noteText);
        } else {
          await _submitEdit(current, editTransactionId, amount, noteText);
        }
      });
    } finally {
      _update((current) => current.copyWith(submitting: false));
    }
  }

  Future<UiActionOutcome<void>> deleteTransaction(String transactionId) async {
    _update((current) => current.copyWith(submitting: true));
    try {
      return await guardUiAction(_logger, 'Transaction delete', () async {
        await ref
            .read(transactionEditAppServiceProvider)
            .deleteTransaction(
              DeleteTransactionCommand(transactionId: transactionId),
            );
      });
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
              tagIds: formState.selectedTagIds,
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
              tagIds: formState.selectedTagIds,
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
            tagIds: formState.selectedTagIds,
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
            tagIds: formState.selectedTagIds,
          ),
        );
      case TransactionFormMode.borrowing:
        final liabilityAccountId = _effectiveId(
          formState.liabilityAccountId,
          formState.liabilityAccounts,
        );
        if (liabilityAccountId == null) {
          throw _invalidCommandException('请选择负债账户');
        }
        final receiveAccountId = _effectiveId(
          formState.toAccountId,
          formState.fundAccounts,
        );
        if (receiveAccountId == null) throw _invalidCommandException('请选择收款账户');
        await postingService.createBorrowing(
          CreateBorrowingCommand(
            amount: amount,
            liabilityAccountId: liabilityAccountId,
            receiveAccountId: receiveAccountId,
            occurredAt: formState.occurredAt,
            note: note,
            tagIds: formState.selectedTagIds,
          ),
        );
      case TransactionFormMode.lending:
        final paidFromAccountId = _effectiveId(
          formState.fromAccountId,
          formState.fundAccounts,
        );
        final receivableAccountId = _effectiveId(
          formState.ordinaryReceivableAccountId,
          formState.ordinaryReceivableAccounts,
        );
        if (paidFromAccountId == null || receivableAccountId == null) {
          throw _invalidCommandException('请选择付款账户和应收账户');
        }
        await (postingService as ReceivableTransactionPostingAppService)
            .createLending(
              CreateLendingCommand(
                amount: amount,
                receivableAccountId: receivableAccountId,
                paidFromAccountId: paidFromAccountId,
                occurredAt: formState.occurredAt,
                note: note,
                tagIds: formState.selectedTagIds,
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
              tagIds: formState.selectedTagIds,
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
              tagIds: formState.selectedTagIds,
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
            tagIds: formState.selectedTagIds,
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
            tagIds: formState.selectedTagIds,
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
          throw _invalidCommandException('请选择负债账户和收款账户');
        }
        await editService.editBorrowing(
          EditBorrowingCommand(
            transactionId: transactionId,
            amount: amount,
            liabilityAccountId: liabilityAccountId,
            receiveAccountId: receiveAccountId,
            occurredAt: formState.occurredAt,
            note: note,
            tagIds: formState.selectedTagIds,
          ),
        );
      case TransactionFormMode.lending:
        final paidFromAccountId = _effectiveId(
          formState.fromAccountId,
          formState.fundAccounts,
        );
        final receivableAccountId = _effectiveId(
          formState.ordinaryReceivableAccountId,
          formState.ordinaryReceivableAccounts,
        );
        if (paidFromAccountId == null || receivableAccountId == null) {
          throw _invalidCommandException('请选择付款账户和应收账户');
        }
        await (editService as ReceivableTransactionEditAppService).editLending(
          EditLendingCommand(
            transactionId: transactionId,
            amount: amount,
            receivableAccountId: receivableAccountId,
            paidFromAccountId: paidFromAccountId,
            occurredAt: formState.occurredAt,
            note: note,
            tagIds: formState.selectedTagIds,
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
    required List<Account>? ordinaryReceivableAccounts,
    required List<CategoryNode>? expenseTree,
    required List<CategoryNode>? incomeTree,
    required List<TagView>? tags,
  }) {
    return current.copyWith(
      settlementAccounts: settlementAccounts,
      fundAccounts: fundAccounts,
      liabilityAccounts: liabilityAccounts,
      reimbursementAccounts: reimbursementAccounts,
      ordinaryReceivableAccounts: ordinaryReceivableAccounts,
      expenseTree: expenseTree,
      incomeTree: incomeTree,
      tags: tags,
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
    required List<Account> ordinaryReceivableAccounts,
    required List<CategoryNode> expenseTree,
    required List<CategoryNode> incomeTree,
    required List<TagView> tags,
    this.selectedTagIds = const {},
    this.expenseCategoryId,
    this.expenseRootId,
    this.incomeCategoryId,
    this.incomeRootId,
    this.fromAccountId,
    this.toAccountId,
    this.reimbursementAccountId,
    this.ordinaryReceivableAccountId,
    this.liabilityAccountId,
  }) : settlementAccounts = List.unmodifiable(settlementAccounts),
       fundAccounts = List.unmodifiable(fundAccounts),
       liabilityAccounts = List.unmodifiable(liabilityAccounts),
       reimbursementAccounts = List.unmodifiable(reimbursementAccounts),
       ordinaryReceivableAccounts = List.unmodifiable(
         ordinaryReceivableAccounts,
       ),
       expenseTree = List.unmodifiable(expenseTree),
       incomeTree = List.unmodifiable(incomeTree),
       tags = List.unmodifiable(tags);

  factory TransactionFormState.initial({
    required TransactionFormMode mode,
    String? fromAccountId,
    String? toAccountId,
    String? liabilityAccountId,
    required List<Account> settlementAccounts,
    required List<Account> fundAccounts,
    required List<Account> liabilityAccounts,
    required List<Account> reimbursementAccounts,
    required List<Account> ordinaryReceivableAccounts,
    required List<CategoryNode> expenseTree,
    required List<CategoryNode> incomeTree,
    required List<TagView> tags,
  }) {
    return TransactionFormState(
      initialValues: const TransactionFormInitialValues(),
      mode: mode,
      occurredAt: DateTime.now(),
      excludeStats: false,
      excludeBudget: false,
      submitting: false,
      fromAccountId: fromAccountId,
      toAccountId:
          mode == TransactionFormMode.lending ||
                  mode == TransactionFormMode.borrowing
              ? null
              : toAccountId,
      ordinaryReceivableAccountId:
          mode == TransactionFormMode.lending ? toAccountId : null,
      liabilityAccountId:
          mode == TransactionFormMode.borrowing ? liabilityAccountId : null,
      settlementAccounts: settlementAccounts,
      fundAccounts: fundAccounts,
      liabilityAccounts: liabilityAccounts,
      reimbursementAccounts: reimbursementAccounts,
      ordinaryReceivableAccounts: ordinaryReceivableAccounts,
      expenseTree: expenseTree,
      incomeTree: incomeTree,
      tags: tags,
    );
  }

  factory TransactionFormState.fromEditSnapshot({
    required TransactionFormEditSnapshot snapshot,
    required List<Account> settlementAccounts,
    required List<Account> fundAccounts,
    required List<Account> liabilityAccounts,
    required List<Account> reimbursementAccounts,
    required List<Account> ordinaryReceivableAccounts,
    required List<CategoryNode> expenseTree,
    required List<CategoryNode> incomeTree,
    required List<TagView> tags,
    required Set<String> initialTagIds,
  }) {
    return TransactionFormState(
      initialValues: TransactionFormInitialValues.fromSnapshot(snapshot),
      mode: snapshot.mode,
      occurredAt: snapshot.occurredAt,
      selectedTagIds: initialTagIds,
      expenseCategoryId: snapshot.expenseCategoryId,
      expenseRootId: snapshot.expenseRootId,
      incomeCategoryId: snapshot.incomeCategoryId,
      incomeRootId: snapshot.incomeRootId,
      fromAccountId: snapshot.fromAccountId,
      toAccountId: snapshot.toAccountId,
      reimbursementAccountId: snapshot.reimbursementAccountId,
      ordinaryReceivableAccountId: snapshot.ordinaryReceivableAccountId,
      liabilityAccountId: snapshot.liabilityAccountId,
      excludeStats: snapshot.excludeStats,
      excludeBudget: snapshot.excludeBudget,
      submitting: false,
      settlementAccounts: settlementAccounts,
      fundAccounts: fundAccounts,
      liabilityAccounts: liabilityAccounts,
      reimbursementAccounts: reimbursementAccounts,
      ordinaryReceivableAccounts: ordinaryReceivableAccounts,
      expenseTree: expenseTree,
      incomeTree: incomeTree,
      tags: tags,
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
  final String? ordinaryReceivableAccountId;
  final String? liabilityAccountId;
  final bool excludeStats;
  final bool excludeBudget;
  final bool submitting;
  final Set<String> selectedTagIds;
  final List<Account> settlementAccounts;
  final List<Account> fundAccounts;
  final List<Account> liabilityAccounts;
  final List<Account> reimbursementAccounts;
  final List<Account> ordinaryReceivableAccounts;
  final List<CategoryNode> expenseTree;
  final List<CategoryNode> incomeTree;
  final List<TagView> tags;

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
    Object? ordinaryReceivableAccountId = _sentinel,
    Object? liabilityAccountId = _sentinel,
    bool? excludeStats,
    bool? excludeBudget,
    bool? submitting,
    List<Account>? settlementAccounts,
    List<Account>? fundAccounts,
    List<Account>? liabilityAccounts,
    List<Account>? reimbursementAccounts,
    List<Account>? ordinaryReceivableAccounts,
    List<CategoryNode>? expenseTree,
    List<CategoryNode>? incomeTree,
    List<TagView>? tags,
    Set<String>? selectedTagIds,
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
      ordinaryReceivableAccountId:
          ordinaryReceivableAccountId == _sentinel
              ? this.ordinaryReceivableAccountId
              : ordinaryReceivableAccountId as String?,
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
      ordinaryReceivableAccounts:
          ordinaryReceivableAccounts ?? this.ordinaryReceivableAccounts,
      expenseTree: expenseTree ?? this.expenseTree,
      incomeTree: incomeTree ?? this.incomeTree,
      tags: tags ?? this.tags,
      selectedTagIds: selectedTagIds ?? this.selectedTagIds,
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
