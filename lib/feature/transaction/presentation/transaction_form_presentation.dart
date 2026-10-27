import '../../../application/ledger/ledger_query_api.dart';
import '../../../application/orchestration/orchestration_command_api.dart';
import '../../../core/money/money.dart';
import '../../../core/money/money_formatter.dart';
import '../../../shared/account_profile/account_profile_kind.dart';
import '../../shared/presentation/transaction_detail_amount.dart';

enum TransactionFormMode { expense, income, transfer, borrowing, lending }

/// 支出录入的业务场景。它只在 feature 层组织入口与账户候选，
/// 最终交给交易编排域创建垫付编排实例。
enum TransactionExpenseScene {
  ordinary,
  reimbursement,
  onBehalf,
  aa,
  reimbursementAccount,
  aaAccount,
}

extension TransactionExpenseScenePresentation on TransactionExpenseScene {
  String get label => switch (this) {
    TransactionExpenseScene.ordinary => '普通支出',
    TransactionExpenseScene.reimbursement => '报销',
    TransactionExpenseScene.onBehalf => '代付',
    TransactionExpenseScene.aa => 'AA',
    TransactionExpenseScene.reimbursementAccount => '报销（账户）',
    TransactionExpenseScene.aaAccount => 'AA（账户）',
  };

  bool get isAdvance => this != TransactionExpenseScene.ordinary;

  bool get isAa =>
      this == TransactionExpenseScene.aa ||
      this == TransactionExpenseScene.aaAccount;

  String get accountLabel => switch (this) {
    TransactionExpenseScene.reimbursement ||
    TransactionExpenseScene.reimbursementAccount => '报销账户',
    TransactionExpenseScene.onBehalf ||
    TransactionExpenseScene.aa ||
    TransactionExpenseScene.aaAccount => '垫付账户',
    TransactionExpenseScene.ordinary => '垫付账户',
  };

  String get noneLabel => switch (this) {
    TransactionExpenseScene.reimbursement ||
    TransactionExpenseScene.reimbursementAccount => '不报销',
    TransactionExpenseScene.onBehalf => '不代付',
    TransactionExpenseScene.aa || TransactionExpenseScene.aaAccount => '不AA',
    TransactionExpenseScene.ordinary => '不垫付',
  };

  AdvanceScenario? get advanceScenario => switch (this) {
    TransactionExpenseScene.ordinary => null,
    TransactionExpenseScene.reimbursement ||
    TransactionExpenseScene.reimbursementAccount =>
      AdvanceScenario.reimbursement,
    TransactionExpenseScene.onBehalf => AdvanceScenario.onBehalf,
    TransactionExpenseScene.aa ||
    TransactionExpenseScene.aaAccount => AdvanceScenario.aa,
  };

  AdvanceTrackingMode? get advanceTrackingMode => switch (this) {
    TransactionExpenseScene.ordinary => null,
    TransactionExpenseScene.reimbursement ||
    TransactionExpenseScene.onBehalf ||
    TransactionExpenseScene.aa => AdvanceTrackingMode.itemized,
    TransactionExpenseScene.reimbursementAccount ||
    TransactionExpenseScene.aaAccount => AdvanceTrackingMode.account,
  };
}

TransactionExpenseScene transactionExpenseSceneForAdvanceScenario(
  AdvanceScenario scenario, {
  AdvanceTrackingMode trackingMode = AdvanceTrackingMode.itemized,
}) {
  return switch (scenario) {
    AdvanceScenario.reimbursement =>
      trackingMode == AdvanceTrackingMode.account
          ? TransactionExpenseScene.reimbursementAccount
          : TransactionExpenseScene.reimbursement,
    AdvanceScenario.onBehalf
        when trackingMode == AdvanceTrackingMode.itemized =>
      TransactionExpenseScene.onBehalf,
    AdvanceScenario.onBehalf => throw ArgumentError.value(
      trackingMode,
      'trackingMode',
      '代付不支持账户垫付',
    ),
    AdvanceScenario.aa =>
      trackingMode == AdvanceTrackingMode.account
          ? TransactionExpenseScene.aaAccount
          : TransactionExpenseScene.aa,
  };
}

List<Account> advanceAccountsForExpenseScene(
  TransactionExpenseScene scene,
  Iterable<Account> accounts,
) {
  final acceptedProfiles = switch (scene) {
    TransactionExpenseScene.ordinary => const <String>{},
    TransactionExpenseScene.reimbursement ||
    TransactionExpenseScene.reimbursementAccount => {
      AccountProfileKind.reimbursement.key,
    },
    TransactionExpenseScene.onBehalf || TransactionExpenseScene.aa => {
      AccountProfileKind.reimbursement.key,
      AccountProfileKind.receivable.key,
    },
    TransactionExpenseScene.aaAccount => {AccountProfileKind.receivable.key},
  };
  return [
    for (final account in accounts)
      if (acceptedProfiles.contains(account.profileKey)) account,
  ];
}

