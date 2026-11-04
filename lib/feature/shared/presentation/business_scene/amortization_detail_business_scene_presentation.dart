import 'package:smartflow/application/transaction_view/transaction_view_query_api.dart';
import 'package:smartflow/domain/orchestration/valobj/amortization_enums.dart';

import 'transaction_detail_business_presentation.dart';

TransactionDetailBusinessContent presentAmortizationDetailBusinessScene(
  TransactionDetailReadModel detail,
) {
  final context = detail.context;
  final item = context.businessItem;
  final activity = detail.businessActivity;
  final summary = activity?.summary;
  final projection = context.transactionProjection;
  if (item is! AmortizationBusinessActivityItem ||
      projection is! AmortizationTransactionProjection ||
      projection.factKind != AmortizationTransactionFactKind.initial ||
      summary is! AmortizationBusinessActivitySummary ||
      activity == null) {
    return const TransactionDetailBusinessContent();
  }
  final type = switch (summary.kind) {
    AmortizationKind.prepaidExpense => '预付费用',
    AmortizationKind.deferredIncome => '递延收入',
  };
  final status = switch (summary.status) {
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
            '${summary.postedPeriodCount}/${summary.totalPeriodCount}',
        route: '/amortizations/${item.ownerId}',
      ),
    ],
  );
}
