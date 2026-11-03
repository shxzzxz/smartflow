import 'package:smartflow/application/transaction_view/transaction_view_query_api.dart';

import 'advance_business_scene_presentation.dart';
import 'amortization_business_scene_presentation.dart';
import 'business_scene_presentation.dart';
import 'installment_business_scene_presentation.dart';
import 'ledger_business_scene_presentation.dart';
import 'repayment_business_scene_presentation.dart';

BusinessItemRowContent presentBusinessSceneRowContent(
  BusinessItemReadModel item,
) {
  return switch (businessSceneKindForBusinessItem(item)) {
    BusinessSceneKind.ledger => presentLedgerBusinessItemRow(item),
    BusinessSceneKind.advance => presentAdvanceBusinessItemRow(item),
    BusinessSceneKind.installment => presentInstallmentBusinessItemRow(item),
    BusinessSceneKind.repayment => presentRepaymentBusinessItemRow(item),
    BusinessSceneKind.amortization => presentAmortizationBusinessItemRow(item),
  };
}
