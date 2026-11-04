import 'package:smartflow/application/transaction_view/transaction_view_query_api.dart';
import 'package:smartflow/domain/credit/valobj/installment_enums.dart';

import 'transaction_detail_business_presentation.dart';

TransactionDetailBusinessContent presentInstallmentDetailBusinessScene(
  TransactionDetailReadModel detail,
) {
  final context = detail.context;
  final item = context.businessItem;
  final activity = detail.businessActivity;
  final summary = activity?.summary;
  if (item is! InstallmentBusinessActivityItem ||
      summary is! InstallmentBusinessActivitySummary ||
      activity == null) {
    return const TransactionDetailBusinessContent();
  }
  if (item.factKind != InstallmentTransactionFactKind.purchase &&
      item.factKind != InstallmentTransactionFactKind.disbursement) {
    return const TransactionDetailBusinessContent();
  }
  final type = switch (summary.installmentType) {
    InstallmentType.disbursement => '放款分期',
    InstallmentType.billConversion => '账单分期',
    InstallmentType.purchase => '消费分期',
  };
  return TransactionDetailBusinessContent(
    modules: [
      DetailBusinessModule.link(
        key: 'installment',
        title: '分期合同',
        summary:
            '$type · 已还 ${summary.completedPeriodCount}/${summary.totalPeriodCount} · '
            '剩余本金 ${summary.remainingPrincipal.format()}',
        route: '/installments/${item.ownerId}',
      ),
    ],
  );
}