Money selfBorneAmountForExpenseScene({
  required TransactionExpenseScene scene,
  required Money total,
  required int aaPeopleCount,
}) {
  return calculateAdvanceEntrySplit(
    scenario: scene.advanceScenario ?? AdvanceScenario.reimbursement,
    total: total,
    aaPeopleCount: aaPeopleCount,
    categoryAllocations: const [],
  ).selfBorneAmount;
}

Money advanceAmountForExpenseScene({
  required TransactionExpenseScene scene,
  required Money total,
  required int aaPeopleCount,
}) {
  return calculateAdvanceEntrySplit(
    scenario: scene.advanceScenario ?? AdvanceScenario.reimbursement,
    total: total,
    aaPeopleCount: aaPeopleCount,
    categoryAllocations: const [],
  ).advanceAmount;
}

class TransactionFormEditSnapshot {
  const TransactionFormEditSnapshot({
    required this.mode,
    required this.amountText,
    required this.noteText,
    required this.occurredAt,
    required this.excludeStats,
    required this.excludeBudget,
    this.counterpartyId,
    this.feeText = '',
    this.advanceAmountText = '',
    this.advanceScenario = AdvanceScenario.reimbursement,
    this.advanceTrackingMode = AdvanceTrackingMode.itemized,
    this.advanceAaPeopleCount,
    this.expenseCategoryId,
    this.expenseRootId,
    this.incomeCategoryId,
    this.incomeRootId,
    this.fromAccountId,
    this.toAccountId,
    this.advanceReceivableAccountId,
    this.ordinaryReceivableAccountId,
    this.liabilityAccountId,
    this.categoryAllocations,
    this.settlementAllocations,
  });

  final TransactionFormMode mode;
  final String amountText;
  final String noteText;
  final DateTime occurredAt;
  final bool excludeStats;
  final bool excludeBudget;
  final String? counterpartyId;
  final String feeText;
  final String advanceAmountText;
  final AdvanceScenario advanceScenario;
  final AdvanceTrackingMode advanceTrackingMode;
  final int? advanceAaPeopleCount;
  final String? expenseCategoryId;
  final String? expenseRootId;
  final String? incomeCategoryId;
  final String? incomeRootId;
  final String? fromAccountId;
  final String? toAccountId;
  final String? advanceReceivableAccountId;
  final String? ordinaryReceivableAccountId;
  final String? liabilityAccountId;
  final List<AccountAmountAllocation>? categoryAllocations;
  final List<AccountAmountAllocation>? settlementAllocations;
}

bool supportsTransactionFormEdit(BusinessPurpose purpose) {
  return switch (purpose) {
    BusinessPurpose.dailyExpense ||
    BusinessPurpose.dailyIncome ||
    BusinessPurpose.transfer ||
    BusinessPurpose.advance ||
    BusinessPurpose.borrowing => true,
    BusinessPurpose.lending => true,
    BusinessPurpose.refund ||
    BusinessPurpose.advanceCollection ||
    BusinessPurpose.advanceSettlement ||
    BusinessPurpose.debtRepayment ||
    BusinessPurpose.openingBalance ||
    BusinessPurpose.balanceAdjustment => false,
    BusinessPurpose.receivableCollection ||
    BusinessPurpose.badDebt ||
    BusinessPurpose.debtRelief => false,
  };
}

