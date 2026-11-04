import 'package:smartflow/application/ledger/ledger_query_api.dart';
import 'package:smartflow/application/transaction_view/transaction_view_query_api.dart';
import 'package:smartflow/domain/credit/valobj/installment_enums.dart';
import 'package:smartflow/domain/credit/valobj/repayment_enums.dart';
import 'package:smartflow/domain/orchestration/valobj/advance_enums.dart';
import 'package:smartflow/domain/orchestration/valobj/amortization_enums.dart';
import 'package:smartflow/widget/business/transaction/transaction_avatar_kind.dart';
import 'package:smartflow/widget/business/finance/finance_labels.dart';

bool isKnownBusinessActivityItem(BusinessActivityItem? item) =>
    item != null && item is! UnknownBusinessActivityItem;

String? businessActivityItemLabel(
  BusinessActivityItem? item, {
  BusinessActivityItemProjection? projection,
}) {
  final effectiveProjection =
      projection ??
      (item != null && item.projections.length == 1
          ? item.projections.single
          : null);
  final amortizationProjection =
      effectiveProjection is AmortizationTransactionProjection
      ? effectiveProjection
      : null;
  return switch (item) {
    AdvanceBusinessActivityItem(:final factKind) => switch (factKind) {
      AdvanceTransactionFactKind.advance => '垫付',
      AdvanceTransactionFactKind.collection => '垫付到账',
      AdvanceTransactionFactKind.refund => '退款',
      AdvanceTransactionFactKind.settlement => '垫付结清',
    },
    InstallmentBusinessActivityItem() => switch (item.factKind) {
      InstallmentTransactionFactKind.purchase => '消费分期',
      InstallmentTransactionFactKind.disbursement => '放款分期',
      InstallmentTransactionFactKind.refund => '分期退款',
    },
    RepaymentBusinessActivityItem(:final repaymentType) => repaymentType.label,
    AmortizationBusinessActivityItem(:final kind) =>
      switch (amortizationProjection?.factKind) {
        AmortizationTransactionFactKind.initial =>
          kind == AmortizationKind.prepaidExpense ? '摊销预付' : '摊销预收',
        AmortizationTransactionFactKind.recognition =>
          switch (amortizationProjection?.occurrencePeriodSequence) {
            final sequence? => '第 $sequence 期确认',
            null => '摊销确认',
          },
        AmortizationTransactionFactKind.refund => '摊销退款',
        AmortizationTransactionFactKind.terminationRecognition => '终止确认',
        AmortizationTransactionFactKind.terminationReturn => '终止退还',
        null => '摊销',
      },
    UnknownBusinessActivityItem() || null => null,
  };
}

String? nonEntryBusinessActivityItemTitle(
  BusinessActivityItem? item,
  TransactionReadModel transaction,
) {
  if (!isKnownBusinessActivityItem(item)) {
    return null;
  }
  if (item!.isOrigin) return null;
  final projection = item.projectionFor(transaction.id);
  return switch (item) {
    AmortizationBusinessActivityItem() => businessActivityItemLabel(
      item,
      projection: projection,
    ),
    InstallmentBusinessActivityItem() => businessActivityItemLabel(
      item,
      projection: projection,
    ),
    RepaymentBusinessActivityItem() => businessActivityItemLabel(
      item,
      projection: projection,
    ),
    _ => transactionPurposeLabel(transaction.businessPurpose),
  };
}

String? businessActivityEntrySupportingText(
  BusinessActivityItem? item,
  TransactionReadModel transaction,
) {
  if (!isKnownBusinessActivityItem(item) || !item!.isOrigin) return null;
  return businessActivityItemLabel(
    item,
    projection: item.projectionFor(transaction.id),
  );
}

TransactionAvatarKind? businessActivityItemAvatarKind(
  BusinessActivityItem? item, {
  BusinessActivityItemProjection? projection,
}) {
  final effectiveProjection =
      projection ??
      (item != null && item.projections.length == 1
          ? item.projections.single
          : null);
  final amortizationFactKind =
      effectiveProjection is AmortizationTransactionProjection
      ? effectiveProjection.factKind
      : null;
  return switch (item) {
    AdvanceBusinessActivityItem(:final factKind) => switch (factKind) {
      AdvanceTransactionFactKind.collection =>
        TransactionAvatarKind.advanceCollection,
      AdvanceTransactionFactKind.settlement =>
        TransactionAvatarKind.advanceSettlement,
      AdvanceTransactionFactKind.refund => TransactionAvatarKind.refund,
      AdvanceTransactionFactKind.advance => null,
    },
    AmortizationBusinessActivityItem() => switch (amortizationFactKind) {
      AmortizationTransactionFactKind.recognition =>
        TransactionAvatarKind.amortizationRecognition,
      AmortizationTransactionFactKind.refund =>
        TransactionAvatarKind.amortizationRefund,
      AmortizationTransactionFactKind.terminationRecognition ||
      AmortizationTransactionFactKind.terminationReturn =>
        TransactionAvatarKind.amortizationTermination,
      AmortizationTransactionFactKind.initial => null,
      null => null,
    },
    RepaymentBusinessActivityItem(repaymentType: RepaymentType.prepayment) =>
      TransactionAvatarKind.prepayment,
    RepaymentBusinessActivityItem() => null,
    InstallmentBusinessActivityItem() ||
    UnknownBusinessActivityItem() ||
    null => null,
  };
}
