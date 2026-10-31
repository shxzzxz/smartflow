import 'package:logging/logging.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../../app/provider.dart';
import '../../../application/credit/credit_command_api.dart';
import '../../../application/ledger/ledger_command_api.dart';
import '../../../application/ledger/ledger_query_api.dart';
import '../../../application/orchestration/orchestration_command_api.dart';
import '../../../core/error/app_exception.dart';
import '../../../core/money/money.dart';
import '../../../core/patch/patch.dart';
import '../../../core/text/text_normalizer.dart';
import '../../../domain/credit/valobj/installment_contract_terms.dart';
import '../../../domain/ledger/valobj/ledger_error_code.dart';
import '../../../shared/account_profile/account_profile_kind.dart';
import '../../shared/provider/counterparty_providers.dart';
import '../../shared/provider/ledger_query_providers.dart';
import '../../shared/provider/tag_providers.dart';
import '../../shared/view_model/action_guard.dart';
import '../../shared/view_model/ui_action_outcome.dart';
import '../presentation/transaction_form_presentation.dart';
import 'transaction_account_options.dart';

part 'transaction_form_view_model.g.dart';

final _logger = Logger('feature.transaction.form');

@riverpod
Future<AdvanceCase?> advanceCaseForForm(Ref ref, String advanceCaseId) {
  return ref.watch(advanceCaseQueryServiceProvider).findById(advanceCaseId);
}

enum TransactionEntryMode { normal, allocated }

class ConsumptionInstallmentConfiguration {
  const ConsumptionInstallmentConfiguration({
    required this.borrowingDate,
    required this.stageTerms,
  });

