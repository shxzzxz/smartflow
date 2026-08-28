import '../../../application/ledger/ledger_query_api.dart';
import '../../../core/money/money.dart';
import '../../../core/money/money_formatter.dart';
import '../../shared/presentation/transaction_detail_amount.dart';

enum TransactionFormMode { expense, income, transfer, borrowing, lending }

class TransactionFormEditSnapshot {
  const TransactionFormEditSnapshot({
    required this.mode,
    required this.amountText,
    required this.noteText,
    required this.occurredAt,
    required this.excludeStats,
    required this.excludeBudget,
    this.feeText = '',
    this.expenseCategoryId,
    this.expenseRootId,
    this.incomeCategoryId,
    this.incomeRootId,
    this.fromAccountId,
    this.toAccountId,
    this.reimbursementAccountId,
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
  final String feeText;
  final String? expenseCategoryId;
  final String? expenseRootId;
  final String? incomeCategoryId;
  final String? incomeRootId;
  final String? fromAccountId;
  final String? toAccountId;
  final String? reimbursementAccountId;
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
    BusinessPurpose.reimbursementAdvance ||
    BusinessPurpose.borrowing => true,
    BusinessPurpose.lending => true,
    BusinessPurpose.refund ||
    BusinessPurpose.reimbursementReceipt ||
    BusinessPurpose.reimbursementClose ||
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
        noteText: noteText,
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
    case BusinessPurpose.reimbursementAdvance:
      final categories = _allocationsOf(
        detail,
        TransactionRole.reimbursementExpenseCategory,
      );
      final settlements = _allocationsOf(detail, TransactionRole.settlementOut);
      final categoryId = transaction.accountOf(
        TransactionRole.reimbursementExpenseCategory,
      );
      return TransactionFormEditSnapshot(
        mode: TransactionFormMode.expense,
        amountText: amountText,
        noteText: noteText,
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
        reimbursementAccountId: detail.accountOf(TransactionRole.receivable),
        categoryAllocations: categories,
        settlementAllocations: settlements,
      );
    case BusinessPurpose.dailyIncome:
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
        occurredAt: transaction.occurredAt,
        excludeStats: transaction.isExcludedFromStats,
        excludeBudget: false,
        incomeCategoryId: categoryId,
        incomeRootId: rootCategoryId(incomeTree, categoryId),
        toAccountId: settlementAccountId(
          detail,
          accountsById,
          EntryDirection.debit,
        ),
      );
    case BusinessPurpose.transfer:
      return TransactionFormEditSnapshot(
        mode: TransactionFormMode.transfer,
        amountText: amountText,
        feeText: _lineAmountText(detail, TransactionRole.fee),
        noteText: noteText,
        occurredAt: transaction.occurredAt,
        excludeStats: false,
        excludeBudget: false,
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
        occurredAt: transaction.occurredAt,
        excludeStats: false,
        excludeBudget: false,
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
        occurredAt: transaction.occurredAt,
        excludeStats: false,
        excludeBudget: true,
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
    case BusinessPurpose.reimbursementReceipt:
    case BusinessPurpose.reimbursementClose:
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

String? reimbursementReceivableAccountId(
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
