import 'package:smartflow/application/transaction_view/transaction_view_query_api.dart';
import 'package:smartflow/domain/orchestration/valobj/amortization_enums.dart';

import 'transaction_detail_business_presentation.dart';

TransactionDetailBusinessContent presentAmortizationDetailBusinessScene(
  TransactionDetailContext context,
) {
  final owner =
      context.businessContext as AmortizationTransactionBusinessContext;
  final type = switch (owner.kind) {
    AmortizationKind.prepaidExpense => '预付费用',
    AmortizationKind.deferredIncome => '递延收入',
  };
  final status = switch (owner.status) {
    AmortizationStatus.active => '进行中',
    AmortizationStatus.completed => '已完成',
    AmortizationStatus.terminated => '已终止',
  };
  return TransactionDetailBusinessContent(
    modules: [
      DetailBusinessModule.link(
        key: 'amortization',
        title: '摊销计划',
        summary:
            '$type · $status · 已确认 '
            '${owner.postedPeriodCount}/${owner.totalPeriodCount}',
        route: '/amortizations/${owner.ownerId}',
      ),
    ],
  );
}
