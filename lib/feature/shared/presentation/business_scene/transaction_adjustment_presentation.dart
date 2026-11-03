import 'package:smartflow/application/ledger/ledger_query_api.dart';
import 'package:smartflow/core/money/money.dart';
import 'package:smartflow/core/money/money_formatter.dart';

enum TransactionAdjustmentKind {
  transferFee,
  refund,
  advanceReceived,
  receivableCollectionPrincipal,
  receivableCollectionInterest,
  repaymentInterest,
  repaymentFee,
  repaymentDiscount,
  advanceCompensationIncome,
  advanceSelfBorne,
  advanceBadDebt,
}

class TransactionAdjustment {
  const TransactionAdjustment({required this.kind, required this.amount});

  final TransactionAdjustmentKind kind;
  final Money amount;
}

List<String> adjustmentSupportingParts(TransactionReadModel transaction) {
  final parts = <String>[];
  for (final adjustment in transactionAdjustments(transaction)) {
    if (adjustment.kind == TransactionAdjustmentKind.refund ||
        adjustment.kind ==
            TransactionAdjustmentKind.receivableCollectionPrincipal) {
      continue;
    }
    parts.add(adjustmentSupportingLabel(adjustment));
  }
  return parts;
}

String adjustmentSupportingLabel(TransactionAdjustment adjustment) {
  final label = switch (adjustment.kind) {
    TransactionAdjustmentKind.transferFee => '手续费',
    TransactionAdjustmentKind.refund => '已退',
    TransactionAdjustmentKind.advanceReceived => '已到账',
    TransactionAdjustmentKind.receivableCollectionPrincipal => '本金',
    TransactionAdjustmentKind.receivableCollectionInterest => '利息',
    TransactionAdjustmentKind.repaymentInterest => '利息',
    TransactionAdjustmentKind.repaymentFee => '手续费',
    TransactionAdjustmentKind.repaymentDiscount => '优惠',
    TransactionAdjustmentKind.advanceCompensationIncome => '补偿',
    TransactionAdjustmentKind.advanceSelfBorne => '自承担',
    TransactionAdjustmentKind.advanceBadDebt => '坏账',
  };
  return '$label ${formatMoney(adjustment.amount.abs(), style: MoneyFormatStyle.compact)}';
}

Money? adjustmentAmount(
  TransactionReadModel item,
  TransactionAdjustmentKind kind,
) {
  for (final adjustment in transactionAdjustments(item)) {
    if (adjustment.kind == kind) return adjustment.amount;
  }
  return null;
}

List<TransactionAdjustment> transactionAdjustments(TransactionReadModel item) {
  if (item.parentTransactionId != null) return const [];
  final result = <TransactionAdjustment>[];
  void add(TransactionAdjustmentKind kind, Money amount) {
    if (amount.minorUnits > 0) {
      result.add(TransactionAdjustment(kind: kind, amount: amount));
    }
  }

  switch (item.businessPurpose) {
    case BusinessPurpose.transfer:
      add(
        TransactionAdjustmentKind.transferFee,
        item.amountOf(TransactionRole.fee),
      );
    case BusinessPurpose.dailyExpense:
      add(
        TransactionAdjustmentKind.refund,
        item.refundSummary?.refundedTotal ?? Money.zero(),
      );
    case BusinessPurpose.advance:
      add(
        TransactionAdjustmentKind.refund,
        item.refundSummary?.refundedTotal ?? Money.zero(),
      );
      add(
        TransactionAdjustmentKind.advanceReceived,
        item.advanceSummary?.receivedAmount ?? Money.zero(),
      );
      for (final child in item.children) {
        add(
          TransactionAdjustmentKind.advanceCompensationIncome,
          child.amountOf(TransactionRole.advanceCompensationIncome),
        );
        add(
          TransactionAdjustmentKind.advanceSelfBorne,
          child.amountOf(TransactionRole.advanceSelfBorne),
        );
        add(
          TransactionAdjustmentKind.advanceBadDebt,
          child.amountOf(TransactionRole.advanceBadDebtExpense),
        );
      }
    case BusinessPurpose.debtRepayment:
      add(
        TransactionAdjustmentKind.repaymentInterest,
        item.amountOf(TransactionRole.interest),
      );
      add(
        TransactionAdjustmentKind.repaymentFee,
        item.amountOf(TransactionRole.fee),
      );
      add(
        TransactionAdjustmentKind.repaymentDiscount,
        item.amountOf(TransactionRole.discount),
      );
    case BusinessPurpose.receivableCollection:
      add(
        TransactionAdjustmentKind.receivableCollectionPrincipal,
        item.amountOf(TransactionRole.receivable),
      );
      add(
        TransactionAdjustmentKind.receivableCollectionInterest,
        item.amountOf(TransactionRole.interest),
      );
    default:
      break;
  }
  return List.unmodifiable(result);
}
