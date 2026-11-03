import 'package:smartflow/application/transaction_view/transaction_view_query_api.dart';
import 'package:smartflow/domain/credit/valobj/repayment_enums.dart';

import 'business_scene_presentation.dart';
import 'transaction_adjustment_presentation.dart';

BusinessActivityRowContent presentRepaymentBusinessActivityRow(
  BusinessActivityReadModel item,
) {
  final summary = item.summary as RepaymentBusinessActivitySummary;
  return BusinessActivityRowContent(
    standardSummary: [
      _repaymentTypeLabel(summary.repaymentType),
      _repaymentTargetLabel(summary.targetType),
      ...adjustmentSupportingParts(item.anchorTransaction),
    ].join(' · '),
  );
}

String _repaymentTypeLabel(RepaymentType type) {
  return switch (type) {
    RepaymentType.bill => '账单还款',
    RepaymentType.installment => '分期还款',
    RepaymentType.prepayment => '提前还款',
    RepaymentType.unattributed => '未归属还款',
  };
}

String _repaymentTargetLabel(RepaymentTargetType type) {
  return switch (type) {
    RepaymentTargetType.bill => '账单',
    RepaymentTargetType.contract => '合同',
    RepaymentTargetType.account => '账户',
  };
}
