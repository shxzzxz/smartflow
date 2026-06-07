import '../../../application/ledger/ledger_query_api.dart';
import '../../../core/money/money.dart';
import 'package:smartflow/feature/shared/presentation/account_lookup.dart';
import 'package:smartflow/widget/business/finance/finance_labels.dart';
import 'package:smartflow/widget/business/finance/money_text.dart';

class DetailHero {
  const DetailHero({
    required this.title,
    required this.amount,
    required this.semantic,
    required this.showSign,
    this.subtitle,
    this.iconKey,
  });

  final String title;
  final String? subtitle;
  final String? iconKey;
  final Money amount;
  final MoneySemantic semantic;
  final bool showSign;
}

class DetailSheetItem {
  const DetailSheetItem({
    required this.id,
    required this.title,
    required this.occurredAtText,
    required this.amount,
    required this.semantic,
    required this.showSign,
  });

  final String id;
  final String title;
  final String occurredAtText;
  final Money amount;
  final MoneySemantic semantic;
  final bool showSign;
}

DetailHero transactionDetailHero({
  required TransactionDetail detail,
  required AccountLookup accountLookup,
}) {
  final transaction = detail.transaction;
  final semantic = semanticForTransactionPurpose(transaction.businessPurpose);
  final category = _resolveCategoryAccount(detail, accountLookup);
  final title =
      category?.name ?? transactionPurposeLabel(transaction.businessPurpose);
  final counterparty = transaction.counterpartyName;
  final subtitle =
      counterparty != null && counterparty.isNotEmpty ? counterparty : null;

  return DetailHero(
    title: title,
    subtitle: subtitle,
    iconKey: category?.iconKey,
    amount: signedAmountForSemantic(transaction.primaryAmount, semantic),
    semantic: semantic,
    showSign: semantic == MoneySemantic.income,
  );
}

List<DetailSheetItem> refundSheetItems(
  Iterable<TransactionListReadModel> children,
) {
  return children
      .where((child) => child.businessPurpose == BusinessPurpose.refund)
      .map(_listItemToSheetItem)
      .toList(growable: false);
}

List<DetailSheetItem> reimbursementSheetItems(
  Iterable<TransactionListReadModel> children,
) {
  return children
      .where(
        (child) =>
            child.businessPurpose == BusinessPurpose.reimbursementReceipt ||
            child.businessPurpose == BusinessPurpose.reimbursementClose,
      )
      .map(_listItemToSheetItem)
      .toList(growable: false);
}

List<DetailSheetItem> historySheetItems(
  Iterable<TransactionHistorySnapshot> history,
) {
  return history
      .map((item) {
        final semantic = semanticForTransactionPurpose(item.businessPurpose);
        return DetailSheetItem(
          id: item.id,
          title: transactionPurposeLabel(item.businessPurpose),
          occurredAtText: formatTransactionDetailDateTime(item.occurredAt),
          amount: signedAmountForSemantic(item.primaryAmount, semantic),
          semantic: semantic,
          showSign: semantic == MoneySemantic.income,
        );
      })
      .toList(growable: false);
}

String formatTransactionDetailDateTime(DateTime value) {
  String two(int n) => n.toString().padLeft(2, '0');
  return '${value.year}年${two(value.month)}月${two(value.day)}日 '
      '${two(value.hour)}:${two(value.minute)}';
}

MoneySemantic semanticForTransactionPurpose(BusinessPurpose purpose) {
  return switch (purpose) {
    BusinessPurpose.dailyExpense ||
    BusinessPurpose.reimbursementAdvance ||
    BusinessPurpose.debtRepayment => MoneySemantic.expense,
    BusinessPurpose.dailyIncome ||
    BusinessPurpose.refund ||
    BusinessPurpose.reimbursementReceipt ||
    BusinessPurpose.reimbursementClose ||
    BusinessPurpose.borrowing => MoneySemantic.income,
    BusinessPurpose.transfer ||
    BusinessPurpose.openingBalance ||
    BusinessPurpose.balanceAdjustment => MoneySemantic.neutral,
  };
}

Money signedAmountForSemantic(Money money, MoneySemantic semantic) {
  if (semantic == MoneySemantic.expense) {
    return Money(minorUnits: -money.minorUnits);
  }
  return money;
}

DetailSheetItem _listItemToSheetItem(TransactionListReadModel item) {
  final semantic = semanticForTransactionPurpose(item.businessPurpose);
  return DetailSheetItem(
    id: item.id,
    title: transactionPurposeLabel(item.businessPurpose),
    occurredAtText: formatTransactionDetailDateTime(item.occurredAt),
    amount: signedAmountForSemantic(item.primaryAmount, semantic),
    semantic: semantic,
    showSign: semantic == MoneySemantic.income,
  );
}

Account? _resolveCategoryAccount(
  TransactionDetail detail,
  AccountLookup accountLookup,
) {
  final purpose = detail.transaction.businessPurpose;
  if (purpose == BusinessPurpose.dailyExpense ||
      purpose == BusinessPurpose.refund) {
    final entry = accountLookup.firstEntryByType(
      detail.entries,
      accountType: AccountType.expense,
    );
    return entry == null ? null : accountLookup.accountOf(entry);
  }
  if (purpose == BusinessPurpose.dailyIncome) {
    final entry = accountLookup.firstEntryByType(
      detail.entries,
      accountType: AccountType.income,
    );
    return entry == null ? null : accountLookup.accountOf(entry);
  }
  if (purpose == BusinessPurpose.reimbursementAdvance) {
    final expenseId = detail.transaction.reimbursementExpenseAccountId;
    if (expenseId != null) {
      return accountLookup.find(expenseId);
    }
  }
  return null;
}