TransactionFormEditSnapshot transactionFormEditSnapshot({
  required TransactionReadModel detail,
  required List<CategoryNode> expenseTree,
  required List<CategoryNode> incomeTree,
  required Map<String, Account> accountsById,
  AdvanceCase? advanceCase,
}) {
  final transaction = detail;
  final amountText = formatMoney(
    transaction.primaryAmount,
    style: MoneyFormatStyle.plain,
  );
  final noteText = transaction.note ?? '';

  switch (transaction.businessPurpose) {
    case BusinessPurpose.dailyExpense:
      final categories = _allocationsOf(detail, TransactionRole.category);
      final settlements = _allocationsOf(detail, TransactionRole.settlementOut);
      final categoryId = _firstAccountId(
        detail,
        accountsById,
        AccountType.expense,
        EntryDirection.debit,
      );
      return TransactionFormEditSnapshot(
        mode: TransactionFormMode.expense,
        amountText: amountText,
        advanceAmountText: amountText,
        noteText: noteText,
        counterpartyId: transaction.counterpartyId,
        occurredAt: transaction.occurredAt,
        excludeStats: transaction.isExcludedFromStats,
        excludeBudget: transaction.isExcludedFromBudget,
        expenseCategoryId: categoryId,
        expenseRootId: rootCategoryId(expenseTree, categoryId),
        fromAccountId: settlementAccountId(
          detail,
          accountsById,
          EntryDirection.credit,
        ),
        categoryAllocations: categories,
        settlementAllocations: settlements,
      );
    case BusinessPurpose.advance:
      final categories = _allocationsOf(
        detail,
        TransactionRole.advanceExpenseCategory,
      );
      final settlements = _allocationsOf(detail, TransactionRole.settlementOut);
      final categoryId = transaction.accountOf(
        TransactionRole.advanceExpenseCategory,
      );
      return TransactionFormEditSnapshot(
        mode: TransactionFormMode.expense,
        amountText: amountText,
        advanceAmountText: _lineAmountText(detail, TransactionRole.receivable),
        advanceScenario: advanceCase?.scenario ?? AdvanceScenario.reimbursement,
        advanceTrackingMode:
            advanceCase?.trackingMode ?? AdvanceTrackingMode.itemized,
        advanceAaPeopleCount: advanceCase?.aaPeopleCount,
        noteText: noteText,
        counterpartyId: transaction.counterpartyId,
        occurredAt: transaction.occurredAt,
        excludeStats: transaction.isExcludedFromStats,
        excludeBudget: transaction.isExcludedFromBudget,
        expenseCategoryId: categoryId,
        expenseRootId: rootCategoryId(expenseTree, categoryId),
        fromAccountId: settlementAccountId(
          detail,
          accountsById,
          EntryDirection.credit,
        ),
        advanceReceivableAccountId: detail.accountOf(
          TransactionRole.receivable,
        ),
        categoryAllocations: categories,
        settlementAllocations: settlements,
      );
    case BusinessPurpose.dailyIncome:
      final categories = _allocationsOf(detail, TransactionRole.category);
      final settlements = _allocationsOf(detail, TransactionRole.settlementIn);
      final categoryId = _firstAccountId(
        detail,
        accountsById,
        AccountType.income,
        EntryDirection.credit,
      );
      return TransactionFormEditSnapshot(
        mode: TransactionFormMode.income,
        amountText: amountText,
        noteText: noteText,
        counterpartyId: transaction.counterpartyId,
        occurredAt: transaction.occurredAt,
        excludeStats: transaction.isExcludedFromStats,
        excludeBudget: transaction.isExcludedFromBudget,
        incomeCategoryId: categoryId,
        incomeRootId: rootCategoryId(incomeTree, categoryId),
        toAccountId: settlementAccountId(
          detail,
          accountsById,
          EntryDirection.debit,
        ),
        categoryAllocations: categories,
        settlementAllocations: settlements,
      );
    case BusinessPurpose.transfer:
      return TransactionFormEditSnapshot(
        mode: TransactionFormMode.transfer,
        amountText: amountText,
        feeText: _lineAmountText(detail, TransactionRole.fee),
        noteText: noteText,
        counterpartyId: transaction.counterpartyId,
        occurredAt: transaction.occurredAt,
        excludeStats: transaction.isExcludedFromStats,
        excludeBudget: transaction.isExcludedFromBudget,
        fromAccountId: settlementAccountId(
          detail,
          accountsById,
          EntryDirection.credit,
        ),
        toAccountId: settlementAccountId(
          detail,
          accountsById,
          EntryDirection.debit,
        ),
      );
    case BusinessPurpose.borrowing:
      return TransactionFormEditSnapshot(
        mode: TransactionFormMode.borrowing,
        amountText: amountText,
        noteText: noteText,
        counterpartyId: transaction.counterpartyId,
        occurredAt: transaction.occurredAt,
        excludeStats: transaction.isExcludedFromStats,
        excludeBudget: transaction.isExcludedFromBudget,
        liabilityAccountId: _firstAccountId(
          detail,
          accountsById,
          AccountType.liability,
          EntryDirection.credit,
        ),
        toAccountId: settlementAccountId(
          detail,
          accountsById,
          EntryDirection.debit,
        ),
      );
    case BusinessPurpose.lending:
      return TransactionFormEditSnapshot(
        mode: TransactionFormMode.lending,
        amountText: amountText,
        noteText: noteText,
        counterpartyId: transaction.counterpartyId,
        occurredAt: transaction.occurredAt,
        excludeStats: transaction.isExcludedFromStats,
        excludeBudget: transaction.isExcludedFromBudget,
        ordinaryReceivableAccountId: _firstAccountId(
          detail,
          accountsById,
          AccountType.asset,
          EntryDirection.debit,
        ),
        fromAccountId: settlementAccountId(
          detail,
          accountsById,
          EntryDirection.credit,
        ),
      );
    case BusinessPurpose.refund:
    case BusinessPurpose.advanceCollection:
    case BusinessPurpose.advanceSettlement:
    case BusinessPurpose.debtRepayment:
    case BusinessPurpose.openingBalance:
    case BusinessPurpose.balanceAdjustment:
    case BusinessPurpose.receivableCollection:
    case BusinessPurpose.badDebt:
    case BusinessPurpose.debtRelief:
      throw ArgumentError.value(
        transaction.businessPurpose,
        'detail.businessPurpose',
        '该交易类型不支持通用交易编辑表单',
      );
  }
}

