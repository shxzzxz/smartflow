import '../../../../application/ledger/ledger_query_api.dart';
import '../../../../application/ledger/tag/query/tag_read_models.dart';
import '../../../../application/orchestration/advance/command/advance_share.dart';
import '../../../../application/orchestration/orchestration_command_api.dart'
    show AmortizationPlan;
import '../../../../core/money/money.dart';
import '../../../../core/money/money_formatter.dart';
import '../../../../domain/credit/valobj/installment_contract_terms.dart';
import '../../../../domain/orchestration/valobj/advance_enums.dart';
import '../../../../domain/orchestration/valobj/amortization_enums.dart';
import '../../../../shared/account_profile/account_profile_kind.dart';
import '../../../amortization/presentation/amortization_configuration_draft.dart';
import '../../presentation/transaction_form_presentation.dart';
import 'transaction_account_options.dart';

enum TransactionEntryMode { normal, allocated }

class ConsumptionInstallmentConfiguration {
  const ConsumptionInstallmentConfiguration({
    required this.borrowingDate,
    required this.stageTerms,
  });

  final DateTime borrowingDate;
  final InstallmentContractTerms stageTerms;
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
    Set<String> selectedTagIds = const {},
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
    this.incomeScene = TransactionIncomeScene.ordinary,
    this.amortizationDeferralAccountId,
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
       selectedTagIds = Set.unmodifiable(selectedTagIds),
       categoryAllocations = List.unmodifiable(categoryAllocations),
       settlementAllocations = List.unmodifiable(settlementAllocations);

