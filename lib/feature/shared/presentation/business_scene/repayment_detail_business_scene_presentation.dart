import 'package:smartflow/application/transaction_view/transaction_view_query_api.dart';
import 'package:smartflow/domain/credit/valobj/repayment_enums.dart';

import 'transaction_detail_business_presentation.dart';

TransactionDetailBusinessContent presentRepaymentDetailBusinessScene(
  TransactionDetailReadModel detail,
) {
  final context = detail.context;
  final item = context.businessItem;
  final activity = detail.businessActivity;
  final summary = activity?.summary;
  if (item is! RepaymentBusinessActivityItem ||
      summary is! RepaymentBusinessActivitySummary ||
      activity == null) {
    return const TransactionDetailBusinessContent();
  }
  final route = switch (summary.targetType) {
    RepaymentTargetType.bill => '/bills/${item.targetId}',
    RepaymentTargetType.contract => '/installments/${item.targetId}',
    RepaymentTargetType.account => '/account/${item.targetId}',
  };
  return TransactionDetailBusinessContent(
    modules: [
      DetailBusinessModule.link(
        key: 'credit-repayment',
        title: '还款归属',
        summary: '${summary.repaymentType.label} · ${summary.targetType.label}',
        route: route,
      ),
    ],
  );
}