String _lineAmountText(TransactionReadModel detail, TransactionRole role) {
  final amount = sumTransactionLineAmount(detail, role);
  if (amount.minorUnits <= 0) return '';
  return formatMoney(amount, style: MoneyFormatStyle.plain);
}

String? rootCategoryId(List<CategoryNode> tree, String? categoryId) {
  if (categoryId == null) return null;
  for (final node in tree) {
    if (node.account.id == categoryId) return node.account.id;
    for (final child in node.children) {
      if (child.id == categoryId) return node.account.id;
    }
  }
  return categoryId;
}

String? effectiveRefundToAccountId({
  required String? selectedId,
  required String? parentSettlementAccountId,
  required List<Account> accounts,
}) {
  if (_containsAccountId(accounts, selectedId)) {
    return selectedId;
  }
  if (_containsAccountId(accounts, parentSettlementAccountId)) {
    return parentSettlementAccountId;
  }
  return null;
}

String? parentSettlementAccountIdForRefund(
  TransactionReadModel? detail,
  Map<String, Account> accountsById,
) {
  if (detail == null) return null;
  return settlementAccountId(detail, accountsById, EntryDirection.credit);
}

/// Returns empty allocation rows for every eligible account that funded the
/// original transaction. A single source account keeps the legacy fallback
/// behavior so its amount can follow the form total automatically.
List<AccountAmountAllocation>? defaultSettlementAllocationsForRefund({
  required TransactionReadModel detail,
  required Iterable<Account> accounts,
}) {
  final eligibleIds = accounts.map((account) => account.id).toSet();
  final sourceAccountIds = <String>[];
  for (final line in detail.linesOf(TransactionRole.settlementOut)) {
    final accountId = line.accountId;
    if (accountId == null ||
        !eligibleIds.contains(accountId) ||
        sourceAccountIds.contains(accountId)) {
      continue;
    }
    sourceAccountIds.add(accountId);
  }
  final sourceAllocations = [
    for (final accountId in sourceAccountIds)
      AccountAmountAllocation(accountId: accountId, amount: Money.zero()),
  ];
  return sourceAllocations.length > 1 ? sourceAllocations : null;
}

String? advanceReceivableAccountId(
  TransactionReadModel? detail,
  Map<String, Account> accountsById,
) {
  if (detail == null) return null;
  return detail.accountOf(TransactionRole.receivable);
}

bool _containsAccountId(List<Account> accounts, String? accountId) {
  if (accountId == null) return false;
  return accounts.any((account) => account.id == accountId);
}

String? _firstAccountId(
  TransactionReadModel detail,
  Map<String, Account> accountsById,
  AccountType type,
  EntryDirection direction,
) {
  final role = switch (type) {
    AccountType.expense || AccountType.income => TransactionRole.category,
    AccountType.asset => TransactionRole.receivable,
    AccountType.liability => TransactionRole.liability,
    AccountType.equity => null,
  };
  return role == null ? null : detail.accountOf(role);
}

String? settlementAccountId(
  TransactionReadModel detail,
  Map<String, Account> accountsById,
  EntryDirection direction,
) {
  final role = direction == EntryDirection.debit
      ? TransactionRole.settlementIn
      : TransactionRole.settlementOut;
  return detail.accountOf(role);
}

List<AccountAmountAllocation> _allocationsOf(
  TransactionReadModel detail,
  TransactionRole role,
) {
  return [
    for (final line in detail.linesOf(role))
      AccountAmountAllocation(accountId: line.accountId!, amount: line.amount),
  ];
}
