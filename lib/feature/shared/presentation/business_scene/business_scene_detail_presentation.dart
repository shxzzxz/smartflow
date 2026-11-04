import 'package:smartflow/application/transaction_view/transaction_view_query_api.dart';

import 'advance_detail_business_scene_presentation.dart';
import 'amortization_detail_business_scene_presentation.dart';
import 'installment_detail_business_scene_presentation.dart';
import 'repayment_detail_business_scene_presentation.dart';
import 'transaction_detail_business_presentation.dart';
import 'business_scene_presentation.dart';

TransactionDetailBusinessContent presentBusinessSceneDetailContent(
  TransactionDetailReadModel detail,
) {
  final context = detail.context;
  return switch (businessSceneKindForDetail(context)) {
    BusinessSceneKind.advance => presentAdvanceDetailBusinessScene(detail),
    BusinessSceneKind.installment => presentInstallmentDetailBusinessScene(
      detail,
    ),
    BusinessSceneKind.repayment => presentRepaymentDetailBusinessScene(detail),
    BusinessSceneKind.amortization => presentAmortizationDetailBusinessScene(
      detail,
    ),
    BusinessSceneKind.ledger => const TransactionDetailBusinessContent(),
  };
}
