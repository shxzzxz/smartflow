import 'package:smartflow/application/transaction_view/transaction_view_query_api.dart';

import 'advance_business_scene_presentation.dart';
import 'amortization_business_scene_presentation.dart';
import 'business_scene_presentation.dart';
import 'installment_business_scene_presentation.dart';
import 'ledger_business_scene_presentation.dart';
import 'repayment_business_scene_presentation.dart';

BusinessActivityRowContent presentBusinessSceneRowContent(
  BusinessActivityReadModel item,
) {
  return switch (businessSceneKindForBusinessActivity(item)) {
    BusinessSceneKind.ledger => presentLedgerBusinessActivityRow(item),
    BusinessSceneKind.advance => presentAdvanceBusinessActivityRow(item),
    BusinessSceneKind.installment => presentInstallmentBusinessActivityRow(
      item,
    ),
    BusinessSceneKind.repayment => presentRepaymentBusinessActivityRow(item),
    BusinessSceneKind.amortization => presentAmortizationBusinessActivityRow(
      item,
    ),
  };
}