  final DateTime borrowingDate;
  final InstallmentContractTerms stageTerms;
}

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
    final accountOptionsAsync = ref.watch(transactionAccountOptionsProvider);
    final expenseTreeAsync = ref.watch(
      categoryTreeProvider(AccountType.expense),
    );
    final incomeTreeAsync = ref.watch(categoryTreeProvider(AccountType.income));
    final editDetailAsync = editTransactionId == null
        ? null
        : ref.watch(transactionDetailProvider(editTransactionId));
    final accountsByIdAsync = editTransactionId == null
        ? null
        : ref.watch(accountsByIdProvider);
    final tagsAsync = ref.watch(tagListProvider);
    final counterpartiesAsync = ref.watch(counterpartyListProvider);
    final editTagIdsAsync = editTransactionId == null
        ? null
        : ref.watch(transactionTagIdsProvider(editTransactionId));

    final initializedState = _initializedState;
    if (initializedState != null) {
      final next = _refreshReferenceData(
        initializedState,
        accountOptions: accountOptionsAsync.value,
        expenseTree: expenseTreeAsync.value,
        incomeTree: incomeTreeAsync.value,
        tags: tagsAsync.value,
        counterparties: counterpartiesAsync.value,
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
          accountOptions:
              accountOptionsAsync.value ?? TransactionAccountOptions.empty(),
          expenseTree: expenseTreeAsync.value ?? const <CategoryNode>[],
          incomeTree: incomeTreeAsync.value ?? const <CategoryNode>[],
          tags: tagsAsync.value ?? const <TagView>[],
          counterparties:
              counterpartiesAsync.value ?? const <CounterpartyView>[],
        ),
      );
    }

    final queries = <AsyncValue<dynamic>>[
      accountOptionsAsync,
      expenseTreeAsync,
      incomeTreeAsync,
      tagsAsync,
      counterpartiesAsync,
      ?editDetailAsync,
      ?accountsByIdAsync,
      ?editTagIdsAsync,
    ];
    for (final query in queries) {
      if (query case AsyncError(:final error, :final stackTrace)) {
        return AsyncValue.error(error, stackTrace);
      }
    }
    if (queries.any((query) => !query.hasValue)) {
      return const AsyncValue.loading();
    }

    final accountOptions = accountOptionsAsync.requireValue;
    final expenseTree = expenseTreeAsync.requireValue;
    final incomeTree = incomeTreeAsync.requireValue;

    final detail = editDetailAsync!.requireValue;
    if (detail == null) return const AsyncValue.data(null);
    if (detail.ownership?.ownerType == installmentOwnerType) {
      return const AsyncValue.data(null);
    }
    if (!supportsTransactionFormEdit(detail.businessPurpose)) {
      return const AsyncValue.data(null);
    }
    final ownership = detail.ownership;
    final advanceCaseAsync =
        ownership?.ownerType == orchestrationAdvanceOwnerType
        ? ref.watch(advanceCaseForFormProvider(ownership!.ownerId))
        : null;
    if (advanceCaseAsync case AsyncError(:final error, :final stackTrace)) {
      return AsyncValue.error(error, stackTrace);
    }
    if (advanceCaseAsync != null && !advanceCaseAsync.hasValue) {
      return const AsyncValue.loading();
    }
    final advanceCase = advanceCaseAsync?.requireValue;
    final snapshot = transactionFormEditSnapshot(
      detail: detail,
      expenseTree: expenseTree,
      incomeTree: incomeTree,
      accountsById: accountsByIdAsync!.requireValue,
      advanceCase: advanceCase,
    );
    return AsyncValue.data(
      _initializedState ??= TransactionFormState.fromEditSnapshot(
        snapshot: snapshot,
        accountOptions: accountOptions,
        expenseTree: expenseTree,
        incomeTree: incomeTree,
        tags: tagsAsync.value ?? const <TagView>[],
        counterparties: counterpartiesAsync.value ?? const <CounterpartyView>[],
        initialTagIds: editTagIdsAsync!.requireValue,
      ),
    );
  }

  void setMode(TransactionFormMode value) {
    _update((current) {
      if (current.mode == value) return current;
      return current.copyWith(
        mode: value,
        relationScene: value == TransactionFormMode.borrowing
            ? TransactionRelationScene.borrowing
            : value == TransactionFormMode.lending
            ? TransactionRelationScene.lending
            : current.relationScene,
        entryMode: TransactionEntryMode.normal,
        categoryAllocations: const [],
        settlementAllocations: const [],
        advanceReceivableAccountId: null,
        advanceScenario: AdvanceScenario.reimbursement,
        expenseScene: TransactionExpenseScene.ordinary,
        ordinaryReceivableAccountId: null,
        excludeStats:
            value == TransactionFormMode.transfer ||
                value == TransactionFormMode.borrowing ||
                value == TransactionFormMode.lending
            ? false
            : current.excludeStats,
        excludeBudget: value == TransactionFormMode.expense
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
      selectAccount: (current, accountId) =>
          current.copyWith(fromAccountId: accountId),
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
      selectAccount: (current, accountId) =>
          current.copyWith(toAccountId: accountId),
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
          (current.mode == TransactionFormMode.expense &&
              current.expenseScene ==
                  TransactionExpenseScene.consumptionInstallment) ||
          requestRevision != _defaultAccountRequestRevision ||
          selectedCategoryId(current) != categoryId ||
          !(current.mode == TransactionFormMode.expense
                  ? current.expenseSettlementAccounts
                  : current.settlementAccounts)
              .any((account) => account.id == accountId)) {
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

  void setRelationScene(TransactionRelationScene value) {
    _update((current) {
      final changingMode = current.mode != value.mode;
      return current.copyWith(
        mode: value.mode,
        relationScene: value,
        entryMode: changingMode
            ? TransactionEntryMode.normal
            : current.entryMode,
        categoryAllocations: changingMode
            ? const []
            : current.categoryAllocations,
        settlementAllocations: changingMode
            ? const []
            : current.settlementAllocations,
        advanceReceivableAccountId: null,
        advanceScenario: AdvanceScenario.reimbursement,
        expenseScene: TransactionExpenseScene.ordinary,
        ordinaryReceivableAccountId: value.mode == TransactionFormMode.lending
            ? current.ordinaryReceivableAccountId
            : null,
        liabilityAccountId: value.mode == TransactionFormMode.borrowing
            ? current.liabilityAccountId
            : null,
        excludeStats: false,
        excludeBudget: false,
      );
    });
  }

  void setCategoryAllocations(List<AccountAmountAllocation> allocations) {
    _update((current) => current.copyWith(categoryAllocations: allocations));
  }

  void setSettlementAllocations(List<AccountAmountAllocation> allocations) {
    _update((current) {
      final consumptionInstallment =
          current.mode == TransactionFormMode.expense &&
          current.expenseScene ==
              TransactionExpenseScene.consumptionInstallment &&
          current.entryMode == TransactionEntryMode.allocated;
      if (!consumptionInstallment) {
        return current.copyWith(settlementAllocations: allocations);
      }
      final creditAccountIds = {
        for (final account in current.creditAccounts) account.id,
      };
      final allocatedCreditIds = [
        for (final allocation in allocations)
          if (allocation.amount.minorUnits > 0 &&
              creditAccountIds.contains(allocation.accountId))
            allocation.accountId,
      ];
      final selectedInstallmentAccountId =
          allocatedCreditIds.contains(current.fromAccountId)
          ? current.fromAccountId
          : allocatedCreditIds.firstOrNull;
      return current.copyWith(
        settlementAllocations: allocations,
        fromAccountId: selectedInstallmentAccountId,
      );
    });
  }

  Money applyConsumptionInstallmentAmount(Money loanAmount) {
    if (loanAmount.minorUnits <= 0) {
      throw _invalidCommandException('贷款金额必须大于零');
    }
    final current = state.asData?.value;
    if (current == null ||
        current.mode != TransactionFormMode.expense ||
        current.expenseScene !=
            TransactionExpenseScene.consumptionInstallment) {
      throw _invalidCommandException('当前交易不是消费分期');
    }
    if (current.entryMode == TransactionEntryMode.normal) {
      return loanAmount;
    }
    final liabilityAccountId = _selectedId(
      current.fromAccountId,
      current.creditAccounts,
    );
    if (liabilityAccountId == null) {
      throw _invalidCommandException('请选择分期账户');
    }
    final settlements = [...current.settlementAllocations];
    final installmentIndex = settlements.indexWhere(
      (allocation) => allocation.accountId == liabilityAccountId,
    );
    if (installmentIndex < 0) {
      throw _invalidCommandException('分期账户必须包含在支付分配中');
    }
    settlements[installmentIndex] = settlements[installmentIndex].copyWith(
      amount: loanAmount,
    );
    final total = sumAllocations(settlements);
    final categories = _fitAllocationsToTotal(
      current.categoryAllocations,
      total,
    );
    _update(
      (latest) => latest.copyWith(
        categoryAllocations: categories,
        settlementAllocations: settlements,
      ),
    );
    return total;
  }

  void useAllocatedEntry(Money amount) {
    _defaultAccountRequestRevision += 1;
    _update((current) {
      final consumptionInstallment =
          current.mode == TransactionFormMode.expense &&
          current.expenseScene ==
              TransactionExpenseScene.consumptionInstallment;
      final categoryId = switch (current.mode) {
        TransactionFormMode.expense => current.expenseCategoryId,
        TransactionFormMode.income => current.incomeCategoryId,
        _ => null,
      };
      final settlementId = _effectiveId(
        switch (current.mode) {
          TransactionFormMode.expense => current.fromAccountId,
          TransactionFormMode.income => current.toAccountId,
          _ => null,
        },
        current.mode == TransactionFormMode.expense
            ? current.expenseSettlementAccounts
            : current.settlementAccounts,
      );
      return current.copyWith(
        entryMode: TransactionEntryMode.allocated,
        categoryAllocations: categoryId == null
            ? const []
            : singleAllocation(accountId: categoryId, amount: amount),
        settlementAllocations: settlementId == null
            ? const []
            : singleAllocation(accountId: settlementId, amount: amount),
        expenseCategoryId: null,
        expenseRootId: null,
        fromAccountId: consumptionInstallment ? current.fromAccountId : null,
        incomeCategoryId: null,
        incomeRootId: null,
        toAccountId: null,
      );
    });
  }

  void useNormalEntry() {
    _defaultAccountRequestRevision += 1;
    _update((current) {
      final consumptionInstallment =
          current.mode == TransactionFormMode.expense &&
          current.expenseScene ==
              TransactionExpenseScene.consumptionInstallment;
      return current.copyWith(
        entryMode: TransactionEntryMode.normal,
        categoryAllocations: const [],
        settlementAllocations: const [],
        expenseCategoryId: null,
        expenseRootId: null,
        fromAccountId: consumptionInstallment ? current.fromAccountId : null,
        incomeCategoryId: null,
        incomeRootId: null,
        toAccountId: null,
      );
    });
  }

  void setAdvanceAccountId(String? value) {
    _update((current) => current.copyWith(advanceReceivableAccountId: value));
  }

  void setAdvanceScenario(AdvanceScenario value) {
    setExpenseScene(transactionExpenseSceneForAdvanceScenario(value));
  }

  void setExpenseScene(TransactionExpenseScene value) {
    _defaultAccountRequestRevision += 1;
    _update((current) {
      final changingMode = current.mode != TransactionFormMode.expense;
      final enteringConsumptionInstallment =
          value == TransactionExpenseScene.consumptionInstallment &&
          current.expenseScene != value;
      final resetEntry = changingMode || enteringConsumptionInstallment;
      final selectedAccountId = current.advanceReceivableAccountId;
      final availableAccountIds = {
        for (final account in advanceAccountsForExpenseScene(
          value,
          current.advanceReceivableAccounts,
        ))
          account.id,
      };
      final selectedAccount = current.advanceReceivableAccounts
          .where((account) => account.id == selectedAccountId)
          .firstOrNull;
      final canKeepSelectedAccount =
          selectedAccountId != null &&
          selectedAccount != null &&
          (selectedAccount.profileKey == null ||
              availableAccountIds.contains(selectedAccountId));
      final currentCreditAccount = current.creditAccounts
          .where((account) => account.id == current.fromAccountId)
          .firstOrNull;
      final consumptionAccountId =
          currentCreditAccount?.id ?? current.creditAccounts.firstOrNull?.id;
      return current.copyWith(
        mode: TransactionFormMode.expense,
        entryMode: resetEntry ? TransactionEntryMode.normal : current.entryMode,
        categoryAllocations: resetEntry
            ? const []
            : current.categoryAllocations,
        settlementAllocations: resetEntry
            ? const []
            : current.settlementAllocations,
        fromAccountId: value == TransactionExpenseScene.consumptionInstallment
            ? consumptionAccountId
            : current.fromAccountId,
        expenseScene: value,
        advanceScenario: value.advanceScenario ?? AdvanceScenario.reimbursement,
        advanceReceivableAccountId: canKeepSelectedAccount
            ? selectedAccountId
            : null,
        ordinaryReceivableAccountId: null,
        excludeBudget: current.excludeBudget,
      );
    });
  }

  void setAaPeopleCount(int value) {
    _update(
      (current) => current.copyWith(aaPeopleCount: value.clamp(2, 99).toInt()),
    );
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

  void setCounterpartyId(String? value) {
    _update((current) => current.copyWith(counterpartyId: value));
  }

  void setCounterparty(CounterpartyView? value) {
    _update((current) {
      final counterparties = [...current.counterparties];
      if (value != null && !counterparties.any((item) => item.id == value.id)) {
        counterparties
          ..add(value)
          ..sort((left, right) => left.name.compareTo(right.name));
      }
      return current.copyWith(
        counterpartyId: value?.id,
        counterparties: counterparties,
      );
    });
  }

  void setExcludeBudget(bool value) {
    _update((current) => current.copyWith(excludeBudget: value));
  }

  void clearForNext({DateTime? occurredAt}) {
    _update(
      (current) => current.copyWith(
        categoryAllocations: current.entryMode == TransactionEntryMode.allocated
            ? const []
            : current.categoryAllocations,
        settlementAllocations:
            current.entryMode == TransactionEntryMode.allocated
            ? const []
            : current.settlementAllocations,
        advanceReceivableAccountId: null,
        advanceScenario: AdvanceScenario.reimbursement,
        expenseScene: TransactionExpenseScene.ordinary,
        aaPeopleCount: 2,
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
    String? feeText,
    ConsumptionInstallmentConfiguration? consumptionInstallment,
  }) async {
    final current = state.asData?.value;
    if (current == null) return _invalidCommand('交易表单尚未加载');
    final amount = _parsePositiveAmount(amountText);
    if (amount == null) {
      return _invalidCommand('请输入有效金额');
    }
    Money? feeAmount;
    if (current.mode == TransactionFormMode.transfer && feeText != null) {
      final trimmedFee = feeText.trim();
      if (trimmedFee.isEmpty) {
        feeAmount = Money.zero();
      } else {
        final parsedFee = Money.tryParse(trimmedFee);
        if (parsedFee == null || parsedFee.minorUnits < 0) {
          return _invalidCommand('请输入有效手续费');
        }
        feeAmount = parsedFee;
      }
    }

    _update((current) => current.copyWith(submitting: true));
    try {
      return await guardSubmit(_logger, 'Transaction form submit', () async {
        final editTransactionId = _editTransactionId;
        if (editTransactionId == null) {
          await _submitCreate(
            current,
            amount,
            feeAmount,
            noteText,
            consumptionInstallment,
          );
        } else {
          await _submitEdit(
            current,
            editTransactionId,
            amount,
            feeAmount,
            noteText,
          );
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
    Money? feeAmount,
    String noteText,
    ConsumptionInstallmentConfiguration? consumptionInstallment,
  ) async {
    final postingService = ref.read(transactionPostingAppServiceProvider);
    final note = trimToNull(noteText);

    switch (formState.mode) {
      case TransactionFormMode.expense:
        if (formState.expenseScene ==
            TransactionExpenseScene.consumptionInstallment) {
          if (consumptionInstallment == null) {
            throw _invalidCommandException('请先完成分期配置');
          }
          await _submitConsumptionInstallment(
            formState,
            amount,
            note,
            consumptionInstallment,
          );
          return;
        }
        final allocations = _expenseAllocations(formState, amount);
        final advanceReceivableAccountId = _selectedId(
          formState.advanceReceivableAccountId,
          formState.advanceReceivableAccounts,
        );
        await ref
            .read(advanceOrchestrationAppServiceProvider)
            .createExpenseScene(
              CreateExpenseSceneWorkflowCommand(
                amount: amount,
                target: _expenseSceneTarget(
                  formState,
                  advanceReceivableAccountId,
                ),
                categoryAllocations: allocations.categories,
                settlementAllocations: allocations.settlements,
                occurredAt: formState.occurredAt,
                counterpartyId: formState.counterpartyId,
                note: note,
                isExcludedFromStats: formState.excludeStats,
                isExcludedFromBudget: formState.excludeBudget,
                tagIds: formState.selectedTagIds,
              ),
            );
      case TransactionFormMode.income:
        final allocations = _incomeAllocations(formState, amount);
        await postingService.createIncome(
          CreateIncomeCommand(
            amount: amount,
            categoryAllocations: allocations.categories,
            settlementAllocations: allocations.settlements,
            occurredAt: formState.occurredAt,
            counterpartyId: formState.counterpartyId,
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
            feeAmount: feeAmount,
            occurredAt: formState.occurredAt,
            counterpartyId: formState.counterpartyId,
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
            counterpartyId: formState.counterpartyId,
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
          throw _invalidCommandException(
            '请选择${formState.relationScene.cashAccountLabel}和'
            '${formState.relationScene.receivableAccountLabel}',
          );
        }
        await (postingService as ReceivableTransactionPostingAppService)
            .createLending(
              CreateLendingCommand(
                amount: amount,
                receivableAccountId: receivableAccountId,
                paidFromAccountId: paidFromAccountId,
                occurredAt: formState.occurredAt,
                counterpartyId: formState.counterpartyId,
                note: note,
                tagIds: formState.selectedTagIds,
              ),
            );
    }
  }

  Future<void> _submitConsumptionInstallment(
    TransactionFormState formState,
    Money amount,
    String? note,
    ConsumptionInstallmentConfiguration configuration,
  ) async {
    final categoryAllocations = switch (formState.entryMode) {
      TransactionEntryMode.normal => [
        if (formState.expenseCategoryId case final categoryId?)
          ConsumptionInstallmentAllocation(
            accountId: categoryId,
            amount: amount,
          ),
      ],
      TransactionEntryMode.allocated => [
        for (final allocation in formState.categoryAllocations)
          ConsumptionInstallmentAllocation(
            accountId: allocation.accountId,
            amount: allocation.amount,
          ),
      ],
    };
    if (categoryAllocations.isEmpty) {
      throw _invalidCommandException('请至少添加一个支出分类');
    }
    final categoryTotal = categoryAllocations.fold<Money>(
      Money.zero(),
      (total, allocation) => total + allocation.amount,
    );
    if (categoryTotal != amount) {
      throw _invalidCommandException('分类分配合计必须等于成交价');
    }

    final liabilityAccountId = _effectiveId(
      formState.fromAccountId,
      formState.creditAccounts,
    );
    if (liabilityAccountId == null) {
      throw _invalidCommandException('请选择分期账户');
    }
    final List<AccountAmountAllocation> settlementAllocations =
        formState.entryMode == TransactionEntryMode.allocated
        ? formState.settlementAllocations
        : singleAllocation(accountId: liabilityAccountId, amount: amount);
    if (settlementAllocations.isEmpty ||
        settlementAllocations.any(
          (allocation) => allocation.amount.minorUnits <= 0,
        )) {
      throw _invalidCommandException('请完成有效的支付分配');
    }
    if (sumAllocations(settlementAllocations) != amount) {
      throw _invalidCommandException('支付分配合计必须等于成交价');
    }
    final installmentAllocation = settlementAllocations
        .where((allocation) => allocation.accountId == liabilityAccountId)
        .firstOrNull;
    if (installmentAllocation == null ||
        installmentAllocation.amount.minorUnits <= 0) {
      throw _invalidCommandException('请选择包含在支付分配中的分期账户');
    }

    await ref
        .read(consumptionInstallmentAppServiceProvider)
        .create(
          CreateConsumptionInstallmentCommand(
            liabilityAccountId: liabilityAccountId,
            amount: amount,
            categoryAllocations: categoryAllocations,
            settlementAllocations: [
              for (final allocation in settlementAllocations)
                ConsumptionInstallmentAllocation(
                  accountId: allocation.accountId,
                  amount: allocation.amount,
                ),
            ],
            borrowingDate: configuration.borrowingDate,
            occurredAt: formState.occurredAt,
            counterpartyId: formState.counterpartyId,
            note: note,
            tagIds: formState.selectedTagIds,
            isExcludedFromStats: formState.excludeStats,
            isExcludedFromBudget: formState.excludeBudget,
            stageTerms: configuration.stageTerms,
          ),
        );
  }

  Future<void> _submitEdit(
    TransactionFormState formState,
    String transactionId,
    Money amount,
    Money? feeAmount,
    String noteText,
  ) async {
    final editService = ref.read(transactionEditAppServiceProvider);
    final note = _stringPatch(trimToNull(noteText));
    final counterpartyId = _counterpartyPatch(formState.counterpartyId);

    switch (formState.mode) {
      case TransactionFormMode.expense:
        final allocations = _expenseAllocations(formState, amount);
        final advanceReceivableAccountId = _selectedId(
          formState.advanceReceivableAccountId,
          formState.advanceReceivableAccounts,
        );
        final target = _expenseSceneTarget(
          formState,
          advanceReceivableAccountId,
        );
        await ref
            .read(advanceOrchestrationAppServiceProvider)
            .editExpenseScene(
              EditExpenseSceneWorkflowCommand(
                transactionId: transactionId,
                target: target,
                amount: amount,
                categoryAllocations: allocations.categories,
                settlementAllocations: allocations.settlements,
                occurredAt: formState.occurredAt,
                counterpartyId: counterpartyId,
                note: note,
                isExcludedFromStats: formState.excludeStats,
                isExcludedFromBudget: formState.excludeBudget,
                tagIds: formState.selectedTagIds,
              ),
            );
      case TransactionFormMode.income:
        final allocations = _incomeAllocations(formState, amount);
        await editService.editIncome(
          EditIncomeCommand(
            transactionId: transactionId,
            amount: amount,
            categoryAllocations: allocations.categories,
            settlementAllocations: allocations.settlements,
            occurredAt: formState.occurredAt,
            counterpartyId: counterpartyId,
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
            feeAmount: feeAmount,
            occurredAt: formState.occurredAt,
            counterpartyId: counterpartyId,
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
            counterpartyId: counterpartyId,
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
          throw _invalidCommandException(
            '请选择${formState.relationScene.cashAccountLabel}和'
            '${formState.relationScene.receivableAccountLabel}',
          );
        }
        await (editService as ReceivableTransactionEditAppService).editLending(
          EditLendingCommand(
            transactionId: transactionId,
            amount: amount,
            receivableAccountId: receivableAccountId,
            paidFromAccountId: paidFromAccountId,
            occurredAt: formState.occurredAt,
            counterpartyId: counterpartyId,
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
    required TransactionAccountOptions? accountOptions,
    required List<CategoryNode>? expenseTree,
    required List<CategoryNode>? incomeTree,
    required List<TagView>? tags,
    required List<CounterpartyView>? counterparties,
  }) {
    return current.copyWith(
      accountOptions: accountOptions,
      expenseTree: expenseTree,
      incomeTree: incomeTree,
      tags: tags,
      counterparties: counterparties,
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

  List<AccountAmountAllocation> _fitAllocationsToTotal(
    List<AccountAmountAllocation> allocations,
    Money total,
  ) {
    if (allocations.isEmpty) return const [];
    if (allocations.length == 1) {
      return [allocations.single.copyWith(amount: total)];
    }
    final currentTotal = sumAllocations(allocations);
    final difference = total.minorUnits - currentTotal.minorUnits;
    final adjusted = [...allocations];
    if (difference >= 0) {
      final last = adjusted.last;
      adjusted[adjusted.length - 1] = last.copyWith(
        amount: Money(minorUnits: last.amount.minorUnits + difference),
      );
      return adjusted;
    }
    var remaining = -difference;
    for (
      var index = adjusted.length - 1;
      index >= 0 && remaining > 0;
      index--
    ) {
      final allocation = adjusted[index];
      final reduction = remaining < allocation.amount.minorUnits
          ? remaining
          : allocation.amount.minorUnits;
      adjusted[index] = allocation.copyWith(
        amount: Money(minorUnits: allocation.amount.minorUnits - reduction),
      );
      remaining -= reduction;
    }
    return [
      for (final allocation in adjusted)
        if (allocation.amount.minorUnits > 0) allocation,
    ];
  }

  Patch<String?> _stringPatch(String? value) {
    return value == null ? const Patch<String?>.clear() : Patch.set(value);
  }

  Patch<String?> _counterpartyPatch(String? value) {
    return value == null
        ? const Patch<String?>.clear()
        : Patch<String?>.set(value);
  }

  ExpenseSceneTarget _expenseSceneTarget(
    TransactionFormState formState,
    String? advanceReceivableAccountId,
  ) {
    if (formState.expenseScene ==
        TransactionExpenseScene.consumptionInstallment) {
      throw _invalidCommandException('消费分期请完成分期配置后提交');
    }
    if (formState.expenseScene == TransactionExpenseScene.ordinary &&
        advanceReceivableAccountId == null) {
      return const OrdinaryExpenseSceneTarget();
    }
    if (advanceReceivableAccountId == null) {
      throw _invalidCommandException('请选择垫付账户');
    }
    final scenario =
        formState.expenseScene.advanceScenario ?? AdvanceScenario.reimbursement;
    final trackingMode =
        formState.expenseScene.advanceTrackingMode ??
        AdvanceTrackingMode.itemized;
    return trackingMode == AdvanceTrackingMode.account
        ? AccountAdvanceSceneTarget(
            scenario: scenario,
            aaPeopleCount: formState.aaPeopleCount,
            receivableAccountId: advanceReceivableAccountId,
          )
        : ItemizedAdvanceSceneTarget(
            scenario: scenario,
            aaPeopleCount: formState.aaPeopleCount,
            receivableAccountId: advanceReceivableAccountId,
          );
  }

  ({
    List<AccountAmountAllocation> categories,
    List<AccountAmountAllocation> settlements,
  })
  _expenseAllocations(TransactionFormState formState, Money amount) {
    if (formState.entryMode == TransactionEntryMode.normal) {
      final categoryId = formState.expenseCategoryId;
      if (categoryId == null) {
        throw _invalidCommandException('请选择支出分类');
      }
      final settlementId = _effectiveId(
        formState.fromAccountId,
        formState.expenseSettlementAccounts,
      );
      if (settlementId == null) {
        throw _invalidCommandException('请选择支出账户');
      }
      return (
        categories: singleAllocation(accountId: categoryId, amount: amount),
        settlements: singleAllocation(accountId: settlementId, amount: amount),
      );
    }

    final categories = formState.categoryAllocations;
    final settlements = formState.settlementAllocations;
    if (categories.isEmpty) {
      throw _invalidCommandException('请至少添加一个支出分类');
    }
    if (settlements.isEmpty) {
      throw _invalidCommandException('请至少添加一个支出账户');
    }
    if (sumAllocations(categories) != amount) {
      throw _invalidCommandException('分类分配合计必须等于交易金额');
    }
    if (sumAllocations(settlements) != amount) {
      throw _invalidCommandException('支付分配合计必须等于交易金额');
    }
    return (categories: categories, settlements: settlements);
  }

  ({
    List<AccountAmountAllocation> categories,
    List<AccountAmountAllocation> settlements,
  })
  _incomeAllocations(TransactionFormState formState, Money amount) {
    if (formState.entryMode == TransactionEntryMode.normal) {
      final categoryId = formState.incomeCategoryId;
      if (categoryId == null) {
        throw _invalidCommandException('请选择收入分类');
      }
      final settlementId = _effectiveId(
        formState.toAccountId,
        formState.settlementAccounts,
      );
      if (settlementId == null) {
        throw _invalidCommandException('请选择收入账户');
      }
      return (
        categories: singleAllocation(accountId: categoryId, amount: amount),
        settlements: singleAllocation(accountId: settlementId, amount: amount),
      );
    }

    final categories = formState.categoryAllocations;
    final settlements = formState.settlementAllocations;
    if (categories.isEmpty) {
      throw _invalidCommandException('请至少添加一个收入分类');
    }
    if (settlements.isEmpty) {
      throw _invalidCommandException('请至少添加一个收入账户');
    }
    if (sumAllocations(categories) != amount) {
      throw _invalidCommandException('收入分配合计必须等于交易金额');
    }
    if (sumAllocations(settlements) != amount) {
      throw _invalidCommandException('到账分配合计必须等于交易金额');
    }
    return (categories: categories, settlements: settlements);
  }
}

class TransactionFormState {
  TransactionFormState({
    required this.initialValues,
    required this.mode,
    required this.entryMode,
    required this.occurredAt,
    required this.excludeStats,
    required this.excludeBudget,
    required this.submitting,
    required this.accountOptions,
    required List<CategoryNode> expenseTree,
    required List<CategoryNode> incomeTree,
    required List<TagView> tags,
    required List<CounterpartyView> counterparties,
    this.selectedTagIds = const {},
    this.counterpartyId,
    this.expenseCategoryId,
    this.expenseRootId,
    this.incomeCategoryId,
    this.incomeRootId,
    this.fromAccountId,
    this.toAccountId,
    this.advanceReceivableAccountId,
    this.advanceScenario = AdvanceScenario.reimbursement,
    this.expenseScene = TransactionExpenseScene.ordinary,
    this.relationScene = TransactionRelationScene.borrowing,
    this.aaPeopleCount = 2,
    this.ordinaryReceivableAccountId,
    this.liabilityAccountId,
    List<AccountAmountAllocation> categoryAllocations = const [],
    List<AccountAmountAllocation> settlementAllocations = const [],
  }) : expenseTree = List.unmodifiable(expenseTree),
       incomeTree = List.unmodifiable(incomeTree),
       tags = List.unmodifiable(tags),
       counterparties = List.unmodifiable(counterparties),
       categoryAllocations = List.unmodifiable(categoryAllocations),
       settlementAllocations = List.unmodifiable(settlementAllocations);

  factory TransactionFormState.initial({
    required TransactionFormMode mode,
    String? fromAccountId,
    String? toAccountId,
    String? liabilityAccountId,
    required TransactionAccountOptions accountOptions,
    required List<CategoryNode> expenseTree,
    required List<CategoryNode> incomeTree,
    required List<TagView> tags,
    required List<CounterpartyView> counterparties,
  }) {
    return TransactionFormState(
      initialValues: const TransactionFormInitialValues(),
      mode: mode,
      relationScene: transactionRelationSceneForMode(mode),
      entryMode: TransactionEntryMode.normal,
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
      ordinaryReceivableAccountId: mode == TransactionFormMode.lending
          ? toAccountId
          : null,
      liabilityAccountId: mode == TransactionFormMode.borrowing
          ? liabilityAccountId
          : null,
      accountOptions: accountOptions,
      expenseTree: expenseTree,
      incomeTree: incomeTree,
      tags: tags,
      counterparties: counterparties,
    );
  }

  factory TransactionFormState.fromEditSnapshot({
    required TransactionFormEditSnapshot snapshot,
    required TransactionAccountOptions accountOptions,
    required List<CategoryNode> expenseTree,
    required List<CategoryNode> incomeTree,
    required List<TagView> tags,
    required List<CounterpartyView> counterparties,
    required Set<String> initialTagIds,
  }) {
    final categoryAllocations = snapshot.categoryAllocations ?? const [];
    final settlementAllocations = snapshot.settlementAllocations ?? const [];
    final usesAllocatedEntry =
        (snapshot.mode == TransactionFormMode.expense ||
            snapshot.mode == TransactionFormMode.income) &&
        (categoryAllocations.length > 1 || settlementAllocations.length > 1);
    return TransactionFormState(
      initialValues: TransactionFormInitialValues.fromSnapshot(snapshot),
      mode: snapshot.mode,
      relationScene: snapshot.relationScene,
      entryMode: usesAllocatedEntry
          ? TransactionEntryMode.allocated
          : TransactionEntryMode.normal,
      occurredAt: snapshot.occurredAt,
      selectedTagIds: initialTagIds,
      counterpartyId: snapshot.counterpartyId,
      expenseCategoryId: usesAllocatedEntry ? null : snapshot.expenseCategoryId,
      expenseRootId: usesAllocatedEntry ? null : snapshot.expenseRootId,
      incomeCategoryId: usesAllocatedEntry ? null : snapshot.incomeCategoryId,
      incomeRootId: usesAllocatedEntry ? null : snapshot.incomeRootId,
      fromAccountId: usesAllocatedEntry ? null : snapshot.fromAccountId,
      toAccountId: usesAllocatedEntry ? null : snapshot.toAccountId,
      advanceReceivableAccountId: snapshot.advanceReceivableAccountId,
      advanceScenario: snapshot.advanceScenario,
      expenseScene: snapshot.advanceReceivableAccountId == null
          ? TransactionExpenseScene.ordinary
          : transactionExpenseSceneForAdvanceScenario(
              snapshot.advanceScenario,
              trackingMode: snapshot.advanceTrackingMode,
            ),
      aaPeopleCount: _aaPeopleCountFromSnapshot(snapshot),
      ordinaryReceivableAccountId: snapshot.ordinaryReceivableAccountId,
      liabilityAccountId: snapshot.liabilityAccountId,
      categoryAllocations: usesAllocatedEntry ? categoryAllocations : const [],
      settlementAllocations: usesAllocatedEntry
          ? settlementAllocations
          : const [],
      excludeStats: snapshot.excludeStats,
      excludeBudget: snapshot.excludeBudget,
      submitting: false,
      accountOptions: accountOptions,
      expenseTree: expenseTree,
      incomeTree: incomeTree,
      tags: tags,
      counterparties: counterparties,
    );
  }

  final TransactionFormInitialValues initialValues;
  final TransactionFormMode mode;
  final TransactionEntryMode entryMode;
  final DateTime occurredAt;
  final String? expenseCategoryId;
  final String? expenseRootId;
  final String? incomeCategoryId;
  final String? incomeRootId;
  final String? fromAccountId;
  final String? toAccountId;
  final String? advanceReceivableAccountId;
  final AdvanceScenario advanceScenario;
  final TransactionExpenseScene expenseScene;
  final TransactionRelationScene relationScene;
  final int aaPeopleCount;
  final String? ordinaryReceivableAccountId;
  final String? liabilityAccountId;
  final List<AccountAmountAllocation> categoryAllocations;
  final List<AccountAmountAllocation> settlementAllocations;
  final bool excludeStats;
  final bool excludeBudget;
  final bool submitting;
  final Set<String> selectedTagIds;
  final String? counterpartyId;
  final TransactionAccountOptions accountOptions;
  final List<CategoryNode> expenseTree;
  final List<CategoryNode> incomeTree;
  final List<TagView> tags;
  final List<CounterpartyView> counterparties;

  List<Account> get settlementAccounts => accountOptions.settlementAccounts;
  List<Account> get fundAccounts => accountOptions.fundAccounts;
  List<Account> get liabilityAccounts => accountOptions.liabilityAccounts;
  List<Account> get creditAccounts => [
    for (final account in liabilityAccounts)
      if (account.profileKey == AccountProfileKind.credit.key) account,
  ];
  List<Account> get advanceReceivableAccounts =>
      accountOptions.advanceReceivableAccounts;
  List<Account> get ordinaryReceivableAccounts =>
      accountOptions.ordinaryReceivableAccounts;
  List<Account> get expenseSettlementAccounts =>
      accountOptions.expenseSettlementAccounts;

  TransactionFormState copyWith({
    TransactionFormInitialValues? initialValues,
    TransactionFormMode? mode,
    TransactionEntryMode? entryMode,
    DateTime? occurredAt,
    Object? expenseCategoryId = _sentinel,
    Object? expenseRootId = _sentinel,
    Object? incomeCategoryId = _sentinel,
    Object? incomeRootId = _sentinel,
    Object? fromAccountId = _sentinel,
    Object? toAccountId = _sentinel,
    Object? advanceReceivableAccountId = _sentinel,
    AdvanceScenario? advanceScenario,
    TransactionExpenseScene? expenseScene,
    TransactionRelationScene? relationScene,
    int? aaPeopleCount,
    Object? ordinaryReceivableAccountId = _sentinel,
    Object? liabilityAccountId = _sentinel,
    List<AccountAmountAllocation>? categoryAllocations,
    List<AccountAmountAllocation>? settlementAllocations,
    bool? excludeStats,
    bool? excludeBudget,
    bool? submitting,
    TransactionAccountOptions? accountOptions,
    List<CategoryNode>? expenseTree,
    List<CategoryNode>? incomeTree,
    List<TagView>? tags,
    List<CounterpartyView>? counterparties,
    Set<String>? selectedTagIds,
    Object? counterpartyId = _sentinel,
  }) {
    return TransactionFormState(
      initialValues: initialValues ?? this.initialValues,
      mode: mode ?? this.mode,
      entryMode: entryMode ?? this.entryMode,
      occurredAt: occurredAt ?? this.occurredAt,
      expenseCategoryId: expenseCategoryId == _sentinel
          ? this.expenseCategoryId
          : expenseCategoryId as String?,
      expenseRootId: expenseRootId == _sentinel
          ? this.expenseRootId
          : expenseRootId as String?,
      incomeCategoryId: incomeCategoryId == _sentinel
          ? this.incomeCategoryId
          : incomeCategoryId as String?,
      incomeRootId: incomeRootId == _sentinel
          ? this.incomeRootId
          : incomeRootId as String?,
      fromAccountId: fromAccountId == _sentinel
          ? this.fromAccountId
          : fromAccountId as String?,
      toAccountId: toAccountId == _sentinel
          ? this.toAccountId
          : toAccountId as String?,
      advanceReceivableAccountId: advanceReceivableAccountId == _sentinel
          ? this.advanceReceivableAccountId
          : advanceReceivableAccountId as String?,
      advanceScenario: advanceScenario ?? this.advanceScenario,
      expenseScene: expenseScene ?? this.expenseScene,
      relationScene: relationScene ?? this.relationScene,
      aaPeopleCount: aaPeopleCount ?? this.aaPeopleCount,
      ordinaryReceivableAccountId: ordinaryReceivableAccountId == _sentinel
          ? this.ordinaryReceivableAccountId
          : ordinaryReceivableAccountId as String?,
      liabilityAccountId: liabilityAccountId == _sentinel
          ? this.liabilityAccountId
          : liabilityAccountId as String?,
      categoryAllocations: categoryAllocations ?? this.categoryAllocations,
      settlementAllocations:
          settlementAllocations ?? this.settlementAllocations,
      excludeStats: excludeStats ?? this.excludeStats,
      excludeBudget: excludeBudget ?? this.excludeBudget,
      submitting: submitting ?? this.submitting,
      accountOptions: accountOptions ?? this.accountOptions,
      expenseTree: expenseTree ?? this.expenseTree,
      incomeTree: incomeTree ?? this.incomeTree,
      tags: tags ?? this.tags,
      counterparties: counterparties ?? this.counterparties,
      selectedTagIds: selectedTagIds ?? this.selectedTagIds,
      counterpartyId: counterpartyId == _sentinel
          ? this.counterpartyId
          : counterpartyId as String?,
    );
  }
}

/// Text captured once from the transaction snapshot for controller creation.
/// This is not the live text state of the form.
class TransactionFormInitialValues {
  const TransactionFormInitialValues({
    this.amount = '',
    this.fee = '',
    this.note = '',
  });

  factory TransactionFormInitialValues.fromSnapshot(
    TransactionFormEditSnapshot snapshot,
  ) {
    return TransactionFormInitialValues(
      amount: snapshot.amountText,
      fee: snapshot.feeText,
      note: snapshot.noteText,
    );
  }

  final String amount;
  final String fee;
  final String note;
}

int _aaPeopleCountFromSnapshot(TransactionFormEditSnapshot snapshot) {
  if (snapshot.advanceScenario != AdvanceScenario.aa) return 2;
  if (snapshot.advanceAaPeopleCount != null) {
    return snapshot.advanceAaPeopleCount!;
  }
  final total = Money.tryParse(snapshot.amountText);
  final advance = Money.tryParse(snapshot.advanceAmountText);
  if (total == null || advance == null) return 2;
  return inferAaPeopleCount(total: total, advanceAmount: advance);
}

const Object _sentinel = Object();
