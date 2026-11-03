import 'package:smartflow/application/transaction_view/transaction_view_query_api.dart';
import 'package:smartflow/domain/credit/valobj/repayment_enums.dart';

import 'transaction_detail_business_presentation.dart';

TransactionDetailBusinessContent presentRepaymentDetailBusinessScene(
  TransactionDetailContext context,
) {
  final owner = context.businessContext as RepaymentTransactionBusinessContext;
  final route = switch (owner.targetType) {
    RepaymentTargetType.bill => '/bills/${owner.targetId}',
    RepaymentTargetType.contract => '/installments/${owner.targetId}',
    RepaymentTargetType.account => '/account/${owner.targetId}',
  };
  return TransactionDetailBusinessContent(
    modules: [
      DetailBusinessModule.link(
        key: 'credit-repayment',
        title: '还款归属',
        summary: '${owner.repaymentType.label} · ${owner.targetType.label}',
        route: route,
      ),
    ],
  );
}