  factory TransactionFormState.initial({
    required TransactionFormMode mode,
    String? fromAccountId,
    String? toAccountId,
    String? liabilityAccountId,
    AmortizationKind? initialAmortizationKind,
    String? initialAmortizationDeferralAccountId,
    required TransactionAccountOptions accountOptions,
    required List<CategoryNode> expenseTree,
    required List<CategoryNode> incomeTree,
    required List<TagView> tags,
    required List<CounterpartyView> counterparties,
  }) {
    final amortizationDeferralAccounts =
        initialAmortizationKind == AmortizationKind.prepaidExpense
        ? accountOptions.prepaidExpenseAccounts
        : initialAmortizationKind == AmortizationKind.deferredIncome
        ? accountOptions.deferredIncomeAccounts
        : const <Account>[];
    return TransactionFormState(
      initialValues: const TransactionFormInitialValues(),
      mode: mode,
      relationScene: transactionRelationSceneForMode(mode),
      entryMode: TransactionEntryMode.normal,
      occurredAt: DateTime.now(),
      excludeStats: false,
      excludeBudget: false,
      submitting: false,
      fromAccountId:
          mode == TransactionFormMode.expense &&
              initialAmortizationKind == AmortizationKind.prepaidExpense
          ? fromAccountId ??
                accountOptions.fundAccounts.firstOrNull?.id ??
                accountOptions.settlementAccounts.firstOrNull?.id
          : fromAccountId,
      toAccountId:
          mode == TransactionFormMode.lending ||
              mode == TransactionFormMode.borrowing
          ? null
          : mode == TransactionFormMode.income &&
                initialAmortizationKind == AmortizationKind.deferredIncome
          ? toAccountId ??
                accountOptions.fundAccounts.firstOrNull?.id ??
                accountOptions.settlementAccounts.firstOrNull?.id
          : toAccountId,
      ordinaryReceivableAccountId: mode == TransactionFormMode.lending
          ? toAccountId
          : null,
      liabilityAccountId: mode == TransactionFormMode.borrowing
          ? liabilityAccountId
          : null,
      expenseScene:
          mode == TransactionFormMode.expense &&
              initialAmortizationKind == AmortizationKind.prepaidExpense
          ? TransactionExpenseScene.amortization
          : TransactionExpenseScene.ordinary,
      incomeScene:
          mode == TransactionFormMode.income &&
              initialAmortizationKind == AmortizationKind.deferredIncome
          ? TransactionIncomeScene.amortization
          : TransactionIncomeScene.ordinary,
      amortizationDeferralAccountId: initialAmortizationKind == null
          ? null
          : initialAmortizationDeferralAccountId ??
                amortizationDeferralAccounts.firstOrNull?.id,
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

  factory TransactionFormState.fromAmortizationPlan({
    required AmortizationPlan plan,
    required TransactionReadModel initialTransaction,
    required TransactionAccountOptions accountOptions,
    required List<CategoryNode> expenseTree,
    required List<CategoryNode> incomeTree,
    required List<TagView> tags,
    required List<CounterpartyView> counterparties,
    required Set<String> initialTagIds,
  }) {
    final prepaid = plan.kind == AmortizationKind.prepaidExpense;
    final mode = prepaid
        ? TransactionFormMode.expense
        : TransactionFormMode.income;
    final usesAllocatedEntry =
        plan.categoryAllocations.length > 1 ||
        plan.fundingAllocations.length > 1;
    final categoryId = plan.categoryAllocations.length == 1
        ? plan.categoryAllocations.single.accountId
        : null;
    final fundingAccountId = plan.fundingAllocations.length == 1
        ? plan.fundingAllocations.single.accountId
        : null;
    final fee = initialTransaction.amountOf(TransactionRole.fee);
    final configuration = AmortizationConfigurationDraft(
      firstRecognitionAt: plan.firstRecognitionAt,
      cadenceUnit: plan.cadenceUnit,
      cadenceInterval: plan.cadenceInterval,
      recognitionCount: plan.recognitionCount,
    );
    return TransactionFormState(
      initialValues: TransactionFormInitialValues(
        amount: formatMoney(plan.originalAmount, style: MoneyFormatStyle.plain),
        fee: fee.minorUnits == 0
            ? ''
            : formatMoney(fee, style: MoneyFormatStyle.plain),
        note: initialTransaction.note ?? '',
        amortizationConfiguration: configuration,
      ),
      mode: mode,
      entryMode: usesAllocatedEntry
          ? TransactionEntryMode.allocated
          : TransactionEntryMode.normal,
      occurredAt: initialTransaction.occurredAt,
      selectedTagIds: initialTagIds,
      counterpartyId: initialTransaction.counterpartyId,
      expenseCategoryId: !usesAllocatedEntry && prepaid ? categoryId : null,
      expenseRootId: !usesAllocatedEntry && prepaid
          ? _rootCategoryId(expenseTree, categoryId)
          : null,
      incomeCategoryId: !usesAllocatedEntry && !prepaid ? categoryId : null,
      incomeRootId: !usesAllocatedEntry && !prepaid
          ? _rootCategoryId(incomeTree, categoryId)
          : null,
      fromAccountId: prepaid && !usesAllocatedEntry ? fundingAccountId : null,
      toAccountId: !prepaid && !usesAllocatedEntry ? fundingAccountId : null,
      expenseScene: prepaid
          ? TransactionExpenseScene.amortization
          : TransactionExpenseScene.ordinary,
      incomeScene: prepaid
          ? TransactionIncomeScene.ordinary
          : TransactionIncomeScene.amortization,
      amortizationDeferralAccountId: plan.deferralAccountId,
      categoryAllocations: usesAllocatedEntry
          ? plan.categoryAllocations
          : const [],
      settlementAllocations: usesAllocatedEntry
          ? plan.fundingAllocations
          : const [],
      excludeStats: initialTransaction.isExcludedFromStats,
      excludeBudget: initialTransaction.isExcludedFromBudget,
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
  final TransactionIncomeScene incomeScene;
  final String? amortizationDeferralAccountId;
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
  List<Account> get prepaidExpenseAccounts =>
      accountOptions.prepaidExpenseAccounts;
  List<Account> get deferredIncomeAccounts =>
      accountOptions.deferredIncomeAccounts;

  bool get isAmortization =>
      (mode == TransactionFormMode.expense &&
          expenseScene == TransactionExpenseScene.amortization) ||
      (mode == TransactionFormMode.income &&
          incomeScene == TransactionIncomeScene.amortization);

  AmortizationKind? get amortizationKind {
    if (mode == TransactionFormMode.expense &&
        expenseScene == TransactionExpenseScene.amortization) {
      return AmortizationKind.prepaidExpense;
    }
    if (mode == TransactionFormMode.income &&
        incomeScene == TransactionIncomeScene.amortization) {
      return AmortizationKind.deferredIncome;
    }
    return null;
  }

  List<Account> get amortizationDeferralAccounts =>
      amortizationKind == AmortizationKind.deferredIncome
      ? deferredIncomeAccounts
      : prepaidExpenseAccounts;

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
    TransactionIncomeScene? incomeScene,
    Object? amortizationDeferralAccountId = _sentinel,
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
      incomeScene: incomeScene ?? this.incomeScene,
      amortizationDeferralAccountId: amortizationDeferralAccountId == _sentinel
          ? this.amortizationDeferralAccountId
          : amortizationDeferralAccountId as String?,
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
    this.amortizationConfiguration,
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
  final AmortizationConfigurationDraft? amortizationConfiguration;
}

String? _rootCategoryId(List<CategoryNode> tree, String? categoryId) {
  if (categoryId == null) return null;
  for (final node in tree) {
    if (node.account.id == categoryId) return node.account.id;
    if (node.children.any((child) => child.id == categoryId)) {
      return node.account.id;
    }
  }
  return null;
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
