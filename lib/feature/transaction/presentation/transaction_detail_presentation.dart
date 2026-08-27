import '../../../application/ledger/ledger_query_api.dart';
import '../../../core/money/money.dart';
import '../../shared/presentation/transaction_detail_amount.dart';
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

class DetailAllocationBreakdown {
  const DetailAllocationBreakdown({
    required this.kind,
    required this.title,
    required this.items,
  });

  final DetailAllocationKind kind;
  final String title;
  final List<DetailAllocationItem> items;
}

enum DetailAllocationKind { category, account }

class DetailAllocationItem {
  const DetailAllocationItem({
    required this.title,
    required this.amount,
    this.iconKey,
  });

  final String title;
  final String? iconKey;
  final Money amount;
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
  required TransactionReadModel detail,
  required AccountLookup accountLookup,
}) {
  final transaction = detail;
  final semantic = semanticForTransactionPurpose(transaction.businessPurpose);
  final categoryLines = detail.categoryLines.toList();
  final hasMultipleCategories = categoryLines.length > 1;
  final category = _resolveCategoryAccount(detail, accountLookup);
  final title = hasMultipleCategories
      ? '多分类'
      : category?.name ?? transactionPurposeLabel(transaction.businessPurpose);
  final counterparty = transaction.counterpartyName;
  final subtitle = counterparty != null && counterparty.isNotEmpty
      ? counterparty
      : null;

  return DetailHero(
    title: title,
    subtitle: subtitle,
    iconKey: hasMultipleCategories ? null : category?.iconKey,
    amount: signedAmountForSemantic(transaction.primaryAmount, semantic),
    semantic: semantic,
    showSign: semantic == MoneySemantic.income,
  );
}

List<DetailAllocationBreakdown> transactionDetailAllocationBreakdowns({
  required TransactionReadModel detail,
  required AccountLookup accountLookup,
}) {
  final result = <DetailAllocationBreakdown>[];
  final categories = detail.categoryLines.toList();
  if (categories.length > 1) {
    result.add(
      DetailAllocationBreakdown(
        kind: DetailAllocationKind.category,
        title: '分类构成',
        items: [
          for (final line in categories) _allocationItem(line, accountLookup),
        ],
      ),
    );
  }

  final settlements = detail.settlementLines.toList();
  if (settlements.length > 1) {
    final roles = settlements.map((line) => line.role).toSet();
    if (roles.length == 1) {
      result.add(
        DetailAllocationBreakdown(
          kind: DetailAllocationKind.account,
          title: '账户构成',
          items: [
            for (final line in settlements)
              _allocationItem(line, accountLookup),
          ],
        ),
      );
    }
  }
  return result;
}

List<DetailSheetItem> refundSheetItems(
  Iterable<TransactionReadModel> children,
) {
  return children
      .where((child) => child.businessPurpose == BusinessPurpose.refund)
      .map(_listItemToSheetItem)
      .toList(growable: false);
}

List<DetailSheetItem> reimbursementSheetItems(
  Iterable<TransactionReadModel> children,
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

String formatTransactionDetailDateTime(DateTime value) {
  String two(int n) => n.toString().padLeft(2, '0');
  return '${value.year}年${two(value.month)}月${two(value.day)}日 '
      '${two(value.hour)}:${two(value.minute)}';
}

Money? transactionTransferFee(TransactionReadModel detail) {
  if (detail.businessPurpose != BusinessPurpose.transfer) {
    return null;
  }
  final amount = sumTransactionLineAmount(detail, TransactionRole.fee);
  return amount.minorUnits > 0 ? amount : null;
}

MoneySemantic semanticForTransactionPurpose(BusinessPurpose purpose) {
  return switch (purpose) {
    BusinessPurpose.dailyExpense ||
    BusinessPurpose.reimbursementAdvance ||
    BusinessPurpose.debtRepayment => MoneySemantic.expense,
    BusinessPurpose.badDebt => MoneySemantic.expense,
    BusinessPurpose.dailyIncome ||
    BusinessPurpose.refund ||
    BusinessPurpose.reimbursementReceipt ||
    BusinessPurpose.reimbursementClose ||
    BusinessPurpose.borrowing => MoneySemantic.income,
    BusinessPurpose.debtRelief => MoneySemantic.income,
    BusinessPurpose.transfer ||
    BusinessPurpose.lending ||
    BusinessPurpose.receivableCollection ||
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

DetailSheetItem _listItemToSheetItem(TransactionReadModel item) {
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
  TransactionReadModel detail,
  AccountLookup accountLookup,
) {
  final categoryId = detail.categoryLines.firstOrNull?.accountId;
  return categoryId == null ? null : accountLookup.find(categoryId);
}

DetailAllocationItem _allocationItem(
  TransactionLine line,
  AccountLookup accountLookup,
) {
  final account = accountLookup.find(line.accountId!);
  return DetailAllocationItem(
    title: account?.name ?? line.accountId!,
    iconKey: account?.iconKey,
    amount: line.amount,
  );
}
