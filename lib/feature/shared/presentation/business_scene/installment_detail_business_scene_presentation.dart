import 'package:smartflow/application/transaction_view/transaction_view_query_api.dart';
import 'package:smartflow/domain/credit/valobj/installment_enums.dart';

import 'transaction_detail_business_presentation.dart';

TransactionDetailBusinessContent presentInstallmentDetailBusinessScene(
  TransactionDetailContext context,
) {
  final owner =
      context.businessContext as InstallmentTransactionBusinessContext;
  final type = switch (owner.installmentType) {
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
            '$type · 已还 ${owner.paidPeriodCount}/${owner.totalPeriodCount} · '
            '剩余本金 ${owner.remainingPrincipal.format()}',
        route: '/installments/${owner.ownerId}',
      ),
    ],
  );
}
