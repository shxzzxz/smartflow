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

String? businessActivityItemLabel(BusinessActivityItem? item) {
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
    AmortizationBusinessActivityItem(
      factKind: AmortizationTransactionFactKind.initial,
      :final kind,
    ) =>
      kind == AmortizationKind.prepaidExpense ? '摊销预付' : '摊销预收',
    AmortizationBusinessActivityItem(
      factKind: AmortizationTransactionFactKind.recognition,
      :final occurrencePeriodSequence,
    )
        when occurrencePeriodSequence != null =>
      '第 $occurrencePeriodSequence 期确认',
    AmortizationBusinessActivityItem(
      factKind: AmortizationTransactionFactKind.recognition,
    ) =>
      '摊销确认',
    AmortizationBusinessActivityItem(
      factKind: AmortizationTransactionFactKind.refund,
    ) =>
      '摊销退款',
    AmortizationBusinessActivityItem(
      factKind: AmortizationTransactionFactKind.terminationRecognition,
    ) =>
      '终止确认',
    AmortizationBusinessActivityItem(
      factKind: AmortizationTransactionFactKind.terminationReturn,
    ) =>
      '终止退还',
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
  return switch (item) {
    AmortizationBusinessActivityItem() => businessActivityItemLabel(item),
    InstallmentBusinessActivityItem() => businessActivityItemLabel(item),
    RepaymentBusinessActivityItem() => businessActivityItemLabel(item),
    _ => transactionPurposeLabel(transaction.businessPurpose),
  };
}

String? businessActivityEntrySupportingText(
  BusinessActivityItem? item,
  TransactionReadModel transaction,
) {
  if (!isKnownBusinessActivityItem(item) || !item!.isOrigin) return null;
  return businessActivityItemLabel(item);
}

TransactionAvatarKind? businessActivityItemAvatarKind(
  BusinessActivityItem? item,
) {
  return switch (item) {
    AdvanceBusinessActivityItem(:final factKind) => switch (factKind) {
      AdvanceTransactionFactKind.collection =>
        TransactionAvatarKind.advanceCollection,
      AdvanceTransactionFactKind.settlement =>
        TransactionAvatarKind.advanceSettlement,
      AdvanceTransactionFactKind.refund => TransactionAvatarKind.refund,
      AdvanceTransactionFactKind.advance => null,
    },
    AmortizationBusinessActivityItem(:final factKind) => switch (factKind) {
      AmortizationTransactionFactKind.recognition =>
        TransactionAvatarKind.amortizationRecognition,
      AmortizationTransactionFactKind.refund =>
        TransactionAvatarKind.amortizationRefund,
      AmortizationTransactionFactKind.terminationRecognition ||
      AmortizationTransactionFactKind.terminationReturn =>
        TransactionAvatarKind.amortizationTermination,
      AmortizationTransactionFactKind.initial => null,
    },
    RepaymentBusinessActivityItem(repaymentType: RepaymentType.prepayment) =>
      TransactionAvatarKind.prepayment,
    RepaymentBusinessActivityItem() => null,
    InstallmentBusinessActivityItem() ||
    UnknownBusinessActivityItem() ||
    null => null,
  };
}
