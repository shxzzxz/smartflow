import 'package:logging/logging.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../../../app/provider.dart';
import '../../../../application/credit/credit_command_api.dart';
import '../../../../application/ledger/ledger_command_api.dart';
import '../../../../application/ledger/ledger_query_api.dart';
import '../../../../application/orchestration/orchestration_command_api.dart';
import '../../../../core/error/app_exception.dart';
import '../../../../core/money/money.dart';
import '../../../../core/patch/patch.dart';
import '../../../../core/text/text_normalizer.dart';
import '../../../../domain/ledger/valobj/ledger_error_code.dart';
import '../../../amortization/presentation/amortization_configuration_draft.dart';
import '../../../amortization/provider/amortization_providers.dart';
import '../../../shared/provider/counterparty_providers.dart';
import '../../../shared/provider/ledger_query_providers.dart';
import '../../../shared/provider/tag_providers.dart';
import '../../../shared/view_model/action_guard.dart';
import '../../../shared/view_model/ui_action_outcome.dart';
import '../../presentation/transaction_form_presentation.dart';
import 'transaction_account_options.dart';
import 'transaction_form_helpers.dart';
import 'transaction_form_state.dart';

export 'transaction_form_state.dart';

part 'transaction_form_common_interactions.dart';
part 'transaction_form_expense_scene_interactions.dart';
part 'transaction_form_installment_interactions.dart';
part 'transaction_form_ledger_interactions.dart';
part 'workflow/transaction_form_workflow.dart';
part 'workflow/transaction_form_command_support.dart';
part 'workflow/transaction_ledger_workflow.dart';
part 'workflow/expense_scene_workflow.dart';
part 'workflow/consumption_installment_workflow.dart';
part 'workflow/amortization_form_workflow.dart';
part 'transaction_form_view_model.g.dart';

final _logger = Logger('feature.transaction.form');

@riverpod
Future<AdvanceCase?> advanceCaseForForm(Ref ref, String advanceCaseId) {
  return ref.watch(advanceCaseQueryServiceProvider).findById(advanceCaseId);
}

@riverpod
class TransactionFormViewModel extends _$TransactionFormViewModel {
  TransactionFormState? _initializedState;
  String? _editTransactionId;
  String? _editAmortizationPlanId;
  int _defaultAccountRequestRevision = 0;

  TransactionFormState? get _currentState => state.asData?.value;

  Future<String?> _findLastUsedSettlementAccountId(String categoryId) {
    return ref
        .read(transactionQueryServiceProvider)
        .findLastUsedSettlementAccountId(categoryId);
  }

  @override
  AsyncValue<TransactionFormState?> build({
    String? editTransactionId,
    TransactionFormMode initialMode = TransactionFormMode.expense,
    String? initialFromAccountId,
    String? initialToAccountId,
    String? initialLiabilityAccountId,
    AmortizationKind? initialAmortizationKind,
    String? initialAmortizationDeferralAccountId,
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
          initialAmortizationKind: initialAmortizationKind,
          initialAmortizationDeferralAccountId:
              initialAmortizationDeferralAccountId,
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
    if (detail.ownership?.ownerType == orchestrationAmortizationOwnerType) {
      final planAsync = ref.watch(
        amortizationPlanProvider(detail.ownership!.ownerId),
      );
      if (planAsync case AsyncError(:final error, :final stackTrace)) {
        return AsyncValue.error(error, stackTrace);
      }
      if (!planAsync.hasValue) return const AsyncValue.loading();
      final plan = planAsync.requireValue;
      if (plan == null || plan.status == AmortizationStatus.terminated) {
        return const AsyncValue.data(null);
      }
      final initialDetailAsync = ref.watch(
        transactionDetailProvider(plan.initialTransactionId),
      );
      final initialTagIdsAsync = ref.watch(
        transactionTagIdsProvider(plan.initialTransactionId),
      );
      final amortizationQueries = <AsyncValue<dynamic>>[
        initialDetailAsync,
        initialTagIdsAsync,
      ];
      for (final query in amortizationQueries) {
        if (query case AsyncError(:final error, :final stackTrace)) {
          return AsyncValue.error(error, stackTrace);
        }
      }
      if (amortizationQueries.any((query) => !query.hasValue)) {
        return const AsyncValue.loading();
      }
      final initialDetail = initialDetailAsync.requireValue;
      if (initialDetail == null) return const AsyncValue.data(null);
      _editAmortizationPlanId = plan.id;
      return AsyncValue.data(
        _initializedState ??= TransactionFormState.fromAmortizationPlan(
          plan: plan,
          initialTransaction: initialDetail,
          accountOptions: accountOptions,
          expenseTree: expenseTree,
          incomeTree: incomeTree,
          tags: tagsAsync.requireValue,
          counterparties: counterpartiesAsync.requireValue,
          initialTagIds: initialTagIdsAsync.requireValue,
        ),
      );
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

  Future<SubmitOutcome> submit({
    required String amountText,
    required String noteText,
    String? feeText,
    ConsumptionInstallmentConfiguration? consumptionInstallment,
    AmortizationConfigurationDraft? amortizationConfiguration,
  }) async {
    final current = state.asData?.value;
    if (current == null) return _invalidCommand('交易表单尚未加载');
    final amount = _parsePositiveAmount(amountText);
    if (amount == null) {
      return _invalidCommand('请输入有效金额');
    }
    Money? feeAmount;
    if ((current.mode == TransactionFormMode.transfer ||
            current.isAmortization) &&
        feeText != null) {
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
        final workflow = _TransactionFormWorkflowDispatcher(
          postingService: ref.read(transactionPostingAppServiceProvider),
          editService: ref.read(transactionEditAppServiceProvider),
          advanceService: ref.read(advanceOrchestrationAppServiceProvider),
          consumptionInstallmentService: ref.read(
            consumptionInstallmentAppServiceProvider,
          ),
          amortizationService: ref.read(amortizationPlanAppServiceProvider),
        );
        final editTransactionId = _editTransactionId;
        if (editTransactionId == null) {
          await workflow.create(
            state: current,
            amount: amount,
            feeAmount: feeAmount,
            note: trimToNull(noteText),
            consumptionInstallment: consumptionInstallment,
            amortizationConfiguration: amortizationConfiguration,
          );
        } else {
          await workflow.edit(
            state: current,
            transactionId: editTransactionId,
            amortizationPlanId: _editAmortizationPlanId,
            amount: amount,
            feeAmount: feeAmount,
            note: trimToNull(noteText),
            amortizationConfiguration: amortizationConfiguration,
          );
          final planId = _editAmortizationPlanId;
          if (planId != null) {
            ref
              ..invalidate(amortizationPlanProvider(planId))
              ..invalidate(amortizationPlansProvider())
              ..invalidate(transactionDetailProvider(editTransactionId));
          }
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
        final planId = _editAmortizationPlanId;
        if (planId != null) {
          await ref
              .read(amortizationPlanAppServiceProvider)
              .deletePlan(DeleteAmortizationPlanCommand(planId: planId));
          ref
            ..invalidate(amortizationPlanProvider(planId))
            ..invalidate(amortizationPlansProvider());
          return;
        }
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
    final next = current.copyWith(
      accountOptions: accountOptions,
      expenseTree: expenseTree,
      incomeTree: incomeTree,
      tags: tags,
      counterparties: counterparties,
    );
    if (!next.isAmortization) return next;
    return next.copyWith(
      fromAccountId: next.mode == TransactionFormMode.expense
          ? effectiveAccountId(next.fromAccountId, next.fundAccounts)
          : next.fromAccountId,
      toAccountId: next.mode == TransactionFormMode.income
          ? effectiveAccountId(next.toAccountId, next.fundAccounts)
          : next.toAccountId,
      amortizationDeferralAccountId: effectiveAccountId(
        next.amortizationDeferralAccountId,
        next.amortizationDeferralAccounts,
      ),
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
}
